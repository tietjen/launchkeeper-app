import SwiftUI
import AppCore
import LaunchKeeperKit

struct ContentView: View {
    @Environment(InventoryStore.self) private var store
    @State private var selectedKey: String?
    @State private var sortOrder = [KeyPathComparator(\InventoryRow.name)]

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } content: {
            Group {
                switch store.selection {
                case .background: BackgroundPane()
                case .receipts: ReceiptsPane()
                case .leftovers: LeftoversPane()
                case .quarantine: QuarantinePane()
                case .all, .orphans, .category:
                    InventoryTable(selectedKey: $selectedKey, sortOrder: $sortOrder)
                        .searchable(text: $store.search, placement: .toolbar, prompt: "Name, Label, Pfad, Team …")
                }
            }
            .navigationSplitViewColumnWidth(min: 480, ideal: 640)
        } detail: {
            if store.selection.isInventory, let row = store.row(for: selectedKey) {
                DetailView(row: row)
            } else {
                ContentUnavailableView("Kein Eintrag gewählt", systemImage: "sidebar.right",
                                       description: Text("Wähle links einen Eintrag, um Herkunft, Signatur und Steuerung zu sehen."))
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: $store.hideApple) { Label("Apple ausblenden", systemImage: "apple.logo") }
                    .help("Apples eigene Einträge aus- oder einblenden")
                Button { Task { await store.refresh(reuseBTM: true) } } label: {
                    Label("Neu einlesen", systemImage: "arrow.clockwise")
                }
                .disabled(store.isScanning)
                .help("Neu einlesen (⌘R) — ⇧⌘R fragt auch die Hintergrundaufgaben neu ab")
            }
        }
        .overlay(alignment: .bottom) { StatusBar() }
    }
}

struct SidebarView: View {
    @Environment(InventoryStore.self) private var store

    var body: some View {
        @Bindable var store = store
        List(selection: $store.selection) {
            Section("Inventar") {
                row(.all, "Alle Einträge", "list.bullet")
                row(.orphans, "Verwaist", "exclamationmark.triangle")
            }
            Section("Kategorien") {
                ForEach(store.categories, id: \.self) { category in
                    row(.category(category), category.title, Self.symbol(category))
                }
            }
            Section("Ansichten") {
                Label("Hintergrund", systemImage: "switch.2").tag(SidebarSelection.background)
                Label("Pakete", systemImage: "shippingbox").tag(SidebarSelection.receipts)
                Label("App-Reste", systemImage: "leaf").tag(SidebarSelection.leftovers)
                Label("Quarantäne", systemImage: "archivebox").tag(SidebarSelection.quarantine)
            }
        }
        .listStyle(.sidebar)
    }

    private func row(_ selection: SidebarSelection, _ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .badge(store.count(selection))
            .tag(selection)
    }

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

struct InventoryTable: View {
    @Environment(InventoryStore.self) private var store
    @Binding var selectedKey: String?
    @Binding var sortOrder: [KeyPathComparator<InventoryRow>]

    var body: some View {
        Table(store.visibleRows.sorted(using: sortOrder), selection: $selectedKey, sortOrder: $sortOrder) {
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
