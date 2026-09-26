//
//  RunsAndOwnFilesTests.swift
//  AppCoreTests — what interpreter entries really run (kit 0.9.4 metadata)
//  in facts, background subtitles and the VirusTotal hash target, and
//  package verdicts judged by own files.
//

import XCTest
@testable import AppCore
import LaunchKeeperKit

final class RunsAndOwnFilesTests: XCTestCase {
    /// An entry as the kit annotates it for `bash /usr/local/bin/sync.sh`.
    private func bashEntry() -> BackgroundItem {
        var item = BackgroundItem(key: "de.example.sync", displayName: "de.example.sync", type: .launchAgentSystem,
                                  path: "/Library/LaunchAgents/de.example.sync.plist", label: "de.example.sync",
                                  executable: "/bin/bash", arguments: ["/usr/local/bin/sync.sh"])
        var items = [item]
        EffectiveProgram.annotate(&items)
        item = items[0]
        item.id = "05"
        return item
    }

    func testFactNamesTheScriptNotTheShell() {
        XCTAssertEqual(EntrySummary.runsFact(for: bashEntry()), "führt aus: Skript /usr/local/bin/sync.sh (über bash)")
        XCTAssertEqual(EntrySummary.build(for: bashEntry()).facts.first,
                       "führt aus: Skript /usr/local/bin/sync.sh (über bash)", "what really runs comes first")
    }

    func testUnnamedBackgroundRowSaysWhatBashRuns() throws {
        let json = """
        {"loginItems":[],"note":"","background":[{"name":"bash","kind":"developer","identifier":"Unknown Developer",
          "toggle":"on","rawDisposition":[],"components":[{"id":"05","name":"de.example.sync","label":"de.example.sync",
          "type":"legacy agent","category":"launch-items","btmEnabled":true,"launchdDisabled":false,"enabled":true,
          "running":false,"orphaned":false,"leftover":false}]}]}
        """
        let view = try JSONDecoder().decode(BackgroundView.self, from: Data(json.utf8))
        let entry = BackgroundEntry.entries(from: view, items: ["05": bashEntry()])[0]
        XCTAssertEqual(entry.subtitle,
                       "ohne Entwicklerangabe · de.example.sync · führt aus: Skript /usr/local/bin/sync.sh (über bash)")
        XCTAssertTrue(BackgroundSummary.build(for: entry).facts.contains("führt aus: Skript /usr/local/bin/sync.sh (über bash)"))
    }

    func testPackageWithOnlySharedFoldersLeftIsGone() throws {
        // Live: ai.abacus.abacusai — 15,245 paths, the one present was /Applications.
        let row = try JSONDecoder().decode(ReceiptsView.Row.self, from: Data(#"""
        {"id":"ai.abacus.abacusai","fileCount":15245,"missingFiles":15244,"items":[],"apple":false,
         "ownFileCount":15226,"ownMissingFiles":15226}
        """#.utf8))
        let summary = PackageSummary.build(for: row)
        XCTAssertEqual(summary.verdict, .leftover, "not 'partially installed'")
        XCTAssertEqual(summary.nextSteps.map(\.title), ["Beleg entfernen"])
        // Localized interpolation groups digits by locale ("15.226" in German) — match the words.
        XCTAssertTrue(summary.facts.contains { $0.hasPrefix("0 von 15") && $0.hasSuffix("226 eigenen Dateien vorhanden") },
                      "\(summary.facts)")
        XCTAssertTrue(summary.facts.contains { $0.contains("geteilte Ordner wie /Applications") })
    }

    func testHashTargetIsTheBinaryBehindALauncher() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lk-runs-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: root + "/tool", contents: Data([0xCF, 0xFA, 0xED, 0xFE]))
        var items = [BackgroundItem(key: "arch", displayName: "arch", type: .launchAgentUser,
                                    executable: "/usr/bin/arch", arguments: ["-arm64", root + "/tool"])]
        EffectiveProgram.annotate(&items)
        XCTAssertEqual(VirusTotalHash.target(of: items[0]), root + "/tool", "not /usr/bin/arch")
    }
}
