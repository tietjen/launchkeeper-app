//
//  ContentView.swift
//  LaunchKeeper — the main window: sidebar, inventory table / dedicated
//  views, detail column, toolbar and scan status.
//

import SwiftUI
import AppCore
import LaunchKeeperKit

/// The main window: a three-column `NavigationSplitView`.
///
/// The sidebar picks either a slice of the inventory (all, orphans, one
/// category) — shown as a table with a detail column — or one of the
/// dedicated views (background, packages, app leftovers, quarantine, watch).
/// All data comes from the `InventoryStore` in the environment.
struct ContentView: View {
    @Environment(InventoryStore.self) private var store
    /// Selected package (receipt id) in the packages view.
    @State private var selectedPackage: String?
    /// Selected bundle id in the app-leftovers view.
    @State private var selectedLeftover: String?
    /// Selected row in the background view (`BackgroundEntry.id` — unique, unlike the BTM identifier).
    @State private var selectedBackground: String?
    /// Selected record in the watch view.
    @State private var selectedRecord: WatchRecord.ID?
    @Environment(WatchModel.self) private var watch
    @Environment(LeftoversModel.self) private var leftovers
    /// Basic vs. expert detail view (shared with the menu command and `DetailView`).
    @AppStorage("expertMode") private var expertMode = false
    /// The table's sort order; name ascending until the user clicks a header.
    @State private var sortOrder = [KeyPathComparator(\InventoryRow.name)]
    /// Selected row in the queue.
    @State private var selectedQueueItem: QueueItem.ID?
    /// Ticks for batch processing, per view.
    @Environment(Marks.self) private var marks
    @Environment(QueueModel.self) private var queue
    /// The introduction and the help window (TJ 2026-09-30).
    @Environment(TourModel.self) private var tour
    @Environment(HelpRouter.self) private var helpRouter
    @Environment(\.openWindow) private var openWindow
    /// This window's token: after the window was closed and opened again,
    /// the introduction knows the new one.
    @State private var windowToken = UUID()
    /// Which columns show; the introduction opens all of them (a collapsed
    /// sidebar would leave its steps without a place — review 2026-09-30, S2).
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        @Bindable var store = store
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(tour: tour, window: windowToken, openHelp: openHelp)
                .tourSpot(.sidebar, tour: tour, window: windowToken, openHelp: openHelp)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } content: {
            Group {
                switch store.selection {
                case .background: BackgroundPane(selection: $selectedBackground)
                case .receipts: ReceiptsPane(selection: $selectedPackage)
                case .leftovers: LeftoversPane(selection: $selectedLeftover)
                case .quarantine: QuarantinePane()
                case .watch: WatchPane(selection: $selectedRecord)
                case .queue: QueuePane(selection: $selectedQueueItem)
                case .all, .orphans, .category:
                    InventoryTable(selectedKey: $store.selectedKey, sortOrder: $sortOrder)
                        .searchable(text: $store.search, placement: .toolbar, prompt: "Name, Label, Pfad, Team …")
                }
            }
            .tourSpot(.content, tour: tour, window: windowToken, openHelp: openHelp)
            .navigationSplitViewColumnWidth(min: 480, ideal: 640)
        } detail: {
            detailColumn
                .tourSpot(.detail, tour: tour, window: windowToken, arrowEdge: .leading, openHelp: openHelp)
        }
        .toolbar {
            ToolbarItemGroup {
                // The icons show the current state (Basic/Expert, Apple hidden/shown);
                // the help text says what a click does.
                Toggle(isOn: $expertMode) {
                    Label { Text("Expertenmodus") } icon: { ToolbarIcon.mode(expert: expertMode).image }
                }
                .help(expertMode ? "Expertenmodus — klicken für die Kurzfassung (⌥⌘E)"
                                 : "Basismodus — klicken für alle Details (⌥⌘E)")
                .tourSpot(.modeToggle, tour: tour, window: windowToken, arrowEdge: .bottom, openHelp: openHelp)
                Toggle(isOn: $store.hideApple) {
                    Label { Text("Apple ausblenden") } icon: { ToolbarIcon.apple(hidden: store.hideApple).image }
                }
                .help(store.hideApple ? "Apple-signierte Einträge sind ausgeblendet — klicken zum Anzeigen"
                                      : "Apple-signierte Einträge werden angezeigt — klicken zum Ausblenden")
                .tourSpot(.appleToggle, tour: tour, window: windowToken, arrowEdge: .bottom, openHelp: openHelp)
                Button { Task { await store.refresh(reuseBTM: true) } } label: {
                    Label("Neu einlesen", systemImage: "arrow.clockwise")
                }
                .disabled(store.isScanning)
                .help("Neu einlesen (⌘R) — ⇧⌘R fragt auch die Hintergrundaufgaben neu ab")
                .tourSpot(.refresh, tour: tour, window: windowToken, arrowEdge: .bottom, openHelp: openHelp)
            }
        }
        .overlay(alignment: .bottom) { StatusBar() }
        .modifier(TourSheetModifier(tour: tour, window: windowToken, openHelp: openHelp))
        .environment(\.tourWindow, windowToken)
        .task {
            // The window prepares itself for each step; then the introduction
            // starts once per session if it is wanted at launch.
            tour.register(window: windowToken) { [store] step in
                columnVisibility = .all
                step.prepare(store)
            }
            tour.startAtLaunchIfWanted()
        }
        .onDisappear { tour.unregister(window: windowToken) }
    }

    /// Opens the help window at the overview.
    private func openHelp() {
        helpRouter.topic = .overview
        openWindow(id: HelpView.windowID)
    }

    /// The right column: the detail for whatever is selected in the current view.
    @ViewBuilder private var detailColumn: some View {
        // Ticked items turn the detail column into the batch panel.
        if marks.count(for: store.selection) > 0 {
            BatchPanel(selection: store.selection)
        } else {
            singleDetail
        }
    }

    /// The detail of the one selected row.
    @ViewBuilder private var singleDetail: some View {
        switch store.selection {
        case .all, .orphans, .category:
            if let row = store.row(for: store.selectedKey) { DetailView(row: row) } else { nothingSelected }
        case .receipts:
            if let row = store.receipts?.rows.first(where: { $0.id == selectedPackage }) {
                PackageDetail(row: row)
            } else { nothingSelected }
        case .leftovers:
            if let candidate = leftovers.candidates.first(where: { $0.bundleIdentifier == selectedLeftover }) {
                LeftoverDetail(candidate: candidate)
            } else { nothingSelected }
        case .background:
            if let view = store.background,
               let entry = BackgroundEntry.entries(from: view, items: store.itemsByDisplayID).first(where: { $0.id == selectedBackground }) {
                BackgroundDetail(entry: entry)
            } else { nothingSelected }
        case .quarantine:
            nothingSelected
        case .watch:
            if let record = watch.records.first(where: { $0.id == selectedRecord }) {
                WatchRecordDetail(record: record)
            } else { nothingSelected }
        case .queue:
            if let item = queue.items.first(where: { $0.id == selectedQueueItem }) {
                QueueItemDetail(item: item)
            } else { nothingSelected }
        }
    }

    /// Placeholder while nothing is selected.
    private var nothingSelected: some View {
        ContentUnavailableView("Nichts gewählt", systemImage: "sidebar.right",
                               description: Text("Wähle links eine Zeile — rechts steht dann, was sie bedeutet und was du tun kannst."))
    }
}

/// The sidebar: inventory slices with entry counts, the categories that
/// have entries, and the dedicated views.
struct SidebarView: View {
    @Environment(InventoryStore.self) private var store
    @Environment(WatchModel.self) private var watch
    @Environment(QueueModel.self) private var queue
    /// Passed in, not read from the environment inside list rows (see `MarkBox`).
    let tour: TourModel
    let window: UUID
    let openHelp: () -> Void

    var body: some View {
        @Bindable var store = store
        ScrollViewReader { proxy in
        List(selection: $store.selection) {
            Section("Inventar") {
                row(.all, "Alle Einträge", "list.bullet")
                row(.orphans, "Verwaist", "exclamationmark.triangle")
            }
            Section("Kategorien") {
                ForEach(store.categories, id: \.self) { category in
                    row(.category(category), LocalizedStringKey(category.title), Self.symbol(category))
                }
            }
            Section("Ansichten") {
                Label("Hintergrund", systemImage: "switch.2")
                    .tourSpot(.backgroundRow, tour: tour, window: window, openHelp: openHelp)
                    .tag(SidebarSelection.background).id(SidebarSelection.background)
                Label("Pakete", systemImage: "shippingbox")
                    .tourSpot(.packagesRow, tour: tour, window: window, openHelp: openHelp)
                    .tag(SidebarSelection.receipts).id(SidebarSelection.receipts)
                Label("App-Reste", systemImage: "leaf")
                    .tourSpot(.leftoversRow, tour: tour, window: window, openHelp: openHelp)
                    .tag(SidebarSelection.leftovers).id(SidebarSelection.leftovers)
                Label("Quarantäne", systemImage: "archivebox")
                    .tourSpot(.quarantineRow, tour: tour, window: window, openHelp: openHelp)
                    .tag(SidebarSelection.quarantine).id(SidebarSelection.quarantine)
                Label("Beobachtung", systemImage: watch.isRunning ? "eye" : "eye.slash")
                    .badge(watch.records.filter { !$0.isOwn && $0.event.kind != .removed }.count)
                    .tourSpot(.watchRow, tour: tour, window: window, openHelp: openHelp)
                    .tag(SidebarSelection.watch).id(SidebarSelection.watch)
            }
            // At the bottom (TJ): the queue collects actions from every view above.
            Section("Stapelverarbeitung") {
                Label("Warteschlange", systemImage: "tray.full")
                    .badge(queue.items.filter { !$0.isFinished }.count)
                    .tourSpot(.queueRow, tour: tour, window: window, openHelp: openHelp)
                    .tag(SidebarSelection.queue).id(SidebarSelection.queue)
            }
        }
        .listStyle(.sidebar)
        // The introduction scrolls the row it talks about into view (before
        // its card appears — a card needs its row on screen).
        .onChange(of: tour.step) { _, step in
            guard let row = step?.sidebarRow else { return }
            withAnimation { proxy.scrollTo(row, anchor: .center) }
        }
        }
    }

    /// One sidebar row with its entry count as badge.
    /// - Parameters:
    ///   - selection: What the row selects.
    ///   - title: The visible title — a localization key (category names
    ///     come from the kit in English and are simply not found in the table).
    ///   - symbol: SF Symbol name.
    private func row(_ selection: SidebarSelection, _ title: LocalizedStringKey, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .badge(store.count(selection))
            .tag(selection)
    }

    /// SF Symbol for a category.
    /// - Parameter category: The Autoruns-style category.
    /// - Returns: A symbol name that exists on macOS 14.
    static func symbol(_ category: ItemCategory) -> String {
        switch category {
        case .launchItems: return "gearshape.2"
        case .loginItems: return "person.crop.circle.badge.checkmark"
        case .appExtensions: return "puzzlepiece.extension"
        case .systemExtensions: return "cpu"
        case .privilegedHelpers: return "lock.shield"
        case .scheduled: return "clock"
        case .legacy: return "archivebox"
        case .shellStartup: return "terminal"
        case .pluginDirectories: return "shippingbox"
        case .network: return "network"
        case .profiles: return "doc.badge.gearshape"
        case .privacy: return "hand.raised"
        }
    }
}

/// The inventory table for the current sidebar slice, sortable by every column.
///
/// Selection is bound to the stable entry key, so a rescan keeps the
/// selected entry selected as long as it still exists.
struct InventoryTable: View {
    @Environment(InventoryStore.self) private var store
    @Environment(Marks.self) private var marks
    @Environment(QueueModel.self) private var queue
    @Binding var selectedKey: String?
    @Binding var sortOrder: [KeyPathComparator<InventoryRow>]

    var body: some View {
        Table(store.visibleRows.sorted(using: sortOrder), selection: $selectedKey, sortOrder: $sortOrder) {
            TableColumn("") { row in MarkBox(id: row.id, set: \.entries, marks: marks, queue: queue, targets: [.entry(key: row.id)]) }
                .width(22)
            TableColumn("") { row in BadgeStrip(badges: row.badges) }
                .width(min: 40, ideal: 56, max: 90)
            TableColumn("Name", value: \.name) { row in
                Text(row.name).help(row.item.key)
            }
            .width(min: 160, ideal: 240)
            TableColumn("Kategorie", value: \.category).width(min: 90, ideal: 130)
            TableColumn("Herkunft", value: \.origin).width(min: 60, ideal: 80)
            TableColumn("Signatur", value: \.signature).width(min: 70, ideal: 110)
            TableColumn("Pfad", value: \.path) { row in
                Text(row.path).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
            }
        }
        .overlay {
            if store.rows.isEmpty && !store.isScanning {
                ContentUnavailableView("Noch kein Inventar", systemImage: "tray",
                                       description: Text("⌘R liest ein, was auf diesem Mac automatisch startet."))
            }
        }
    }
}

/// Up to three status symbols for a row, most important first
/// (the order `InventoryRow.badges` defines).
struct BadgeStrip: View {
    let badges: [InventoryRow.Badge]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(badges.prefix(3), id: \.self) { badge in
                Image(systemName: Self.symbol(badge))
                    .foregroundStyle(Self.color(badge))
                    .help(Self.title(badge))
            }
        }
    }

    /// SF Symbol for a badge.
    static func symbol(_ badge: InventoryRow.Badge) -> String {
        switch badge {
        case .orphan: return "exclamationmark.triangle.fill"
        case .leftover: return "leaf.fill"
        case .unsigned: return "signature"
        case .review: return "eye.fill"
        case .disabled: return "pause.circle.fill"
        case .running: return "play.circle.fill"
        }
    }

    /// Colour code for a badge: orange = orphan, red = unsigned, yellow = review hint.
    static func color(_ badge: InventoryRow.Badge) -> Color {
        switch badge {
        case .orphan: return .orange
        case .leftover: return .secondary
        case .unsigned: return .red
        case .review: return .yellow
        case .disabled: return .gray
        case .running: return .green
        }
    }

    /// Tooltip text explaining a badge in plain words.
    static func title(_ badge: InventoryRow.Badge) -> String {
        switch badge {
        case .orphan: return String(localized: "Verwaist — die Quelle fehlt")
        case .leftover: return String(localized: "Rest — nur noch ein Eintrag der Hintergrundaufgaben")
        case .unsigned: return String(localized: "Nicht signiert")
        case .review: return String(localized: "Ansehen empfohlen")
        case .disabled: return String(localized: "Deaktiviert")
        case .running: return String(localized: "Läuft")
        }
    }
}

/// A floating capsule at the bottom of the window: progress while a scan
/// runs, a warning while the inventory is incomplete. Invisible otherwise.
struct StatusBar: View {
    @Environment(InventoryStore.self) private var store

    var body: some View {
        if store.isScanning || !store.incompleteLayers.isEmpty {
            HStack(spacing: 8) {
                if store.isScanning {
                    ProgressView().controlSize(.small)
                    Text(store.status)
                } else {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    Text("Inventar unvollständig: \(store.incompleteLayers.joined(separator: ", ")) — ⇧⌘R versucht es erneut")
                }
            }
            .font(.callout)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 10)
        }
    }
}
