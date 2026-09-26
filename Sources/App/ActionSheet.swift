//
//  ActionSheet.swift
//  LaunchKeeper — the confirmation sheet every action goes through:
//  plan (dry-run) → explicit "Ausführen" → verified result.
//

import SwiftUI
import AppKit
import AppCore
import HelperShared

/// Shows what an action will do before it does it, then the verified result.
///
/// The plan comes from the same engines as the CLI's dry-run. A plan with a
/// step that needs administrator rights is shown but cannot be executed from
/// the app yet (Phase 5 helper) — the sheet offers the Terminal command instead.
struct ActionSheet: View {
    /// Drives plan and execution; one per sheet.
    @State private var model: ActionModel
    /// Whether the privileged helper is set up — decides what admin plans offer.
    @Environment(HelperStatus.self) private var helper
    /// Called once when the sheet closes after something was executed.
    private let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    /// Opens LaunchKeeper's own Settings window (helper setup and restart).
    @Environment(\.openSettings) private var openSettings

    /// Creates the sheet and its model.
    /// - Parameters:
    ///   - request: What to do.
    ///   - performer: Runs the engines.
    ///   - onChanged: Called when the sheet closes after an execution (refresh the views).
    init(request: ActionRequest, performer: ActionPerforming, onChanged: @escaping () -> Void) {
        _model = State(initialValue: ActionModel(request: request, performer: performer))
        self.onChanged = onChanged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.request.title).font(.title2).bold()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 120, maxHeight: 360)
            // Outside the scroll view: a long plan must never push the reason
            // why "Ausführen" is unavailable (and the way out) out of sight.
            adminFooter
            buttons
        }
        .padding(20)
        .frame(width: 600)
        .task {
            helper.refresh()
            await model.plan()
        }
        .onChange(of: helperUsable) { _, usable in model.privileged = usable ? PrivilegedPerformer() : nil }
        .onAppear { model.privileged = helperUsable ? PrivilegedPerformer() : nil }
    }

    /// The helper can take requests: registered, allowed and running this
    /// app's build. An outdated helper is never sent anything — it may check
    /// authorization the old way and would fail after the Touch ID prompt.
    private var helperUsable: Bool { helper.isReady && !helper.isOutdated }

    // MARK: Content per phase

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .planning:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Plan wird berechnet — das Inventar wird dafür neu gelesen …").foregroundStyle(.secondary)
            }
        case .planned(let outcome):
            planView(outcome, heading: "Das würde passieren — noch ist nichts geändert:")
        case .executing(let outcome):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Wird ausgeführt und danach überprüft …").foregroundStyle(.secondary)
            }
            planView(outcome, heading: "Plan:")
        case .finished(let outcome):
            resultView(outcome)
        }
    }

    /// How a plan with administrator steps can run: via the helper (Touch ID),
    /// after restarting an outdated helper, or after setting it up.
    @ViewBuilder private var adminFooter: some View {
        if model.helperFailedBeforeRunning {
            helperRepair
        } else if case .planned(let outcome) = model.phase, outcome.needsAdmin, case .planned = outcome.state {
            if helper.isOutdated && model.request.privileged != nil {
                outdatedNotice
            } else if helperUsable && model.request.privileged != nil {
                Label("Braucht Administratorrechte — nach dem Klick fragt macOS nach Touch ID oder deinem Passwort.",
                      systemImage: "touchid")
                    .font(.callout)
            } else {
                adminNotice
            }
        }
    }

    /// The plan: each step in words, with the command in small monospace below.
    @ViewBuilder private func planView(_ outcome: ActionOutcome, heading: LocalizedStringKey) -> some View {
        if case .refused(let reason) = outcome.state {
            Label(reason, systemImage: "hand.raised.fill").foregroundStyle(.orange)
        } else if !outcome.steps.isEmpty {
            Text(heading).font(.headline)
            ForEach(outcome.steps) { step in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(step.id + 1). \(step.description)")
                        if step.needsAdmin {
                            Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                                .help("Braucht Administratorrechte")
                        }
                    }
                    Text(step.command).font(.caption.monospaced()).foregroundStyle(.secondary)
                        .textSelection(.enabled).lineLimit(3)
                }
            }
        }
        notes(outcome)
    }

    /// Engine notes and the way back.
    @ViewBuilder private func notes(_ outcome: ActionOutcome) -> some View {
        ForEach(Array(outcome.messages.enumerated()), id: \.offset) { _, message in
            Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
        }
        if let undo = outcome.undo {
            Label { Text("Rückweg: \(undo)").textSelection(.enabled) } icon: {
                Image(systemName: "arrow.uturn.backward")
            }
            .font(.callout)
        }
    }

    /// The helper did not run the request: offer the repair in one click —
    /// restart it and plan again, or open LaunchKeeper's Settings.
    private var helperRepair: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Das Hilfsprogramm hat nichts ausgeführt — auf dem Mac ist nichts geändert.",
                  systemImage: "wrench.and.screwdriver").font(.headline)
            Text("Meist hilft ein Neustart des Hilfsprogramms. Danach wird der Plan neu berechnet und du kannst es noch einmal versuchen.")
                .font(.callout)
            HStack {
                Button("Neu starten und erneut versuchen") {
                    Task {
                        await helper.restart()
                        await model.plan()
                    }
                }
                .keyboardShortcut(.defaultAction)
                settingsButton
                if helper.status == .requiresApproval {
                    Button("In den Systemeinstellungen erlauben") { helper.openSettings() }
                }
            }
            if let error = helper.lastError { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    /// Closes the sheet and opens the helper section in LaunchKeeper's Settings.
    private var settingsButton: some View {
        Button("Einstellungen öffnen") {
            dismiss()
            openSettings()
        }
    }

    /// An older helper is running: offer the restart right here.
    private var outdatedNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Hilfsprogramm veraltet", systemImage: "arrow.triangle.2.circlepath").font(.headline)
            Text("Es läuft noch Version \(helper.version ?? "?") des Hilfsprogramms, diese App bringt \(HelperIdentity.version) mit. Nach dem Neustart kannst du ausführen.")
                .font(.callout)
            HStack {
                Button("Hilfsprogramm neu starten") { Task { await helper.restart() } }
                settingsButton
                if helper.status == .requiresApproval {
                    Button("In den Systemeinstellungen erlauben") { helper.openSettings() }
                }
                if let error = helper.lastError { Text(error).font(.caption).foregroundStyle(.red) }
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    /// Why the app does not execute this plan, and how to do it now.
    private var adminNotice: some View {
        let command = model.request.cliCommand(apply: true)
        return VStack(alignment: .leading, spacing: 6) {
            Label("Braucht Administratorrechte", systemImage: "lock.fill").font(.headline)
            if model.request.privileged == nil {
                Text("Diese Aktion führt die App noch nicht mit Administratorrechten aus. Im Terminal geht es; dort fragt macOS nach deinem Passwort:")
                    .font(.callout)
            } else {
                Text("Schritte mit Administratorrechten führt LaunchKeeper über sein Hilfsprogramm aus — mit Touch ID bei jeder Ausführung. Einmal einrichten:")
                    .font(.callout)
                HStack {
                    Button(helper.status == .requiresApproval ? "In den Systemeinstellungen erlauben" : "Hilfsprogramm einrichten") {
                        if helper.status == .requiresApproval { helper.openSettings() } else { helper.register() }
                    }
                    settingsButton
                    if let error = helper.lastError { Text(error).font(.caption).foregroundStyle(.red) }
                }
                Text("Oder jetzt im Terminal:").font(.callout)
            }
            HStack {
                Text(command).font(.callout.monospaced()).textSelection(.enabled)
                Spacer()
                Button("Kopieren") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                }
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    /// The verified result — or what failed and how to recover.
    @ViewBuilder private func resultView(_ outcome: ActionOutcome) -> some View {
        switch outcome.state {
        case .done:
            Label("Erledigt und überprüft", systemImage: "checkmark.seal.fill").foregroundStyle(.green).font(.headline)
        case .failed(let detail):
            Label("Nicht vollständig: \(detail)", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange).font(.headline)
        case .refused(let reason):
            Label(reason, systemImage: "hand.raised.fill").foregroundStyle(.orange)
        case .planned:
            EmptyView()
        }
        notes(outcome)
    }

    // MARK: Buttons

    @ViewBuilder private var buttons: some View {
        HStack {
            Spacer()
            switch model.phase {
            case .planning, .executing:
                Button("Abbrechen") { dismiss() }.disabled(true)
            case .planned:
                Button("Abbrechen", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(model.executesPrivileged ? "Ausführen (Touch ID)" : "Ausführen") { Task { await model.execute() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canExecute)
            case .finished:
                Button("Fertig") {
                    onChanged()
                    dismiss()
                }
                // Return goes to the repair button when the helper failed.
                .keyboardShortcut(model.helperFailedBeforeRunning ? .cancelAction : .defaultAction)
            }
        }
    }
}

/// The performer the app's sheets use: the CLI engines with the inventory's
/// BTM cache and AppKit presence sources.
@MainActor
enum Performer {
    static func make(store: InventoryStore) -> ActionPerforming {
        EnginePerformer(btmCache: store.btmDumpCache, presence: { LivePresence.sources() })
    }
}
