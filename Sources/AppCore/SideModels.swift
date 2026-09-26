//
//  SideModels.swift
//  AppCore — state of the dedicated views beside the inventory table.
//
//  Each model loads its data off the main thread and exposes plain values
//  for SwiftUI. None of them writes anything: Phase 2 is read-only.
//

import Foundation
import Observation
import LaunchKeeperKit

/// Carries a value from a detached task to the main actor.
///
/// Used for kit types that are not `Sendable` (`AppLeftoverCandidate`,
/// `SignatureVerification`, a `CommandRunner`). Every carried value is
/// built once and never mutated afterwards, which makes the unchecked
/// conformance safe.
struct Carry<T>: @unchecked Sendable {
    /// The carried value.
    let value: T
}

// MARK: - App leftovers

/// State of the "App-Reste" view: what apps left behind after they were
/// deleted (CLI V0.8.2, `launchkeeper leftovers`).
///
/// Loaded on demand, not with every scan: the presence check asks
/// LaunchServices and Spotlight for each candidate and takes about 30 s.
@MainActor
@Observable
public final class LeftoversModel {
    /// Every checked bundle id with its verdict (gone, present, unknown, no app evidence).
    public private(set) var candidates: [AppLeftoverCandidate] = []
    /// `true` while a check runs.
    public private(set) var isLoading = false
    /// `true` once a check has finished — the view loads on first appearance only.
    public private(set) var loaded = false
    /// Shows every verdict instead of only "gone" — for checking why an entry is not offered.
    public var showAll = false

    private let load: @Sendable () -> [AppLeftoverCandidate]

    /// Creates the model for the real Mac.
    /// - Parameter sources: Builds the presence sources. The app supplies
    ///   them because LaunchServices and the running apps come from
    ///   `NSWorkspace` — AppKit stays out of AppCore.
    public init(sources: @escaping @Sendable () -> AppPresenceSources) {
        load = { AppLeftoverScanner().scan(sources: sources()) }
    }

    /// Creates the model with a fixed loader (tests, previews).
    /// - Parameter loader: Returns the candidates; called off the main thread.
    public init(loader: @escaping @Sendable () -> [AppLeftoverCandidate]) {
        load = loader
    }

    /// Runs the check again. A call while one runs is ignored.
    public func reload() async {
        guard !isLoading else { return }
        isLoading = true
        let load = self.load
        candidates = await Task.detached(priority: .userInitiated) { Carry(value: load()) }.value.value
        isLoading = false
        loaded = true
    }

    /// What the list shows: only apps that are provably gone, unless `showAll` is on.
    public var visible: [AppLeftoverCandidate] {
        showAll ? candidates : candidates.filter { $0.presence.label == "gone" }
    }

    /// Number of candidates whose app is provably gone.
    public var goneCount: Int { candidates.filter { $0.presence.label == "gone" }.count }
}

// MARK: - Quarantine

/// State of the "Quarantäne" view: what cleanup moved away and can bring
/// back (CLI V0.8, `launchkeeper quarantine list`).
@MainActor
@Observable
public final class QuarantineModel {
    /// The quarantine entries, newest first.
    public private(set) var entries: [QuarantineManifest] = []
    private let store: QuarantineStore

    /// Creates the model.
    /// - Parameter root: The quarantine directory; defaults to the CLI's
    ///   (`~/Library/Application Support/launchkeeper/quarantine`), so the
    ///   app and the CLI see the same entries.
    public init(root: String = LaunchKeeperPaths.quarantine(home: NSHomeDirectory())) {
        store = QuarantineStore(root: root)
    }

    /// Reads the manifests again. Cheap (one JSON file per entry), so it runs on the main actor.
    public func reload() { entries = store.list() }

    /// The folder of one entry, for "Reveal in Finder".
    /// - Parameter entry: A listed entry.
    /// - Returns: The entry's directory inside the quarantine root.
    public func directory(of entry: QuarantineManifest) -> String { store.directory(entry.name) }
}

// MARK: - Signature in depth

/// Signature in depth for one entry, on demand (CLI V0.6.2, `inspect --verify`).
///
/// Not part of the scan: `codesign --verify --strict` and `spctl` cost
/// about a third of a second per path — fine for one entry, too slow for
/// hundreds.
public enum SignatureCheck {
    /// Verifies one file or bundle off the main thread.
    /// - Parameters:
    ///   - path: What to verify — see `target(of:)`.
    ///   - runner: Runs `codesign`/`spctl`; tests inject a stub.
    /// - Returns: Seal, identity, Gatekeeper verdict, authority chain and SHA-256.
    public static func verify(path: String,
                              runner: CommandRunner = SystemCommandRunner()) async -> SignatureVerification {
        let runner = Carry(value: runner)
        return await Task.detached(priority: .userInitiated) {
            Carry(value: SignatureVerifier(runner: runner.value).verify(path: path))
        }.value.value
    }

    /// The path to verify for an entry.
    ///
    /// Extensions, kexts and plug-ins are signed as a whole bundle, so the
    /// bundle path is verified; for everything else the executable.
    /// - Parameter item: The entry.
    /// - Returns: The path, or `nil` when the entry has neither.
    public static func target(of item: BackgroundItem) -> String? {
        let bundleTypes: Set<ItemType> = [.systemExtension, .kernelExtension, .plugin, .appExtension]
        if bundleTypes.contains(item.type), let path = item.path { return path }
        return item.executable ?? item.path
    }
}
