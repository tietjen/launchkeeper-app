import SwiftUI
import AppKit
import AppCore
import LaunchKeeperKit

struct DetailView: View {
    let row: InventoryRow
    private var item: BackgroundItem { row.item }

    var body: some View {
        Form {
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
        .formStyle(.grouped)
    }

    private var stateText: String {
        var parts = [item.enabled ? String(localized: "aktiviert") : String(localized: "deaktiviert")]
        if item.loaded { parts.append(String(localized: "geladen")) }
        if item.running { parts.append(item.pid.map { String(localized: "läuft (PID \($0))") } ?? String(localized: "läuft")) }
        return parts.joined(separator: " · ")
    }

    private var provenanceText: String {
        guard let provenance = item.provenance else { return "unknown" }
        var text = provenance.kind.rawValue
        if let package = provenance.packageIdentifier { text += " · \(package)" }
        if let version = provenance.version { text += " \(version)" }
        return text
    }

    private func controlText(_ control: Controllability) -> String {
        let actions = control.actions.isEmpty ? "" : " — " + control.actions.joined(separator: ", ")
        let via = control.mechanism.map { " (\($0.rawValue))" } ?? ""
        return control.level.rawValue + actions + via
    }

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
