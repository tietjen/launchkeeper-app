//
//  LaunchKeeperApp.swift
//  LaunchKeeper — app entry point.
//

import SwiftUI
import AppCore

/// The app: one window, the models it shares, and the refresh commands.
///
/// The models live here (not in the window) so they outlive a closed and
/// reopened window and a slow scan is not started twice.
@main
struct LaunchKeeperApp: App {
    /// The scanned inventory and the window's filter state.
    @State private var store = InventoryStore()
    /// App leftovers; LaunchServices via AppKit comes from `LivePresence`.
    @State private var leftovers = LeftoversModel(sources: { LivePresence.sources() })
    /// Quarantine entries shared with the CLI.
    @State private var quarantine = QuarantineModel()
    /// Basic vs. expert detail view; same key as the toolbar toggle and `DetailView`.
    @AppStorage("expertMode") private var expertMode = false

    var body: some Scene {
        WindowGroup("LaunchKeeper") {
            ContentView()
                .environment(store)
                .environment(leftovers)
                .environment(quarantine)
                .frame(minWidth: 980, minHeight: 560)
                // First scan on launch; a full one, so the BTM dump is fresh.
                .task { await store.refresh() }
        }
        // ⌘R reuses the session's BTM dump (seconds), ⇧⌘R asks the daemon
        // again (can take minutes after it sat idle).
        .commands {
            // "Darstellung" (the View menu): the detail mode, next to the sidebar commands.
            CommandGroup(after: .sidebar) {
                Toggle("Expertenmodus", isOn: $expertMode)
                    .keyboardShortcut("e", modifiers: [.command, .option])
            }
            CommandGroup(after: .toolbar) {
                Button("Neu einlesen") { Task { await store.refresh(reuseBTM: true) } }
                    .keyboardShortcut("r")
                Button("Vollständig neu einlesen") { Task { await store.refresh() } }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
