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

    /// Creates the executor.
    public init(runner: CommandRunner = RootRunner(), btmCache: BTMDumpCache = BTMDumpCache(),
                auditDirectory: String = "/Library/Logs/launchkeeper", fileManager: FileManager = .default) {
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
        let audit = AuditLog(directory: auditDirectory)
        let quarantineRoot = LaunchKeeperPaths.quarantine(home: client.home)
        btmCache.preferCached = true
        if let refusal = trustRefusal(request, quarantineRoot: quarantineRoot, client: client) { return refusal }

        switch request.kind {
        case .disable, .enable, .remove, .removeWorking:
            let operation: RemediationOperation = request.kind == .disable ? .disable
                : request.kind == .enable ? .enable : .remove
            let engine = RemediationEngine(environment: RemediationEnvironment(
                runner: runner, fileManager: fileManager, home: client.home, uid: client.uid,
                quarantineRoot: quarantineRoot, btmCache: btmCache), audit: audit)
            let result = engine.run(operation: operation, target: request.target, apply: true,
                                    allowWorking: request.kind == .removeWorking)
            return Self.outcome(result.status, plan: result.plan, messages: result.messages, undo: result.undoHint)
        case .restore, .purge, .uninstall:
            let engine = CleanupEngine(environment: CleanupEnvironment(
                runner: runner, disk: DiskView(fileManager: fileManager), home: client.home,
                quarantineRoot: quarantineRoot), audit: audit)
            let result: CleanupResult
            switch request.kind {
            case .restore: result = engine.restore(name: request.target, apply: true)
            case .purge: result = engine.purge(name: request.target, apply: true)
            default: result = engine.uninstall(packageIdentifier: request.target, apply: true, verifyAsRoot: true)
            }
            return Self.outcome(result.status, plan: result.plan, messages: result.messages, undo: result.undoHint)
        }
    }

    /// The quarantine checks before root touches the user's quarantine
    /// (review 2026-09-27): a request that creates entries needs a safe,
    /// client-owned quarantine root; a restore or purge needs a root-owned,
    /// untouched entry. `nil` = go ahead.
    func trustRefusal(_ request: PrivilegedRequest, quarantineRoot: String,
                      client: ClientContext) -> PrivilegedOutcome? {
        switch request.kind {
        case .disable, .enable:
            return nil
        case .remove, .removeWorking, .uninstall:
            guard let problem = QuarantineTrust.prepareRoot(quarantineRoot, for: client) else { return nil }
            return PrivilegedOutcome(state: "refused", detail: "unsafe quarantine directory: \(problem)")
        case .restore, .purge:
            let paths = QuarantineStore(root: quarantineRoot, fileManager: fileManager)
                .load(request.target)?.moves.map(\.quarantined) ?? []
            guard let problem = QuarantineTrust.verifyEntry(root: quarantineRoot, name: request.target,
                                                            quarantinedPaths: paths) else { return nil }
            return PrivilegedOutcome(state: "refused", detail: "quarantine entry not trustworthy: \(problem)")
        }
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
        let quarantineRoot = LaunchKeeperPaths.quarantine(home: client.home)
        func finish(_ index: Int, _ outcome: PrivilegedOutcome) {
            outcomes[index] = outcome
            progress(index, outcome)
        }
        let audit = AuditLog(directory: auditDirectory)
        btmCache.preferCached = true

        // Invalid entries never reach an engine.
        var remediation: [(index: Int, request: RemediationRequest)] = []
        var cleanup: [Int] = []
        for (index, request) in requests.enumerated() {
            if let problem = request.validationError() { finish(index, .error(problem)); continue }
            if let refusal = trustRefusal(request, quarantineRoot: quarantineRoot, client: client) {
                finish(index, refusal); continue
            }
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
            let engine = RemediationEngine(environment: RemediationEnvironment(
                runner: runner, fileManager: fileManager, home: client.home, uid: client.uid,
                quarantineRoot: quarantineRoot, btmCache: btmCache), audit: audit)
            _ = engine.runBatch(remediation.map(\.request), apply: true, shouldContinue: shouldContinue,
                                progress: { position, result in
                finish(remediation[position].index,
                       Self.outcome(result.status, plan: result.plan, messages: result.messages, undo: result.undoHint))
            })
        }

        let cleanupEngine = CleanupEngine(environment: CleanupEnvironment(
            runner: runner, disk: DiskView(fileManager: fileManager), home: client.home,
            quarantineRoot: quarantineRoot), audit: audit)
        for index in cleanup {
            guard shouldContinue() else {
                finish(index, PrivilegedOutcome(state: "refused", detail: "stopped before this entry",
                                                messages: ["the batch was stopped — nothing ran for this entry"]))
                continue
            }
            let request = requests[index]
            let result: CleanupResult
            switch request.kind {
            case .restore: result = cleanupEngine.restore(name: request.target, apply: true)
            case .purge: result = cleanupEngine.purge(name: request.target, apply: true)
            default: result = cleanupEngine.uninstall(packageIdentifier: request.target, apply: true, verifyAsRoot: true)
            }
            finish(index, Self.outcome(result.status, plan: result.plan, messages: result.messages, undo: result.undoHint))
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
