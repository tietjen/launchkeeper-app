//
//  Actions.swift
//  AppCore — running actions from the app (Phase 4a: everything that needs
//  no administrator rights).
//
//  Every action goes through the same engines as the CLI — same gate, same
//  dry-run plan, same snapshots/quarantine, same verification, same audit
//  log. The app adds two rules on top:
//   1. It always computes the plan first (dry-run) and shows it; executing
//      is a second, explicit step.
//   2. It never runs a privileged step: a plan containing `sudo` is shown
//      but not executed, and the runner refuses `sudo` outright. Those
//      actions arrive with the privileged helper (Phase 5); until then the
//      sheet offers the Terminal command.
//

import Foundation
import Observation
import HelperShared
import LaunchKeeperKit

// MARK: - Request

/// Something the user asked the app to do.
public enum ActionRequest: Hashable, Sendable {
    /// `disable`, `enable` or `remove` for one inventory entry, by stable key.
    case remediation(operation: String, key: String)
    /// Move a gone app's leftovers into the quarantine, by bundle id.
    case leftovers(bundleID: String)
    /// Move a quarantine entry back, by name.
    case restore(quarantine: String)
    /// Uninstall an installer package by its receipt, by exact package id.
    case uninstall(package: String)

    /// Title of the confirmation sheet.
    public var title: String {
        switch self {
        case .remediation(let operation, _):
            switch operation {
            case "disable": return String(localized: "Deaktivieren")
            case "enable": return String(localized: "Wieder aktivieren")
            case "remove": return String(localized: "Entfernen")
            default: return operation
            }
        case .leftovers: return String(localized: "Reste in die Quarantäne verschieben")
        case .restore: return String(localized: "Aus der Quarantäne wiederherstellen")
        case .uninstall: return String(localized: "Paket deinstallieren")
        }
    }

    /// The request as the privileged helper takes it, or `nil` when the
    /// helper does not run it (app leftovers: the presence check needs the
    /// user's LaunchServices, which a daemon does not have).
    public var privileged: PrivilegedRequest? {
        switch self {
        case .remediation(let operation, let key):
            guard let kind = PrivilegedRequest.Kind(rawValue: operation),
                  [.disable, .enable, .remove].contains(kind) else { return nil }
            return PrivilegedRequest(kind: kind, target: key)
        case .restore(let name): return PrivilegedRequest(kind: .restore, target: name)
        case .uninstall(let id): return PrivilegedRequest(kind: .uninstall, target: id)
        case .leftovers: return nil
        }
    }

    /// The equivalent CLI command.
    /// - Parameter apply: `true` adds `--apply` (executes); `false` is the dry-run form.
    /// - Returns: A command line to paste into Terminal.
    public func cliCommand(apply: Bool) -> String {
        let base: String
        switch self {
        case .remediation(let operation, let key): base = "launchkeeper \(operation) \(EntrySummary.quote(key))"
        case .leftovers(let id): base = "launchkeeper leftovers \(EntrySummary.quote(id))"
        case .restore(let name): base = "launchkeeper quarantine restore \(EntrySummary.quote(name))"
        case .uninstall(let id): base = "launchkeeper uninstall \(EntrySummary.quote(id))"
        }
        return apply ? base + " --apply" : base
    }
}

// MARK: - Outcome

/// What an engine answered — a plan (dry-run) or the result of executing it.
public struct ActionOutcome: Equatable, Sendable {
    /// The engine's verdict.
    public enum State: Equatable, Sendable {
        /// Dry-run: nothing changed, `steps` is the plan.
        case planned
        /// Executed and verified.
        case done
        /// Executed, but a step failed or verification disagreed.
        case failed(String)
        /// The gate (or a precondition) refused — nothing ran.
        case refused(String)
    }

    /// One planned or executed step.
    public struct Step: Equatable, Sendable, Identifiable {
        /// Stable id for SwiftUI lists (position in the plan).
        public var id: Int
        /// The command line, e.g. "/bin/launchctl disable gui/501/com.vendor.agent".
        public var command: String
        /// What the step does, in the engine's words.
        public var description: String
        /// `true` when the step runs through `sudo`.
        public var needsAdmin: Bool
    }

    /// The verdict.
    public var state: State
    /// The plan (for `.planned`) or the steps that were planned for execution.
    public var steps: [Step]
    /// The engine's notes: warnings, what stays, verification results.
    public var messages: [String]
    /// How to undo, when there is a way.
    public var undo: String?

    /// `true` when any step needs administrator rights — the app does not execute those (yet).
    public var needsAdmin: Bool { steps.contains(where: \.needsAdmin) }

    /// Creates an outcome.
    public init(state: State, steps: [Step], messages: [String], undo: String?) {
        self.state = state; self.steps = steps; self.messages = messages; self.undo = undo
    }

    /// Maps the privileged helper's answer into an outcome.
    /// - Parameter privileged: The helper's reply.
    /// - Returns: The outcome; helper errors (not authorized, unreachable) become `.failed`.
    public static func from(privileged: PrivilegedOutcome) -> ActionOutcome {
        let state: State
        switch privileged.state {
        case "done": state = .done
        case "refused": state = .refused(privileged.detail ?? "refused")
        default: state = .failed(privileged.detail ?? privileged.state)
        }
        let steps = privileged.steps.enumerated().map { index, pair in
            Step(id: index, command: pair.first ?? "", description: pair.dropFirst().first ?? "", needsAdmin: true)
        }
        return ActionOutcome(state: state, steps: steps, messages: privileged.messages, undo: privileged.undo)
    }

    /// Maps an engine status and plan into an outcome.
    /// - Parameters:
    ///   - status: The engine's status.
    ///   - plan: The engine's planned commands.
    ///   - messages: The engine's notes.
    ///   - undo: The engine's undo hint.
    static func from(status: RemediationStatus, plan: [PlannedCommand], messages: [String],
                     undo: String?) -> ActionOutcome {
        let state: State
        switch status {
        case .planned: state = .planned
        case .appliedOk: state = .done
        case .appliedFailed(let detail): state = .failed(detail)
        case .refused(let reason): state = .refused(reason)
        }
        let steps = plan.enumerated().map { index, command in
            Step(id: index, command: command.display, description: command.description,
                 needsAdmin: command.command == "/usr/bin/sudo")
        }
        // "refused: …" repeats the state's reason — keep the rest.
        return ActionOutcome(state: state, steps: steps,
                             messages: messages.filter { !$0.hasPrefix("refused:") }, undo: undo)
    }
}

// MARK: - Performing

/// Runs commands but refuses `sudo`: the app cannot answer a password
/// prompt, and privileged steps are the helper's job (Phase 5). A second
/// line of defence behind the "no admin step in the plan" check.
public struct NoSudoRunner: CommandRunner {
    /// The runner that executes everything else.
    public let inner: CommandRunner

    /// Creates the guard.
    /// - Parameter inner: The real runner.
    public init(inner: CommandRunner = SystemCommandRunner()) { self.inner = inner }

    public func run(command: String, arguments: [String], timeout: TimeInterval) -> CommandResult {
        guard command != "/usr/bin/sudo" else {
            return CommandResult(exitCode: 126, stdout: "",
                                 stderr: "needs administrator rights — the app runs this with its helper (not yet)")
        }
        return inner.run(command: command, arguments: arguments, timeout: timeout)
    }

    public func runInteractive(command: String, arguments: [String], timeout: TimeInterval) -> Int32 {
        guard command != "/usr/bin/sudo" else { return 126 }
        return inner.runInteractive(command: command, arguments: arguments, timeout: timeout)
    }
}

/// Performs a request: plans it (dry-run) or executes it.
public protocol ActionPerforming: Sendable {
    /// Plans or executes a request. Called off the main thread; may take seconds (it rescans).
    /// - Parameters:
    ///   - request: What to do.
    ///   - apply: `false` plans only (dry-run), `true` executes.
    /// - Returns: The engine's answer.
    func perform(_ request: ActionRequest, apply: Bool) -> ActionOutcome
}

/// The real performer: the CLI's engines with a `NoSudoRunner`.
///
/// `@unchecked Sendable`: it holds a `CommandRunner` (not declared
/// `Sendable`) and the shared BTM cache; both are used by one action at a
/// time — the sheet runs plan and execute sequentially.
public struct EnginePerformer: ActionPerforming, @unchecked Sendable {
    private let runner: CommandRunner
    private let btmCache: BTMDumpCache?
    private let presence: @Sendable () -> AppPresenceSources

    /// Creates the performer.
    /// - Parameters:
    ///   - btmCache: The inventory's dump cache — the engines' resolution scan
    ///     reuses it instead of paying a cold dump per action.
    ///   - presence: Presence sources for app leftovers (AppKit lives in the app).
    ///   - runner: Executes commands; wrapped so `sudo` is always refused.
    public init(btmCache: BTMDumpCache?, presence: @escaping @Sendable () -> AppPresenceSources,
                runner: CommandRunner = SystemCommandRunner()) {
        self.runner = NoSudoRunner(inner: runner)
        self.btmCache = btmCache
        self.presence = presence
    }

    public func perform(_ request: ActionRequest, apply: Bool) -> ActionOutcome {
        btmCache?.preferCached = true
        switch request {
        case .remediation(let name, let key):
            guard let operation = RemediationOperation(rawValue: name) else {
                return ActionOutcome(state: .refused("unknown operation \(name)"), steps: [], messages: [], undo: nil)
            }
            let engine = RemediationEngine(environment: RemediationEnvironment(runner: runner, btmCache: btmCache))
            let result = engine.run(operation: operation, target: key, apply: apply)
            return .from(status: result.status, plan: result.plan, messages: result.messages, undo: result.undoHint)
        case .leftovers(let id):
            let result = CleanupEngine(environment: CleanupEnvironment(runner: runner))
                .removeAppLeftovers(bundleIdentifier: id, sources: presence(), apply: apply)
            return .from(status: result.status, plan: result.plan, messages: result.messages, undo: result.undoHint)
        case .restore(let name):
            let result = CleanupEngine(environment: CleanupEnvironment(runner: runner)).restore(name: name, apply: apply)
            return .from(status: result.status, plan: result.plan, messages: result.messages, undo: result.undoHint)
        case .uninstall(let id):
            let result = CleanupEngine(environment: CleanupEnvironment(runner: runner))
                .uninstall(packageIdentifier: id, apply: apply)
            return .from(status: result.status, plan: result.plan, messages: result.messages, undo: result.undoHint)
        }
    }
}

// MARK: - Sheet state

/// The state of one action sheet: plan → (execute) → result.
@MainActor
@Observable
public final class ActionModel {
    /// Where the sheet is.
    public enum Phase: Equatable {
        /// Computing the plan (a rescan runs).
        case planning
        /// The plan is ready; nothing has changed yet.
        case planned(ActionOutcome)
        /// Executing.
        case executing(ActionOutcome)
        /// Executed (or refused while executing) — the result.
        case finished(ActionOutcome)
    }

    /// What the sheet is about.
    public let request: ActionRequest
    /// The current phase.
    public private(set) var phase: Phase = .planning
    private let performer: ActionPerforming
    /// Executes plans with administrator steps through the privileged
    /// helper — `nil` while the helper is not set up (then such plans are shown only).
    public var privileged: ActionPerforming?

    /// Creates the model; call `plan()` to start.
    /// - Parameters:
    ///   - request: What to do.
    ///   - performer: Plans, and executes plans without admin steps (tests inject a stub).
    ///   - privileged: Executes plans with admin steps (the helper), if available.
    public init(request: ActionRequest, performer: ActionPerforming, privileged: ActionPerforming? = nil) {
        self.request = request
        self.performer = performer
        self.privileged = privileged
    }

    /// `true` when the plan needs administrator rights and will go through the helper (Touch ID).
    public var executesPrivileged: Bool {
        guard case .planned(let outcome) = phase else { return false }
        return outcome.needsAdmin
    }

    /// Whether "Ausführen" is available: a plan exists, the gate allowed it,
    /// and — for a plan with administrator steps — the helper is available
    /// and the request is one the helper runs.
    public var canExecute: Bool {
        guard case .planned(let outcome) = phase, outcome.state == .planned, !outcome.steps.isEmpty else { return false }
        return !outcome.needsAdmin || (privileged != nil && request.privileged != nil)
    }

    /// Computes the plan (dry-run). Nothing changes on the Mac.
    public func plan() async {
        phase = .planning
        let performer = self.performer, request = self.request
        let outcome = await Task.detached(priority: .userInitiated) { performer.perform(request, apply: false) }.value
        phase = .planned(outcome)
    }

    /// Executes the planned action — only when `canExecute`.
    public func execute() async {
        guard canExecute, case .planned(let plan) = phase else { return }
        phase = .executing(plan)
        // Administrator steps never run in the app process: they go to the helper.
        guard let performer = plan.needsAdmin ? privileged : self.performer else { return }
        let request = self.request
        let outcome = await Task.detached(priority: .userInitiated) { performer.perform(request, apply: true) }.value
        phase = .finished(outcome)
    }
}
