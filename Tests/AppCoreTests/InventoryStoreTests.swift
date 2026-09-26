//
//  InventoryStoreTests.swift
//  AppCoreTests — sidebar filtering, search, Apple toggle, badges, and that
//  scans run off the main thread with the session BTM cache.
//

import XCTest
@testable import AppCore
import LaunchKeeperKit

@MainActor
final class InventoryStoreTests: XCTestCase {
    private func item(_ key: String, category: ItemCategory = .launchItems, path: String? = nil,
                      orphaned: Bool = false, schedule: String? = nil) -> BackgroundItem {
        var item = BackgroundItem(key: key, displayName: key, type: .launchAgentUser,
                                  path: path ?? "/Users/alice/Library/LaunchAgents/\(key).plist",
                                  label: key, domain: .user, orphaned: orphaned, category: category)
        if let schedule { item.metadata["schedule"] = schedule }
        return item
    }

    private func store(_ items: [BackgroundItem]) -> InventoryStore {
        let store = InventoryStore(scanner: { _ in ScanReport(items: items, uncorrelated: [], warnings: []) })
        store.apply(ScanReport(items: items, uncorrelated: [], warnings: []))
        return store
    }

    func testSidebarSelectionSearchAndAppleToggle() {
        let apple = item("com.apple.x", path: "/System/Library/LaunchAgents/com.apple.x.plist")
        let s = store([item("com.vendor.agent"), item("com.vendor.gone", orphaned: true),
                       item("ext:com.vendor.QL", category: .appExtensions), apple,
                       item("com.vendor.nightly", schedule: "calendar Hour=3")])
        XCTAssertEqual(s.visibleRows.count, 4, "Apple hidden by default")
        XCTAssertEqual(s.count(.orphans), 1)
        s.selection = .category(.appExtensions)
        XCTAssertEqual(s.visibleRows.map(\.id), ["ext:com.vendor.QL"])
        s.selection = .category(.scheduled)
        XCTAssertEqual(s.visibleRows.map(\.id), ["com.vendor.nightly"], "a launchd timer shows under Scheduled")
        s.selection = .all
        s.search = "GONE"
        XCTAssertEqual(s.visibleRows.map(\.id), ["com.vendor.gone"])
        s.search = ""
        s.hideApple = false
        XCTAssertEqual(s.visibleRows.count, 5)
        XCTAssertTrue(s.categories.contains(.appExtensions))
        XCTAssertFalse(s.categories.contains(.network), "empty categories stay out of the sidebar")
    }

    func testBadgesOrderLeftoverBeforeOrphan() {
        var leftover = item("btm:x", orphaned: true)
        leftover.metadata["btm-leftover"] = "true"
        leftover.enabled = false
        XCTAssertEqual(InventoryRow(item: leftover).badges, [.leftover, .disabled])
        var unsigned = item("com.vendor.u")
        unsigned.codeSignatureStatus = "unsigned"
        unsigned.riskFlags = ["REVIEW: shell interpreter"]
        XCTAssertEqual(InventoryRow(item: unsigned).badges, [.unsigned, .review])
    }

    func testRefreshScansOffTheMainActorAndKeepsTheBTMCacheForQuickRefreshes() async {
        final class Probe: @unchecked Sendable { var preferCached: [Bool] = []; var onMain: [Bool] = [] }
        let probe = Probe()
        let s = InventoryStore(scanner: { cache in
            probe.preferCached.append(cache.preferCached)
            probe.onMain.append(Thread.isMainThread)
            return ScanReport(items: [], uncorrelated: [], warnings: [])
        })
        await s.refresh()
        await s.refresh(reuseBTM: true)
        XCTAssertEqual(probe.preferCached, [false, true])
        XCTAssertEqual(probe.onMain, [false, false], "the scan never blocks the UI")
        XCTAssertNotNil(s.lastScan)
        XCTAssertFalse(s.isScanning)
    }
}
