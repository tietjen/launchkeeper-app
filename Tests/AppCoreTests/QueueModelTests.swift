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
}
