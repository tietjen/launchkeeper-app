import XCTest
@testable import AppCore
import LaunchKeeperKit

@MainActor
final class SideModelsTests: XCTestCase {
    func testLeftoversLoadOffMainAndShowOnlyGoneByDefault() async {
        let model = LeftoversModel(loader: {
            XCTAssertFalse(Thread.isMainThread)
            return [SideModelsTests.make("org.gone.App", .gone(["x"])),
                    SideModelsTests.make("com.vendor.Installed", .present("installed")),
                    SideModelsTests.make("org.tool.cli", .noAppEvidence)]
        })
        await model.reload()
        XCTAssertTrue(model.loaded)
        XCTAssertEqual(model.visible.map(\.bundleIdentifier), ["org.gone.App"])
        XCTAssertEqual(model.goneCount, 1)
        model.showAll = true
        XCTAssertEqual(model.visible.count, 3)
    }

    nonisolated static func make(_ id: String, _ presence: AppPresence) -> AppLeftoverCandidate {
        AppLeftoverCandidate(bundleIdentifier: id, paths: [], presence: presence, appEvidence: [])
    }

    func testViewSelectionsAreNotInventoryAndCountNothing() {
        let store = InventoryStore(scanner: { _ in ScanReport(items: [], uncorrelated: [], warnings: []) })
        let item = BackgroundItem(key: "com.vendor.a", displayName: "a", type: .launchAgentUser,
                                  path: "/Users/alice/Library/LaunchAgents/com.vendor.a.plist", label: "com.vendor.a",
                                  domain: .user)
        store.apply(ScanReport(items: [item], uncorrelated: [], warnings: []))
        for selection in [SidebarSelection.background, .receipts, .leftovers, .quarantine] {
            XCTAssertFalse(selection.isInventory)
            XCTAssertEqual(store.count(selection), 0)
        }
        XCTAssertTrue(SidebarSelection.all.isInventory)
    }

    func testQuarantineModelListsManifests() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lk-app-q-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = QuarantineStore(root: root)
        let manifest = QuarantineManifest(name: "2026-09-26-120000Z-uninstall-com.vendor.x", kind: "uninstall",
                                          createdAt: "2026-09-26T12:00:00Z", toolVersion: "0.9.2",
                                          packageIdentifier: "com.vendor.x", version: "1.0",
                                          moves: [QuarantineMove(original: "/Library/Vendor/x", quarantined: root + "/x",
                                                                 kind: "file")],
                                          receiptCopies: [], forgot: false, status: "applied-ok", notes: [])
        XCTAssertNil(store.write(manifest))
        let model = QuarantineModel(root: root)
        model.reload()
        XCTAssertEqual(model.entries.map(\.packageIdentifier), ["com.vendor.x"])
    }

    func testSignatureTargetIsTheBundleForBundleSignedTypes() {
        let ext = BackgroundItem(key: "ext:x", displayName: "x", type: .appExtension,
                                 path: "/Applications/X.app/Contents/PlugIns/X.appex", executable: "/bin/should-not-win")
        XCTAssertEqual(SignatureCheck.target(of: ext), "/Applications/X.app/Contents/PlugIns/X.appex")
        let agent = BackgroundItem(key: "a", displayName: "a", type: .launchAgentUser,
                                   path: "/Users/alice/Library/LaunchAgents/a.plist", executable: "/opt/a/bin/a")
        XCTAssertEqual(SignatureCheck.target(of: agent), "/opt/a/bin/a")
    }
}
