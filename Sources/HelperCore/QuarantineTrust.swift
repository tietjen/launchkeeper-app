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
            }
            if let problem = verifyChain(directory, from: "/", trustedUID: 0) { return problem }
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
    /// Defense in depth — the store's chain is root-owned, so nothing below
    /// it can have been swapped by the user: the entry directory, its
    /// manifest and every path from the entry down to each quarantined item
    /// must belong to `trustedUID`, be no symlink, and (directories) be
    /// writable by nobody else.
    /// - Parameters:
    ///   - root: The quarantine root (the helper: `LaunchKeeperPaths.systemQuarantine`).
    ///   - name: The entry name (one path component).
    ///   - quarantinedPaths: The entry's quarantined paths and receipt copies from its manifest.
    ///   - trustedUID: The only owner accepted (root; tests use their own uid).
    /// - Returns: `nil` when trustworthy, else the reason.
    public static func verifyEntry(root: String, name: String, quarantinedPaths: [String],
                                   trustedUID: uid_t = 0) -> String? {
        guard QuarantineStore.isValidName(name) else { return "invalid entry name" }
        let entry = root + "/" + name
        if let problem = owned(entry, directory: true, by: trustedUID) { return problem }
        if let problem = owned(entry + "/manifest.json", directory: false, by: trustedUID) { return problem }
        for path in quarantinedPaths {
            guard path.hasPrefix(entry + "/") else { return "a quarantined path lies outside the entry" }
            var walked = entry
            let parts = path.dropFirst(entry.count + 1).split(separator: "/").map(String.init)
            guard !parts.contains(where: { $0 == ".." || $0 == "." }) else { return "relative components in a quarantined path" }
            for part in parts {
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
