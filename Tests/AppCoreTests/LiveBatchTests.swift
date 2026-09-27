//
//  LiveBatchTests.swift
//  AppCoreTests — the queue's engine against THIS Mac, dry-run only.
//  Skipped unless LAUNCHKEEPER_LIVE=1 (reads the real inventory, takes up to a minute).
//

import XCTest
@testable import AppCore
import LaunchKeeperKit

final class LiveBatchTests: XCTestCase {
    func testPlanningSeveralRealEntriesUsesOneScan() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LAUNCHKEEPER_LIVE"] == "1", "live test — set LAUNCHKEEPER_LIVE=1")
        let cache = BTMDumpCache()
        let report = ScanCoordinator(environment: ScanEnvironment(btmCache: cache)).perform(options: ScanOptions())
        let keys = report.items.filter { !ListFilter.isAppleInternal($0) && $0.control?.actions.contains("disable") == true && $0.enabled }
            .prefix(3).map(\.key)
        try XCTSkipIf(keys.count < 2, "not enough third-party entries to disable on this Mac")
        let performer = EnginePerformer(btmCache: cache, presence: { AppPresenceSources(installed: [], launchServices: { _ in nil }, spotlight: { _ in nil }) })
        let started = Date()
        let outcomes = performer.performBatch(keys.map { ActionRequest.remediation(operation: "disable", key: $0) }, apply: false,
                                              shouldContinue: { true }, progress: { _, _ in })
        let seconds = Date().timeIntervalSince(started)
        XCTAssertEqual(outcomes.map(\.state), Array(repeating: .planned, count: keys.count), "\(outcomes)")
        print("live batch: planned \(keys.count) entries in \(String(format: "%.1f", seconds)) s — \(keys)")
    }
}
