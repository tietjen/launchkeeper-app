//
//  ViewSummariesTests.swift
//  AppCoreTests — the VirusTotal hash target and SHA-256, the summaries of
//  packages, app leftovers and background rows, and jumping to an entry.
//

import XCTest
@testable import AppCore
import LaunchKeeperKit

final class VirusTotalHashTests: XCTestCase {
    private var root = ""

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("lk-vt-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(atPath: root) }

    /// Writes a file whose first four bytes are a 64-bit Mach-O magic (little-endian).
    private func machO(_ path: String) {
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                                 withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: path, contents: Data([0xCF, 0xFA, 0xED, 0xFE, 0x07, 0x00]))
    }

    func testOnlyProgramCodeQualifies() throws {
        machO(root + "/opt/tool/bin/tool")
        FileManager.default.createFile(atPath: root + "/script.sh", contents: Data("#!/bin/sh\n".utf8))
        let binary = BackgroundItem(key: "a", displayName: "a", type: .launchAgentUser,
                                    path: root + "/a.plist", executable: root + "/opt/tool/bin/tool")
        XCTAssertEqual(VirusTotalHash.target(of: binary), root + "/opt/tool/bin/tool")
        let script = BackgroundItem(key: "s", displayName: "s", type: .launchAgentUser,
                                    path: root + "/s.plist", executable: root + "/script.sh")
        XCTAssertNil(VirusTotalHash.target(of: script), "a script is user-editable text, not an installed program")
        let shell = BackgroundItem(key: "z", displayName: ".zshrc", type: .shellProfile, path: root + "/.zshrc")
        XCTAssertNil(VirusTotalHash.target(of: shell))
    }

    func testBundleResolvesToItsMainExecutable() throws {
        let appex = root + "/X.app/Contents/PlugIns/QL.appex"
        machO(appex + "/Contents/MacOS/QL")
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleExecutable": "QL"],
                                                       format: .xml, options: 0)
        FileManager.default.createFile(atPath: appex + "/Contents/Info.plist", contents: plist)
        let ext = BackgroundItem(key: "ext:x", displayName: "x", type: .appExtension, path: appex)
        XCTAssertEqual(VirusTotalHash.target(of: ext), appex + "/Contents/MacOS/QL")
    }

    func testAppleBinariesAreSkipped() {
        let apple = BackgroundItem(key: "d", displayName: "d", type: .launchDaemon,
                                   path: "/System/Library/LaunchDaemons/com.apple.x.plist", executable: "/usr/libexec/logd")
        XCTAssertNil(VirusTotalHash.target(of: apple))
    }

    func testSHA256MatchesTheKnownVector() async {
        FileManager.default.createFile(atPath: root + "/abc", contents: Data("abc".utf8))
        let hash = await VirusTotalHash.sha256(of: root + "/abc")
        XCTAssertEqual(hash, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}

@MainActor
final class ViewSummariesTests: XCTestCase {
    /// Receipt rows have no public memberwise initializer; they are Codable.
    private func receipt(_ json: String) -> ReceiptsView.Row {
        try! JSONDecoder().decode(ReceiptsView.Row.self, from: Data(json.utf8))
    }

    func testPackageVerdictsAndSteps() {
        let gone = receipt(#"{"id":"com.vendor.old","version":"1.0","installedAt":"2025-01-02T00:00:00Z","fileCount":10,"missingFiles":10,"items":[],"apple":false}"#)
        let summary = PackageSummary.build(for: gone)
        XCTAssertEqual(summary.verdict, .leftover)
        XCTAssertEqual(summary.nextSteps.map(\.title), ["Beleg entfernen"])
        XCTAssertEqual(summary.nextSteps.first?.command, "launchkeeper uninstall com.vendor.old")

        let partial = receipt(#"{"id":"com.vendor.tool","fileCount":10,"missingFiles":3,"items":["Tool Agent"],"apple":false}"#)
        let partSummary = PackageSummary.build(for: partial)
        XCTAssertEqual(partSummary.verdict.severity, 2)
        XCTAssertEqual(partSummary.nextSteps.map(\.title), ["Deinstallieren (Vorschau)"])
        XCTAssertTrue(partSummary.facts.contains("startet: Tool Agent"))
    }

    func testLeftoverStepsOnlyForGoneApps() {
        let path = LeftoverPath(path: "/Users/alice/Library/Caches/org.gone.App", kind: "caches", bytes: 2048,
                                needsRoot: false)
        let gone = AppLeftoverCandidate(bundleIdentifier: "org.gone.App", paths: [path],
                                        presence: .gone(["LaunchServices: not registered"]),
                                        appEvidence: ["saved window state"])
        let steps = LeftoverSummary.build(for: gone).nextSteps
        XCTAssertEqual(steps.first?.command, "launchkeeper leftovers org.gone.App")
        XCTAssertEqual(steps.last?.kind, .reveal(path.path))

        let present = AppLeftoverCandidate(bundleIdentifier: "com.vendor.App", paths: [path],
                                           presence: .present("installed"), appEvidence: [])
        XCTAssertFalse(LeftoverSummary.build(for: present).nextSteps.contains { $0.command != nil },
                       "an installed app's data is never offered for removal")
    }

    func testBackgroundRowOpensSettingsAndLinksComponents() throws {
        let data = """
        {"name":"Vendor","kind":"app","identifier":"2.com.vendor","toggle":"on","rawDisposition":[],
         "components":[{"id":"07","name":"Vendor Agent","label":"com.vendor.agent","type":"user-agent",
           "category":"launch-items","btmEnabled":true,"launchdDisabled":true,"enabled":false,"running":false,
           "orphaned":false,"leftover":false}]}
        """.data(using: .utf8)!
        let row = try JSONDecoder().decode(BackgroundView.Row.self, from: data)
        let summary = BackgroundSummary.build(for: row)
        XCTAssertEqual(summary.verdict.severity, 2, "a launchd override the pane cannot show is worth a look")
        XCTAssertEqual(summary.nextSteps.first?.kind, .openURL(BackgroundSummary.settingsURL))
        XCTAssertEqual(summary.nextSteps.last?.kind, .showEntry("07"))
    }

    /// Live 2026-09-26: four "Unknown Developer" rows shared one identifier —
    /// rendered alike, selected together, the detail showed another row.
    func testUnnamedRowsGetUniqueIdsAndAnExplanation() throws {
        func component(_ id: String, _ label: String) -> String {
            #"{"id":"\#(id)","name":"\#(label)","label":"\#(label)","type":"legacy agent","category":"launch-items","btmEnabled":true,"launchdDisabled":false,"enabled":true,"running":false,"orphaned":false,"leftover":false}"#
        }
        let json = """
        {"loginItems":[],"note":"","background":[
         {"name":"arch","kind":"developer","identifier":"Unknown Developer","toggle":"on","rawDisposition":[],"components":[\(component("03", "local.brother.loginserver"))]},
         {"name":"sleepwatcher","kind":"developer","identifier":"Unknown Developer","toggle":"on","rawDisposition":[],"components":[\(component("09", "homebrew.mxcl.sleepwatcher"))]},
         {"name":"Docker","kind":"app","identifier":"2.com.docker.docker","toggle":"on","rawDisposition":[],"components":[\(component("11", "com.docker.helper"))]},
         {"name":"Docker","kind":"developer","identifier":"Docker Inc","toggle":"on","rawDisposition":[],"components":[\(component("12", "com.docker.vmnetd"))]}
        ]}
        """
        let view = try JSONDecoder().decode(BackgroundView.self, from: Data(json.utf8))
        let entries = BackgroundEntry.entries(from: view)
        XCTAssertEqual(Set(entries.map(\.id)).count, 4, "every row needs its own identity")
        XCTAssertEqual(entries.map(\.unnamed), [true, true, false, false])
        XCTAssertEqual(entries[0].subtitle, "ohne Entwicklerangabe · local.brother.loginserver")
        XCTAssertEqual(entries[2].subtitle, "App · com.docker.helper")
        XCTAssertEqual(entries[3].subtitle, "Entwickler · com.docker.vmnetd", "the two Docker rows are told apart")

        let summary = BackgroundSummary.build(for: entries[0])
        XCTAssertEqual(summary.headline, "Hintergrundobjekt ohne Entwicklerangabe")
        XCTAssertTrue(summary.facts[0].contains("„arch“"))
        XCTAssertEqual(summary.facts[1], "Tatsächlich: local.brother.loginserver")
    }

    func testShowJumpsToTheEntryAndClearsFilters() {
        var item = BackgroundItem(key: "com.apple.x", displayName: "x", type: .launchAgentSystem,
                                  path: "/System/Library/LaunchAgents/com.apple.x.plist", label: "com.apple.x")
        item.id = "07"
        let store = InventoryStore(scanner: { _ in ScanReport(items: [], uncorrelated: [], warnings: []) })
        store.apply(ScanReport(items: [item], uncorrelated: [], warnings: []))
        store.selection = .background
        store.search = "something"
        store.show(displayID: "07")
        XCTAssertEqual(store.selection, .all)
        XCTAssertEqual(store.selectedKey, "com.apple.x")
        XCTAssertEqual(store.search, "")
        XCTAssertFalse(store.hideApple, "an Apple entry is only visible with the toggle off")
    }
}
