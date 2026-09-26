//
//  EntrySummaryTests.swift
//  AppCoreTests — basic-mode summaries: verdicts, facts, next steps derived
//  from the control matrix, admin detection and CLI addresses.
//

import XCTest
@testable import AppCore
import LaunchKeeperKit

final class EntrySummaryTests: XCTestCase {
    /// A user LaunchAgent with a given control matrix entry.
    private func agent(_ label: String, control: Controllability?, orphaned: Bool = false,
                       enabled: Bool = true) -> BackgroundItem {
        var item = BackgroundItem(key: label, displayName: label, type: .launchAgentUser,
                                  path: NSHomeDirectory() + "/Library/LaunchAgents/\(label).plist", label: label,
                                  domain: .user, enabled: enabled, orphaned: orphaned)
        item.plistPresent = true
        item.control = control
        if orphaned { item.orphanReasons = ["executable missing: /Applications/Gone.app"] }
        return item
    }

    func testOrphanOffersRemovalFirstThenDisableThenFinder() {
        let item = agent("com.vendor.gone", control: Controllability(level: .removable,
            actions: ["disable", "enable", "remove"], reason: "orphaned", mechanism: .launchd), orphaned: true)
        let summary = EntrySummary.build(for: item)
        XCTAssertEqual(summary.verdict, .orphan("executable missing: /Applications/Gone.app"))
        XCTAssertEqual(summary.nextSteps.map(\.title), ["Entfernen", "Deaktivieren (umkehrbar)", "Im Finder zeigen"])
        XCTAssertEqual(summary.nextSteps.first?.command, "launchkeeper remove com.vendor.gone")
        XCTAssertFalse(summary.nextSteps.first!.requiresAdmin, "a user agent needs no admin rights")
        XCTAssertEqual(summary.headline, "Startet beim Anmelden (LaunchAgent)")
    }

    func testDisabledEntryOffersEnableNotDisable() {
        let item = agent("com.vendor.off", control: Controllability(level: .reversible,
            actions: ["disable", "enable"], reason: "override", mechanism: .launchd), enabled: false)
        let titles = EntrySummary.build(for: item).nextSteps.map(\.title)
        XCTAssertTrue(titles.contains("Wieder aktivieren"))
        XCTAssertFalse(titles.contains("Deaktivieren (umkehrbar)"))
        XCTAssertTrue(EntrySummary.build(for: item).facts.contains("ausgeschaltet"))
    }

    func testSystemDaemonNeedsAdminExtensionDoesNot() {
        var daemon = BackgroundItem(key: "com.vendor.d", displayName: "d", type: .launchDaemon,
                                    path: "/Library/LaunchDaemons/com.vendor.d.plist", label: "com.vendor.d",
                                    domain: .system)
        daemon.control = Controllability(level: .reversible, actions: ["disable", "enable"], reason: "x",
                                         mechanism: .launchd)
        XCTAssertTrue(EntrySummary.build(for: daemon).nextSteps.first!.requiresAdmin)

        var ext = BackgroundItem(key: "ext:com.vendor.QL", displayName: "QL", type: .appExtension,
                                 path: "/Applications/V.app/Contents/PlugIns/QL.appex", category: .appExtensions)
        ext.sources = [SourceEvidence(kind: .pluginkit, detail: "x", confidence: .high)]
        ext.metadata["ext-identifier"] = "com.vendor.QL"
        ext.control = Controllability(level: .reversible, actions: ["disable", "enable"], reason: "x",
                                      mechanism: .pluginkit)
        let step = EntrySummary.build(for: ext).nextSteps.first!
        XCTAssertFalse(step.requiresAdmin)
        XCTAssertEqual(step.command, "launchkeeper disable com.vendor.QL", "addressed by pluginkit id, not display id")
    }

    func testDisplayOnlySaysWhereTheSwitchIs() {
        var sysext = BackgroundItem(key: "sysext:x", displayName: "x", type: .systemExtension, domain: .system,
                                    category: .systemExtensions)
        sysext.control = Controllability(level: .displayOnly, actions: [],
                                         reason: "move its host app to the Trash in the Finder")
        let steps = EntrySummary.build(for: sysext).nextSteps
        XCTAssertEqual(steps.map(\.kind), [.info])
        XCTAssertTrue(steps[0].detail.contains("Trash"))
    }

    func testVerdictsAndSigner() {
        var unsigned = agent("com.vendor.u", control: nil)
        unsigned.codeSignatureStatus = "unsigned"
        XCTAssertEqual(EntrySummary.build(for: unsigned).verdict.severity, 2)
        XCTAssertTrue(EntrySummary.build(for: unsigned).facts.contains("nicht signiert"))

        var leftover = agent("btm:x", control: nil, orphaned: true)
        leftover.metadata["btm-leftover"] = "true"
        XCTAssertEqual(EntrySummary.build(for: leftover).verdict, .leftover, "a leftover is not an alarm")

        var signed = agent("com.vendor.s", control: nil)
        signed.codeSignatureStatus = "signed"
        signed.metadata["signature-team"] = "ABCDE12345"
        signed.metadata["signature-authority"] = "Developer ID Application: Vendor Inc (ABCDE12345)"
        XCTAssertTrue(EntrySummary.build(for: signed).facts.contains("signiert von Vendor Inc"))
        XCTAssertEqual(EntrySummary.build(for: signed).verdict, .ok)
    }

    func testCliAddressQuotesWhenNeeded() {
        var cron = BackgroundItem(key: "cron:alice:crontab:/opt/x --flag", displayName: "x", type: .cronJob)
        cron.metadata["cron-command"] = "/opt/x --flag"
        XCTAssertEqual(EntrySummary.cliAddress(cron), "'cron:alice:crontab:/opt/x --flag'")
        XCTAssertEqual(EntrySummary.authorityName("Apple Development: x (Y)"), "x")
    }
}
