//
//  WatchModelTests.swift
//  AppCoreTests — the watch: baseline first, new entries notified, own
//  actions labelled and not notified, incomplete scans not compared,
//  rescans during a scan queued, history read back from the log.
//

import XCTest
@testable import AppCore
import LaunchKeeperKit

/// Records delivered notifications.
@MainActor
final class RecordingNotifier: WatchNotifying {
    private(set) var delivered: [WatchRecord] = []
    func deliver(_ record: WatchRecord) { delivered.append(record) }
}

/// Returns the reports it is given, one per scan (the last one repeats).
final class ScriptedScans: @unchecked Sendable {
    private let lock = NSLock()
    private var reports: [ScanReport]
    private(set) var count = 0
    init(_ reports: [ScanReport]) { self.reports = reports }
    func next() -> ScanReport {
        lock.lock(); defer { lock.unlock() }
        count += 1
        return reports.count > 1 ? reports.removeFirst() : reports[0]
    }
}

@MainActor
final class WatchModelTests: XCTestCase {
    private func item(_ key: String) -> BackgroundItem {
        BackgroundItem(key: key, displayName: key, type: .launchAgentUser,
                       path: "/Users/alice/Library/LaunchAgents/\(key).plist", label: key, domain: .user)
    }

    private func report(_ keys: [String], incomplete: [String] = []) -> ScanReport {
        ScanReport(items: keys.map(item), uncorrelated: [], warnings: [], incompleteLayers: incomplete)
    }

    /// A store scanning the scripted reports and a started watch (no FSEvents, no timer, no log).
    private func setUp(_ reports: [ScanReport], clock: @escaping () -> Date = Date.init)
        -> (InventoryStore, WatchModel, RecordingNotifier, ScriptedScans) {
        let scans = ScriptedScans(reports)
        let store = InventoryStore(scanner: { _ in scans.next() })
        let watch = WatchModel(store: store, logPath: nil, now: clock)
        let notifier = RecordingNotifier()
        watch.notifier = notifier
        watch.start(interval: nil, fileEvents: false)
        return (store, watch, notifier, scans)
    }

    func testBaselineThenNewEntryIsRecordedAndNotified() async {
        let (store, watch, notifier, _) = setUp([report(["com.vendor.a"]), report(["com.vendor.a", "com.evil.b"])])
        await store.refresh(reason: .launch)
        XCTAssertEqual(watch.baselineCount, 1)
        XCTAssertTrue(watch.records.isEmpty, "the baseline is not a change")

        await store.refresh(reuseBTM: true, reason: .watch("fsevents: /Users/alice/Library/LaunchAgents/com.evil.b.plist"))
        XCTAssertEqual(watch.records.map(\.event.kind), [.added])
        XCTAssertEqual(watch.records.first?.event.key, "com.evil.b")
        XCTAssertEqual(notifier.delivered.map(\.event.key), ["com.evil.b"])
        XCTAssertEqual(store.reveal(key: "com.evil.b"), true, "the notification's entry can be shown")
    }

    func testOwnActionIsLabelledAndNotNotified() async {
        var clock = Date(timeIntervalSince1970: 1_000)
        let (store, watch, notifier, _) = setUp([report(["com.vendor.a"]), report([]), report(["com.x"])],
                                                clock: { clock })
        await store.refresh(reason: .launch)
        watch.ownActionStarted()
        await store.refresh(reuseBTM: true, reason: .watch("fsevents: x"))
        XCTAssertEqual(watch.records.first?.event.kind, .removed)
        XCTAssertEqual(watch.records.first?.isOwn, true, "a difference during an own action is LaunchKeeper's")
        XCTAssertTrue(notifier.delivered.isEmpty)

        // Long after the action: someone else's change again.
        watch.ownActionFinished()
        clock += WatchModel.ownActionGrace + 1
        await store.refresh(reuseBTM: true, reason: .watch("interval"))
        let added = watch.records.first { $0.event.kind == .added }
        XCTAssertEqual(added?.isOwn, false)
        XCTAssertEqual(notifier.delivered.map(\.event.key), ["com.x"])
    }

    func testIncompleteScanIsNotComparedAndRemovalsAreNotNotified() async {
        let (store, watch, notifier, _) = setUp([report(["a", "b"]), report([], incomplete: ["btm"]), report(["a"])])
        await store.refresh(reason: .launch)
        await store.refresh(reason: .watch("interval"))
        XCTAssertNotNil(watch.lastSkipReason, "a missing layer would look like everything removed")
        XCTAssertTrue(watch.records.isEmpty)
        await store.refresh(reason: .watch("interval"))
        XCTAssertEqual(watch.records.map(\.event.kind), [.removed])
        XCTAssertTrue(notifier.delivered.isEmpty, "something that no longer starts is listed, not notified")
    }

    func testRescanRequestedDuringAScanIsQueued() async {
        let scans = ScriptedScans([report(["a"])])
        // A slow scan, so the watch's request arrives while it runs.
        let store = InventoryStore(scanner: { _ in Thread.sleep(forTimeInterval: 0.2); return scans.next() })
        let first = Task { await store.refresh(reason: .launch) }
        while !store.isScanning { await Task.yield() }
        await store.refresh(reuseBTM: true, reason: .watch("fsevents: x"))
        await store.refresh(reuseBTM: true, reason: .user)
        await first.value
        XCTAssertEqual(scans.count, 2, "a watch rescan is queued, a second manual one dropped")
        XCTAssertEqual(ScanReason.watch("x").merged(with: .action), .action)
    }

    func testHistoryIsReadBackFromTheSharedLog() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("watch-\(UUID()).log").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        // The lines as the CLI's `watch` writes them (WatchEvent has no public init).
        let lines = [
            #"{"timestamp":"2026-09-26T10:00:00Z","kind":"baseline","changes":[],"trigger":"start","note":"3 entries"}"#,
            #"{"timestamp":"2026-09-26T10:05:00Z","kind":"added","key":"com.x","displayName":"x","category":"Launch Items","changes":[],"trigger":"fsevents: /x"}"#,
            #"{"timestamp":"2026-09-26T10:06:00Z","kind":"removed","key":"com.y","displayName":"y","changes":[],"trigger":"LaunchKeeper action","note":"\#(WatchModel.ownNote)"}"#,
            "garbage",
        ]
        try (lines.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        let records = WatchModel.loadHistory(path: path, limit: 10)
        XCTAssertEqual(records.map(\.event.key), ["com.y", "com.x"], "newest first, baseline skipped")
        XCTAssertEqual(records.map(\.isOwn), [true, false])
    }
}
