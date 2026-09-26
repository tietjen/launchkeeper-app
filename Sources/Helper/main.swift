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
let helperVersion = "0.1.0"

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

/// Checks that an authorization handed over by the client holds LaunchKeeper's right.
///
/// The client obtained it interactively (the user authenticated); here it is
/// only verified — no interaction, and a missing or expired grant fails.
/// - Parameter data: `AuthorizationExternalForm` bytes.
/// - Returns: `true` when the right is held.
func clientHoldsRight(_ data: Data) -> Bool {
    guard data.count == MemoryLayout<AuthorizationExternalForm>.size else { return false }
    var external = AuthorizationExternalForm()
    withUnsafeMutableBytes(of: &external) { _ = data.copyBytes(to: $0) }
    var authRef: AuthorizationRef?
    guard AuthorizationCreateFromExternalForm(&external, &authRef) == errAuthorizationSuccess, let authRef else {
        return false
    }
    defer { AuthorizationFree(authRef, []) }
    return HelperRight.name.withCString { name in
        var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
        return withUnsafeMutablePointer(to: &item) { itemPointer in
            var rights = AuthorizationRights(count: 1, items: itemPointer)
            return AuthorizationCopyRights(authRef, &rights, nil, [.extendRights], nil) == errAuthorizationSuccess
        }
    }
}

/// The exported XPC object. One request at a time (serial queue): two
/// actions racing on launchd state or the same files would make verification
/// meaningless.
final class HelperService: NSObject, NSXPCListenerDelegate, LaunchKeeperHelperXPC, @unchecked Sendable {
    private let queue = DispatchQueue(label: "de.paranoidsecurity.LaunchKeeper.Helper.requests")
    private let executor = PrivilegedExecutor()

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
            let outcome: PrivilegedOutcome
            if !clientHoldsRight(authorization) {
                outcome = .error("not authorized — the authentication was cancelled or has expired")
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
