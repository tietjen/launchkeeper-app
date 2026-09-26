import SwiftUI
import AppCore

@main
struct LaunchKeeperApp: App {
    @State private var store = InventoryStore()
    @State private var leftovers = LeftoversModel(sources: { LivePresence.sources() })
    @State private var quarantine = QuarantineModel()

    var body: some Scene {
        WindowGroup("LaunchKeeper") {
            ContentView()
                .environment(store)
                .environment(leftovers)
                .environment(quarantine)
                .frame(minWidth: 980, minHeight: 560)
                .task { await store.refresh() }
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Neu einlesen") { Task { await store.refresh(reuseBTM: true) } }
                    .keyboardShortcut("r")
                Button("Vollständig neu einlesen") { Task { await store.refresh() } }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
