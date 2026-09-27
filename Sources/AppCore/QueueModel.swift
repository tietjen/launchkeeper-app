//
//  QueueModel.swift
//  AppCore — the work queue (Phase 10): collect actions across views, check
//  the plan of all of them at once, run them in one go.
//
//  Decisions (TJ, 2026-09-27): Touch ID once per run for exactly the checked
//  list; a failed entry does not stop the rest; the queue survives a restart.
//  Speed comes from the engines, not from the UI: one scan plans every
//  remediation entry (kit 0.11 `runBatch`), one helper call carries all
//  administrator steps, one rescan follows the run.
//

import Foundation
import Observation
import LaunchKeeperKit

// MARK: - Items

/// What a queue entry acts on — the stable address of a row in one of the views.
public enum QueueTarget: Codable, Hashable, Sendable {
    /// An inventory entry, by stable key.
    case entry(key: String)
    /// An installer package, by receipt id.
    case package(id: String)
    /// A gone app's leftovers, by bundle id.
    case leftovers(bundleID: String)
    /// A quarantine entry, by name.
    case quarantine(name: String)

    /// The actions the queue offers for this kind of target when nothing
    /// more specific is known (packages, leftovers, quarantine have one each).
    public var defaultActions: [ActionRequest] {
        switch self {
        case .entry: return []
        case .package(let id): return [.uninstall(package: id)]
        case .leftovers(let id): return [.leftovers(bundleID: id)]
        case .quarantine(let name): return [.restore(quarantine: name)]
        }
    }
}

/// One queued action.
public struct QueueItem: Identifiable, Codable, Equatable, Sendable {
    /// Where the item stands.
    public enum Status: Codable, Equatable, Sendable {
        /// Queued, plan not checked yet.
        case pending
        /// Plan checked: would run; `needsAdmin` = goes to the helper (Touch ID).
        case planned(needsAdmin: Bool)
        /// Running now.
        case running
        /// Executed and verified.
        case done
        /// Executed, but a step or the verification failed.
        case failed(String)
        /// The gate (or a precondition) refused — nothing ran.
        case refused(String)
        /// By hand (step 4): open until a scan shows the change, or the user ticks it.
        case manual(done: Bool)
    }

    /// Stable id of the queue row.
    public let id: UUID
    /// What the action is about.
    public var target: QueueTarget
    /// Row title as it was when queued (the entry may be gone later).
    public var title: String
    /// The view it came from ("Hintergrund", "Pakete" …), for orientation.
    public var origin: String
    /// The chosen action — switchable among `QueueModel.options(for:)`.
    public var action: ActionRequest
    /// Where it stands.
    public var status: Status
    /// By hand: whether the entry was enabled when queued — "done" once a
    /// scan shows it gone or switched off. `nil` for automatic items.
    public var manualBaseline: Bool?

    /// Creates a pending item (or an open manual one for `.manual` actions).
    public init(target: QueueTarget, title: String, origin: String, action: ActionRequest,
                manualBaseline: Bool? = nil) {
        self.id = UUID()
        self.target = target
        self.title = title
        self.origin = origin
        self.action = action
        if case .manual = action {
            self.status = .manual(done: false)
            self.manualBaseline = manualBaseline ?? true
        } else {
            self.status = .pending
            self.manualBaseline = nil
        }
    }

    /// `true` for by-hand items — never planned or executed by the app.
    public var isManual: Bool {
        if case .manual = action { return true }
        return false
    }

    /// `true` once the run is over for this item (done, failed or refused).
    public var isFinished: Bool {
        switch status {
        case .done, .failed, .refused, .manual(done: true): return true
        case .pending, .planned, .running, .manual(done: false): return false
        }
    }
}

// MARK: - Model

/// The queue: items, their plans and results, the run.
@MainActor
@Observable
public final class QueueModel {
    /// Where the queue is in its work.
    public enum Phase: Equatable, Sendable {
        /// Nothing running.
        case idle
        /// Checking the plan of every item (one scan).
        case planning
        /// Executing: `done` of `total` items finished.
        case running(done: Int, total: Int)
    }

    /// The queued actions, in the order they were queued. They run grouped:
    /// administrator items first (one helper call), then the app's own; the
    /// engines run removals and switches before restores and uninstalls.
    public private(set) var items: [QueueItem] = []
    /// Plan or result per item (not persisted — a restart plans again).
    public private(set) var outcomes: [QueueItem.ID: ActionOutcome] = [:]
    /// What the queue is doing.
    public private(set) var phase: Phase = .idle
    /// Runs requests in the app process (no administrator steps).
    private let local: BatchPerforming
    /// Runs administrator steps through the privileged helper; `nil` until it is set up.
    public var privileged: BatchPerforming?
    /// Stops the helper's running batch (it runs in another process).
    public var stopPrivileged: (() -> Void)?
    /// JSON file the queue is kept in; `nil` = memory only (tests).
    private let storeURL: URL?
    private let stopSignal = StopSignal()
    /// The items of the run in progress (the progress counts only these).
    private var runIDs: Set<QueueItem.ID> = []
    /// Items that ran in THIS session. Only they get a way back: a status
    /// read from the file proves nothing (review 2026-09-27, C3).
    private var ranThisSession: Set<QueueItem.ID> = []

    /// Creates the queue and loads what was saved.
    /// - Parameters:
    ///   - local: The app-side batch performer (`EnginePerformer`).
    ///   - storeURL: Where the queue is kept across restarts; `nil` for none.
    public init(local: BatchPerforming, storeURL: URL? = QueueModel.defaultStoreURL) {
        self.local = local
        self.storeURL = storeURL
        if let storeURL, let data = try? Data(contentsOf: storeURL),
           let saved = try? JSONDecoder().decode([QueueItem].self, from: data) {
            // A run interrupted by quitting is not "running" any more.
            items = saved.map { item in
                var item = item
                if item.status == .running || { if case .planned = item.status { return true }; return false }() {
                    item.status = .pending
                }
                return item
            }
        }
    }

    /// `~/Library/Application Support/de.paranoidsecurity.LaunchKeeper/queue.json`.
    public nonisolated static var defaultStoreURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("de.paranoidsecurity.LaunchKeeper/queue.json")
    }

    // MARK: Editing

    /// Adds items; a target that is already queued keeps its entry (and
    /// gets the new action), so the queue never holds one target twice.
    /// - Parameter new: The items to add.
    /// - Returns: How many were new.
    @discardableResult
    public func add(_ new: [QueueItem]) -> Int {
        guard phase == .idle else { return 0 }
        var added = 0
        for item in new {
            if let index = items.firstIndex(where: { $0.target == item.target }) {
                items[index].action = item.action
                items[index].status = item.status
                items[index].manualBaseline = item.manualBaseline
                outcomes[items[index].id] = nil
            } else {
                items.append(item)
                added += 1
            }
        }
        save()
        return added
    }

    /// Switches an item to another action (its plan is checked again).
    public func setAction(_ action: ActionRequest, for id: QueueItem.ID) {
        guard phase == .idle, let index = items.firstIndex(where: { $0.id == id }) else { return }
        // By-hand items are created with their baseline (QueueItem.init);
        // the picker only switches between automatic actions.
        guard !items[index].isManual, !{ if case .manual = action { return true }; return false }() else { return }
        items[index].action = action
        items[index].status = .pending
        outcomes[id] = nil
        save()
    }

    /// Takes items out of the queue without running them.
    public func remove(_ ids: Set<QueueItem.ID>) {
        guard phase == .idle else { return }
        items.removeAll { ids.contains($0.id) }
        for id in ids { outcomes[id] = nil }
        save()
    }

    /// Empties the queue — nothing is executed.
    public func clear() {
        guard phase == .idle else { return }
        items.removeAll()
        outcomes.removeAll()
        save()
    }

    /// Removes the items that are done (successful ones only).
    public func clearDone() {
        remove(Set(items.filter { $0.status == .done || $0.status == .manual(done: true) }.map(\.id)))
    }

    // MARK: Checks

    /// Hints about items that get in each other's way — today: a package
    /// queued for uninstalling while entries it installed are queued too
    /// (the uninstall takes their files; the entries' actions would then fail).
    /// - Parameter packageOf: The package id an inventory entry came from, if known.
    /// - Returns: A hint per affected item.
    public func conflicts(packageOf: (String) -> String?) -> [QueueItem.ID: String] {
        let uninstalling = Set(items.compactMap { item -> String? in
            if case .uninstall(let id) = item.action { return id }
            return nil
        })
        var hints: [QueueItem.ID: String] = [:]
        for item in items {
            guard case .entry(let key) = item.target, let package = packageOf(key), uninstalling.contains(package) else { continue }
            hints[item.id] = String(localized: "Das Paket \(package) wird in derselben Warteschlange deinstalliert — diese Aktion ist dann überflüssig.")
        }
        return hints
    }

    // MARK: Running

    /// Checks the plan of every item not done yet — ONE scan for all
    /// remediation entries. Refused or failed items are checked again (the
    /// helper may have been set up meanwhile, a file may be back).
    public func plan() async {
        guard phase == .idle else { return }
        let open = items.indices.filter { items[$0].status != .done && !items[$0].isManual }
        guard !open.isEmpty else { return }
        phase = .planning
        let requests = open.map { items[$0].action }
        let local = self.local
        let results = await Task.detached(priority: .userInitiated) {
            local.performBatch(requests, apply: false, shouldContinue: { true }, progress: { _, _ in })
        }.value
        for (position, index) in open.enumerated() where index < items.count {
            let outcome = results[position]
            outcomes[items[index].id] = outcome
            switch outcome.state {
            case .planned: items[index].status = .planned(needsAdmin: outcome.needsAdmin)
            case .refused(let reason): items[index].status = .refused(reason)
            case .failed(let detail): items[index].status = .failed(detail)
            case .done: items[index].status = .done
            }
        }
        phase = .idle
        save()
    }

    /// Runs every item whose plan was checked and allowed.
    ///
    /// Administrator items go to the helper first — one Touch ID for all of
    /// them, while the user is still at the screen — then the app runs the
    /// rest. Items with administrator steps but no helper are refused with
    /// the reason. A failure does not stop the others; `stop()` does, after
    /// the entry in progress.
    public func execute() async {
        guard phase == .idle else { return }
        if items.contains(where: { $0.status == .pending }) { await plan() }
        let runnable = items.indices.filter { if case .planned = items[$0].status { return true }; return false }
        guard !runnable.isEmpty else { return }

        var adminIndices: [Int] = []
        var localIndices: [Int] = []
        for index in runnable {
            guard case .planned(let needsAdmin) = items[index].status else { continue }
            if !needsAdmin {
                localIndices.append(index)
            } else if privileged != nil, items[index].action.privileged != nil {
                adminIndices.append(index)
            } else {
                items[index].status = .refused(privileged == nil
                    ? String(localized: "braucht Administratorrechte — Hilfsprogramm in den Einstellungen einrichten")
                    : String(localized: "braucht Administratorrechte — nur im Terminal möglich"))
            }
        }
        let total = adminIndices.count + localIndices.count
        guard total > 0 else { save(); return }
        stopSignal.reset()
        runIDs = Set((adminIndices + localIndices).map { items[$0].id })
        var finished = 0
        phase = .running(done: 0, total: total)

        for (isLocal, performer, indices) in [(false, privileged, adminIndices), (true, local, localIndices)] {
            guard let performer, !indices.isEmpty else { continue }
            // Cancelling the Touch ID dialog means "do nothing" (review S2):
            // when every administrator item came back unauthorized, the app's
            // own items do not run either.
            if isLocal, !adminIndices.isEmpty,
               adminIndices.allSatisfy({ outcomes[items[$0].id]?.authorizationDenied == true }) {
                for index in indices {
                    items[index].status = .refused(String(localized: "nicht ausgeführt — Anmeldung abgebrochen"))
                }
                finished += indices.count
                continue
            }
            for index in indices { items[index].status = .running }
            let requests = indices.map { items[$0].action }
            let ids = indices.map { items[$0].id }
            ranThisSession.formUnion(ids)
            let signal = stopSignal
            let results = await Task.detached(priority: .userInitiated) { [weak self] in
                performer.performBatch(requests, apply: true, shouldContinue: { signal.shouldContinue },
                                       progress: { position, outcome in
                    Task { @MainActor in self?.record(outcome, for: ids[position]) }
                })
            }.value
            // The final answer wins over progress messages still in flight.
            for (position, id) in ids.enumerated() { record(results[position], for: id) }
            finished += indices.count
            phase = .running(done: finished, total: total)
        }
        runIDs = []
        phase = .idle
        save()
    }

    /// Stops the run after the entry in progress; the rest is reported as not run.
    public func stop() {
        stopSignal.set()
        stopPrivileged?()
    }

    /// Stores an item's result and its status.
    private func record(_ outcome: ActionOutcome, for id: QueueItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        outcomes[id] = outcome
        switch outcome.state {
        case .done: items[index].status = .done
        case .failed(let detail): items[index].status = .failed(detail)
        case .refused(let reason): items[index].status = .refused(reason)
        case .planned: items[index].status = .planned(needsAdmin: outcome.needsAdmin)
        }
        if case .running(_, let total) = phase {
            let done = items.filter { runIDs.contains($0.id) && $0.isFinished }.count
            phase = .running(done: min(done, total), total: total)
        }
    }

    // MARK: By hand (step 4)

    /// Ticks off by-hand items a scan shows as done: the entry is gone, or it
    /// was enabled when queued and is switched off now.
    /// - Parameters:
    ///   - complete: Whether the scan was complete. An incomplete scan (e.g.
    ///     the Background Task Management dump timed out) lacks whole layers —
    ///     "gone" proves nothing then, only "switched off" counts (review
    ///     2026-09-27; the watch has the same rule).
    ///   - state: Current state of an entry by key — `nil` when it is not in
    ///     the inventory, else whether it is enabled.
    /// - Returns: How many items were ticked off now.
    @discardableResult
    public func updateManual(complete: Bool = true, state: (String) -> Bool?) -> Int {
        var ticked = 0
        for index in items.indices where items[index].status == .manual(done: false) {
            guard case .entry(let key) = items[index].target else { continue }
            let enabledNow = state(key)
            let gone = enabledNow == nil && complete
            if gone || (items[index].manualBaseline == true && enabledNow == false) {
                items[index].status = .manual(done: true)
                ticked += 1
            }
        }
        if ticked > 0 { save() }
        return ticked
    }

    /// Ticks a by-hand item off (or opens it again) by the user's word.
    /// - Parameters:
    ///   - done: The new state.
    ///   - id: The item.
    ///   - enabledNow: When opening again: the entry's current state, the new
    ///     baseline — so the next scan does not tick it straight off again
    ///     (`nil` = not in the inventory; then it stays done).
    public func setManual(done: Bool, for id: QueueItem.ID, enabledNow: Bool? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].isManual else { return }
        if !done {
            guard let enabledNow else { return }   // gone entries cannot be "open" again
            items[index].manualBaseline = enabledNow
        }
        items[index].status = .manual(done: done)
        save()
    }

    // MARK: Way back

    /// Queue items that undo what the last run did: disable ↔ enable, and
    /// "restore from the quarantine" for everything that went there.
    /// - Returns: The undo items (not queued yet — the caller adds them).
    public func undoItems() -> [QueueItem] {
        items.filter { $0.status == .done && ranThisSession.contains($0.id) }.compactMap { item -> QueueItem? in
            switch item.action {
            case .remediation(let operation, let key) where operation == "disable":
                return QueueItem(target: item.target, title: item.title, origin: item.origin,
                                 action: .remediation(operation: "enable", key: key))
            case .remediation(let operation, let key) where operation == "enable":
                return QueueItem(target: item.target, title: item.title, origin: item.origin,
                                 action: .remediation(operation: "disable", key: key))
            default:
                guard let name = outcomes[item.id]?.undo.flatMap(Self.quarantineName(inUndo:)) else { return nil }
                return QueueItem(target: .quarantine(name: name), title: item.title,
                                 origin: String(localized: "Rückweg"), action: .restore(quarantine: name))
            }
        }
    }

    /// The quarantine entry an undo hint names ("launchkeeper quarantine restore <name> …").
    nonisolated static func quarantineName(inUndo undo: String) -> String? {
        let marker = "quarantine restore "
        guard let range = undo.range(of: marker) else { return nil }
        let name = undo[range.upperBound...].prefix { !$0.isWhitespace }
        return name.isEmpty || name.hasPrefix("<") ? nil : String(name)
    }

    // MARK: Persistence

    /// Writes the queue (items and statuses, not the plans) to its file.
    private func save() {
        guard let storeURL, let data = try? JSONEncoder().encode(items) else { return }
        try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: storeURL, options: .atomic)
        // Owner only: the queue lists what may run with administrator rights.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storeURL.path)
    }
}

/// A stop request for the running batch — set on the main actor, read by the
/// performer's thread between entries.
final class StopSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false

    func set() { lock.lock(); stopped = true; lock.unlock() }
    func reset() { lock.lock(); stopped = false; lock.unlock() }
    var shouldContinue: Bool { lock.lock(); defer { lock.unlock() }; return !stopped }
}
