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

    /// Brings LaunchKeeper to the front with a main window, changing nothing
    /// else: an existing one (also a minimized one) comes forward, in front
    /// of Help and Settings; only without any is a new one opened.
    func bringToFront() {
        NSApp.activate()
        let main = NSApp.windows.first {
            $0.identifier?.rawValue.hasPrefix(LaunchKeeperApp.mainWindowID) == true && ($0.isVisible || $0.isMiniaturized)
        }
        if let main {
            if main.isMiniaturized { main.deminiaturize(nil) }
            main.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow?()
        }
    }

    /// Shows the app with the entry selected (or the watch view when it is gone).
    /// - Parameter key: The entry's stable key, if any.
    func show(key: String?) {
        bringToFront()
        if let key, store.reveal(key: key) { return }
        store.selection = .watch
    }
}

// MARK: - Notifications

/// Delivers watch records as macOS notifications and routes clicks to the entry.
///
/// Notifications need a bundled, signed app; run via `swift run` (no bundle
/// identifier) they are skipped instead of crashing the notification center.
///
/// Every delivery keeps its outcome (TJ 2026-09-28: a notification went
/// missing on a second Mac and nothing said why): not sent and why, refused
/// by macOS with its error, or handed over — and whether macOS then lists it
/// as delivered. The watch record's detail and Settings show it.
@MainActor
@Observable
final class WatchNotifier: NSObject, WatchNotifying, UNUserNotificationCenterDelegate {
    @ObservationIgnored private let router: EntryRouter
    /// Mirrors the "Mitteilungen" setting at delivery time.
    @ObservationIgnored private let isEnabled: () -> Bool

    /// macOS's answer to "may LaunchKeeper notify?"; `nil` until read.
    private(set) var authorization: UNAuthorizationStatus?
    /// Whether macOS shows LaunchKeeper's notifications as banners/alerts.
    private(set) var alertsEnabled: Bool?
    /// What happened to the notification of each record (this session only,
    /// the latest `outcomeLimit` — the watch keeps as many records).
    private(set) var outcomes: [WatchRecord.ID: String] = [:]
    @ObservationIgnored private var outcomeOrder: [WatchRecord.ID] = []
    private let outcomeLimit = 200
    /// What happened to the last test notification.
    private(set) var testResult: String?

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

    /// Asks for permission again (shows the prompt only while undecided) and re-reads the state.
    func requestAgain() {
        guard Self.available else { return }
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            refreshAuthorization()
        }
    }

    /// Re-reads macOS's notification settings for LaunchKeeper.
    func refreshAuthorization() {
        guard Self.available else { return }
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            authorization = settings.authorizationStatus
            alertsEnabled = settings.alertSetting == .enabled
        }
    }

    /// Opens LaunchKeeper's page in System Settings › Notifications.
    func openSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// The permission state in words.
    var authorizationText: String {
        guard Self.available else { return String(localized: "nicht verfügbar (kein App-Bundle)") }
        switch authorization {
        case .authorized?, .provisional?:
            return alertsEnabled == false
                ? String(localized: "erlaubt, aber ohne Banner (Stil „Ohne“)")
                : String(localized: "erlaubt")
        case .denied?: return String(localized: "nicht erlaubt")
        case .notDetermined?: return String(localized: "noch nicht gefragt")
        case nil: return "…"
        @unknown default: return String(localized: "unbekannt")
        }
    }

    func deliver(_ record: WatchRecord) {
        guard Self.available else { note(record.id.uuidString, authorizationText); return }
        guard isEnabled() else {
            note(record.id.uuidString, String(localized: "nicht gesendet: Mitteilungen sind in LaunchKeeper ausgeschaltet"))
            return
        }
        note(record.id.uuidString, String(localized: "wird gesendet …"))
        let content = UNMutableNotificationContent()
        content.title = record.headline
        content.body = record.detail
        content.sound = .default
        if let key = record.event.key { content.userInfo = ["key": key] }
        post(content, identifier: record.id.uuidString)
    }

    /// Sends a notification that only shows how the watch's notifications look.
    func sendTest() {
        guard Self.available else { testResult = authorizationText; return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "LaunchKeeper-Test")
        content.body = String(localized: "So meldet die Beobachtung neue Autostart-Einträge.")
        content.sound = .default
        let identifier = Self.testPrefix + UUID().uuidString
        note(identifier, String(localized: "wird gesendet …"))
        post(content, identifier: identifier)
    }

    /// Request identifiers of test notifications start with this.
    private static let testPrefix = "test-"

    /// Stores what became of a notification: a record's outcome (by its
    /// UUID) or the test result.
    /// - Parameters:
    ///   - identifier: The request identifier.
    ///   - text: The outcome in words.
    private func note(_ identifier: String, _ text: String) {
        if identifier.hasPrefix(Self.testPrefix) { testResult = text; return }
        guard let id = UUID(uuidString: identifier) else { return }
        if outcomes.updateValue(text, forKey: id) == nil {
            outcomeOrder.append(id)
            if outcomeOrder.count > outcomeLimit { outcomes[outcomeOrder.removeFirst()] = nil }
        }
    }

    /// Hands a notification to macOS and records what can be known about it.
    ///
    /// Checks the permission first (a refused request raises no error of its
    /// own), awaits the hand-over, then looks a moment later whether the
    /// notification is listed in the Notification Center. That list says
    /// nothing about a banner (Focus files notifications there silently), so
    /// the wording claims only what was measured; the only proof that the
    /// user saw it is a click or its presentation while LaunchKeeper is in
    /// front — the delegate records both (review 2026-09-28).
    /// - Parameters:
    ///   - content: The notification.
    ///   - identifier: Its request identifier (a record's UUID or a test id).
    private func post(_ content: UNMutableNotificationContent, identifier: String) {
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            authorization = settings.authorizationStatus
            alertsEnabled = settings.alertSetting == .enabled
            guard [.authorized, .provisional].contains(settings.authorizationStatus) else {
                note(identifier, String(localized: "nicht gesendet: macOS erlaubt LaunchKeeper keine Mitteilungen (\(authorizationText))"))
                return
            }
            do {
                try await center.add(request)
            } catch {
                note(identifier, String(localized: "von macOS abgelehnt: \(error.localizedDescription)"))
                return
            }
            let time = Date().formatted(date: .omitted, time: .standard)
            var text: String
            if settings.notificationCenterSetting == .enabled {
                try? await Task.sleep(for: .seconds(1))
                // Clicked or shown in front meanwhile: that note is the better one.
                if let current = currentNote(identifier), current != String(localized: "wird gesendet …") { return }
                let listed = await center.deliveredNotifications().contains { $0.request.identifier == identifier }
                text = listed
                    ? String(localized: "an macOS übergeben um \(time); steht in der Mitteilungszentrale.")
                    : String(localized: "an macOS übergeben um \(time); nicht in der Mitteilungszentrale — schon weggeklickt oder von macOS zurückgehalten.")
            } else {
                text = String(localized: "an macOS übergeben um \(time) (Mitteilungszentrale für LaunchKeeper aus — ob sie erschien, lässt sich nicht prüfen).")
            }
            // What decides about a banner: the style first, then a Focus.
            text += " " + (settings.alertSetting == .enabled
                ? String(localized: "Ein Banner zeigt macOS nur ohne aktiven Fokus.")
                : String(localized: "Banner sind für LaunchKeeper ausgeschaltet (Stil „Ohne“)."))
            note(identifier, text)
        }
    }

    /// The outcome stored so far for an identifier.
    private func currentNote(_ identifier: String) -> String? {
        if identifier.hasPrefix(Self.testPrefix) { return testResult }
        return UUID(uuidString: identifier).flatMap { outcomes[$0] }
    }

    // Also show notifications while LaunchKeeper is in front — and note that
    // macOS asked (it reached presentation; a Focus may still hide the banner).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let identifier = notification.request.identifier
        let time = Date().formatted(date: .omitted, time: .standard)
        await MainActor.run {
            note(identifier, String(localized: "um \(time) zur Anzeige freigegeben (LaunchKeeper war vorne; ein aktiver Fokus kann das Banner trotzdem unterdrücken)"))
        }
        return [.banner, .sound, .list]
    }

    // A click opens the entry in the main window; the click is the proof the user saw it.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let identifier = response.notification.request.identifier
        let key = response.notification.request.content.userInfo["key"] as? String
        let time = Date().formatted(date: .omitted, time: .standard)
        await MainActor.run {
            note(identifier, String(localized: "angezeigt und um \(time) angeklickt"))
        }
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
    @Environment(WatchNotifier.self) private var notifier

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
                LabeledContent("Mitteilung") { Text(notificationText).textSelection(.enabled) }
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

    /// Whether a notification went out for this record, and if not, why.
    private var notificationText: String {
        if record.isOwn { return String(localized: "keine — LaunchKeeper hat das selbst geändert") }
        if !record.deservesNotification { return String(localized: "keine — Entfernungen werden nur aufgelistet") }
        return notifier.outcomes[record.id]
            ?? String(localized: "unbekannt (vor dem letzten Start der App bemerkt)")
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
    @Environment(WatchNotifier.self) private var notifier
    @AppStorage(WatchSettings.enabled) private var enabled = false
    @AppStorage(WatchSettings.notify) private var notify = true

    var body: some View {
        Section("Beobachtung") {
            Toggle("Neue Autostart-Einträge beobachten", isOn: $enabled)
            Toggle("Mitteilung bei neuen oder geänderten Einträgen", isOn: $notify).disabled(!enabled)
            LabeledContent("Mitteilungen laut macOS", value: notifier.authorizationText)
            HStack {
                Button("Test-Mitteilung senden") { notifier.sendTest() }
                    .help("Test-Mitteilung senden — zeigt, ob und wie macOS Mitteilungen von LaunchKeeper anzeigt, ohne dass sich etwas ändern muss.")
                if notifier.authorization == .notDetermined {
                    Button("Erlaubnis anfragen") { notifier.requestAgain() }
                        .help("Erlaubnis anfragen — macOS fragt, ob LaunchKeeper Mitteilungen senden darf.")
                }
                Button("Mitteilungseinstellungen öffnen") { notifier.openSettings() }
                    .help("Mitteilungseinstellungen öffnen — Systemeinstellungen › Mitteilungen › LaunchKeeper: Erlaubnis, Stil, Ton.")
            }
            if let result = notifier.testResult {
                Text(result).font(.callout).foregroundStyle(.secondary)
            }
            // Phase 9 (MacMini01, 2026-09-28): everything was handed over and
            // released, yet no banner — the Mac was used via screen sharing.
            Text("Kein Banner, obwohl die Mitteilung freigegeben wurde? Beim Teilen oder Spiegeln des Bildschirms (z. B. Bildschirmfreigabe) unterdrückt macOS Banner standardmäßig — Systemeinstellungen › Mitteilungen › „Beim Spiegeln oder Teilen des Bildschirms“.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Bei der Anmeldung starten", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.set($0) }))
            Text("Beim Start bei der Anmeldung öffnet LaunchKeeper sein Fenster; schließt du es, beobachtet die App weiter — das Auge in der Menüleiste zeigt es.")
                .font(.callout).foregroundStyle(.secondary)
            if loginItem.status == .requiresApproval {
                Button("In den Systemeinstellungen erlauben") { SMAppService.openSystemSettingsLoginItems() }
            }
            if let error = loginItem.lastError { Text(error).foregroundStyle(.red).font(.callout) }
        }
        // The user may have changed it in System Settings meanwhile — also
        // while this window stayed open ("Mitteilungseinstellungen öffnen").
        .onAppear { notifier.refreshAuthorization() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            notifier.refreshAuthorization()
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
