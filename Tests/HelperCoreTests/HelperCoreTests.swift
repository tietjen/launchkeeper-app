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

/// An executor whose bookkeeping is a temp tree owned by the test user
/// (production: the root-owned tree under /Library/Application Support).
func testExecutor(_ base: String) -> PrivilegedExecutor {
    let bookkeeping = Bookkeeping(quarantine: base + "/quarantine", backups: base + "/backups",
                                  configSnapshots: base + "/config-snapshots", trustedUID: getuid(), prepare: {
        for directory in ["quarantine", "backups", "config-snapshots"] {
            try? FileManager.default.createDirectory(atPath: base + "/" + directory, withIntermediateDirectories: true,
                                                     attributes: [.posixPermissions: 0o755])
        }
        return nil
    })
    return PrivilegedExecutor(runner: ScriptedCommandRunner(), auditDirectory: NSTemporaryDirectory(), bookkeeping: bookkeeping)
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
        let executor = testExecutor(client.home + "-bookkeeping")
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
        let executor = testExecutor(client.home + "-bookkeeping")
        let outcomes = executor.performBatch([PrivilegedRequest(kind: .disable, target: "a"),
                                              PrivilegedRequest(kind: .enable, target: "b")],
                                             client: client, shouldContinue: { false })
        XCTAssertEqual(outcomes.map(\.detail), ["stopped before this entry", "stopped before this entry"])
    }
}

// MARK: - Root-owned bookkeeping (reviews 2026-09-27: root keeps nothing in the user's home)

final class QuarantineTrustTests: XCTestCase {
    private func temp() throws -> String {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("lk-trust-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
        return base
    }

    func testChainMustBeRealOwnedAndNotWritableByOthers() throws {
        let base = try temp()
        defer { try? FileManager.default.removeItem(atPath: base) }
        let fm = FileManager.default
        try fm.createDirectory(atPath: base + "/a/b", withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
        XCTAssertNil(QuarantineTrust.verifyChain(base + "/a/b", from: base, trustedUID: getuid()))
        XCTAssertNotNil(QuarantineTrust.verifyChain(base + "/a/b", from: base, trustedUID: 0), "foreign owner")
        try fm.setAttributes([.posixPermissions: 0o775], ofItemAtPath: base + "/a")
        XCTAssertTrue(QuarantineTrust.verifyChain(base + "/a/b", from: base, trustedUID: getuid())?.contains("writable") == true)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: base + "/a")
        try fm.createSymbolicLink(atPath: base + "/link", withDestinationPath: base + "/a")
        XCTAssertTrue(QuarantineTrust.verifyChain(base + "/link/b", from: base, trustedUID: getuid())?.contains("symlink") == true)
    }

    func testIntactEntryIsTrustedAndTamperingIsNot() throws {
        let base = try temp()
        defer { try? FileManager.default.removeItem(atPath: base) }
        let fm = FileManager.default
        let entry = base + "/2026-09-27-1Z-remove-x"
        let file = entry + "/files/Library/LaunchDaemons/x.plist"
        try fm.createDirectory(atPath: (file as NSString).deletingLastPathComponent, withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o755])
        fm.createFile(atPath: file, contents: Data("<plist/>".utf8))
        fm.createFile(atPath: entry + "/manifest.json", contents: Data("{}".utf8))
        let name = "2026-09-27-1Z-remove-x"
        XCTAssertNil(QuarantineTrust.verifyEntry(root: base, name: name, quarantinedPaths: [file], trustedUID: getuid()),
                     "the positive path (review S5)")
        XCTAssertEqual(QuarantineTrust.verifyEntry(root: base, name: "../etc", quarantinedPaths: [], trustedUID: getuid()),
                       "invalid entry name")
        XCTAssertNotNil(QuarantineTrust.verifyEntry(root: base, name: name, quarantinedPaths: ["/etc/passwd"], trustedUID: getuid()))
        try fm.setAttributes([.posixPermissions: 0o777], ofItemAtPath: entry + "/files")
        XCTAssertTrue(QuarantineTrust.verifyEntry(root: base, name: name, quarantinedPaths: [file], trustedUID: getuid())?
            .contains("writable") == true)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: entry + "/files")
        try fm.removeItem(atPath: file)
        try fm.createSymbolicLink(atPath: file, withDestinationPath: "/etc/sudoers")
        XCTAssertTrue(QuarantineTrust.verifyEntry(root: base, name: name, quarantinedPaths: [file], trustedUID: getuid())?
            .contains("symlink") == true)
        XCTAssertTrue(QuarantineTrust.verifyEntry(root: base, name: name, quarantinedPaths: [file], trustedUID: 0)?
            .contains("foreign owner") == true)
    }

    func testEntriesOfTheUsersQuarantineAreNeverRestoredByTheHelper() throws {
        let base = try temp()
        defer { try? FileManager.default.removeItem(atPath: base) }
        let home = base + "/home"
        let name = "2026-09-27-1Z-remove-y"
        try FileManager.default.createDirectory(atPath: home + "/Library/Application Support/launchkeeper/quarantine/" + name,
                                                withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: home + "/Library/Application Support/launchkeeper/quarantine/" + name + "/manifest.json",
                                       contents: Data("{}".utf8))
        let executor = testExecutor(base + "/bookkeeping")
        let client = ClientContext(uid: Int(getuid()), home: home)
        let own = executor.perform(PrivilegedRequest(kind: .restore, target: name), client: client)
        XCTAssertEqual(own.state, "refused")
        XCTAssertTrue(own.detail?.contains("launchkeeper quarantine restore \(name)") == true, own.detail ?? "")
        let none = executor.perform(PrivilegedRequest(kind: .purge, target: "nothing-here"), client: client)
        XCTAssertEqual(none.detail, "no such quarantine entry")
    }

    func testUnsafeBookkeepingRefusesEverything() {
        let broken = Bookkeeping(quarantine: "/nonexistent/q", backups: "/nonexistent/b", configSnapshots: "/nonexistent/c",
                                 trustedUID: 0, prepare: { "symlink: /Library/Application Support/launchkeeper" })
        let executor = PrivilegedExecutor(runner: ScriptedCommandRunner(), auditDirectory: NSTemporaryDirectory(), bookkeeping: broken)
        let client = ClientContext(uid: 501, home: "/Users/alice")
        XCTAssertEqual(executor.perform(PrivilegedRequest(kind: .disable, target: "x"), client: client).state, "refused")
        XCTAssertEqual(executor.performBatch([PrivilegedRequest(kind: .disable, target: "x")], client: client).map(\.state),
                       ["refused"])
    }
}
