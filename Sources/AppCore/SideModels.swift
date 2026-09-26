import Foundation
import Observation
import LaunchKeeperKit

/// Moves a value that is built once off the main thread and never mutated.
struct Carry<T>: @unchecked Sendable { let value: T }

/// "App-Reste": what gone apps left behind (V0.8.2). Loaded on demand — the
/// presence check asks LaunchServices and Spotlight per candidate (~30 s).
@MainActor
@Observable
public final class LeftoversModel {
    public private(set) var candidates: [AppLeftoverCandidate] = []
    public private(set) var isLoading = false
    public private(set) var loaded = false
    public var showAll = false

    private let load: @Sendable () -> [AppLeftoverCandidate]

    /// `sources` comes from the app (LaunchServices via NSWorkspace — AppKit
    /// stays out of AppCore).
    public init(sources: @escaping @Sendable () -> AppPresenceSources) {
        load = { AppLeftoverScanner().scan(sources: sources()) }
    }

    public init(loader: @escaping @Sendable () -> [AppLeftoverCandidate]) {
        load = loader
    }

    public func reload() async {
        guard !isLoading else { return }
        isLoading = true
        let load = self.load
        candidates = await Task.detached(priority: .userInitiated) { Carry(value: load()) }.value.value
        isLoading = false
        loaded = true
    }

    public var visible: [AppLeftoverCandidate] {
        showAll ? candidates : candidates.filter { $0.presence.label == "gone" }
    }

    public var goneCount: Int { candidates.filter { $0.presence.label == "gone" }.count }
}

/// "Quarantäne": what cleanup took away and can bring back (V0.8).
@MainActor
@Observable
public final class QuarantineModel {
    public private(set) var entries: [QuarantineManifest] = []
    private let store: QuarantineStore

    public init(root: String = LaunchKeeperPaths.quarantine(home: NSHomeDirectory())) {
        store = QuarantineStore(root: root)
    }

    public func reload() { entries = store.list() }

    public func directory(of entry: QuarantineManifest) -> String { store.directory(entry.name) }
}

/// Signature in depth for one entry (V0.6.2 `inspect --verify`), on demand.
public enum SignatureCheck {
    public static func verify(path: String,
                              runner: CommandRunner = SystemCommandRunner()) async -> SignatureVerification {
        let runner = Carry(value: runner)
        return await Task.detached(priority: .userInitiated) {
            Carry(value: SignatureVerifier(runner: runner.value).verify(path: path))
        }.value.value
    }

    /// What to verify: the executable, or the bundle for bundle-signed types.
    public static func target(of item: BackgroundItem) -> String? {
        let bundleTypes: Set<ItemType> = [.systemExtension, .kernelExtension, .plugin, .appExtension]
        if bundleTypes.contains(item.type), let path = item.path { return path }
        return item.executable ?? item.path
    }
}
