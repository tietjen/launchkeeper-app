//
//  QuarantineTrust.swift
//  HelperCore — what the helper (root) may trust in the user's quarantine.
//
//  The quarantine lives in the user's home, which every process of that user
//  can change. Review 2026-09-27 (Fable) found two ways to root:
//   1. `handOver` chowned paths below the quarantine as root; a symlink put
//      there by any user process redirected the chown onto e.g. /Library.
//   2. A restore moved back, as root, whatever the entry held, to whatever
//      its (user-owned) manifest named — a swapped file or target path
//      would land anywhere as root, after one legitimate Touch ID.
//  Now: the helper never chowns into the home; entries it creates stay
//  root-owned (readable, not changeable by the user); a restore or purge as
//  root requires the entry, its manifest and every path below it to be
//  root-owned real files/directories. Directory chains are walked with file
//  descriptors and O_NOFOLLOW, never by path strings.
//

import Foundation
import Darwin

/// Checks and prepares quarantine paths for root.
public enum QuarantineTrust {

    /// Makes sure the quarantine root exists as a chain of real directories
    /// below the client's home, owned by the client.
    ///
    /// Missing directories are created (and given to the client) through
    /// directory descriptors; an existing component that is a symlink, not a
    /// directory, or owned by someone else stops the helper.
    /// - Parameters:
    ///   - root: The quarantine root (must lie inside `client.home`).
    ///   - client: The calling user.
    /// - Returns: `nil` when the chain is safe, else the reason.
    public static func prepareRoot(_ root: String, for client: ClientContext) -> String? {
        let home = client.home.hasSuffix("/") ? String(client.home.dropLast()) : client.home
        guard root.hasPrefix(home + "/") else { return "quarantine root outside the home" }
        let components = root.dropFirst(home.count + 1).split(separator: "/").map(String.init)
        guard !components.contains(where: { $0 == ".." || $0 == "." || $0.isEmpty }) else {
            return "quarantine root with relative components"
        }

        var current = open(home, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard current >= 0 else { return "cannot open the home safely" }
        var homeInfo = stat()
        guard fstat(current, &homeInfo) == 0, Int(homeInfo.st_uid) == client.uid else {
            close(current); return "the home does not belong to the client"
        }
        let group = homeInfo.st_gid
        for component in components {
            var next = openat(current, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
            if next < 0 && errno == ENOENT {
                guard mkdirat(current, component, 0o755) == 0 || errno == EEXIST else {
                    close(current); return "cannot create \(component)"
                }
                next = openat(current, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
                if next >= 0 {
                    var created = stat()
                    // Only a directory root just made (owner root) is handed to the client.
                    if fstat(next, &created) == 0, created.st_uid == 0 {
                        _ = fchown(next, uid_t(client.uid), group)
                    }
                }
            }
            close(current)
            guard next >= 0 else { return "\(component) is not a real directory (symlink?)" }
            var info = stat()
            guard fstat(next, &info) == 0, Int(info.st_uid) == client.uid else {
                close(next); return "\(component) does not belong to the client"
            }
            current = next
        }
        close(current)
        return nil
    }

    /// Whether root may restore or purge a quarantine entry.
    ///
    /// The entry directory, its manifest and every path from the entry down
    /// to each quarantined item must be root-owned and no symlink — then no
    /// process of the user can have changed what root is about to move or
    /// delete. Entries a pre-0.1.7 helper handed over to the user fail this
    /// check on purpose: their content can no longer be proven.
    /// - Parameters:
    ///   - root: The quarantine root.
    ///   - name: The entry name (one path component).
    ///   - quarantinedPaths: The entry's quarantined paths from its manifest.
    /// - Returns: `nil` when trustworthy, else the reason.
    public static func verifyEntry(root: String, name: String, quarantinedPaths: [String]) -> String? {
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else { return "invalid entry name" }
        let entry = root + "/" + name
        if let problem = rootOwned(entry, directory: true) { return problem }
        if let problem = rootOwned(entry + "/manifest.json", directory: false) { return problem }
        for path in quarantinedPaths {
            guard path.hasPrefix(entry + "/files/") else { return "a quarantined path lies outside the entry" }
            var walked = entry
            let parts = path.dropFirst(entry.count + 1).split(separator: "/").map(String.init)
            guard !parts.contains(where: { $0 == ".." || $0 == "." }) else { return "relative components in a quarantined path" }
            for part in parts {
                walked += "/" + part
                var info = stat()
                guard lstat(walked, &info) == 0 else { continue }   // already restored / gone: the engine decides
                if (info.st_mode & S_IFMT) == S_IFLNK { return "symlink inside the entry: \(walked)" }
                if info.st_uid != 0 { return "not root-owned: \(walked)" }
            }
        }
        return nil
    }

    /// A path that must be a root-owned directory or regular file, no symlink.
    private static func rootOwned(_ path: String, directory: Bool) -> String? {
        var info = stat()
        guard lstat(path, &info) == 0 else { return "missing: \(path)" }
        let type = info.st_mode & S_IFMT
        if type == S_IFLNK { return "symlink: \(path)" }
        if type != (directory ? S_IFDIR : S_IFREG) { return "unexpected file type: \(path)" }
        if info.st_uid != 0 {
            return "owned by the user, not root: \(path) — handed over by an older helper; its content cannot be "
                + "proven any more, so it is not restored with administrator rights (check it and move it back by hand)"
        }
        return nil
    }
}
