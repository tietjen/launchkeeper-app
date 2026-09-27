//
//  HelperCoreTests.swift
//  HelperCoreTests — the helper's safety rules without a daemon: sudo steps
//  map only to allowlisted tools, requests are validated, engine results map
//  onto the wire type, the client context never comes from the payload.
//

import XCTest
@testable import HelperCore
import HelperShared
import LaunchKeeperKit

final class RootRunnerTests: XCTestCase {
    func testSudoStepsRunTheAllowlistedToolDirectly() {
        XCTAssertEqual(RootRunner.resolve(command: "/usr/bin/sudo", arguments: ["launchctl", "bootout", "system/x"]),
                       .run("/bin/launchctl", ["bootout", "system/x"]))
        XCTAssertEqual(RootRunner.resolve(command: "/usr/bin/sudo", arguments: ["/bin/mv", "--", "/a", "/b/"]),
                       .run("/bin/mv", ["--", "/a", "/b/"]))
        XCTAssertEqual(RootRunner.resolve(command: "/usr/bin/sudo", arguments: ["-n", "/usr/bin/cksum", "--", "/x"]),
                       .run("/usr/bin/cksum", ["--", "/x"]))
        XCTAssertEqual(RootRunner.resolve(command: "/usr/bin/sudo", arguments: ["-v"]), .skip)
        XCTAssertEqual(RootRunner.resolve(command: "/bin/launchctl", arguments: ["print", "system"]),
                       .run("/bin/launchctl", ["print", "system"]), "non-sudo steps pass unchanged")
    }

    func testAnythingOffTheListIsRefused() {
        for tool in ["bash", "/bin/sh", "osascript", "/usr/bin/python3", "chmod", "/tmp/evil"] {
            XCTAssertNil(RootRunner.resolve(command: "/usr/bin/sudo", arguments: [tool, "-c", "x"]), tool)
        }
        let runner = RootRunner(inner: ScriptedCommandRunner())
        XCTAssertEqual(runner.run(command: "/usr/bin/sudo", arguments: ["bash", "-c", "id"], timeout: 1).exitCode, 126)
    }
}

final class PrivilegedRequestTests: XCTestCase {
    func testValidation() {
        XCTAssertNil(PrivilegedRequest(kind: .disable, target: "com.vendor.daemon").validationError())
        XCTAssertNotNil(PrivilegedRequest(kind: .disable, target: "").validationError())
        XCTAssertNotNil(PrivilegedRequest(kind: .remove, target: "--apply").validationError())
        XCTAssertNotNil(PrivilegedRequest(kind: .uninstall, target: "com.x\nrm").validationError())
        XCTAssertNotNil(PrivilegedRequest(kind: .purge, target: String(repeating: "a", count: 2000)).validationError())
    }

    func testRoundTripAndUnknownKindIsRejected() throws {
        let request = PrivilegedRequest(kind: .uninstall, target: "com.vendor.pkg")
        XCTAssertEqual(try JSONDecoder().decode(PrivilegedRequest.self, from: JSONEncoder().encode(request)), request)
        XCTAssertThrowsError(try JSONDecoder().decode(PrivilegedRequest.self,
                                                      from: Data(#"{"kind":"shell","target":"id"}"#.utf8)))
    }
}

final class PrivilegedExecutorTests: XCTestCase {
    func testInvalidRequestNeverReachesAnEngine() {
        let executor = PrivilegedExecutor(runner: ScriptedCommandRunner(), auditDirectory: NSTemporaryDirectory())
        let outcome = executor.perform(PrivilegedRequest(kind: .disable, target: "-x"),
                                       client: ClientContext(uid: 501, home: "/Users/alice"))
        XCTAssertEqual(outcome.state, "error")
        XCTAssertEqual(outcome.detail, "target looks like an option")
    }

    func testEngineStatusesMapOntoTheWire() {
        let plan = [PlannedCommand(command: "/usr/bin/sudo", arguments: ["launchctl", "disable", "system/x"],
                                   description: "persistently disable")]
        let done = PrivilegedExecutor.outcome(.appliedOk, plan: plan, messages: ["verified"], undo: "launchkeeper enable x")
        XCTAssertEqual(done.state, "done")
        XCTAssertEqual(done.steps, [["/usr/bin/sudo launchctl disable system/x", "persistently disable"]])
        XCTAssertEqual(PrivilegedExecutor.outcome(.refused("Apple"), plan: [], messages: [], undo: nil).detail, "Apple")
        XCTAssertEqual(PrivilegedExecutor.outcome(.planned, plan: [], messages: [], undo: nil).state, "error",
                       "the helper never answers with a mere plan")
    }

    func testClientContextComesFromTheUserDatabaseNotRoot() {
        XCTAssertNil(ClientContext.forUID(0), "root is never a client")
        let me = ClientContext.forUID(getuid())
        XCTAssertEqual(me?.home, NSHomeDirectory())
    }

    func testHandOverRefusesAHomeTheClientDoesNotOwn() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("lk-handover-\(UUID().uuidString)").path
        let quarantine = home + "/q/entry"
        try FileManager.default.createDirectory(atPath: quarantine, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: home) }
        // Claimed uid 4242 does not own the temp home: nothing may be chowned (and nothing crashes).
        PrivilegedExecutor(runner: ScriptedCommandRunner()).handOver(quarantineRoot: home + "/q",
                                                                     to: ClientContext(uid: 4242, home: home))
        let owner = try FileManager.default.attributesOfItem(atPath: quarantine)[.ownerAccountID] as? NSNumber
        XCTAssertEqual(owner?.intValue, Int(getuid()))
    }
}

// MARK: - Phase 10: batches

final class PrivilegedBatchTests: XCTestCase {
    private let client = ClientContext(uid: 501, home: FileManager.default.temporaryDirectory
        .appendingPathComponent("lk-batch-\(UUID().uuidString)").path)

    func testBatchValidation() {
        let one = [PrivilegedRequest(kind: .disable, target: "x")]
        XCTAssertNil(PrivilegedBatch(requests: one, prompt: "LaunchKeeper wants to change 1 startup item.").validationError())
        XCTAssertEqual(PrivilegedBatch(requests: [], prompt: "p").validationError(), "empty batch")
        XCTAssertEqual(PrivilegedBatch(requests: Array(repeating: one[0], count: PrivilegedBatch.maxRequests + 1),
                                       prompt: "p").validationError(), "batch too large")
        XCTAssertEqual(PrivilegedBatch(requests: one, prompt: "two\nlines").validationError(), "control characters in prompt")
        XCTAssertEqual(PrivilegedBatch(requests: one, prompt: "").validationError(), "prompt missing or too long")
        // Review C2: a batch of several must name its size in the dialog.
        let three = Array(repeating: one[0], count: 3)
        XCTAssertEqual(PrivilegedBatch(requests: three, prompt: "LaunchKeeper wants to change a startup item.").validationError(),
                       "prompt does not name the batch size")
        XCTAssertNil(PrivilegedBatch(requests: three, prompt: "LaunchKeeper wants to change 3 startup items.").validationError())
    }

    func testOutcomesComeBackInRequestOrderWithProgressForEveryEntry() {
        let executor = PrivilegedExecutor(runner: ScriptedCommandRunner(), auditDirectory: NSTemporaryDirectory())
        let requests = [
            PrivilegedRequest(kind: .restore, target: "no-such-quarantine-entry"),   // cleanup, runs second
            PrivilegedRequest(kind: .disable, target: "-bad"),                         // invalid, never runs
            PrivilegedRequest(kind: .disable, target: "de.example.not.installed"),     // remediation, runs first
        ]
        var progressed: [Int] = []
        let outcomes = executor.performBatch(requests, client: client, progress: { index, _ in progressed.append(index) })
        XCTAssertEqual(outcomes.count, 3)
        XCTAssertEqual(outcomes[1].state, "error")
        XCTAssertEqual(outcomes[1].detail, "target looks like an option")
        XCTAssertEqual(outcomes[0].state, "refused", "\(outcomes[0])")
        XCTAssertEqual(outcomes[2].state, "refused", "\(outcomes[2])")
        XCTAssertEqual(Set(progressed), [0, 1, 2], "every entry reports progress exactly once")
        XCTAssertEqual(progressed.count, 3)
    }

    func testStopLeavesTheRestUnrun() {
        let executor = PrivilegedExecutor(runner: ScriptedCommandRunner(), auditDirectory: NSTemporaryDirectory())
        let outcomes = executor.performBatch([PrivilegedRequest(kind: .restore, target: "a"),
                                              PrivilegedRequest(kind: .restore, target: "b")],
                                             client: client, shouldContinue: { false })
        XCTAssertEqual(outcomes.map(\.detail), ["stopped before this entry", "stopped before this entry"])
    }
}
