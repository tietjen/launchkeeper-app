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
    /// Identifier of the main window group (prefix of its windows' identifiers).
    static let mainWindowID = "main"

    /// The scanned inventory and the window's filter state.
    @State private var store: InventoryStore
    /// The watch (Phase 7): compares every scan, notifies new entries.
    @State private var watch: WatchModel
    /// Launch at login.
    @State private var loginItem = LoginItem()
    /// The work queue (Phase 10) and the ticks that feed it.
    @State private var queue: QueueModel
    @State private var marks = Marks()
    /// Opens entries from notifications and the menu bar.
    private let router: EntryRouter
    /// Keeps the notification delegate and the watch switch alive for the app's lifetime.
    private let notifier: WatchNotifier
    private let watchController: WatchController
    /// Sparkle (Phase 8); inert when not running from the release bundle.
    private let updater = Updater()
    /// Shows the menu-bar item while the watch is on.
    @AppStorage(WatchSettings.enabled) private var watchEnabled = false
    /// App leftovers; LaunchServices via AppKit comes from `LivePresence`.
    @State private var leftovers = LeftoversModel(sources: { LivePresence.sources() })
    /// Quarantine entries shared with the CLI.
    @State private var quarantine = QuarantineModel()
    /// The privileged helper's registration state (Settings, action sheets).
    @State private var helper = HelperStatus()
    /// Basic vs. expert detail view; same key as the toolbar toggle and `DetailView`.
    @AppStorage("expertMode") private var expertMode = false

    /// Wires store, watch, notifications and router; starts the watch when it was on.
    init() {
        UserDefaults.standard.register(defaults: [WatchSettings.notify: true])
        let store = InventoryStore()
        // Fresh BTM dumps through the helper, without Touch ID, when it is set up.
        store.quietBTMReader = { HelperClient.readBTM() }
        let watch = WatchModel(store: store)
        let router = EntryRouter(store: store)
        let notifier = WatchNotifier(router: router) { UserDefaults.standard.bool(forKey: WatchSettings.notify) }
        watch.notifier = notifier
        _store = State(initialValue: store)
        _watch = State(initialValue: watch)
        // The queue's app-side engine shares the inventory's BTM dump.
        _queue = State(initialValue: QueueModel(local: EnginePerformer(btmCache: store.btmDumpCache,
                                                                       presence: { LivePresence.sources() })))
        self.router = router
        self.notifier = notifier
        watchController = WatchController(watch: watch)
    }

    var body: some Scene {
        WindowGroup("LaunchKeeper", id: Self.mainWindowID) {
            ContentView()
                .environment(store)
                .environment(watch)
                .environment(queue)
                .environment(marks)
                .modifier(RegisterWindowOpener(router: router))
                .environment(leftovers)
                .environment(quarantine)
                .environment(helper)
                .environment(notifier)
                .frame(minWidth: 980, minHeight: 560)
                // First scan on launch; a full one, so the BTM dump is fresh.
                .task { await store.refresh(reason: .launch) }
        }
        // ⌘R reuses the session's BTM dump (seconds), ⇧⌘R asks the daemon
        // again (can take minutes after it sat idle).
        .commands {
            // App menu: "Nach Updates suchen …" right below "Über LaunchKeeper".
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updater.updater)
            }
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
        // ⌘, — the privileged helper's state and controls.
        Settings {
            HelperSettingsView(updater: updater.updater).environment(helper).environment(loginItem).environment(notifier)
        }
        // While the watch is on: an eye in the menu bar, also with no window open.
        MenuBarExtra("LaunchKeeper", systemImage: "eye", isInserted: $watchEnabled) {
            WatchMenu(router: router).environment(watch)
        }
    }
}
