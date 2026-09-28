//
//  WatchModel.swift
//  AppCore — the watch (Phase 7): say it when something new may start
//  automatically, like `launchkeeper watch`, inside the app.
//
//  The comparison is the CLI's `InventoryWatcher` (stable keys, the last
//  complete inventory as baseline, incomplete scans never compared). What
//  the app adds: every scan of the app goes through it (manual, after an
//  action, the watch's own), so nothing is scanned twice; changes the app
//  itself made are labelled as its own and never notified.
//

import Foundation
import Observation
import LaunchKeeperKit

/// One change the watch noticed, as the app lists and notifies it.
public struct WatchRecord: Identifiable, Equatable, Sendable {
    /// Unique per record (events have no id of their own).
    public let id: UUID
    /// The CLI's event: kind, entry key/name/category/path, changed fields, trigger.
    public let event: WatchEvent
    /// When it was noticed.
    public let date: Date
    /// `true` when LaunchKeeper made the change itself (an action it executed).
    public let isOwn: Bool

    /// Creates a record.
    /// - Parameters:
    ///   - event: The watcher's event.
    ///   - date: When it was noticed.
    ///   - isOwn: Whether LaunchKeeper made the change itself.
    public init(event: WatchEvent, date: Date, isOwn: Bool) {
        self.id = UUID()
        self.event = event
        self.date = date
        self.isOwn = isOwn
    }

    /// Whether this record deserves a notification: something new or changed
    /// that LaunchKeeper did not do itself. Removals are listed, not notified —
    /// something that no longer starts is no risk.
    public var deservesNotification: Bool {
        !isOwn && (event.kind == .added || event.kind == .changed)
    }

    /// A short German headline for lists and notifications.
    public var headline: String {
        let name = event.displayName ?? event.key ?? "?"
        switch event.kind {
        case .added: return String(localized: "Neu: \(name)")
        case .removed: return String(localized: "Entfernt: \(name)")
        case .changed: return String(localized: "Geändert: \(name)")
        case .baseline, .skipped: return event.summary
        }
    }

    /// The details under the headline: category, path, changed fields.
    public var detail: String {
        var parts: [String] = []
        if let category = event.category { parts.append(category) }
        if event.kind == .changed, !event.changes.isEmpty {
            parts.append(event.changes.map { "\($0.field): \($0.before) → \($0.after)" }.joined(separator: "; "))
        } else if let path = event.path {
            parts.append(path)
        }
        return parts.joined(separator: " — ")
    }
}

/// Delivers notifications for watch records (the app uses the macOS
/// notification center; tests record the calls).
@MainActor
public protocol WatchNotifying: AnyObject {
    /// Shows a notification for one record.
    func deliver(_ record: WatchRecord)
}

/// The watch: file-system triggers and a periodic check, compared through the
/// CLI's `InventoryWatcher`, with a history of what changed.
@MainActor
@Observable
public final class WatchModel {
    /// `true` while the watch is on.
    public private(set) var isRunning = false
    /// What changed, newest first (at most `historyLimit`).
    public private(set) var records: [WatchRecord] = []
    /// Entries in the baseline (without Apple's), once the first complete scan is in.
    public private(set) var baselineCount: Int?
    /// When the last comparison ran.
    public private(set) var lastCheck: Date?
    /// Why the last scan was not compared (a source did not answer), if so.
    public private(set) var lastSkipReason: String?
    /// `false` when FSEvents could not be started — the periodic check still runs.
    public private(set) var fileEventsActive = false
    /// Receives records that deserve a notification; `nil` = no notifications.
    public var notifier: WatchNotifying?

    /// How many records the list keeps.
    public let historyLimit = 200

    private let store: InventoryStore
    private let logPath: String?
    private let now: () -> Date
    /// Hands the store's report to `InventoryWatcher.tick`, which scans
    /// through a closure; the app scans once and gives the result to both.
    private let slot = ReportSlot()
    private var watcher: InventoryWatcher
    private var triggers: FileSystemTriggers?
    private var periodic: Task<Void, Never>?
    private var pending: Task<Void, Never>?
    private var pendingReasons: [String] = []
    /// Whether a collected trigger asked for a fresh BTM dump.
    private var pendingFresh = false
    /// Actions LaunchKeeper is executing right now.
    private var ownActions = 0
    /// When the last own action finished.
    private var lastOwnActionEnd: Date?

    /// How long after an own action a difference still counts as its own:
    /// a scan that started before the action can finish after it.
    static let ownActionGrace: TimeInterval = 30
    /// The quiet period after a file event before scanning (installers write in bursts).
    static let fileEventDelay: Duration = .seconds(5)
    /// Without the helper, a fresh Background Task Management dump makes
    /// macOS ask for Touch ID. The periodic check then takes one at most this
    /// often and otherwise compares with the kept dump (TJ 2026-09-28).
    static let promptedFreshBTMInterval: TimeInterval = 6 * 3600

    /// Whether the periodic check should read BTM fresh: always while the
    /// helper supplies the dumps (no Touch ID), else once the last dump or
    /// the last prompted attempt — even a cancelled one — is
    /// `promptedFreshBTMInterval` old.
    var freshBTMDue: Bool {
        if store.lastFreshBTMWasQuiet { return true }
        guard let last = [store.lastPromptedFreshBTM, store.btmDumpTaken].compactMap({ $0 }).max() else { return true }
        return now().timeIntervalSince(last) >= Self.promptedFreshBTMInterval
    }

    /// Creates the watch (not started).
    /// - Parameters:
    ///   - store: The inventory store; the watch scans through it and gets every scan.
    ///   - logPath: JSON-lines log shared with the CLI's `watch`; `nil` = none (tests).
    ///   - now: The clock (tests).
    public init(store: InventoryStore,
                logPath: String? = LaunchKeeperPaths.logs(home: NSHomeDirectory()) + "/watch.log",
                now: @escaping () -> Date = Date.init) {
        self.store = store
        self.logPath = logPath
        self.now = now
        self.watcher = Self.makeWatcher(slot: slot)
        records = logPath.map { Self.loadHistory(path: $0, limit: historyLimit) } ?? []
    }

    private static func makeWatcher(slot: ReportSlot) -> InventoryWatcher {
        InventoryWatcher(includeAll: false, includeState: false) {
            slot.report ?? ScanReport(items: [], uncorrelated: [], warnings: [], incompleteLayers: ["no scan"])
        }
    }

    // MARK: Start / stop

    /// Starts watching.
    /// - Parameters:
    ///   - interval: Period of the full check (fresh Background Task
    ///     Management dump); catches what file events miss. `nil` = none (tests).
    ///   - fileEvents: Rescan when an autostart location changes (FSEvents).
    public func start(interval: Duration? = .seconds(600), fileEvents: Bool = true) {
        guard !isRunning else { return }
        isRunning = true
        store.onScan = { [weak self] report, reason in self?.observe(report, reason: reason) }
        if fileEvents {
            let fs = FileSystemTriggers(paths: WatchPaths(), queue: DispatchQueue(label: "de.paranoidsecurity.LaunchKeeper.watch")) {
                [weak self] path in
                Task { @MainActor in self?.schedule("fsevents: \(path)", reuseBTM: true) }
            }
            fileEventsActive = fs.start()
            triggers = fs
        }
        if let interval {
            periodic = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    guard !Task.isCancelled else { return }
                    guard let self else { return }
                    self.schedule("interval", reuseBTM: !self.freshBTMDue, delay: .zero)
                }
            }
        }
        // The baseline comes from the next scan: the launch scan when the app
        // just started (no second scan right behind it), else a quick one now.
        if store.lastScan != nil && !store.isScanning {
            Task { await store.refresh(reuseBTM: true, reason: .watch("start")) }
        }
    }

    /// Stops watching and forgets the baseline (the next start takes a new one).
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        store.onScan = nil
        triggers?.stop()
        triggers = nil
        fileEventsActive = false
        periodic?.cancel()
        pending?.cancel()
        pendingReasons.removeAll()
        pendingFresh = false
        watcher = Self.makeWatcher(slot: slot)
        baselineCount = nil
        lastSkipReason = nil
    }

    // MARK: Own actions

    /// Call when LaunchKeeper starts executing an action: differences seen
    /// until shortly after `ownActionFinished()` are its own.
    public func ownActionStarted() { ownActions += 1 }

    /// Call when the action has finished; rescans at once so the result
    /// is compared (and labelled) as LaunchKeeper's own.
    public func ownActionFinished() {
        ownActions = max(0, ownActions - 1)
        lastOwnActionEnd = now()
        Task { await store.refresh(reuseBTM: true, reason: .action) }
    }

    /// Whether a difference noticed now was caused by LaunchKeeper.
    private func isOwn(_ reason: ScanReason) -> Bool {
        if reason == .action || ownActions > 0 { return true }
        guard let end = lastOwnActionEnd else { return false }
        return now().timeIntervalSince(end) < Self.ownActionGrace
    }

    // MARK: Scanning

    /// Collects a trigger and (re)starts the quiet period; one scan follows.
    /// - Parameters:
    ///   - reason: Trigger text (CLI style).
    ///   - reuseBTM: Reuse the session's BTM dump (file events) or ask anew (interval).
    ///   - delay: Quiet period.
    private func schedule(_ reason: String, reuseBTM: Bool, delay: Duration = WatchModel.fileEventDelay) {
        guard isRunning else { return }
        pendingReasons.append(reason)
        // One trigger that wants a fresh dump makes the collected scan fresh.
        if !reuseBTM { pendingFresh = true }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            let reasons = self.pendingReasons
            self.pendingReasons.removeAll()
            let trigger = reasons.count == 1 ? reasons[0] : "\(reasons[0]) (+\(reasons.count - 1) more)"
            let fresh = self.pendingFresh
            self.pendingFresh = false
            await self.store.refresh(reuseBTM: !fresh, reason: .watch(trigger))
        }
    }

    /// Compares one finished scan with the baseline and records the differences.
    /// - Parameters:
    ///   - report: The scan.
    ///   - reason: Why it ran.
    func observe(_ report: ScanReport, reason: ScanReason) {
        guard isRunning else { return }
        slot.report = report
        defer { slot.report = nil }
        let own = isOwn(reason)
        let date = now()
        lastCheck = date
        for event in watcher.tick(trigger: reason.trigger) {
            switch event.kind {
            case .baseline:
                baselineCount = report.items.filter { !ListFilter.isAppleInternal($0) }.count
                lastSkipReason = nil
            case .skipped:
                lastSkipReason = event.note
            case .added, .removed, .changed:
                lastSkipReason = nil
                var logged = event
                if own { logged.note = Self.ownNote }
                let record = WatchRecord(event: logged, date: date, isOwn: own)
                records.insert(record, at: 0)
                if records.count > historyLimit { records.removeLast(records.count - historyLimit) }
                append(logged)
                if record.deservesNotification { notifier?.deliver(record) }
            }
        }
    }

    /// Clears the list (the log file stays).
    public func clearHistory() { records.removeAll() }

    // MARK: Log

    /// Note stored with events LaunchKeeper caused, so the history knows after a restart.
    static let ownNote = "caused by a LaunchKeeper app action"

    /// Appends one event to the shared JSON-lines log (the CLI writes the same format).
    private func append(_ event: WatchEvent) {
        guard let logPath, let data = try? JSONEncoder().encode(event) else { return }
        let line = data + Data("\n".utf8)
        let fm = FileManager.default
        try? fm.createDirectory(atPath: (logPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        if let handle = FileHandle(forWritingAtPath: logPath) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            fm.createFile(atPath: logPath, contents: line)
        }
    }

    /// Reads the latest changes from the log, newest first.
    /// - Parameters:
    ///   - path: The JSON-lines log.
    ///   - limit: How many records at most.
    /// - Returns: Records for added/removed/changed events; unreadable lines are skipped.
    static func loadHistory(path: String, limit: Int) -> [WatchRecord] {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let formatter = ISO8601DateFormatter()
        let decoder = JSONDecoder()
        var records: [WatchRecord] = []
        for line in text.split(separator: "\n").reversed() where records.count < limit {
            guard let event = try? decoder.decode(WatchEvent.self, from: Data(line.utf8)),
                  [.added, .removed, .changed].contains(event.kind) else { continue }
            records.append(WatchRecord(event: event, date: formatter.date(from: event.timestamp) ?? .distantPast,
                                       isOwn: event.note == ownNote))
        }
        return records
    }
}

/// The report of the scan being compared, handed to the watcher's scan
/// closure. Only touched on the main actor (`WatchModel.observe`); the class
/// exists because `InventoryWatcher` wants a `Sendable`-free closure it can call.
private final class ReportSlot: @unchecked Sendable {
    var report: ScanReport?
}
