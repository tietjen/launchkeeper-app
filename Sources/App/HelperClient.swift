//
//  HelperClient.swift
//  LaunchKeeper — the app side of the privileged helper: registration
//  (SMAppService), authentication (Touch ID / password via LaunchKeeper's
//  authorization right) and the XPC call.
//

import Foundation
import Observation
import Security
import ServiceManagement
import AppCore
import HelperShared

/// Registration state of the helper, for the UI.
@MainActor
@Observable
final class HelperStatus {
    /// What macOS reports for the helper's launchd registration.
    private(set) var status: SMAppService.Status = .notRegistered
    /// The running helper's version, when it answered.
    private(set) var version: String?
    /// The last registration error, for display.
    private(set) var lastError: String?

    private var service: SMAppService { SMAppService.daemon(plistName: HelperIdentity.daemonPlistName) }

    /// `true` when the helper is registered and allowed — admin actions can run.
    var isReady: Bool { status == .enabled }

    /// Reads the registration state (and the helper version when enabled).
    func refresh() {
        status = service.status
        guard isReady else { version = nil; return }
        Task.detached {
            let answer = HelperClient.version()
            await MainActor.run { self.version = answer }
        }
    }

    /// Registers the helper. macOS then asks the user to allow it in
    /// System Settings › General › Login Items & Extensions (status `.requiresApproval`).
    func register() {
        do {
            try service.register()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
        if status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    /// Unregisters the helper (the app's admin actions stop working until registered again).
    func unregister() async {
        do {
            try await service.unregister()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    /// Opens System Settings where the helper is allowed.
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

/// Talks to the helper. All calls block and run off the main thread.
enum HelperClient {

    /// Asks the user to authenticate for LaunchKeeper's right (Touch ID or
    /// admin password — the macOS dialog shows `HelperRight.prompt`).
    ///
    /// Defines the right first when it does not exist yet (adding new rights
    /// is allowed for everyone; the helper does the same on start).
    /// - Returns: The authorization's external form for the helper, or `nil`
    ///   when the user cancelled or authentication failed.
    static func authorize() -> Data? {
        var authRef: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &authRef) == errAuthorizationSuccess, let authRef else { return nil }
        if AuthorizationRightGet(HelperRight.name, nil) != errAuthorizationSuccess {
            _ = AuthorizationRightSet(authRef, HelperRight.name, HelperRight.definition as CFDictionary,
                                      HelperRight.prompt as CFString, nil, nil)
        }
        let granted = HelperRight.name.withCString { name -> Bool in
            var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &item) { itemPointer in
                var rights = AuthorizationRights(count: 1, items: itemPointer)
                return AuthorizationCopyRights(authRef, &rights, nil,
                                               [.interactionAllowed, .extendRights, .preAuthorize],
                                               nil) == errAuthorizationSuccess
            }
        }
        guard granted else {
            AuthorizationFree(authRef, [])
            return nil
        }
        var external = AuthorizationExternalForm()
        guard AuthorizationMakeExternalForm(authRef, &external) == errAuthorizationSuccess else {
            AuthorizationFree(authRef, [])
            return nil
        }
        // The helper reads the grant through the external form; the local
        // reference must stay alive until then — freed after the call returns.
        pendingReferences.append(authRef)
        return withUnsafeBytes(of: &external) { Data($0) }
    }

    /// Authorization references handed to the helper, freed after each call.
    nonisolated(unsafe) private static var pendingReferences: [AuthorizationRef] = []

    /// Frees the references created for the last call (destroying the rights with them).
    private static func releaseReferences() {
        for reference in pendingReferences { AuthorizationFree(reference, [.destroyRights]) }
        pendingReferences.removeAll()
    }

    /// A connection to the helper that only accepts the genuine, team-signed helper.
    private static func connect() -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: HelperIdentity.helperID, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: LaunchKeeperHelperXPC.self)
        connection.setCodeSigningRequirement(HelperIdentity.helperRequirement)
        connection.resume()
        return connection
    }

    /// Holds a reply across the XPC callback thread.
    private final class Reply<T>: @unchecked Sendable {
        var value: T?
        let done = DispatchSemaphore(value: 0)
    }

    /// Sends one request and waits for the answer.
    /// - Parameters:
    ///   - request: What to do.
    ///   - authorization: From `authorize()`.
    ///   - timeout: Upper bound; an uninstall of a large package moves many files.
    /// - Returns: The helper's outcome, or an error outcome when it is unreachable.
    static func perform(_ request: PrivilegedRequest, authorization: Data,
                        timeout: TimeInterval = 900) -> PrivilegedOutcome {
        defer { releaseReferences() }
        guard let payload = try? JSONEncoder().encode(request) else { return .error("cannot encode the request") }
        let connection = connect()
        defer { connection.invalidate() }
        let reply = Reply<PrivilegedOutcome>()
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            reply.value = .error("helper not reachable: \(error.localizedDescription)")
            reply.done.signal()
        } as? LaunchKeeperHelperXPC
        guard let proxy else { return .error("helper interface unavailable") }
        proxy.perform(payload, authorization: authorization) { data in
            reply.value = (try? JSONDecoder().decode(PrivilegedOutcome.self, from: data)) ?? .error("malformed reply")
            reply.done.signal()
        }
        guard reply.done.wait(timeout: .now() + timeout) == .success else {
            return .error("the helper did not answer within \(Int(timeout)) s")
        }
        return reply.value ?? .error("no reply")
    }

    /// The helper's version, or `nil` when it does not answer within a few seconds.
    static func version() -> String? {
        let connection = connect()
        defer { connection.invalidate() }
        let reply = Reply<String>()
        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in reply.done.signal() } as? LaunchKeeperHelperXPC
        proxy?.version { value in
            reply.value = value
            reply.done.signal()
        }
        _ = reply.done.wait(timeout: .now() + 5)
        return reply.value
    }
}

/// Executes plans with administrator steps through the helper: Touch ID
/// first, then the XPC call. Planning never goes here — the app computes
/// plans itself (dry-run, no privileges).
struct PrivilegedPerformer: ActionPerforming {
    func perform(_ request: ActionRequest, apply: Bool) -> ActionOutcome {
        guard apply, let privileged = request.privileged else {
            return ActionOutcome(state: .refused("the helper only executes; plans come from the app"),
                                 steps: [], messages: [], undo: nil)
        }
        guard let authorization = HelperClient.authorize() else {
            return ActionOutcome(state: .refused("Anmeldung abgebrochen — nichts geändert"), steps: [], messages: [],
                                 undo: nil)
        }
        return .from(privileged: HelperClient.perform(privileged, authorization: authorization))
    }
}
