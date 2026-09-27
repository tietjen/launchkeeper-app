//
//  PrivilegedExecutor.swift
//  HelperCore — executes privileged requests (one, or a batch) with the CLI's engines.
//
//  Runs inside the helper (root). The request carries only an operation and
//  a target name; the executor resolves everything itself: the calling
//  user's uid and home come from the XPC connection, the entry from its own
//  scan, the plan from the same gate and engines the CLI uses.
//

import Foundation
import HelperShared
import LaunchKeeperKit

/// The calling user, as the XPC connection reports it — never as the client claims.
public struct ClientContext: Equatable, Sendable {
    /// The client's effective user id.
    public var uid: Int
    /// The client's home directory, from the user database.
    public var home: String

    /// Creates a context.
    public init(uid: Int, home: String) {
        self.uid = uid
        self.home = home
    }

    /// Looks up the home directory of a uid in the user database.
    /// - Parameter uid: The connection's effective uid.
    /// - Returns: The context, or `nil` for root or unknown users.
    public static func forUID(_ uid: uid_t) -> ClientContext? {
        guard uid != 0, let entry = getpwuid(uid), let dir = entry.pointee.pw_dir else { return nil }
        return ClientContext(uid: Int(uid), home: String(cString: dir))
    }
}

/// Where the helper keeps quarantine, backups and config snapshots.
///
/// In production the root-owned tree under /Library/Application Support/
/// launchkeeper (`system`); tests point it at a temp directory and their own uid.
public struct Bookkeeping: Sendable {
    /// Quarantine entries the helper creates, restores and purges.
    public var quarantine: String
    /// Launch-dir snapshots before removals.
    public var backups: String
    /// Config-source snapshots (crontab, loginwindow).
    public var configSnapshots: String
    /// The only owner trusted inside the tree.
    public var trustedUID: uid_t
    /// Creates the directories when missing and checks the chain; `nil` = safe.
    public var prepare: @Sendable () -> String?

    /// Creates a bookkeeping description.
    public init(quarantine: String, backups: String, configSnapshots: String, trustedUID: uid_t,
                prepare: @escaping @Sendable () -> String?) {
        self.quarantine = quarantine; self.backups = backups; self.configSnapshots = configSnapshots
        self.trustedUID = trustedUID; self.prepare = prepare
    }

    /// The root-owned tree (review 2026-09-27: root keeps nothing in a user's home).
    public static let system = Bookkeeping(
        quarantine: LaunchKeeperPaths.systemQuarantine, backups: LaunchKeeperPaths.systemBackups,
        configSnapshots: LaunchKeeperPaths.systemConfigSnapshots, trustedUID: 0,
        prepare: { QuarantineTrust.prepareSystemDirectories() })
}

/// Executes privileged requests (always with `--apply` semantics — the plan
/// was shown to the user by the app before they authenticated).
public struct PrivilegedExecutor {
    /// Runs the engines' commands as root.
    public var runner: CommandRunner
    /// The helper's own Background Task Management dump cache (reused between requests).
    public var btmCache: BTMDumpCache
    /// Where the helper writes its audit lines. Root-owned, readable by admins.
    public var auditDirectory: String
    /// File-system access (tests use a temp tree).
    public var fileManager: FileManager
    /// Where quarantine, backups and config snapshots go — never the user's home.
    public var bookkeeping: Bookkeeping

    /// Creates the executor.
    public init(runner: CommandRunner = RootRunner(), btmCache: BTMDumpCache = BTMDumpCache(),
                auditDirectory: String = "/Library/Logs/launchkeeper", fileManager: FileManager = .default,
                bookkeeping: Bookkeeping = .system) {
        self.bookkeeping = bookkeeping
        self.runner = runner
        self.btmCache = btmCache
        self.auditDirectory = auditDirectory
        self.fileManager = fileManager
    }

    /// Executes one request for one client.
    /// - Parameters:
    ///   - request: What to do.
    ///   - client: Who asked (from the connection).
    /// - Returns: The engines' result.
    public func perform(_ request: PrivilegedRequest, client: ClientContext) -> PrivilegedOutcome {
        if let problem = request.validationError() { return .error(problem) }
        if let problem = bookkeeping.prepare() {
            return PrivilegedOutcome(state: "refused", detail: "unsafe bookkeeping directory: \(problem)")
        }
        btmCache.preferCached = true
        switch request.kind {
        case .disable, .enable, .remove, .removeWorking:
            let operation: RemediationOperation = request.kind == .disable ? .disable
                : request.kind == .enable ? .enable : .remove
            let result = remediationEngine(for: client).run(operation: operation, target: request.target, apply: true,
                                                            allowWorking: request.kind == .removeWorking)
            return Self.outcome(result.status, plan: result.plan, messages: result.messages, undo: result.undoHint)
        case .restore, .purge, .uninstall:
            return performCleanup(request, client: client)
        }
    }

    /// The remediation engine as root: the client's uid and home for resolving
    /// entries, the root-owned tree for everything the engine writes.
    func remediationEngine(for client: ClientContext) -> RemediationEngine {
        RemediationEngine(environment: RemediationEnvironment(
            runner: runner, fileManager: fileManager, home: client.home, uid: client.uid,
            // Only the system launch dirs: removals and their snapshots as root
            // never touch the user's own LaunchAgents (review 2026-09-27, B4).
            launchDirs: Self.systemLaunchDirs, systemDirPrefixes: Self.systemLaunchDirs,
            backupsRoot: bookkeeping.backups, configSnapshotsRoot: bookkeeping.configSnapshots,
            quarantineRoot: bookkeeping.quarantine, systemQuarantineRoot: bookkeeping.quarantine,
            btmCache: btmCache), audit: AuditLog(directory: auditDirectory))
    }

    /// The launch directories the helper removes from and snapshots.
    static let systemLaunchDirs = ["/Library/LaunchAgents", "/Library/LaunchDaemons"]

    /// Restore, purge or uninstall — restore and purge only for trusted
    /// entries of the root-owned store, checked right before the engine runs.
    func performCleanup(_ request: PrivilegedRequest, client: ClientContext) -> PrivilegedOutcome {
        if request.kind == .restore || request.kind == .purge, let refusal = entryRefusal(request.target, client: client) {
            return refusal
        }
        let engine = CleanupEngine(environment: CleanupEnvironment(
            runner: runner, disk: DiskView(fileManager: fileManager), home: client.home,
            quarantineRoot: bookkeeping.quarantine, systemQuarantineRoot: bookkeeping.quarantine),
            audit: AuditLog(directory: auditDirectory))
        let result: CleanupResult
        switch request.kind {
        case .restore: result = engine.restore(name: request.target, apply: true)
        case .purge: result = engine.purge(name: request.target, apply: true)
        default: result = engine.uninstall(packageIdentifier: request.target, apply: true, verifyAsRoot: true)
        }
        return Self.outcome(result.status, plan: result.plan, messages: result.messages, undo: result.undoHint)
    }

    /// Why root must not restore or purge an entry — `nil` when it may.
    ///
    /// Only entries of the root-owned store qualify (defense in depth:
    /// `QuarantineTrust.verifyEntry`). An entry in the user's quarantine —
    /// made by the CLI, or handed over by a helper before 0.1.7 — is refused
    /// with the way that still works: the terminal.
    func entryRefusal(_ name: String, client: ClientContext) -> PrivilegedOutcome? {
        let store = QuarantineStore(root: bookkeeping.quarantine, fileManager: fileManager)
        guard QuarantineStore.isValidName(name), let manifest = store.load(name) else {
            let userManifest = LaunchKeeperPaths.quarantine(home: client.home) + "/" + name + "/manifest.json"
            if QuarantineStore.isValidName(name), fileManager.fileExists(atPath: userManifest) {
                return PrivilegedOutcome(state: "refused", detail: "entry in your own quarantine (made by the CLI or an "
                    + "older helper) — the helper only restores entries it keeps itself; in Terminal: "
                    + "launchkeeper quarantine restore \(name)")
            }
            return PrivilegedOutcome(state: "refused", detail: "no such quarantine entry")
        }
        guard let problem = QuarantineTrust.verifyEntry(root: bookkeeping.quarantine, manifest: manifest,
                                                        clientHome: client.home, trustedUID: bookkeeping.trustedUID) else {
            return nil
        }
        return PrivilegedOutcome(state: "refused", detail: "quarantine entry not trustworthy: \(problem)")
    }

    /// Executes a batch for one client (Phase 10) — after ONE authorization.
    ///
    /// Remediation entries (disable / enable / remove / remove --working) run
    /// first, as one kit batch against a single scan; quarantine and package
    /// entries follow in order. Every entry keeps its own gate, audit line and
    /// verification; a failure does not stop the rest (TJ, 2026-09-27).
    /// - Parameters:
    ///   - requests: The batch's actions, in the order the user queued them.
    ///   - client: Who asked (from the connection).
    ///   - shouldContinue: Asked between entries; `false` stops the batch.
    ///   - progress: Called after each entry with its position in `requests`.
    /// - Returns: One outcome per request, in the order of `requests`.
    public func performBatch(_ requests: [PrivilegedRequest], client: ClientContext,
                             shouldContinue: () -> Bool = { true },
                             progress: (Int, PrivilegedOutcome) -> Void = { _, _ in }) -> [PrivilegedOutcome] {
        var outcomes = [PrivilegedOutcome?](repeating: nil, count: requests.count)
        func finish(_ index: Int, _ outcome: PrivilegedOutcome) {
            outcomes[index] = outcome
            progress(index, outcome)
        }
        btmCache.preferCached = true
        if let problem = bookkeeping.prepare() {
            let refusal = PrivilegedOutcome(state: "refused", detail: "unsafe bookkeeping directory: \(problem)")
            for index in requests.indices { finish(index, refusal) }
            return outcomes.map { $0 ?? refusal }
        }

        // Invalid entries never reach an engine.
        var remediation: [(index: Int, request: RemediationRequest)] = []
        var cleanup: [Int] = []
        for (index, request) in requests.enumerated() {
            if let problem = request.validationError() { finish(index, .error(problem)); continue }
            switch request.kind {
            case .disable: remediation.append((index, RemediationRequest(operation: .disable, target: request.target)))
            case .enable: remediation.append((index, RemediationRequest(operation: .enable, target: request.target)))
            case .remove: remediation.append((index, RemediationRequest(operation: .remove, target: request.target)))
            case .removeWorking:
                remediation.append((index, RemediationRequest(operation: .remove, target: request.target, allowWorking: true)))
            case .restore, .purge, .uninstall: cleanup.append(index)
            }
        }

        if !remediation.isEmpty {
            _ = remediationEngine(for: client).runBatch(remediation.map(\.request), apply: true,
                                                        shouldContinue: shouldContinue, progress: { position, result in
                finish(remediation[position].index,
                       Self.outcome(result.status, plan: result.plan, messages: result.messages, undo: result.undoHint))
            })
        }

        for index in cleanup {
            guard shouldContinue() else {
                finish(index, PrivilegedOutcome(state: "refused", detail: "stopped before this entry",
                                                messages: ["the batch was stopped — nothing ran for this entry"]))
                continue
            }
            // Trust is checked here, right before the engine (review S4).
            finish(index, performCleanup(requests[index], client: client))
        }

        return outcomes.map { $0 ?? .error("not run") }
    }

    /// Maps an engine result into the wire type.
    static func outcome(_ status: RemediationStatus, plan: [PlannedCommand], messages: [String],
                        undo: String?) -> PrivilegedOutcome {
        let steps = plan.map { [$0.display, $0.description] }
        switch status {
        case .appliedOk: return PrivilegedOutcome(state: "done", steps: steps, messages: messages, undo: undo)
        case .appliedFailed(let detail):
            return PrivilegedOutcome(state: "failed", detail: detail, steps: steps, messages: messages, undo: undo)
        case .refused(let reason):
            return PrivilegedOutcome(state: "refused", detail: reason, steps: steps, messages: messages, undo: undo)
        case .planned:
            return PrivilegedOutcome(state: "error", detail: "the engine only planned — nothing executed",
                                     steps: steps, messages: messages, undo: undo)
        }
    }
}
