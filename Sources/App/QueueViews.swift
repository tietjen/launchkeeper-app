//
//  QueueViews.swift
//  LaunchKeeper — batch processing in the UI (Phase 10): marks in every
//  view, the batch panel in the detail column, and the work queue.
//

import SwiftUI
import AppCore
import LaunchKeeperKit
import HelperShared

// MARK: - Marks

/// What is ticked in each view. Separate sets, so ticks survive switching
/// views (TJ: collect in one view, continue in another).
@MainActor
@Observable
final class Marks {
    /// Inventory entries (all inventory slices share it — keys are unique).
    var entries: Set<String> = []
    /// Background rows, by `BackgroundEntry.id`.
    var background: Set<String> = []
    /// Installer packages, by receipt id.
    var packages: Set<String> = []
    /// Gone apps, by bundle id.
    var leftovers: Set<String> = []
    /// Quarantine entries, by name.
    var quarantine: Set<String> = []

    /// Ticked items of the view a sidebar selection shows.
    func count(for selection: SidebarSelection) -> Int {
        switch selection {
        case .all, .orphans, .category: return entries.count
        case .background: return background.count
        case .receipts: return packages.count
        case .leftovers: return leftovers.count
        case .quarantine: return quarantine.count
        case .watch, .queue: return 0
        }
    }

    /// Clears the ticks of the view a sidebar selection shows.
    func clear(for selection: SidebarSelection) {
        switch selection {
        case .all, .orphans, .category: entries.removeAll()
        case .background: background.removeAll()
        case .receipts: packages.removeAll()
        case .leftovers: leftovers.removeAll()
        case .quarantine: quarantine.removeAll()
        case .watch, .queue: break
        }
    }
}

/// A checkbox bound to membership in a set of marks.
///
/// Gets `Marks` passed in instead of reading the environment: it lives in
/// table and list cells, which AppKit hosts one by one — a cell laid out
/// without the environment crashed the app (live 2026-09-27, 0.2.0 build 34).
struct MarkBox: View {
    let id: String
    let set: ReferenceWritableKeyPath<Marks, Set<String>>
    let marks: Marks

    var body: some View {
        Toggle("", isOn: Binding(
            get: { marks[keyPath: set].contains(id) },
            set: { on in if on { marks[keyPath: set].insert(id) } else { marks[keyPath: set].remove(id) } }))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .help("Für die Stapelverarbeitung markieren")
    }
}

// MARK: - Options per target

/// Which actions a queue target can take — from the same next steps the
/// detail view offers (one gate, one matrix).
@MainActor
enum QueueOptions {
    /// The actions for a target, in the order the detail view lists them.
    static func actions(for target: QueueTarget, store: InventoryStore) -> [ActionRequest] {
        switch target {
        case .entry(let key):
            guard let row = store.row(for: key) else { return [] }
            return EntrySummary.build(for: row.item).nextSteps.compactMap(\.action)
        default:
            return target.defaultActions
        }
    }

    /// Queue items for ticked inventory entries, grouped by action: every
    /// entry that offers the action is in its group.
    static func entryGroups(keys: Set<String>, store: InventoryStore, origin: String)
        -> (groups: [(title: String, items: [QueueItem])], none: [String]) {
        var groups: [String: (title: String, items: [QueueItem])] = [:]
        var order: [String] = []
        var none: [String] = []
        for key in keys.sorted() {
            guard let row = store.row(for: key) else { continue }
            let actions = actions(for: .entry(key: key), store: store)
            if actions.isEmpty { none.append(row.name) }
            for action in actions {
                guard case .remediation(let operation, _) = action else { continue }
                if groups[operation] == nil { groups[operation] = (action.title, []); order.append(operation) }
                groups[operation]?.items.append(QueueItem(target: .entry(key: key), title: row.name, origin: origin, action: action))
            }
        }
        return (order.compactMap { groups[$0] }, none)
    }
}

// MARK: - Batch panel (detail column while items are ticked)

/// The detail column while items are ticked: how many, which actions are
/// possible for how many of them, and "add to the queue".
struct BatchPanel: View {
    let selection: SidebarSelection
    @Environment(Marks.self) private var marks
    @Environment(InventoryStore.self) private var store
    @Environment(QueueModel.self) private var queue
    @Environment(LeftoversModel.self) private var leftovers
    @State private var added: Int?

    var body: some View {
        Form {
            Section {
                Text("\(marks.count(for: selection)) markiert").font(.title3).bold()
                Text("Wähle, was mit ihnen geschehen soll. Die Aktionen landen zuerst in der Warteschlange — ausgeführt wird erst dort, nach einem gemeinsamen Plan.")
                    .foregroundStyle(.secondary)
            }
            Section("Zur Warteschlange hinzufügen") {
                switch selection {
                case .all, .orphans, .category, .background:
                    entryButtons(keys: entryKeys, origin: originName)
                case .receipts:
                    addButton(title: String(localized: "Paket deinstallieren"),
                              items: marks.packages.sorted().map {
                                  QueueItem(target: .package(id: $0), title: $0, origin: originName, action: .uninstall(package: $0))
                              }, of: marks.packages.count)
                case .leftovers:
                    addButton(title: String(localized: "Reste in die Quarantäne verschieben"),
                              items: marks.leftovers.sorted().map {
                                  QueueItem(target: .leftovers(bundleID: $0), title: $0, origin: originName, action: .leftovers(bundleID: $0))
                              }, of: marks.leftovers.count)
                case .quarantine:
                    addButton(title: String(localized: "Aus der Quarantäne wiederherstellen"),
                              items: marks.quarantine.sorted().map {
                                  QueueItem(target: .quarantine(name: $0), title: $0, origin: originName, action: .restore(quarantine: $0))
                              }, of: marks.quarantine.count)
                case .watch, .queue:
                    EmptyView()
                }
            }
            if let added {
                Section {
                    Label("\(added) zur Warteschlange hinzugefügt", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    Button("Warteschlange öffnen") { store.selection = .queue }
                }
            }
            Section {
                Button("Markierung aufheben") { marks.clear(for: selection) }
            }
        }
        .formStyle(.grouped)
        .onChange(of: marks.count(for: selection)) { _, _ in added = nil }
    }

    /// Inventory keys behind the ticks (background rows stand for their components).
    private var entryKeys: Set<String> {
        guard selection == .background else { return marks.entries }
        guard let view = store.background else { return [] }
        let byID = store.itemsByDisplayID
        let entries = BackgroundEntry.entries(from: view, items: byID).filter { marks.background.contains($0.id) }
        return Set(entries.flatMap { $0.row.components.compactMap { byID[$0.id]?.key } })
    }

    /// The name of the current view, stored with each queue item.
    private var originName: String {
        switch selection {
        case .all: return String(localized: "Alle Einträge")
        case .orphans: return String(localized: "Verwaist")
        case .category(let category): return category.title
        case .background: return String(localized: "Hintergrund")
        case .receipts: return String(localized: "Pakete")
        case .leftovers: return String(localized: "App-Reste")
        case .quarantine: return String(localized: "Quarantäne")
        case .watch: return String(localized: "Beobachtung")
        case .queue: return String(localized: "Warteschlange")
        }
    }

    /// One button per action the ticked entries offer, with "n of m".
    @ViewBuilder private func entryButtons(keys: Set<String>, origin: String) -> some View {
        let (groups, none) = QueueOptions.entryGroups(keys: keys, store: store, origin: origin)
        if groups.isEmpty {
            Text("Für keinen der markierten Einträge gibt es eine automatische Aktion.").foregroundStyle(.secondary)
        }
        ForEach(groups, id: \.title) { group in
            addButton(title: group.title, items: group.items, of: keys.count)
        }
        if !none.isEmpty {
            DisclosureGroup("\(none.count) ohne automatische Aktion") {
                ForEach(none, id: \.self) { Text($0).font(.callout) }
                Text("Deren Schalter verwaltet macOS selbst — die Detailansicht zeigt, wo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// "Title — n of m" that adds the items and clears the ticks it used.
    private func addButton(title: String, items: [QueueItem], of total: Int) -> some View {
        Button {
            added = queue.add(items)
            marks.clear(for: selection)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text("\(items.count) von \(total)").foregroundStyle(.secondary)
            }
        }
        .disabled(items.isEmpty || queue.phase != .idle)
    }
}

// MARK: - The queue

/// The work queue: every queued action with its switchable choice, the
/// shared plan, the run with progress, and the way back.
struct QueuePane: View {
    @Environment(QueueModel.self) private var queue
    @Environment(InventoryStore.self) private var store
    @Environment(HelperStatus.self) private var helper
    @Environment(WatchModel.self) private var watch
    @Environment(QuarantineModel.self) private var quarantine
    @Environment(LeftoversModel.self) private var leftovers
    @Binding var selection: QueueItem.ID?
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            PaneIntro(text: "Gesammelte Aktionen aus allen Ansichten. „Plan prüfen“ rechnet alle auf einmal durch; „Alle ausführen“ fragt für alle Schritte mit Administratorrechten nur einmal nach Touch ID. Ein Fehler hält die übrigen nicht an. Reihenfolge: zuerst alle Schritte mit Administratorrechten, dann die übrigen; Entfernen und Deaktivieren vor Wiederherstellen und Deinstallieren.")
                .padding(12)
            if queue.items.isEmpty {
                ContentUnavailableView("Warteschlange ist leer", systemImage: "tray",
                                       description: Text("Markiere in einer Ansicht Einträge und füge sie rechts hinzu."))
            } else {
                let conflicts = queue.conflicts { store.row(for: $0)?.item.provenance?.packageIdentifier }
                List(selection: $selection) {
                    ForEach(queue.items) { item in
                        QueueRow(item: item, conflict: conflicts[item.id], queue: queue, store: store).tag(item.id)
                    }
                }
            }
            Divider()
            footer.padding(12)
        }
        .onAppear { updatePrivileged() }
        .onChange(of: helper.isReady) { _, _ in updatePrivileged() }
        .onChange(of: helper.version) { _, _ in updatePrivileged() }
        .confirmationDialog("Warteschlange leeren?", isPresented: $confirmClear) {
            Button("Leeren — nichts wird ausgeführt", role: .destructive) { queue.clear() }
        }
    }

    /// Controls and progress under the list.
    @ViewBuilder private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch queue.phase {
            case .planning:
                HStack { ProgressView().controlSize(.small); Text("Plan wird für alle Einträge berechnet …").foregroundStyle(.secondary) }
            case .running(let done, let total):
                ProgressView(value: Double(done), total: Double(max(total, 1))) {
                    Text("\(done) von \(total) erledigt")
                }
            case .idle:
                summary
            }
            HStack {
                Button("Leeren") { confirmClear = true }
                    .disabled(queue.items.isEmpty || queue.phase != .idle)
                Button("Erledigte entfernen") { queue.clearDone() }
                    .disabled(!queue.items.contains { $0.status == .done } || queue.phase != .idle)
                let back = queue.undoItems()
                if !back.isEmpty && queue.phase == .idle {
                    Button("Rückwege hinzufügen (\(back.count))") { queue.add(back) }
                        .help("Legt für jede erledigte Aktion den Rückweg in die Warteschlange: Aktivieren ↔ Deaktivieren, Wiederherstellen aus der Quarantäne.")
                }
                Spacer()
                if case .running = queue.phase {
                    Button("Anhalten") { queue.stop() }
                        .help("Hält nach dem laufenden Eintrag an — halbe Sachen gibt es nicht.")
                } else {
                    Button("Plan prüfen") { Task { await queue.plan() } }
                        .disabled(!queue.items.contains { $0.status != .done } || queue.phase != .idle)
                    Button(needsTouchID ? "Alle ausführen (Touch ID)" : "Alle ausführen") { Task { await run() } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!queue.items.contains { !$0.isFinished } || queue.phase != .idle)
                }
            }
        }
    }

    /// Counts by status, one line.
    private var summary: some View {
        let open = queue.items.filter { !$0.isFinished }.count
        let done = queue.items.filter { $0.status == .done }.count
        let problems = queue.items.filter { if case .failed = $0.status { return true }; if case .refused = $0.status { return true }; return false }.count
        return Text("\(queue.items.count) Einträge · \(open) offen · \(done) erledigt · \(problems) abgelehnt oder fehlgeschlagen")
            .font(.callout).foregroundStyle(.secondary)
    }

    /// Whether the run will ask for Touch ID (a checked plan with admin steps).
    private var needsTouchID: Bool {
        queue.items.contains { $0.status == .planned(needsAdmin: true) }
    }

    /// The helper takes administrator batches only when set up and current.
    private func updatePrivileged() {
        let usable = helper.isReady && !helper.isOutdated
        queue.privileged = usable ? PrivilegedBatchPerformer() : nil
        queue.stopPrivileged = usable ? { HelperClient.stopBatch() } : nil
    }

    /// Runs the queue as LaunchKeeper's own action (the watch labels its
    /// changes, no notifications), then reads the views again once.
    private func run() async {
        helper.refresh()
        updatePrivileged()
        watch.ownActionStarted()
        await queue.execute()
        watch.ownActionFinished()   // also rescans the inventory (one scan for the whole run)
        quarantine.reload()
        await leftovers.reload()
    }
}

/// One queue row: title, origin, the action (switchable), the status.
/// Models are passed in — list cells get no environment reads (see `MarkBox`).
struct QueueRow: View {
    let item: QueueItem
    let conflict: String?
    let queue: QueueModel
    let store: InventoryStore

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            QueueStatusIcon(status: item.status)
            VStack(alignment: .leading, spacing: 2) {
                // The live name when the entry is known — the stored title is
                // only a fallback (the queue file is not trusted, review C3).
                Text(liveTitle).lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.origin)
                    if let reason = statusText { Text("· \(reason)") }
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if let conflict { Text(conflict).font(.caption).foregroundStyle(.orange) }
            }
            Spacer()
            actionPicker.frame(maxWidth: 230)
            Button { queue.remove([item.id]) } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
                .help("Aus der Warteschlange nehmen — nichts wird ausgeführt")
                .disabled(queue.phase != .idle)
        }
        .padding(.vertical, 2)
    }

    /// The chosen action and all others this target allows.
    @ViewBuilder private var actionPicker: some View {
        let options = QueueOptions.actions(for: item.target, store: store)
        let choices = options.contains(item.action) ? options : [item.action] + options
        Picker("", selection: Binding(get: { item.action }, set: { queue.setAction($0, for: item.id) })) {
            ForEach(choices, id: \.self) { Text($0.title).tag($0) }
        }
        .labelsHidden()
        .disabled(queue.phase != .idle || choices.count < 2)
    }

    /// The entry's current name from the inventory, else the queued title.
    private var liveTitle: String {
        if case .entry(let key) = item.target, let row = store.row(for: key) { return row.name }
        return item.title
    }

    /// Status in words, when there is something to say.
    private var statusText: String? {
        switch item.status {
        case .pending: return String(localized: "Plan noch nicht geprüft")
        case .planned(let admin): return admin ? String(localized: "bereit · Touch ID") : String(localized: "bereit")
        case .running: return String(localized: "läuft …")
        case .done: return String(localized: "erledigt und überprüft")
        case .failed(let detail): return String(localized: "fehlgeschlagen: \(detail)")
        case .refused(let reason): return String(localized: "abgelehnt: \(reason)")
        }
    }
}

/// The status as a coloured symbol.
struct QueueStatusIcon: View {
    let status: QueueItem.Status

    var body: some View {
        switch status {
        case .pending: Image(systemName: "circle").foregroundStyle(.secondary)
        case .planned(let admin): Image(systemName: admin ? "lock.circle" : "circle.inset.filled").foregroundStyle(.blue)
        case .running: ProgressView().controlSize(.small)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .refused: Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
        }
    }
}

/// Detail of one queue item: the plan or the result, with the way back.
struct QueueItemDetail: View {
    let item: QueueItem
    @Environment(QueueModel.self) private var queue
    @Environment(InventoryStore.self) private var store

    var body: some View {
        Form {
            Section {
                Text(item.title).font(.title3).bold()
                LabeledContent("Aktion", value: item.action.title)
                LabeledContent("Aus der Ansicht", value: item.origin)
                LabeledContent("Befehl") { Text(item.action.cliCommand(apply: true)).font(.caption.monospaced()).textSelection(.enabled) }
            }
            if let outcome = queue.outcomes[item.id] {
                Section(item.isFinished ? "Ergebnis" : "Plan") {
                    ForEach(outcome.steps) { step in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("\(step.id + 1). \(step.description)")
                                if step.needsAdmin { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary) }
                            }
                            Text(step.command).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    ForEach(Array(outcome.messages.enumerated()), id: \.offset) { _, message in
                        Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    if let undo = outcome.undo {
                        LabeledContent("Rückweg") { Text(undo).textSelection(.enabled) }
                    }
                }
            } else {
                Text("„Plan prüfen“ zeigt, was geschehen würde.").foregroundStyle(.secondary)
            }
            if case .entry(let key) = item.target, store.row(for: key) != nil {
                Section { Button("Im Inventar zeigen") { store.reveal(key: key) } }
            }
        }
        .formStyle(.grouped)
    }
}
