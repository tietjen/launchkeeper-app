//
//  DetailView.swift
//  LaunchKeeper — the detail column for one inventory entry.
//

import SwiftUI
import AppKit
import AppCore
import LaunchKeeperKit

/// The detail column for one entry, in two modes.
///
/// - **Basic** (default): what the entry is in one phrase, a traffic-light
///   verdict, the key facts and the sensible next steps (`EntrySummary`).
///   "Alle Details anzeigen" opens the expert sections below for this entry.
/// - **Expert**: everything the scan knows — identity and state, files,
///   findings, provenance and signature (with an on-demand deep check),
///   control and why, the evidence sources and all metadata.
///
/// The mode is remembered (`expertMode` in the user defaults) and switched
/// from the toolbar or "Darstellung › Expertenmodus" (⌥⌘E).
struct DetailView: View {
    /// The row to show.
    let row: InventoryRow
    private var item: BackgroundItem { row.item }
    /// Global mode, shared with the toolbar toggle and the menu command.
    @AppStorage("expertMode") private var expertMode = false
    /// Basic mode only: this entry's details were opened. Reset per entry (`.id`).
    @State private var showAllDetails = false
    /// Result of "Signatur gründlich prüfen"; reset when another entry is shown (`.id`).
    @State private var verification: SignatureVerification?
    /// `true` while the deep signature check runs.
    @State private var verifying = false

    var body: some View {
        Form {
            if expertMode {
                expertSections
            } else {
                basicSections
                if showAllDetails {
                    expertSections
                } else {
                    Section {
                        Button("Alle Details anzeigen") { showAllDetails = true }
                            .buttonStyle(.link)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .id(item.key)   // a new entry starts collapsed and without the previous verification
    }

    // MARK: - Basic mode

    /// Headline, verdict, facts and next steps — what a user needs to decide.
    @ViewBuilder private var basicSections: some View {
        let summary = EntrySummary.build(for: item)
        Section {
            VerdictBanner(verdict: summary.verdict)
            Text(summary.headline).font(.title3)
            if !summary.facts.isEmpty {
                Text(summary.facts.joined(separator: " · ")).foregroundStyle(.secondary)
            }
        } header: {
            Text(item.displayName).font(.headline).textSelection(.enabled)
        }
        Section("Nächste Schritte") {
            ForEach(summary.nextSteps) { step in NextStepRow(step: step) }
        }
    }

    // MARK: - Expert mode

    /// Every section the scan can fill — the full picture for experts.
    @ViewBuilder private var expertSections: some View {
            Section {
                LabeledContent("Name", value: item.displayName)
                LabeledContent("Kategorie", value: item.category.title)
                LabeledContent("Typ", value: item.type.rawValue)
                if let label = item.label { LabeledContent("Label", value: label) }
                LabeledContent("Schlüssel") { Text(item.key).textSelection(.enabled) }
                LabeledContent("Zustand", value: stateText)
            } header: {
                HStack { BadgeStrip(badges: row.badges); Text(item.displayName).font(.headline) }
            }

            Section("Dateien") {
                if let path = item.path { pathRow("Quelle", path) }
                if let exec = item.executable, exec != item.path { pathRow("Programm", exec) }
                if !item.arguments.isEmpty {
                    LabeledContent("Argumente") { Text(item.arguments.joined(separator: " ")).textSelection(.enabled) }
                }
                if let app = item.parentApplication { LabeledContent("App", value: app) }
            }

            if item.orphaned || !item.riskFlags.isEmpty {
                Section("Befund") {
                    ForEach(item.orphanReasons, id: \.self) { reason in
                        Label(reason, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                    ForEach(item.riskFlags, id: \.self) { flag in
                        Label(flag, systemImage: "eye").foregroundStyle(.yellow)
                    }
                }
            }

            Section("Herkunft & Signatur") {
                LabeledContent("Herkunft", value: provenanceText)
                LabeledContent("Signatur", value: item.codeSignatureStatus ?? "–")
                if let team = item.teamIdentifier ?? item.metadata["signature-team"] { LabeledContent("Team", value: team) }
                if let developer = item.developer { LabeledContent("Entwickler", value: developer) }
                if let target = SignatureCheck.target(of: item) {
                    if let verification {
                        LabeledContent("Siegel", value: verification.sealValid ? String(localized: "intakt") : verification.sealDetail)
                        LabeledContent("Gatekeeper", value: [verification.assessment, verification.assessmentSource]
                                        .compactMap { $0 }.joined(separator: " · "))
                        LabeledContent("Hardened Runtime", value: verification.hardenedRuntime ? "ja" : "nein")
                        if !verification.authorities.isEmpty {
                            LabeledContent("Kette") { Text(verification.authorities.joined(separator: " → ")).textSelection(.enabled) }
                        }
                        if let sha = verification.sha256 {
                            LabeledContent("SHA-256") { Text(sha).font(.caption.monospaced()).textSelection(.enabled) }
                        }
                    } else {
                        Button {
                            verifying = true
                            Task {
                                verification = await SignatureCheck.verify(path: target)
                                verifying = false
                            }
                        } label: {
                            if verifying { ProgressView().controlSize(.small) } else { Text("Signatur gründlich prüfen") }
                        }
                        .disabled(verifying)
                        .help("codesign --verify --strict, Gatekeeper, Zertifikatskette, SHA-256")
                    }
                }
            }

            if let control = item.control {
                Section("Steuerung") {
                    LabeledContent("Möglich", value: controlText(control))
                    Text(control.reason).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }

            Section("Quellen") {
                ForEach(Array(item.sources.enumerated()), id: \.offset) { _, source in
                    Text("\(source.kind.rawValue): \(source.detail)").font(.callout).textSelection(.enabled)
                }
            }

            if !item.metadata.isEmpty {
                Section("Details") {
                    ForEach(item.metadata.keys.sorted(), id: \.self) { key in
                        LabeledContent(key) { Text(item.metadata[key] ?? "").textSelection(.enabled) }
                    }
                }
            }
            }

    /// "aktiviert · geladen · läuft (PID 123)" — the entry's live state in one line.
    private var stateText: String {
        var parts = [item.enabled ? String(localized: "aktiviert") : String(localized: "deaktiviert")]
        if item.loaded { parts.append(String(localized: "geladen")) }
        if item.running { parts.append(item.pid.map { String(localized: "läuft (PID \($0))") } ?? String(localized: "läuft")) }
        return parts.joined(separator: " · ")
    }

    /// Provenance kind plus package id and version when a receipt is known.
    private var provenanceText: String {
        guard let provenance = item.provenance else { return "unknown" }
        var text = provenance.kind.rawValue
        if let package = provenance.packageIdentifier { text += " · \(package)" }
        if let version = provenance.version { text += " \(version)" }
        return text
    }

    /// Control level, allowed actions and mechanism in one line,
    /// e.g. "reversible — disable, enable (pluginkit)".
    /// - Parameter control: The entry's control matrix entry.
    private func controlText(_ control: Controllability) -> String {
        let actions = control.actions.isEmpty ? "" : " — " + control.actions.joined(separator: ", ")
        let via = control.mechanism.map { " (\($0.rawValue))" } ?? ""
        return control.level.rawValue + actions + via
    }

    /// A labelled, selectable path with a "Reveal in Finder" button when the file exists.
    /// - Parameters:
    ///   - title: The row label.
    ///   - path: The absolute path.
    private func pathRow(_ title: LocalizedStringKey, _ path: String) -> some View {
        LabeledContent(title) {
            HStack {
                Text(path).textSelection(.enabled).lineLimit(2).truncationMode(.middle)
                if FileManager.default.fileExists(atPath: path) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.borderless)
                    .help("Im Finder zeigen")
                }
            }
        }
    }
}

// MARK: - Basic-mode building blocks

/// The traffic light at the top of the basic view: colour, symbol and one sentence.
struct VerdictBanner: View {
    let verdict: EntrySummary.Verdict

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
        .padding(.vertical, 4)
    }

    private var text: String {
        switch verdict {
        case .ok: return String(localized: "Unauffällig")
        case .leftover: return String(localized: "Nur noch ein Rest-Eintrag — harmlos, macOS räumt ihn selbst auf")
        case .review(let why): return String(localized: "Ansehen empfohlen: \(why)")
        case .orphan(let why): return String(localized: "Verwaist: \(why)")
        }
    }

    private var symbol: String {
        switch verdict {
        case .ok: return "checkmark.seal.fill"
        case .leftover: return "leaf.fill"
        case .review: return "eye.fill"
        case .orphan: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch verdict {
        case .ok: return .green
        case .leftover: return .secondary
        case .review: return .yellow
        case .orphan: return .orange
        }
    }
}

/// One next step: title and explanation, and what can be done with it now.
///
/// Operations are not executed by the app yet (Phase 4a); until then the row
/// offers the equivalent CLI command — a dry run — to copy into Terminal.
struct NextStepRow: View {
    let step: EntrySummary.NextStep

    var body: some View {
        switch step.kind {
        case .operation:
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(step.title).bold()
                        if step.requiresAdmin {
                            Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                                .help("Braucht Administratorrechte")
                        }
                    }
                    Text(step.detail).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if let command = step.command {
                    Button("Befehl kopieren") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(command, forType: .string)
                    }
                    .help("\(command) — zeigt im Terminal erst den Plan; ausgeführt wird erst mit --apply. "
                          + "Direkt in der App: bald.")
                }
            }
        case .reveal(let path):
            Button { revealInFinder(path) } label: {
                Label(step.title, systemImage: "magnifyingglass")
            }
            .buttonStyle(.link)
            .help(path)
        case .info:
            VStack(alignment: .leading, spacing: 2) {
                Label(step.title, systemImage: "info.circle")
                Text(step.detail).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
    }
}
