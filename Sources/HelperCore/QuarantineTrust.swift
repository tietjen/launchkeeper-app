//
//  QuarantineTrust.swift
//  HelperCore — where root keeps its bookkeeping, and what it may trust.
//
//  Three independent reviews (Fable, 2026-09-27) led here:
//   1. `handOver` chowned paths below the user's quarantine as root; a
//      symlink placed there redirected the chown onto a system directory.
//   2. A restore moved back, as root, what a user-owned entry held to where
//      its user-owned manifest pointed.
//   3. Checking first and writing later by path is not enough while ANY
//      directory on the way belongs to the user: `rename` needs only write
//      access to the parent, so a checked entry (or a backup directory in
//      the making) can be swapped between root's check and root's write.
//  So root keeps nothing in the home. Quarantine, backups and config
//  snapshots of the helper live under /Library/Application Support/
//  launchkeeper — a chain that belongs to root and is writable by nobody
//  else, created and checked here before every request. Entries in the
//  user's quarantine (the CLI's, or handed over by helpers before 0.1.7)
//  are never restored or purged by the helper.
//

import Foundation
import Darwin
import LaunchKeeperKit

/// Checks and prepares the root-owned bookkeeping tree.
public enum QuarantineTrust {

    /// The helper's bookkeeping directories (quarantine, backups, config snapshots).
    public static let systemDirectories = [LaunchKeeperPaths.systemQuarantine, LaunchKeeperPaths.systemBackups,
                                           LaunchKeeperPaths.systemConfigSnapshots]

    /// Creates the helper's bookkeeping directories when missing and checks
    /// the whole chain from `/`: real directories, owned by root, writable
    /// by nobody else. Only root calls this (the helper).
    /// - Returns: `nil` when safe, else the reason.
    public static func prepareSystemDirectories() -> String? {
        for directory in systemDirectories {
            var path = ""
            for component in directory.split(separator: "/") {
                path += "/" + component
                if mkdir(path, 0o755) != 0 && errno != EEXIST { return "cannot create \(path)" }
                // Our own directories (launchkeeper and below) that belong to root
                // but carry other modes (e.g. made under a 077 umask) are repaired:
                // root-owned means nobody else can have put them there.
                if path.hasPrefix(LaunchKeeperPaths.systemRoot) {
                    var info = stat()
                    if lstat(path, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR, info.st_uid == 0,
                       info.st_mode & 0o777 != 0o755 {
                        _ = chmod(path, 0o755)
                    }
                }
            }
            if let problem = verifyChain(directory, from: "/", trustedUID: 0) {
                return problem + " — fix in Terminal: sudo chown -R root:wheel '\(LaunchKeeperPaths.systemRoot)' "
                    + "&& sudo chmod -R go-w '\(LaunchKeeperPaths.systemRoot)'"
            }
        }
        return nil
    }

    /// Checks every component of `path` below `base`: exists, is a directory,
    /// no symlink, owned by `trustedUID` (the system chain: root), not
    /// writable by group or others.
    /// - Parameters:
    ///   - path: The directory to check.
    ///   - base: Where the check starts (the system chain: `/`).
    ///   - trustedUID: The only owner accepted.
    /// - Returns: `nil` when the chain is safe, else the reason.
    public static func verifyChain(_ path: String, from base: String, trustedUID: uid_t) -> String? {
        let trimmedBase = base == "/" ? "" : base
        guard path.hasPrefix(trimmedBase + "/") else { return "\(path) is not below \(base)" }
        var walked = trimmedBase
        for component in path.dropFirst(trimmedBase.count + 1).split(separator: "/") {
            guard component != ".." && component != "." else { return "relative component in \(path)" }
            walked += "/" + component
            var info = stat()
            guard lstat(walked, &info) == 0 else { return "missing: \(walked)" }
            let type = info.st_mode & S_IFMT
            if type == S_IFLNK { return "symlink: \(walked)" }
            if type != S_IFDIR { return "not a directory: \(walked)" }
            // /Library/Application Support is root:admin — the group may own, not write.
            if info.st_uid != trustedUID { return "not owned by \(trustedUID == 0 ? "root" : "the trusted user"): \(walked)" }
            if info.st_mode & (S_IWGRP | S_IWOTH) != 0 { return "writable by group or others: \(walked)" }
        }
        return nil
    }

    /// Whether root may restore or purge a quarantine entry of the root-owned store.
    ///
    /// Defense in depth — only the helper writes that store. Ownership: the
    /// entry directory, its manifest and every path from the entry down to
    /// each quarantined item belong to `trustedUID`, are no symlink, and
    /// (directories) are writable by nobody else. Meaning (review 2026-09-27):
    /// every move goes from exactly `entry/files` + its original back to that
    /// original; originals are absolute, without `.`/`..`, never under
    /// /System and never in the client's home (root does not write there);
    /// receipt copies are exactly `entry/receipt/<package>.bom|.plist`.
    /// - Parameters:
    ///   - root: The quarantine root (the helper: `LaunchKeeperPaths.systemQuarantine`).
    ///   - manifest: The entry's manifest.
    ///   - clientHome: The calling user's home (restores never go there as root).
    ///   - trustedUID: The only owner accepted (root; tests use their own uid).
    /// - Returns: `nil` when trustworthy, else the reason.
    public static func verifyEntry(root: String, manifest: QuarantineManifest, clientHome: String,
                                   trustedUID: uid_t = 0) -> String? {
        let name = manifest.name
        guard QuarantineStore.isValidName(name) else { return "invalid entry name" }
        let entry = root + "/" + name
        if let problem = owned(entry, directory: true, by: trustedUID) { return problem }
        if let problem = owned(entry + "/manifest.json", directory: false, by: trustedUID) { return problem }
        let home = clientHome.hasSuffix("/") ? String(clientHome.dropLast()) : clientHome
        for move in manifest.moves {
            let original = move.original
            guard original.hasPrefix("/"), !original.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else {
                return "original is not a clean absolute path: \(original)"
            }
            if original == "/System" || original.hasPrefix("/System/") { return "original under /System: \(original)" }
            if original == home || original.hasPrefix(home + "/") {
                return "original in your home — root does not write there; restore it in Terminal: "
                    + "launchkeeper quarantine restore \(name)"
            }
            // The way back must not run through a place users can change (review S2).
            if CleanupEnvironment.userWritablePrefixes.contains(where: { original.hasPrefix($0) })
                || PathUtils.userWritableAncestor(of: original) != nil {
                return "original lies where users can write (\(original)) — root does not move files there; "
                    + "restore it in Terminal: launchkeeper quarantine restore \(name)"
            }
            guard move.quarantined == entry + "/files" + original else {
                return "quarantined path does not match its original: \(move.quarantined)"
            }
        }
        if !manifest.receiptCopies.isEmpty {
            // The same rule the uninstall gate applies to package ids (no path
            // tricks), not the stricter quarantine-name rule (review C-3).
            guard let package = manifest.packageIdentifier, !package.isEmpty, !package.contains("/"),
                  !package.contains(".."), !package.hasPrefix("-"), !package.hasPrefix(".") else {
                return "receipt copies without a valid package id"
            }
            let allowed = Set([".bom", ".plist"].map { entry + "/receipt/" + package + $0 })
            guard manifest.receiptCopies.allSatisfy(allowed.contains) else { return "unexpected receipt copy path" }
        }
        // The chain the helper made (files/…, receipt/) must be root's; the moved
        // object itself is what it was at its place — its owner and type are
        // kept by the rename (a vendor file owned by a user, a symlink from a
        // package). It sits in a root-owned directory nobody else can write,
        // so it cannot be swapped (review 2026-09-27, S-A).
        for path in manifest.moves.map(\.quarantined) + manifest.receiptCopies {
            var walked = entry
            for part in path.dropFirst(entry.count + 1).split(separator: "/").dropLast().map(String.init) {
                walked += "/" + part
                var info = stat()
                guard lstat(walked, &info) == 0 else { break }   // already restored or gone: the engine reports it
                if (info.st_mode & S_IFMT) == S_IFLNK { return "symlink inside the entry: \(walked)" }
                if info.st_uid != trustedUID { return "foreign owner inside the entry: \(walked)" }
                if (info.st_mode & S_IFMT) == S_IFDIR && info.st_mode & (S_IWGRP | S_IWOTH) != 0 {
                    return "writable by group or others: \(walked)"
                }
            }
        }
        return nil
    }

    /// A path that must be a directory or regular file of `uid`, no symlink.
    private static func owned(_ path: String, directory: Bool, by uid: uid_t) -> String? {
        var info = stat()
        guard lstat(path, &info) == 0 else { return "missing: \(path)" }
        let type = info.st_mode & S_IFMT
        if type == S_IFLNK { return "symlink: \(path)" }
        if type != (directory ? S_IFDIR : S_IFREG) { return "unexpected file type: \(path)" }
        if info.st_uid != uid { return "foreign owner: \(path)" }
        if directory && info.st_mode & (S_IWGRP | S_IWOTH) != 0 { return "writable by group or others: \(path)" }
        return nil
    }
}
