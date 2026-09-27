//
//  QueueModelTests.swift
//  AppCoreTests — the work queue: one target once, plans for all at once,
//  administrator items to the helper (one call), failures do not stop the
//  rest, the queue survives a restart, the way back is offered.
//

import XCTest
@testable import AppCore
import LaunchKeeperKit

/// Answers batches from a table and records every call.
final class StubBatch: BatchPerforming, @unchecked Sendable {
    /// Plan per request (dry-run); `admin` marks a plan with a sudo step.
    var plans: [ActionRequest: (admin: Bool, refused: String?)] = [:]
    /// Result per request when executed; missing = done.
    var failures: [ActionRequest: String] = [:]
    /// Undo hint per request.
    var undo: [ActionRequest: String] = [:]
    /// Answer every executed request as "not authorized" (cancelled Touch ID).
    var denyAuthorization = false
    private(set) var calls: [(requests: [ActionRequest], apply: Bool)] = []

    func performBatch(_ requests: [ActionRequest], apply: Bool, shouldContinue: @escaping @Sendable () -> Bool,
                      progress: @escaping @Sendable (Int, ActionOutcome) -> Void) -> [ActionOutcome] {
        calls.append((requests, apply))
        return requests.enumerated().map { index, request in
            let outcome: ActionOutcome
            if !apply {
                let plan = plans[request] ?? (false, nil)
                let step = ActionOutcome.Step(id: 0, command: plan.admin ? "/usr/bin/sudo x" : "/bin/launchctl x",
                                              description: "x", needsAdmin: plan.admin)
                outcome = ActionOutcome(state: plan.refused.map { .refused($0) } ?? .planned, steps: [step],
                                        messages: [], undo: nil)
            } else if !shouldContinue() {
                outcome = ActionOutcome(state: .refused("stopped"), steps: [], messages: [], undo: nil)
            } else if denyAuthorization {
                var denied = ActionOutcome(state: .refused("Anmeldung abgebrochen"), steps: [], messages: [], undo: nil)
                denied.authorizationDenied = true
                outcome = denied
            } else if let failure = failures[request] {
                outcome = ActionOutcome(state: .failed(failure), steps: [], messages: [], undo: nil)
            } else {
                outcome = ActionOutcome(state: .done, steps: [], messages: [], undo: undo[request])
            }
            progress(index, outcome)
            return outcome
        }
    }
}

@MainActor
final class QueueModelTests: XCTestCase {
    private func entry(_ key: String, _ operation: String = "disable") -> QueueItem {
        QueueItem(target: .entry(key: key), title: key, origin: "Inventar", action: .remediation(operation: operation, key: key))
    }

    func testOneTargetIsQueuedOnceAndTakesTheNewAction() {
        let queue = QueueModel(local: StubBatch(), storeURL: nil)
        XCTAssertEqual(queue.add([entry("a"), entry("b")]), 2)
        XCTAssertEqual(queue.add([entry("a", "remove")]), 0, "already queued")
        XCTAssertEqual(queue.items.count, 2)
        XCTAssertEqual(queue.items[0].action, .remediation(operation: "remove", key: "a"))
    }

    func testPlanThenRunSplitsAdminItemsToTheHelperInOneCall() async {
        let local = StubBatch(), helper = StubBatch()
        let a = ActionRequest.remediation(operation: "disable", key: "a")
        let b = ActionRequest.remediation(operation: "disable", key: "b")
        let c = ActionRequest.remediation(operation: "disable", key: "c")
        local.plans = [b: (true, nil), c: (true, nil)]
        local.failures = [a: "exit 1"]
        let queue = QueueModel(local: local, storeURL: nil)
        queue.privileged = helper
        queue.add([entry("a"), entry("b"), entry("c")])

        await queue.execute()   // plans first (pending items)
        XCTAssertEqual(local.calls.map(\.apply), [false, true], "one plan for all, then the app's own items")
        XCTAssertEqual(local.calls[0].requests.count, 3, "every item planned in ONE batch")
        XCTAssertEqual(helper.calls.count, 1, "one helper call — one Touch ID")
        XCTAssertEqual(helper.calls[0].requests, [b, c])
        XCTAssertEqual(queue.items.map(\.status), [.failed("exit 1"), .done, .done], "a failure does not stop the rest")
        XCTAssertEqual(queue.phase, .idle)
    }

    func testCancelledTouchIDRunsNothingElse() async {
        // Review S2: cancelling the dialog means "do nothing" — also for the app's own items.
        let local = StubBatch(), helper = StubBatch()
        local.plans = [.remediation(operation: "disable", key: "admin"): (true, nil)]
        helper.denyAuthorization = true
        let queue = QueueModel(local: local, storeURL: nil)
        queue.privileged = helper
        queue.add([entry("admin"), entry("local")])
        await queue.execute()
        XCTAssertEqual(local.calls.map(\.apply), [false], "the app's own item did not run")
        guard case .refused = queue.items[1].status else { return XCTFail("\(queue.items[1].status)") }
    }

    func testNoWayBackForStatusesReadFromTheFile() throws {
        // Review C3: a "done" from queue.json proves nothing — only this session's runs get a way back.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("queue-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        var forged = entry("x")
        forged.status = .done
        try JSONEncoder().encode([forged]).write(to: url)
        let queue = QueueModel(local: StubBatch(), storeURL: url)
        XCTAssertEqual(queue.items.first?.status, .done)
        XCTAssertTrue(queue.undoItems().isEmpty)
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        queue.clearDone()
        let after = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(after, 0o600, "saved owner-only (was \(String(describing: permissions)))")
    }

    func testAdminItemsWithoutHelperAreRefusedWithTheReason() async {
        let local = StubBatch()
        local.plans = [.remediation(operation: "disable", key: "a"): (true, nil)]
        let queue = QueueModel(local: local, storeURL: nil)
        queue.add([entry("a")])
        await queue.execute()
        guard case .refused(let reason) = queue.items[0].status else { return XCTFail("\(queue.items[0].status)") }
        XCTAssertTrue(reason.contains("Hilfsprogramm"), reason)
        XCTAssertEqual(local.calls.map(\.apply), [false], "nothing executed")
    }

    func testGateRefusalsAreShownAndNotRun() async {
        let local = StubBatch()
        local.plans = [.remediation(operation: "disable", key: "apple"): (false, "Apple system component")]
        let queue = QueueModel(local: local, storeURL: nil)
        queue.add([entry("apple"), entry("b")])
        await queue.execute()
        XCTAssertEqual(queue.items.map(\.status), [.refused("Apple system component"), .done])
        XCTAssertEqual(local.calls.last?.requests, [.remediation(operation: "disable", key: "b")])
    }

    func testQueueSurvivesARestart() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("queue-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let first = QueueModel(local: StubBatch(), storeURL: url)
        first.add([entry("a"), QueueItem(target: .quarantine(name: "q1"), title: "q1", origin: "Quarantäne",
                                         action: .restore(quarantine: "q1"))])
        let second = QueueModel(local: StubBatch(), storeURL: url)
        XCTAssertEqual(second.items.map(\.target), [.entry(key: "a"), .quarantine(name: "q1")])
        second.clear()
        XCTAssertTrue(QueueModel(local: StubBatch(), storeURL: url).items.isEmpty, "clearing is saved too")
    }

    func testWayBackInvertsAndRestores() async {
        let local = StubBatch()
        let removal = ActionRequest.remediation(operation: Controllability.removeWorking, key: "w")
        local.undo = [removal: "launchkeeper quarantine restore 2026-09-27-1Z-remove-w.plist && launchkeeper enable w"]
        let queue = QueueModel(local: local, storeURL: nil)
        queue.add([entry("a"), QueueItem(target: .entry(key: "w"), title: "w", origin: "Inventar", action: removal)])
        await queue.execute()
        let back = queue.undoItems().map(\.action)
        XCTAssertEqual(back, [.remediation(operation: "enable", key: "a"), .restore(quarantine: "2026-09-27-1Z-remove-w.plist")])
        XCTAssertNil(QueueModel.quarantineName(inUndo: "launchkeeper quarantine restore <the new quarantine entry>"))
    }

    func testUninstallingAPackageFlagsItsQueuedEntries() {
        let queue = QueueModel(local: StubBatch(), storeURL: nil)
        queue.add([entry("from.pkg"), entry("other"),
                   QueueItem(target: .package(id: "com.vendor.pkg"), title: "pkg", origin: "Pakete",
                             action: .uninstall(package: "com.vendor.pkg"))])
        let hints = queue.conflicts { $0 == "from.pkg" ? "com.vendor.pkg" : nil }
        XCTAssertEqual(hints.count, 1)
        XCTAssertNotNil(hints[queue.items[0].id])
    }

    // MARK: By hand (step 4)

    func testByHandItemsAreNeverPlannedOrRunAndTickOffAfterAScan() async {
        let local = StubBatch()
        let queue = QueueModel(local: local, storeURL: nil)
        queue.add([QueueItem(target: .entry(key: "login"), title: "App", origin: "Hintergrund", action: .manual(key: "login"),
                             manualBaseline: true),
                   QueueItem(target: .entry(key: "gone"), title: "Old", origin: "Hintergrund", action: .manual(key: "gone")),
                   entry("auto")])
        XCTAssertEqual(queue.items[0].status, .manual(done: false))
        await queue.execute()
        XCTAssertEqual(local.calls.flatMap(\.requests), [.remediation(operation: "disable", key: "auto"),
                                                         .remediation(operation: "disable", key: "auto")],
                       "only the automatic item is planned and run")
        XCTAssertEqual(queue.items[0].status, .manual(done: false))

        // After a scan: "login" still enabled, "gone" no longer in the inventory.
        XCTAssertEqual(queue.updateManual { $0 == "login" ? true : nil }, 1)
        XCTAssertEqual(queue.items.map(\.status), [.manual(done: false), .manual(done: true), .done])
        // Switched off in System Settings → ticked off by the next scan.
        XCTAssertEqual(queue.updateManual { $0 == "login" ? false : nil }, 1)
        queue.clearDone()
        XCTAssertTrue(queue.items.isEmpty, "finished by-hand items are cleared with the done ones")
    }

    func testByHandItemsSurviveARestartAndCanBeTickedByHand() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("queue-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let first = QueueModel(local: StubBatch(), storeURL: url)
        first.add([QueueItem(target: .entry(key: "ext"), title: "Ext", origin: "Inventar", action: .manual(key: "ext"),
                             manualBaseline: false)])
        let second = QueueModel(local: StubBatch(), storeURL: url)
        XCTAssertEqual(second.items.first?.manualBaseline, false)
        XCTAssertEqual(second.updateManual { _ in false }, 0, "was off already: only its disappearance counts")
        second.setManual(done: true, for: second.items[0].id)
        XCTAssertEqual(QueueModel(local: StubBatch(), storeURL: url).items.first?.status, .manual(done: true))
    }

    func testIncompleteScansNeverTickOffMissingEntriesAndReopeningHolds() {
        // Review 2026-09-27 (B1): a timed-out BTM dump lacks all login items.
        let queue = QueueModel(local: StubBatch(), storeURL: nil)
        queue.add([QueueItem(target: .entry(key: "login"), title: "App", origin: "Hintergrund", action: .manual(key: "login"),
                             manualBaseline: true)])
        XCTAssertEqual(queue.updateManual(complete: false) { _ in nil }, 0, "missing in an incomplete scan proves nothing")
        XCTAssertEqual(queue.updateManual(complete: false) { _ in false }, 1, "switched off counts even then")

        // Review C3: opened again by the user, with the current state as baseline — the next scan leaves it open.
        let id = queue.items[0].id
        queue.setManual(done: false, for: id, enabledNow: false)
        XCTAssertEqual(queue.updateManual { _ in false }, 0)
        XCTAssertEqual(queue.items[0].status, .manual(done: false))
        // A gone entry cannot be opened again.
        queue.setManual(done: true, for: id)
        queue.setManual(done: false, for: id, enabledNow: nil)
        XCTAssertEqual(queue.items[0].status, .manual(done: true))
    }

    func testViewsFindWhatIsQueuedAndCanTakeItOut() {
        // TJ 2026-09-27: queued rows are marked in their view and can be taken out there.
        let queue = QueueModel(local: StubBatch(), storeURL: nil)
        queue.add([entry("a"), QueueItem(target: .package(id: "com.vendor.pkg"), title: "pkg", origin: "Pakete",
                                         action: .uninstall(package: "com.vendor.pkg"))])
        XCTAssertEqual(queue.item(for: .entry(key: "a"))?.action, .remediation(operation: "disable", key: "a"))
        XCTAssertNil(queue.item(for: .entry(key: "b")))
        queue.remove([queue.item(for: .package(id: "com.vendor.pkg"))!.id])
        XCTAssertNil(queue.item(for: .package(id: "com.vendor.pkg")))
    }

    func testGuidesPointToTheRightPlace() {
        func item(_ type: ItemType, _ category: ItemCategory) -> BackgroundItem {
            BackgroundItem(key: "k", displayName: "k", type: type, path: nil, label: nil, domain: .user, category: category)
        }
        XCTAssertEqual(ManualGuide.for(item(.loginItem, .loginItems)).url, ManualGuide.loginItems)
        XCTAssertEqual(ManualGuide.for(item(.systemExtension, .systemExtensions)).url, ManualGuide.loginItems)
        XCTAssertEqual(ManualGuide.for(item(.unknown, .profiles)).url, ManualGuide.profiles)
        XCTAssertEqual(ManualGuide.for(item(.unknown, .privacy)).url, ManualGuide.privacy)
        XCTAssertNil(ManualGuide.for(item(.kernelExtension, .systemExtensions)).url, "only the vendor's uninstaller")
    }
}
