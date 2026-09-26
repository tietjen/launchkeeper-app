//
//  VirusTotalHash.swift
//  AppCore — "Hash für VirusTotal kopieren": the SHA-256 of an entry's
//  program file, for a manual lookup on virustotal.com.
//
//  No network access: the app only computes the hash. The user pastes it
//  into VirusTotal's search, so nothing leaves the Mac without them doing it.
//

import Foundation
import CryptoKit
import LaunchKeeperKit

/// Which file of an entry is worth a VirusTotal lookup, and its SHA-256.
public enum VirusTotalHash {

    /// The program file to hash, or `nil` when the entry has none worth looking up.
    ///
    /// Only installed program code qualifies: a Mach-O binary, or the main
    /// executable of a bundle (app, extension, plug-in, kext). Configuration
    /// files (plists, shell profiles, crontab lines, paths.d) are edited by
    /// users and would only produce "unknown" results; Apple's own platform
    /// binaries (`/System`, `/usr`, `/bin`, `/sbin`) are skipped as known.
    /// - Parameters:
    ///   - item: The entry.
    ///   - fileManager: File access (tests use a temp tree).
    /// - Returns: Absolute path of the file to hash.
    public static func target(of item: BackgroundItem, fileManager: FileManager = .default) -> String? {
        // Behind a launcher (`arch -arm64 /opt/x/tool`) the real binary is the
        // one worth looking up, not /usr/bin/arch (which is Apple's anyway).
        let behindLauncher = item.metadata["runs-kind"] == EffectiveProgram.Kind.binary.rawValue
            ? item.metadata["runs-target"] : nil
        let candidates = [behindLauncher, SignatureCheck.target(of: item), item.executable].compactMap { $0 }
        for candidate in candidates {
            guard let file = programFile(candidate, fileManager: fileManager) else { continue }
            if PathUtils.isApplePlatformPath(PathUtils.canonicalize(file, fileManager: fileManager)) { return nil }
            return file
        }
        return nil
    }

    /// Resolves a path to the Mach-O file behind it.
    /// - Parameters:
    ///   - path: A file or a bundle directory.
    ///   - fileManager: File access.
    /// - Returns: The Mach-O file (a bundle's `CFBundleExecutable`), or `nil`.
    static func programFile(_ path: String, fileManager: FileManager) -> String? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return nil }
        if isDirectory.boolValue {
            // Bundles keep their executable name in Contents/Info.plist
            // (macOS layout) or Info.plist at the top (flat bundles).
            for plist in [path + "/Contents/Info.plist", path + "/Info.plist"] {
                guard let data = fileManager.contents(atPath: plist),
                      let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      let name = dict["CFBundleExecutable"] as? String else { continue }
                let base = plist.hasSuffix("/Contents/Info.plist") ? path + "/Contents/MacOS/" : path + "/"
                return isMachO(base + name, fileManager: fileManager) ? base + name : nil
            }
            return nil
        }
        return isMachO(path, fileManager: fileManager) ? path : nil
    }

    /// Whether a file starts with a Mach-O or universal ("fat") magic number.
    ///
    /// Scripts (`#!/bin/sh`) and data files are excluded this way — a script
    /// is a user-editable text, not an installed program build.
    static func isMachO(_ path: String, fileManager: FileManager) -> Bool {
        guard let handle = FileHandle(forReadingAtPath: path),
              let head = try? handle.read(upToCount: 4), head.count == 4 else { return false }
        try? handle.close()
        let magic = head.withUnsafeBytes { $0.load(as: UInt32.self) }
        // Little-endian reads of: MH_MAGIC, MH_MAGIC_64, their byte-swapped
        // forms, and FAT_MAGIC / FAT_MAGIC_64 (stored big-endian).
        let known: Set<UInt32> = [0xFEEDFACE, 0xFEEDFACF, 0xCEFAEDFE, 0xCFFAEDFE, 0xBEBAFECA, 0xBFBAFECA]
        return known.contains(magic)
    }

    /// SHA-256 of a file as lowercase hex, computed off the main thread in 1 MB chunks.
    /// - Parameter path: The file.
    /// - Returns: 64 hex characters, or `nil` when the file cannot be read.
    public static func sha256(of path: String) async -> String? {
        await Task.detached(priority: .userInitiated) { () -> String? in
            guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
            defer { try? handle.close() }
            var hasher = SHA256()
            do {
                // `read(upToCount:)` answers nil at the end of the file.
                while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
            } catch {
                return nil
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }.value
    }
}
