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

/// Makes sure LaunchKeeper's authorization right exists in the database.
///
/// Adding a *new* right is allowed for everyone (`config.add.` is `allow`);
/// an existing one is left as it is — an admin may have tightened it.
func ensureRight() {
    guard AuthorizationRightGet(HelperRight.name, nil) != errAuthorizationSuccess else { return }
    var authRef: AuthorizationRef?
    guard AuthorizationCreate(nil, nil, [], &authRef) == errAuthorizationSuccess, let authRef else { return }
    defer { AuthorizationFree(authRef, []) }
    _ = AuthorizationRightSet(authRef, HelperRight.name, HelperRight.definition as CFDictionary,
                              HelperRight.prompt as CFString, nil, nil)
}

/// Asks for LaunchKeeper's right on the client's authorization.
///
/// The client sends an empty authorization; here the right is requested
/// with interaction allowed, so macOS shows the authentication dialog
/// (Touch ID or admin password, with `HelperRight.prompt`) in the client's
/// session. The right has no grace period: this is the only check, and it
/// happens right before the action. (Live 2026-09-26: checking a grant the
/// app had obtained itself failed — with timeout 0 a grant is used up.)
/// - Parameter data: `AuthorizationExternalForm` bytes from the client.
/// - Returns: `true` when the user authenticated as an administrator.
func authorizeClient(_ data: Data) -> Bool {
    guard data.count == MemoryLayout<AuthorizationExternalForm>.size else { return false }
    var external = AuthorizationExternalForm()
    withUnsafeMutableBytes(of: &external) { _ = data.copyBytes(to: $0) }
    var authRef: AuthorizationRef?
    guard AuthorizationCreateFromExternalForm(&external, &authRef) == errAuthorizationSuccess, let authRef else {
        return false
    }
    defer { AuthorizationFree(authRef, [.destroyRights]) }
    return HelperRight.name.withCString { name in
        var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
        return withUnsafeMutablePointer(to: &item) { itemPointer in
            var rights = AuthorizationRights(count: 1, items: itemPointer)
            return AuthorizationCopyRights(authRef, &rights, nil, [.extendRights, .interactionAllowed],
                                           nil) == errAuthorizationSuccess
        }
    }
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
