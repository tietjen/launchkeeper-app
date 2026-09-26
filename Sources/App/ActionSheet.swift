//
//  ActionSheet.swift
//  LaunchKeeper — the confirmation sheet every action goes through:
//  plan (dry-run) → explicit "Ausführen" → verified result.
//

import SwiftUI
import AppKit
import AppCore

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
            .frame(minHeight: 160, maxHeight: 420)
            buttons
        }
        .padding(20)
        .frame(width: 600)
        .task {
            helper.refresh()
            await model.plan()
        }
        .onChange(of: helper.isReady) { _, ready in model.privileged = ready ? PrivilegedPerformer() : nil }
        .onAppear { model.privileged = helper.isReady ? PrivilegedPerformer() : nil }
    }

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
            if outcome.needsAdmin, case .planned = outcome.state {
                if helper.isReady && model.request.privileged != nil {
                    Label("Braucht Administratorrechte — nach dem Klick fragt macOS nach Touch ID oder deinem Passwort.",
                          systemImage: "touchid")
                        .font(.callout)
                } else {
                    adminNotice
                }
            }
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
                .keyboardShortcut(.defaultAction)
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
