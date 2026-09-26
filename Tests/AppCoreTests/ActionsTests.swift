//
//  ActionsTests.swift
//  AppCoreTests — the action flow: plan first, execute only without admin
//  steps, refusals shown, sudo refused by the runner, next steps carry the
//  request by stable key.
//

import XCTest
@testable import AppCore
import LaunchKeeperKit
import HelperShared

/// Answers plan and execute with fixed outcomes and records the calls.
final class StubPerformer: ActionPerforming, @unchecked Sendable {
    var planned: ActionOutcome
    var executed: ActionOutcome
    private(set) var calls: [Bool] = []

    init(planned: ActionOutcome, executed: ActionOutcome) {
        self.planned = planned
        self.executed = executed
    }

    func perform(_ request: ActionRequest, apply: Bool) -> ActionOutcome {
        calls.append(apply)
        return apply ? executed : planned
    }
}

@MainActor
final class ActionsTests: XCTestCase {
    private func step(_ command: String, admin: Bool = false) -> ActionOutcome.Step {
        ActionOutcome.Step(id: 0, command: command, description: "x", needsAdmin: admin)
    }

    func testPlanThenExecute() async {
        let stub = StubPerformer(
            planned: ActionOutcome(state: .planned, steps: [step("/bin/launchctl disable gui/501/x")], messages: [], undo: "launchkeeper enable x"),
            executed: ActionOutcome(state: .done, steps: [], messages: ["verified"], undo: "launchkeeper enable x"))
        let model = ActionModel(request: .remediation(operation: "disable", key: "x"), performer: stub)
        await model.plan()
        XCTAssertTrue(model.canExecute)
        XCTAssertEqual(stub.calls, [false], "planning is a dry-run")
        await model.execute()
        XCTAssertEqual(stub.calls, [false, true])
        guard case .finished(let outcome) = model.phase else { return XCTFail("\(model.phase)") }
        XCTAssertEqual(outcome.state, .done)
    }

    func testAdminStepsAndRefusalsCannotBeExecuted() async {
        let admin = StubPerformer(
            planned: ActionOutcome(state: .planned, steps: [step("/usr/bin/sudo launchctl disable system/x", admin: true)],
                                   messages: [], undo: nil),
            executed: ActionOutcome(state: .done, steps: [], messages: [], undo: nil))
        let adminModel = ActionModel(request: .remediation(operation: "disable", key: "x"), performer: admin)
        await adminModel.plan()
        XCTAssertFalse(adminModel.canExecute, "the app never runs a sudo step")
        await adminModel.execute()
        XCTAssertEqual(admin.calls, [false], "execute is a no-op without permission")

        let refused = StubPerformer(planned: ActionOutcome(state: .refused("Apple"), steps: [], messages: [], undo: nil),
                                    executed: ActionOutcome(state: .done, steps: [], messages: [], undo: nil))
        let refusedModel = ActionModel(request: .remediation(operation: "remove", key: "com.apple.x"), performer: refused)
        await refusedModel.plan()
        XCTAssertFalse(refusedModel.canExecute)
    }

    func testOutcomeMappingMarksSudoStepsAndDropsDuplicateRefusalLine() {
        let outcome = ActionOutcome.from(
            status: .refused("not orphaned"),
            plan: [PlannedCommand(command: "/usr/bin/sudo", arguments: ["rm", "--", "/Library/x"], description: "delete")],
            messages: ["refused: not orphaned", "this is a hard gate — no flag bypasses it"], undo: nil)
        XCTAssertEqual(outcome.state, .refused("not orphaned"))
        XCTAssertTrue(outcome.needsAdmin)
        XCTAssertEqual(outcome.messages, ["this is a hard gate — no flag bypasses it"])
    }

    func testNoSudoRunnerRefusesSudoOnly() {
        let inner = ScriptedCommandRunner(responses: ["/bin/echo hi": CommandResult(exitCode: 0, stdout: "hi", stderr: "")])
        let runner = NoSudoRunner(inner: inner)
        XCTAssertEqual(runner.run(command: "/usr/bin/sudo", arguments: ["rm", "-rf", "/"], timeout: 1).exitCode, 126)
        XCTAssertEqual(runner.runInteractive(command: "/usr/bin/sudo", arguments: ["-v"], timeout: 1), 126)
        XCTAssertEqual(runner.run(command: "/bin/echo", arguments: ["hi"], timeout: 1).stdout, "hi")
    }

    func testCommandsAndStepsAddressByStableKey() {
        XCTAssertEqual(ActionRequest.remediation(operation: "disable", key: "cron:alice:crontab:/x -y").cliCommand(apply: true),
                       "launchkeeper disable 'cron:alice:crontab:/x -y' --apply")
        XCTAssertEqual(ActionRequest.restore(quarantine: "2026-09-26-1Z-leftovers-org.x").cliCommand(apply: false),
                       "launchkeeper quarantine restore 2026-09-26-1Z-leftovers-org.x")

        var item = BackgroundItem(key: "com.vendor.agent", displayName: "agent", type: .launchAgentUser,
                                  path: NSHomeDirectory() + "/Library/LaunchAgents/com.vendor.agent.plist",
                                  label: "com.vendor.agent", domain: .user)
        item.control = Controllability(level: .reversible, actions: ["disable", "enable"], reason: "x", mechanism: .launchd)
        XCTAssertEqual(EntrySummary.build(for: item).nextSteps.first?.action,
                       .remediation(operation: "disable", key: "com.vendor.agent"))
    }
}

// MARK: - Phase 5: routing to the helper

@MainActor
final class PrivilegedRoutingTests: XCTestCase {
    func testRequestsMapToHelperRequestsExceptLeftovers() {
        XCTAssertEqual(ActionRequest.remediation(operation: "remove", key: "k").privileged,
                       PrivilegedRequest(kind: .remove, target: "k"))
        XCTAssertEqual(ActionRequest.uninstall(package: "com.x").privileged, PrivilegedRequest(kind: .uninstall, target: "com.x"))
        XCTAssertEqual(ActionRequest.restore(quarantine: "n").privileged, PrivilegedRequest(kind: .restore, target: "n"))
        XCTAssertNil(ActionRequest.leftovers(bundleID: "org.x").privileged)
    }

    func testAdminPlansGoToTheHelperOnlyWhenItIsThere() async {
        let adminPlan = ActionOutcome(state: .planned,
                                      steps: [ActionOutcome.Step(id: 0, command: "/usr/bin/sudo launchctl disable system/x",
                                                                 description: "x", needsAdmin: true)],
                                      messages: [], undo: nil)
        let local = StubPerformer(planned: adminPlan, executed: ActionOutcome(state: .done, steps: [], messages: [], undo: nil))
        let helper = StubPerformer(planned: adminPlan,
                                   executed: ActionOutcome(state: .done, steps: [], messages: ["via helper"], undo: nil))
        let model = ActionModel(request: .remediation(operation: "disable", key: "x"), performer: local)
        await model.plan()
        XCTAssertFalse(model.canExecute, "no helper, no admin execution")
        model.privileged = helper
        XCTAssertTrue(model.canExecute)
        XCTAssertTrue(model.executesPrivileged)
        await model.execute()
        XCTAssertEqual(local.calls, [false], "the app process never executes an admin plan")
        XCTAssertEqual(helper.calls, [true])
    }

    func testHelperOutcomeMapping() {
        let outcome = ActionOutcome.from(privileged: PrivilegedOutcome(state: "error", detail: "not authorized"))
        XCTAssertEqual(outcome.state, .failed("not authorized"))
        // A cancelled Touch ID / password dialog: refused, nothing changed — not an error.
        let cancelled = ActionOutcome.from(privileged: PrivilegedOutcome(state: "refused", detail: "not authorized"))
        XCTAssertEqual(cancelled.state, .refused("Anmeldung abgebrochen oder abgelehnt — nichts geändert"))
        let done = ActionOutcome.from(privileged: PrivilegedOutcome(state: "done", steps: [["/bin/rm -- /x", "delete"]]))
        XCTAssertEqual(done.state, .done)
        XCTAssertEqual(done.steps.first?.description, "delete")
    }
}
