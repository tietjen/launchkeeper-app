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
        // Switches only: quarantine requests are checked for trust before the stop.
        let outcomes = executor.performBatch([PrivilegedRequest(kind: .disable, target: "a"),
                                              PrivilegedRequest(kind: .enable, target: "b")],
                                             client: client, shouldContinue: { false })
        XCTAssertEqual(outcomes.map(\.detail), ["stopped before this entry", "stopped before this entry"])
    }
}

// MARK: - Quarantine trust (review 2026-09-27: no chown into the home, no restore of user-owned entries)

final class QuarantineTrustTests: XCTestCase {
    private func tempHome() throws -> (home: String, client: ClientContext) {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("lk-trust-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: home, withIntermediateDirectories: true)
        return (home, ClientContext(uid: Int(getuid()), home: home))
    }

    func testRootChainIsCreatedAndAcceptedWhenReal() throws {
        let (home, client) = try tempHome()
        defer { try? FileManager.default.removeItem(atPath: home) }
        let root = home + "/Library/Application Support/launchkeeper/quarantine"
        XCTAssertNil(QuarantineTrust.prepareRoot(root, for: client))
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: root, isDirectory: &isDirectory) && isDirectory.boolValue)
        XCTAssertNil(QuarantineTrust.prepareRoot(root, for: client), "idempotent")
    }

    func testSymlinkInTheChainIsRefused() throws {
        let (home, client) = try tempHome()
        defer { try? FileManager.default.removeItem(atPath: home) }
        try FileManager.default.createDirectory(atPath: home + "/Library", withIntermediateDirectories: true)
        // The attack from the review: a component redirected elsewhere.
        try FileManager.default.createSymbolicLink(atPath: home + "/Library/Application Support", withDestinationPath: "/tmp")
        let problem = QuarantineTrust.prepareRoot(home + "/Library/Application Support/launchkeeper/quarantine", for: client)
        XCTAssertNotNil(problem)
        XCTAssertTrue(problem?.contains("symlink") == true, problem ?? "")
        XCTAssertNotNil(QuarantineTrust.prepareRoot("/tmp/elsewhere/quarantine", for: client), "outside the home")
    }

    func testUserOwnedEntryIsNeverRestoredAsRoot() throws {
        // Tests run as the user, so every entry here is user-owned — exactly the
        // state a pre-0.1.7 helper left behind by handing entries over.
        let (home, _) = try tempHome()
        defer { try? FileManager.default.removeItem(atPath: home) }
        let root = home + "/q"
        let entry = root + "/2026-09-27-1Z-remove-x"
        try FileManager.default.createDirectory(atPath: entry + "/files/Library/LaunchDaemons", withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: URL(fileURLWithPath: entry + "/manifest.json"))
        let problem = QuarantineTrust.verifyEntry(root: root, name: "2026-09-27-1Z-remove-x",
                                                  quarantinedPaths: [entry + "/files/Library/LaunchDaemons/x.plist"])
        XCTAssertTrue(problem?.contains("owned by the user") == true, problem ?? "nil")
        XCTAssertEqual(QuarantineTrust.verifyEntry(root: root, name: "../etc", quarantinedPaths: []), "invalid entry name")
    }

    func testRestoreOfAnUntrustedEntryIsRefusedBeforeAnyEngine() throws {
        let (home, client) = try tempHome()
        defer { try? FileManager.default.removeItem(atPath: home) }
        let executor = PrivilegedExecutor(runner: ScriptedCommandRunner(), auditDirectory: NSTemporaryDirectory())
        let outcome = executor.perform(PrivilegedRequest(kind: .restore, target: "nothing-here"), client: client)
        XCTAssertEqual(outcome.state, "refused")
        XCTAssertTrue(outcome.detail?.hasPrefix("quarantine entry not trustworthy") == true, outcome.detail ?? "")
    }
}
