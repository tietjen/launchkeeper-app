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

    /// `true` when the running helper is an older build than this app's
    /// (it restarts by itself after a quiet minute; "Entfernen" + "Einrichten"
    /// forces it).
    var isOutdated: Bool { version.map { $0 != HelperIdentity.version } ?? false }

    /// Reads the registration state (and the helper version when enabled).
    func refresh() {
        status = service.status
        // A working helper makes any earlier registration error obsolete.
        if isReady { lastError = nil }
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
        // The first registration of a daemon fails with "Operation not
        // permitted" until the user allows it — that is the expected first
        // step, not an error (seen live 2026-09-26). Show the way instead.
        if status == .requiresApproval {
            lastError = nil
            SMAppService.openSystemSettingsLoginItems()
        }
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

    /// Replaces a running helper with the one in this app's bundle.
    ///
    /// Unregistering boots the daemon out (ending the running process);
    /// registering again lets launchd start the bundled build on the next
    /// request. Needed for helpers before 0.1.1, which never exit on their
    /// own and would keep answering with old code (live 2026-09-26).
    func restart() async {
        await unregister()
        guard lastError == nil else { return }
        register()
    }

    /// Opens System Settings where the helper is allowed.
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

/// Talks to the helper. All calls block and run off the main thread.
enum HelperClient {

    /// Creates the (empty) authorization the helper asks the user on.
    ///
    /// The app does not request the right itself: the right has no grace
    /// period, so a grant obtained here would be used up before the helper
    /// could check it (live 2026-09-26). The helper requests it with
    /// interaction allowed; macOS shows Touch ID / password in this session.
    /// The right is defined first when missing (adding new rights is allowed
    /// for everyone; the helper does the same on start).
    /// - Returns: The authorization's external form, or `nil` on failure.
    static func authorize() -> Data? {
        var authRef: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &authRef) == errAuthorizationSuccess, let authRef else { return nil }
        if AuthorizationRightGet(HelperRight.name, nil) != errAuthorizationSuccess {
            _ = AuthorizationRightSet(authRef, HelperRight.name, HelperRight.definition as CFDictionary,
                                      HelperRight.prompt as CFString, nil, nil)
        }
        var external = AuthorizationExternalForm()
        guard AuthorizationMakeExternalForm(authRef, &external) == errAuthorizationSuccess else {
            AuthorizationFree(authRef, [])
            return nil
        }
        // The reference must outlive the helper's use of the external form.
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
            return ActionOutcome(state: .failed("keine Autorisierung möglich"), steps: [], messages: [], undo: nil)
        }
        return .from(privileged: HelperClient.perform(privileged, authorization: authorization))
    }
}
