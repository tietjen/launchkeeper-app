//
//  main.swift
//  LaunchKeeperHelper — the privileged helper daemon.
//
//  Registered by the app via SMAppService, started by launchd on demand
//  through its Mach service. It accepts connections only from the signed
//  LaunchKeeper app, executes one request at a time, and only after checking
//  that the client's authorization holds LaunchKeeper's right (Touch ID or
//  admin password, asked by macOS in the app, every time).
//

import Foundation
import Security
import HelperShared
import HelperCore
import LaunchKeeperKit

/// The helper's version; the app compares it with its own.
let helperVersion = HelperIdentity.version

/// Makes sure LaunchKeeper's authorization right exists in the database,
/// with the current per-language prompts.
///
/// Adding a *new* right is allowed for everyone (`config.add.` is `allow`).
/// An existing rule is kept as it is — an admin may have tightened it —
/// except for its prompts: rules written before 0.1.2 carried a German-only
/// prompt, so only `default-prompt` is brought up to date (the helper runs
/// as root, which may modify rules). Best effort: on failure the old prompt
/// stays and nothing else changes.
func ensureRight() {
    var authRef: AuthorizationRef?
    guard AuthorizationCreate(nil, nil, [], &authRef) == errAuthorizationSuccess, let authRef else { return }
    defer { AuthorizationFree(authRef, []) }
    var existing: CFDictionary?
    guard AuthorizationRightGet(HelperRight.name, &existing) == errAuthorizationSuccess,
          var rule = existing as? [String: Any] else {
        // No descriptionKey: the prompts come from the definition's `default-prompt`.
        _ = AuthorizationRightSet(authRef, HelperRight.name, HelperRight.definition as CFDictionary, nil, nil, nil)
        return
    }
    guard (rule["default-prompt"] as? [String: String]) != HelperRight.prompts else { return }
    rule["default-prompt"] = HelperRight.prompts
    _ = AuthorizationRightSet(authRef, HelperRight.name, rule as CFDictionary, nil, nil, nil)
}

/// Asks for LaunchKeeper's right on the client's authorization.
///
/// The client sends an empty authorization; here the right is requested
/// with interaction allowed, so macOS shows the authentication dialog
/// (Touch ID or admin password, with `HelperRight.prompts`) in the client's
/// session. The right has no grace period: this is the only check, and it
/// happens right before the action. (Live 2026-09-26: checking a grant the
/// app had obtained itself failed — with timeout 0 a grant is used up.)
/// - Parameters:
///   - data: `AuthorizationExternalForm` bytes from the client.
///   - prompt: A line for the dialog (batches: "… 17 startup items"); `nil`
///     shows the rule's own prompt.
/// - Returns: `true` when the user authenticated as an administrator.
func authorizeClient(_ data: Data, prompt: String? = nil) -> Bool {
    guard data.count == MemoryLayout<AuthorizationExternalForm>.size else { return false }
    var external = AuthorizationExternalForm()
    withUnsafeMutableBytes(of: &external) { _ = data.copyBytes(to: $0) }
    var authRef: AuthorizationRef?
    guard AuthorizationCreateFromExternalForm(&external, &authRef) == errAuthorizationSuccess, let authRef else {
        return false
    }
    defer { AuthorizationFree(authRef, [.destroyRights]) }
    let flags: AuthorizationFlags = [.extendRights, .interactionAllowed]
    return HelperRight.name.withCString { name in
        var right = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
        return withUnsafeMutablePointer(to: &right) { rightPointer in
            var rights = AuthorizationRights(count: 1, items: rightPointer)
            guard let prompt else {
                return AuthorizationCopyRights(authRef, &rights, nil, flags, nil) == errAuthorizationSuccess
            }
            // kAuthorizationEnvironmentPrompt: the dialog's text for this one request.
            return kAuthorizationEnvironmentPrompt.withCString { key in
                prompt.withCString { text in
                    var item = AuthorizationItem(name: key, valueLength: strlen(text),
                                                 value: UnsafeMutableRawPointer(mutating: text), flags: 0)
                    return withUnsafeMutablePointer(to: &item) { itemPointer in
                        var environment = AuthorizationEnvironment(count: 1, items: itemPointer)
                        return AuthorizationCopyRights(authRef, &rights, &environment, flags, nil) == errAuthorizationSuccess
                    }
                }
            }
        }
    }
}

/// The app's progress receiver. `@unchecked Sendable`: an XPC proxy may be
/// messaged from any thread (NSXPCConnection serializes the sends).
struct ProgressSink: @unchecked Sendable {
    let proxy: LaunchKeeperClientXPC?
}

/// A stop request for the running batch, set from the XPC thread while the
/// batch runs on the service queue.
final class StopFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false

    /// Marks the running batch as stopped.
    func set() { lock.lock(); stopped = true; lock.unlock() }
    /// Whether the batch may go on.
    var shouldContinue: Bool { lock.lock(); defer { lock.unlock() }; return !stopped }
}

/// Exits the helper after a quiet minute. launchd starts it again on the
/// next request — from the bundle as it is then, so an updated app brings
/// its updated helper without a manual restart.
final class IdleExit: @unchecked Sendable {
    private let queue: DispatchQueue
    private var work: DispatchWorkItem?
    private var busy = 0

    init(queue: DispatchQueue) { self.queue = queue }

    /// Call on `queue` when a request starts.
    func begin() { busy += 1; work?.cancel() }

    /// Call on `queue` when a request ends (and once at start).
    func end() {
        busy = max(0, busy - 1)
        guard busy == 0 else { return }
        let item = DispatchWorkItem { exit(0) }
        work = item
        queue.asyncAfter(deadline: .now() + 60, execute: item)
    }
}

/// The exported XPC object. One request at a time (serial queue): two
/// actions racing on launchd state or the same files would make verification
/// meaningless.
final class HelperService: NSObject, NSXPCListenerDelegate, LaunchKeeperHelperXPC, @unchecked Sendable {
    private let queue = DispatchQueue(label: "de.paranoidsecurity.LaunchKeeper.Helper.requests")
    private let executor = PrivilegedExecutor()
    /// Stop tokens of the batches each connection has sent (running or
    /// waiting for authentication). Created the moment a batch arrives — a
    /// stop during the Touch ID dialog is not lost (review 2026-09-27, S1) —
    /// and set when the connection goes away, so a crashed or quit app does
    /// not leave root working through its list (S5).
    private var tokens: [ObjectIdentifier: [StopFlag]] = [:]
    private let tokensLock = NSLock()
    let idle: IdleExit

    override init() {
        idle = IdleExit(queue: queue)
        super.init()
        queue.async { self.idle.end() }   // exit if nobody connects at all
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // The code-signing requirement on the listener already refused every
        // other client; this is the second check on the concrete connection.
        connection.setCodeSigningRequirement(HelperIdentity.clientRequirement)
        connection.exportedInterface = NSXPCInterface(with: LaunchKeeperHelperXPC.self)
        connection.exportedObject = self
        // Batch progress goes back to the app through its exported object.
        connection.remoteObjectInterface = NSXPCInterface(with: LaunchKeeperClientXPC.self)
        let id = ObjectIdentifier(connection)
        connection.invalidationHandler = { [weak self] in self?.stopBatches(of: id, forget: true) }
        // Interruption rarely fires on the listener side (a dead peer invalidates);
        // handled the same way for completeness.
        connection.interruptionHandler = { [weak self] in self?.stopBatches(of: id, forget: true) }
        connection.resume()
        return true
    }

    func perform(_ request: Data, authorization: Data, reply: @escaping @Sendable (Data) -> Void) {
        // Who asks comes from the connection (audit token), never from the payload.
        let uid = NSXPCConnection.current()?.effectiveUserIdentifier
        queue.async { [self] in
            idle.begin()
            defer { idle.end() }
            let outcome: PrivilegedOutcome
            if !authorizeClient(authorization) {
                outcome = PrivilegedOutcome(state: "refused", detail: "not authorized")
            } else if let uid, let client = ClientContext.forUID(uid) {
                if let decoded = try? JSONDecoder().decode(PrivilegedRequest.self, from: request) {
                    outcome = self.executor.perform(decoded, client: client)
                } else {
                    outcome = .error("malformed request")
                }
            } else {
                outcome = .error("unknown client user")
            }
            reply((try? JSONEncoder().encode(outcome)) ?? Data())
        }
    }

    func performBatch(_ batch: Data, authorization: Data, reply: @escaping @Sendable (Data) -> Void) {
        // Who asks, and where progress goes, come from the connection — never the payload.
        let connection = NSXPCConnection.current()
        let uid = connection?.effectiveUserIdentifier
        let progressSink = ProgressSink(proxy: connection?.remoteObjectProxyWithErrorHandler { _ in } as? LaunchKeeperClientXPC)
        // The token exists before the batch waits for the queue or the dialog.
        let stop = StopFlag()
        let connectionID = connection.map(ObjectIdentifier.init)
        if let connectionID { register(stop, for: connectionID) }
        queue.async { [self] in
            defer { if let connectionID { unregister(stop, for: connectionID) } }
            idle.begin()
            defer { idle.end() }
            func answer(_ outcomes: [PrivilegedOutcome]) { reply((try? JSONEncoder().encode(outcomes)) ?? Data()) }
            guard let decoded = try? JSONDecoder().decode(PrivilegedBatch.self, from: batch) else {
                return answer([.error("malformed batch")])
            }
            if let problem = decoded.validationError() {
                return answer(decoded.requests.map { _ in .error(problem) })
            }
            // Stopped while waiting (or the app is gone): no dialog for a batch
            // that would not run anyway (review 2026-09-27).
            guard stop.shouldContinue else {
                return answer(decoded.requests.map { _ in
                    PrivilegedOutcome(state: "refused", detail: "stopped before this entry")
                })
            }
            // One authentication for exactly this list (TJ, 2026-09-27).
            guard authorizeClient(authorization, prompt: decoded.prompt) else {
                return answer(decoded.requests.map { _ in PrivilegedOutcome(state: "refused", detail: "not authorized") })
            }
            guard let uid, let client = ClientContext.forUID(uid) else {
                return answer(decoded.requests.map { _ in .error("unknown client user") })
            }
            let outcomes = executor.performBatch(decoded.requests, client: client,
                                                 shouldContinue: { stop.shouldContinue },
                                                 progress: { index, outcome in
                if let data = try? JSONEncoder().encode(outcome) { progressSink.proxy?.batchProgress(index, outcome: data) }
            })
            answer(outcomes)
        }
    }

    func stopBatch() {
        // Not on `queue`: that queue is busy running the batch. Stops only
        // the batches of the connection that asks.
        guard let connection = NSXPCConnection.current() else { return }
        stopBatches(of: ObjectIdentifier(connection), forget: false)
    }

    /// Remembers a batch's stop token for its connection.
    private func register(_ token: StopFlag, for connection: ObjectIdentifier) {
        tokensLock.lock(); tokens[connection, default: []].append(token); tokensLock.unlock()
    }

    /// Forgets a finished batch's token.
    private func unregister(_ token: StopFlag, for connection: ObjectIdentifier) {
        tokensLock.lock()
        tokens[connection]?.removeAll { $0 === token }
        if tokens[connection]?.isEmpty == true { tokens[connection] = nil }
        tokensLock.unlock()
    }

    /// Stops every batch of a connection (after the entry in progress).
    private func stopBatches(of connection: ObjectIdentifier, forget: Bool) {
        tokensLock.lock()
        let pending = tokens[connection] ?? []
        if forget { tokens[connection] = nil }
        tokensLock.unlock()
        pending.forEach { $0.set() }
    }

    func version(reply: @escaping @Sendable (String) -> Void) {
        reply(helperVersion)
    }
}

ensureRight()
let service = HelperService()
let listener = NSXPCListener(machServiceName: HelperIdentity.helperID)
listener.setConnectionCodeSigningRequirement(HelperIdentity.clientRequirement)
listener.delegate = service
listener.resume()
dispatchMain()
