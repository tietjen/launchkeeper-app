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
        // The completion-handler form keeps the (non-Sendable) SMAppService on
        // the main actor; `await service.unregister()` would send it to a
        // nonisolated context, which Swift 6.1 rejects.
        let service = self.service
        let failure: String? = await withCheckedContinuation { continuation in
            service.unregister { error in continuation.resume(returning: error?.localizedDescription) }
        }
        lastError = failure
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
    static func authorize() -> ClientAuthorization? {
        var authRef: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &authRef) == errAuthorizationSuccess, let authRef else { return nil }
        if AuthorizationRightGet(HelperRight.name, nil) != errAuthorizationSuccess {
            _ = AuthorizationRightSet(authRef, HelperRight.name, HelperRight.definition as CFDictionary,
                                      nil, nil, nil)  // prompts: the definition's default-prompt
        }
        var external = AuthorizationExternalForm()
        guard AuthorizationMakeExternalForm(authRef, &external) == errAuthorizationSuccess else {
            AuthorizationFree(authRef, [])
            return nil
        }
        // The reference must outlive the helper's use of the external form;
        // its owner frees it (and only it) when the call is over.
        return ClientAuthorization(reference: authRef, externalForm: withUnsafeBytes(of: &external) { Data($0) })
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
    static func perform(_ request: PrivilegedRequest, authorization: ClientAuthorization,
                        timeout: TimeInterval = 900) -> PrivilegedOutcome {
        defer { authorization.release() }
        guard let payload = try? JSONEncoder().encode(request) else { return .error("cannot encode the request") }
        let connection = connect()
        defer { connection.invalidate() }
        let reply = Reply<PrivilegedOutcome>()
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            reply.value = .error("helper not reachable: \(error.localizedDescription)")
            reply.done.signal()
        } as? LaunchKeeperHelperXPC
        guard let proxy else { return .error("helper interface unavailable") }
        proxy.perform(payload, authorization: authorization.externalForm) { data in
            reply.value = (try? JSONDecoder().decode(PrivilegedOutcome.self, from: data)) ?? .error("malformed reply")
            reply.done.signal()
        }
        guard reply.done.wait(timeout: .now() + timeout) == .success else {
            return .error("the helper did not answer within \(Int(timeout)) s")
        }
        return reply.value ?? .error("no reply")
    }

    // MARK: Batches (Phase 10)

    /// Receives the helper's per-entry progress on the batch connection.
    private final class ProgressReceiver: NSObject, LaunchKeeperClientXPC, @unchecked Sendable {
        let onProgress: @Sendable (Int, PrivilegedOutcome) -> Void
        init(onProgress: @escaping @Sendable (Int, PrivilegedOutcome) -> Void) { self.onProgress = onProgress }
        func batchProgress(_ index: Int, outcome: Data) {
            if let decoded = try? JSONDecoder().decode(PrivilegedOutcome.self, from: outcome) { onProgress(index, decoded) }
        }
    }

    /// The connection of the batch in progress — `stopBatch()` talks through it.
    nonisolated(unsafe) private static var batchConnection: NSXPCConnection?

    /// Sends a batch and waits for all its outcomes; progress arrives per entry before.
    /// - Parameters:
    ///   - batch: The actions and the dialog line.
    ///   - authorization: From `authorize()` — asked once for the whole batch.
    ///   - progress: Called per finished entry (on an XPC thread).
    ///   - timeout: Upper bound for the whole batch (package uninstalls move many files).
    /// - Returns: One outcome per request, or errors when the helper is unreachable.
    static func performBatch(_ batch: PrivilegedBatch, authorization: ClientAuthorization,
                             progress: @escaping @Sendable (Int, PrivilegedOutcome) -> Void,
                             timeout: TimeInterval = 3600) -> [PrivilegedOutcome] {
        defer { authorization.release() }
        let count = batch.requests.count
        let failAll: @Sendable (String) -> [PrivilegedOutcome] = { detail in
            Array(repeating: PrivilegedOutcome.error(detail), count: count)
        }
        guard let payload = try? JSONEncoder().encode(batch) else { return failAll("cannot encode the batch") }
        let connection = connect()
        connection.exportedInterface = NSXPCInterface(with: LaunchKeeperClientXPC.self)
        connection.exportedObject = ProgressReceiver(onProgress: progress)
        batchConnection = connection
        defer { batchConnection = nil; connection.invalidate() }
        let reply = Reply<[PrivilegedOutcome]>()
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            reply.value = failAll("helper not reachable: \(error.localizedDescription)")
            reply.done.signal()
        } as? LaunchKeeperHelperXPC
        guard let proxy else { return failAll("helper interface unavailable") }
        proxy.performBatch(payload, authorization: authorization.externalForm) { data in
            reply.value = (try? JSONDecoder().decode([PrivilegedOutcome].self, from: data)) ?? failAll("malformed reply")
            reply.done.signal()
        }
        guard reply.done.wait(timeout: .now() + timeout) == .success else {
            return failAll("the helper did not answer within \(Int(timeout)) s")
        }
        let outcomes = reply.value ?? failAll("no reply")
        // A batch the helper refused as a whole answers with one outcome per request too.
        return outcomes.count == batch.requests.count ? outcomes : failAll("unexpected reply")
    }

    /// Asks the helper to stop the running batch after the entry in progress.
    static func stopBatch() {
        (batchConnection?.remoteObjectProxy as? LaunchKeeperHelperXPC)?.stopBatch()
    }

    /// A fresh Background Task Management dump read by the helper as root —
    /// no Touch ID (0.2.0). Only the system's and this user's sections.
    ///
    /// Used for every fresh inventory when the helper is set up, allowed and
    /// of this app's build; otherwise `nil`, and the scan runs `sfltool`
    /// itself (macOS then asks for administrator authentication).
    /// - Parameter timeout: Upper bound; a cold BTM daemon can take minutes.
    /// - Returns: The dump; `.unavailable` without a usable helper (then the
    ///   scan asks macOS itself); `.failed` when the helper did not deliver.
    static func readBTM(timeout: TimeInterval = 200) -> QuietBTMRead {
        // Never start a connection to a helper that is not allowed or of another build.
        guard SMAppService.daemon(plistName: HelperIdentity.daemonPlistName).status == .enabled,
              version() == HelperIdentity.version else { return .unavailable }
        let connection = connect()
        defer { connection.invalidate() }
        let reply = Reply<String>()
        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in reply.done.signal() } as? LaunchKeeperHelperXPC
        guard let proxy else { return .failed }
        proxy.readBTM { data, _ in
            reply.value = data.flatMap { String(data: $0, encoding: .utf8) }
            reply.done.signal()
        }
        guard reply.done.wait(timeout: .now() + timeout) == .success, let text = reply.value else { return .failed }
        return .dump(text)
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

/// One authorization handed to the helper: the reference and its external form.
///
/// Each call owns its own reference and frees only that one. A shared list
/// freed after every call let a single action started during a queue run
/// destroy the batch's authorization (review 2026-09-27, S3).
final class ClientAuthorization: @unchecked Sendable {
    let reference: AuthorizationRef
    let externalForm: Data
    private let lock = NSLock()
    private var released = false

    init(reference: AuthorizationRef, externalForm: Data) {
        self.reference = reference
        self.externalForm = externalForm
    }

    /// Frees the reference and destroys its rights (idempotent).
    func release() {
        lock.lock(); defer { lock.unlock() }
        guard !released else { return }
        released = true
        AuthorizationFree(reference, [.destroyRights])
    }

    deinit { release() }
}

/// The queue's administrator batch: one Touch ID for the whole list, the
/// dialog names how many entries it is about (Phase 10, TJ 2026-09-27).
struct PrivilegedBatchPerformer: BatchPerforming {
    func performBatch(_ requests: [ActionRequest], apply: Bool, shouldContinue: @escaping @Sendable () -> Bool,
                      progress: @escaping @Sendable (Int, ActionOutcome) -> Void) -> [ActionOutcome] {
        func all(_ state: ActionOutcome.State) -> [ActionOutcome] {
            requests.map { _ in ActionOutcome(state: state, steps: [], messages: [], undo: nil) }
        }
        let privileged = requests.compactMap(\.privileged)
        guard apply, privileged.count == requests.count else {
            return all(.refused("the helper only executes; plans come from the app"))
        }
        // The helper refuses oversized batches; say so before asking for Touch ID.
        guard requests.count <= PrivilegedBatch.maxRequests else {
            return all(.refused(String(localized: "zu viele Einträge für einen Lauf (höchstens \(PrivilegedBatch.maxRequests)) — bitte in Teilen ausführen")))
        }
        guard let authorization = HelperClient.authorize() else {
            return all(.failed(String(localized: "keine Autorisierung möglich")))
        }
        let prompt = requests.count == 1
            ? String(localized: "LaunchKeeper möchte einen Autostart-Eintrag ändern.")
            : String(localized: "LaunchKeeper möchte \(requests.count) Autostart-Einträge ändern.")
        let outcomes = HelperClient.performBatch(PrivilegedBatch(requests: privileged, prompt: prompt),
                                                 authorization: authorization,
                                                 progress: { index, outcome in progress(index, .from(privileged: outcome)) })
        return outcomes.map(ActionOutcome.from(privileged:))
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
            return ActionOutcome(state: .failed(String(localized: "keine Autorisierung möglich")), steps: [], messages: [], undo: nil)
        }
        return .from(privileged: HelperClient.perform(privileged, authorization: authorization))
    }
}
