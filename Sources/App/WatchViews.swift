//
//  WatchViews.swift
//  LaunchKeeper — the watch in the UI (Phase 7): the "Beobachtung" view,
//  macOS notifications, the menu-bar item and launch at login.
//

import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications
import AppCore

// MARK: - Settings keys

/// `@AppStorage` keys of the watch, shared by the pane, Settings and the app.
enum WatchSettings {
    /// The watch is on (and restarts with the app).
    static let enabled = "watchEnabled"
    /// New or changed entries are notified.
    static let notify = "watchNotify"
}

// MARK: - Opening an entry from outside the window

/// Brings the main window forward and selects an entry — for notifications
/// and the menu-bar item, which live outside the window.
@MainActor
final class EntryRouter {
    /// Opens a main window; set by the window's content (`openWindow` exists
    /// only in a view's environment). Stays valid after that window closes.
    var openMainWindow: (() -> Void)?
    private let store: InventoryStore

    init(store: InventoryStore) { self.store = store }

    /// Shows the app with the entry selected (or the watch view when it is gone).
    /// - Parameter key: The entry's stable key, if any.
    func show(key: String?) {
        NSApp.activate()
        let hasWindow = NSApp.windows.contains { $0.isVisible && $0.identifier?.rawValue.hasPrefix(LaunchKeeperApp.mainWindowID) == true }
        if !hasWindow { openMainWindow?() }
        if let key, store.reveal(key: key) { return }
        store.selection = .watch
    }
}

// MARK: - Notifications

/// Delivers watch records as macOS notifications and routes clicks to the entry.
///
/// Notifications need a bundled, signed app; run via `swift run` (no bundle
/// identifier) they are skipped instead of crashing the notification center.
@MainActor
final class WatchNotifier: NSObject, WatchNotifying, UNUserNotificationCenterDelegate {
    private let router: EntryRouter
    /// Mirrors the "Mitteilungen" setting at delivery time.
    private let isEnabled: () -> Bool

    init(router: EntryRouter, isEnabled: @escaping () -> Bool) {
        self.router = router
        self.isEnabled = isEnabled
        super.init()
        if Self.available { UNUserNotificationCenter.current().delegate = self }
    }

    /// Notifications work only inside an app bundle.
    static var available: Bool { Bundle.main.bundleIdentifier != nil }

    /// Asks macOS for permission (once; later calls return the stored answer).
    static func requestPermission() {
        guard available else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func deliver(_ record: WatchRecord) {
        guard Self.available, isEnabled() else { return }
        let content = UNMutableNotificationContent()
        content.title = record.headline
        content.body = record.detail
        content.sound = .default
        if let key = record.event.key { content.userInfo = ["key": key] }
        let request = UNNotificationRequest(identifier: record.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // Also show notifications while LaunchKeeper is in front.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    // A click opens the entry in the main window.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let key = response.notification.request.content.userInfo["key"] as? String
        await router.show(key: key)
    }
}

// MARK: - Launch at login

/// Launch at login via `SMAppService.mainApp` (no helper app needed).
@MainActor
@Observable
final class LoginItem {
    /// macOS's state for the app as login item.
    private(set) var status: SMAppService.Status = SMAppService.mainApp.status
    /// The last error, for display.
    private(set) var lastError: String?

    /// `true` when the app starts at login.
    var isEnabled: Bool { status == .enabled }

    /// Turns launch at login on or off.
    /// - Parameter on: The wanted state.
    func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        status = SMAppService.mainApp.status
    }
}

// MARK: - The watch view

/// "Beobachtung": switch the watch on/off and see what it noticed.
struct WatchPane: View {
    @Environment(WatchModel.self) private var watch
    @Binding var selection: WatchRecord.ID?
    @AppStorage(WatchSettings.enabled) private var enabled = false
    @AppStorage(WatchSettings.notify) private var notify = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PaneIntro(text: "Die Beobachtung meldet, wenn etwas Neues automatisch starten will oder sich ein Eintrag ändert — sobald eine Autostart-Stelle geschrieben wird, und alle zehn Minuten vollständig. Was LaunchKeeper selbst geändert hat, wird nur aufgelistet, nicht gemeldet.")
            HStack(spacing: 16) {
                Toggle("Beobachtung", isOn: $enabled).toggleStyle(.switch)
                Toggle("Mitteilungen", isOn: $notify).disabled(!enabled)
                Spacer()
                if !watch.records.isEmpty {
                    Button("Liste leeren") { watch.clearHistory() }
                }
            }
            WatchStatusLine()
            List(watch.records, selection: $selection) { record in
                WatchRecordRow(record: record)
            }
            .overlay {
                if watch.records.isEmpty {
                    ContentUnavailableView("Noch nichts bemerkt", systemImage: "eye",
                                           description: Text(enabled ? "Neue und geänderte Einträge erscheinen hier." : "Schalte die Beobachtung ein."))
                }
            }
        }
        .padding()
    }
}

/// One line on the watch's state: running, baseline, last check, problems.
struct WatchStatusLine: View {
    @Environment(WatchModel.self) private var watch

    var body: some View {
        Group {
            if !watch.isRunning {
                Label("Aus", systemImage: "eye.slash")
            } else if let reason = watch.lastSkipReason {
                Label("Letzte Prüfung unvollständig, nicht verglichen: \(reason)", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if let count = watch.baselineCount {
                Label {
                    Text("Aktiv — \(count) Einträge im Blick") + Text(lastCheckText)
                        + Text(watch.fileEventsActive ? "" : " · nur alle zehn Minuten (Dateiereignisse nicht verfügbar)")
                } icon: { Image(systemName: "eye") }
            } else {
                Label("Aktiv — erstes Inventar wird gelesen …", systemImage: "eye")
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    private var lastCheckText: String {
        guard let date = watch.lastCheck else { return "" }
        return String(localized: ", zuletzt geprüft \(date.formatted(date: .omitted, time: .shortened))")
    }
}

/// A record in the list: what happened, to what, when.
struct WatchRecordRow: View {
    let record: WatchRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(record.headline).bold()
                    if record.isOwn {
                        Text("durch LaunchKeeper").font(.caption)
                            .padding(.horizontal, 5).background(.quaternary, in: Capsule())
                    }
                }
                Text(record.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2).truncationMode(.middle)
            }
            Spacer()
            Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var symbol: String {
        switch record.event.kind {
        case .added: return "plus.circle.fill"
        case .removed: return "minus.circle.fill"
        default: return "pencil.circle.fill"
        }
    }

    private var color: Color {
        if record.isOwn { return .secondary }
        switch record.event.kind {
        case .added: return .orange
        case .removed: return .secondary
        default: return .blue
        }
    }
}

/// Detail of one watch record: what changed, why the watch looked, next step.
struct WatchRecordDetail: View {
    let record: WatchRecord
    @Environment(InventoryStore.self) private var store

    var body: some View {
        Form {
            Section {
                Text(record.headline).font(.title3).bold()
                if record.isOwn {
                    Text("LaunchKeeper hat das selbst geändert (eine Aktion, die du ausgeführt hast).")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Was") {
                if let category = record.event.category { LabeledContent("Kategorie", value: category) }
                if let path = record.event.path {
                    LabeledContent("Pfad") { Text(path).textSelection(.enabled) }
                }
                if let key = record.event.key {
                    LabeledContent("Kennung") { Text(key).textSelection(.enabled).font(.callout.monospaced()) }
                }
                ForEach(Array(record.event.changes.enumerated()), id: \.offset) { _, change in
                    LabeledContent(change.field) { Text("\(change.before) → \(change.after)") }
                }
            }
            Section("Bemerkt") {
                LabeledContent("Wann", value: record.date.formatted(date: .abbreviated, time: .standard))
                LabeledContent("Anlass") { Text(record.event.trigger).textSelection(.enabled) }
            }
            Section {
                if let key = record.event.key, store.row(for: key) != nil {
                    Button("Im Inventar zeigen") { store.reveal(key: key) }
                        .help("Dort steht, was der Eintrag ist, und was du tun kannst.")
                } else if record.event.kind != .removed {
                    Text("Der Eintrag ist im aktuellen Inventar nicht (mehr) vorhanden.").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Menu bar

/// The menu-bar item while the watch is on: its state, the latest changes, and the way into the app.
struct WatchMenu: View {
    @Environment(WatchModel.self) private var watch
    let router: EntryRouter
    @AppStorage(WatchSettings.enabled) private var enabled = false

    var body: some View {
        Text(watch.isRunning ? "Beobachtung aktiv" : "Beobachtung aus")
        let latest = watch.records.filter { !$0.isOwn }.prefix(5)
        if !latest.isEmpty {
            Divider()
            ForEach(Array(latest)) { record in
                Button(record.headline) { router.show(key: record.event.key) }
            }
        }
        Divider()
        Button("LaunchKeeper öffnen") { router.show(key: nil) }
        Button("Beobachtung ausschalten") { enabled = false }
        Divider()
        Button("LaunchKeeper beenden") { NSApp.terminate(nil) }
    }
}

// MARK: - Settings section

/// Settings (⌘,) section for the watch and launch at login.
struct WatchSettingsSection: View {
    @Environment(LoginItem.self) private var loginItem
    @AppStorage(WatchSettings.enabled) private var enabled = false
    @AppStorage(WatchSettings.notify) private var notify = true

    var body: some View {
        Section("Beobachtung") {
            Toggle("Neue Autostart-Einträge beobachten", isOn: $enabled)
            Toggle("Mitteilung bei neuen oder geänderten Einträgen", isOn: $notify).disabled(!enabled)
            Toggle("Bei der Anmeldung starten", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.set($0) }))
            Text("Beim Start bei der Anmeldung öffnet LaunchKeeper sein Fenster; schließt du es, beobachtet die App weiter — das Auge in der Menüleiste zeigt es.")
                .font(.callout).foregroundStyle(.secondary)
            if loginItem.status == .requiresApproval {
                Button("In den Systemeinstellungen erlauben") { SMAppService.openSystemSettingsLoginItems() }
            }
            if let error = loginItem.lastError { Text(error).foregroundStyle(.red).font(.callout) }
        }
    }
}

// MARK: - Switching the watch

/// Applies the "Beobachtung" setting wherever it is changed (pane, Settings,
/// menu bar) — also while no window is open, which an `onChange` in a
/// window could not.
@MainActor
final class WatchController {
    private let watch: WatchModel
    private var observer: NSObjectProtocol?

    /// Creates the controller and applies the stored setting (starts the watch at launch).
    /// - Parameter watch: The watch to start and stop.
    init(watch: WatchModel) {
        self.watch = watch
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil,
                                                          queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.apply() }
        }
        apply()
    }

    /// Starts or stops the watch to match the setting.
    func apply() {
        let enabled = UserDefaults.standard.bool(forKey: WatchSettings.enabled)
        if enabled && !watch.isRunning {
            WatchNotifier.requestPermission()
            watch.start()
        } else if !enabled && watch.isRunning {
            watch.stop()
        }
    }
}

/// Hands the window's `openWindow` action to the router, so notifications
/// and the menu bar can open a window when none is open.
struct RegisterWindowOpener: ViewModifier {
    let router: EntryRouter
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            let open = openWindow
            router.openMainWindow = { open(id: LaunchKeeperApp.mainWindowID) }
        }
    }
}
