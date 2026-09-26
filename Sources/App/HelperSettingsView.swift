//
//  HelperSettingsView.swift
//  LaunchKeeper — Settings (⌘,): the privileged helper's state and controls,
//  the watch, launch at login and updates.
//

import SwiftUI
import AppCore
import HelperShared
import Sparkle

/// Shows whether the helper is registered and allowed, and sets it up or removes it.
struct HelperSettingsView: View {
    @Environment(HelperStatus.self) private var helper
    /// Sparkle's updater for the "Updates" section; `nil` outside the release bundle.
    let updater: SPUUpdater?

    var body: some View {
        Form {
            Section("Hilfsprogramm für Administratorrechte") {
                LabeledContent("Zustand", value: stateText)
                if let version = helper.version { LabeledContent("Version", value: version) }
                if helper.isOutdated {
                    // Helpers before 0.1.1 never exit by themselves, so only a restart helps.
                    Text("Es läuft noch eine ältere Version des Hilfsprogramms (\(helper.version ?? "?")). Bis zum Neustart führt LaunchKeeper darüber nichts aus.")
                        .font(.callout).foregroundStyle(.orange)
                    Button("Hilfsprogramm neu starten") { Task { await helper.restart() } }
                }
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
                if helper.status == .requiresApproval {
                    Text("Erlaube „LaunchKeeper“ in Systemeinstellungen › Allgemein › Anmeldeobjekte & Erweiterungen unter „Im Hintergrund erlauben“, dann „Neu prüfen“.")
                        .font(.callout)
                }
                if let error = helper.lastError { Text(error).foregroundStyle(.red).font(.callout) }
            }
            WatchSettingsSection()
            UpdateSettingsSection(updater: updater)
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
