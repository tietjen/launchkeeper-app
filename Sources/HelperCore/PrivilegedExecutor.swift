//
//  PrivilegedExecutor.swift
//  HelperCore — executes one privileged request with the CLI's engines.
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

        switch request.kind {
        case .disable, .enable, .remove, .removeWorking:
            let operation: RemediationOperation = request.kind == .disable ? .disable
                : request.kind == .enable ? .enable : .remove
            let engine = RemediationEngine(environment: RemediationEnvironment(
                runner: runner, fileManager: fileManager, home: client.home, uid: client.uid,
                quarantineRoot: quarantineRoot, btmCache: btmCache), audit: audit)
            let result = engine.run(operation: operation, target: request.target, apply: true,
                                    allowWorking: request.kind == .removeWorking)
            handOver(quarantineRoot: quarantineRoot, to: client)
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
            handOver(quarantineRoot: quarantineRoot, to: client)
            return Self.outcome(result.status, plan: result.plan, messages: result.messages, undo: result.undoHint)
        }
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

    /// Gives the user's quarantine bookkeeping back to the user.
    ///
    /// The helper writes quarantine entries (directory, manifest, receipt
    /// copies) into the user's home as root. The user must be able to read
    /// and update them (the app lists entries, restores of home paths run as
    /// the user) — so ownership goes back to the client. The moved files
    /// themselves (`files/…`) keep their owner: they are system files.
    func handOver(quarantineRoot: String, to client: ClientContext) {
        guard let owner = (try? fileManager.attributesOfItem(atPath: client.home))?[.ownerAccountID] as? NSNumber,
              owner.intValue == client.uid else { return }   // never chown into a home the client does not own
        let group = (try? fileManager.attributesOfItem(atPath: client.home))?[.groupOwnerAccountID] as? NSNumber
        var paths = [quarantineRoot]
        for name in (try? fileManager.contentsOfDirectory(atPath: quarantineRoot)) ?? [] {
            let entry = quarantineRoot + "/" + name
            paths += [entry, entry + "/manifest.json", entry + "/receipt", entry + "/files"]
            paths += ((try? fileManager.contentsOfDirectory(atPath: entry + "/receipt")) ?? []).map { entry + "/receipt/" + $0 }
        }
        for path in paths where fileManager.fileExists(atPath: path) {
            var attributes: [FileAttributeKey: Any] = [.ownerAccountID: NSNumber(value: client.uid)]
            if let group { attributes[.groupOwnerAccountID] = group }
            try? fileManager.setAttributes(attributes, ofItemAtPath: path)
        }
    }
}
