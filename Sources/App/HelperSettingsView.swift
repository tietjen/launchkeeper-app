//
//  HelperSettingsView.swift
//  LaunchKeeper — Settings (⌘,): the privileged helper's state and controls.
//

import SwiftUI
import AppCore
import HelperShared

/// Shows whether the helper is registered and allowed, and sets it up or removes it.
struct HelperSettingsView: View {
    @Environment(HelperStatus.self) private var helper

    var body: some View {
        Form {
            Section("Hilfsprogramm für Administratorrechte") {
                LabeledContent("Zustand", value: stateText)
                if let version = helper.version { LabeledContent("Version", value: version) }
                Text("Änderungen an Systemdiensten, Dateien in /Library, der Firewall, Paket-Deinstallationen und das endgültige Löschen aus der Quarantäne brauchen Administratorrechte. LaunchKeeper führt sie über dieses Hilfsprogramm aus — nur nach Touch ID oder Passwort, jedes Mal neu, und nur Aktionen, die dieselbe Prüfung wie die Kommandozeile bestehen. Es nimmt keine Befehle entgegen, nur „was mit welchem Eintrag“.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    switch helper.status {
                    case .enabled:
                        Button("Entfernen", role: .destructive) { Task { await helper.unregister() } }
                    case .requiresApproval:
                        Button("In den Systemeinstellungen erlauben") { helper.openSettings() }
                    default:
                        Button("Einrichten") { helper.register() }
                    }
                    Button("Neu prüfen") { helper.refresh() }
                }
                if let error = helper.lastError { Text(error).foregroundStyle(.red).font(.callout) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .onAppear { helper.refresh() }
    }

    private var stateText: String {
        switch helper.status {
        case .enabled: return String(localized: "eingerichtet und erlaubt")
        case .requiresApproval: return String(localized: "wartet auf deine Freigabe in den Systemeinstellungen")
        case .notRegistered: return String(localized: "nicht eingerichtet")
        case .notFound: return String(localized: "nicht gefunden — die App muss aus ihrem Bundle gestartet werden")
        @unknown default: return String(localized: "unbekannt")
        }
    }
}
