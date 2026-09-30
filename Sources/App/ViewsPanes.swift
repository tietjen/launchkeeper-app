//
//  ViewsPanes.swift
//  LaunchKeeper — the dedicated views beside the inventory table:
//  background (Login Items & Extensions), packages, app leftovers, quarantine.
//

import SwiftUI
import AppKit
import AppCore
import LaunchKeeperKit

/// The live presence sources for the app-leftover check.
///
/// LaunchServices and the running apps are AppKit APIs (`NSWorkspace`);
/// they are assembled here because AppCore deliberately does not link AppKit.
enum LivePresence {
    /// Builds the three sources the "app is gone" verdict needs: installed
    /// bundle ids (application folders, extensions, running apps),
    /// LaunchServices and Spotlight.
    /// - Returns: Sources for `AppLeftoverScanner.scan(sources:)`.
    static func sources() -> AppPresenceSources {
        let runner = SystemCommandRunner()
        var installed = SystemAppPresence.installedBundleIdentifiers(home: NSHomeDirectory())
        installed.formUnion(SystemAppPresence.extensionIdentifiers(runner: runner))
        installed.formUnion(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return AppPresenceSources(
            installed: installed,
            launchServices: { id in NSWorkspace.shared.urlsForApplications(withBundleIdentifier: id).first?.path },
            spotlight: SystemAppPresence.spotlight(runner: runner))
    }
}

/// Selects a file in a Finder window.
/// - Parameter path: Absolute path of the file or folder.
func revealInFinder(_ path: String) {
    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
}

// MARK: - Hintergrund (System Settings › Login Items & Extensions, rebuilt)

/// System Settings › General › Login Items & Extensions, rebuilt from the
/// inventory (CLI `launchkeeper background`): "Open at Login", then one row
/// per app or developer with the switch the pane shows and its components.
///
/// The switch is the components' Background Task Management bit — exactly
/// what System Settings shows. A launchd override is invisible there and is
/// marked separately (verified against the real pane, CLI V0.5.2).
struct BackgroundPane: View {
    @Environment(InventoryStore.self) private var store
    @Environment(Marks.self) private var marks
    @Environment(QueueModel.self) private var queue
    /// Selected row, by `BackgroundEntry.id` (unique — the BTM identifier is not).
    @Binding var selection: String?

    var body: some View {
        if let view = store.background {
            // Built once per render, not per row (review: O(rows × entries)).
            let byID = store.itemsByDisplayID
            let entries = BackgroundEntry.entries(from: view, items: byID)
            List(selection: $selection) {
                Section {
                    PaneIntro(text: "So sieht macOS die Hintergrundobjekte — dieselbe Liste wie in Systemeinstellungen › Allgemein › Anmeldeobjekte & Erweiterungen. Wähle eine Zeile, um zu sehen, was dahintersteckt, und springe zu den einzelnen Komponenten.")
                }
                Section("Beim Anmelden öffnen") {
                    if view.loginItems.isEmpty { Text("Keine").foregroundStyle(.secondary) }
                    ForEach(view.loginItems, id: \.identifier) { item in
                        Label(item.name, systemImage: "person.crop.circle.badge.checkmark")
                            .help(item.bundlePath ?? item.identifier)
                    }
                }
                Section("Im Hintergrund erlauben — Apps und Entwickler") {
                    ForEach(entries.filter { !$0.unnamed }) { entry in BackgroundEntryRow(entry: entry, marks: marks, queue: queue, targets: targets(entry, byID)).tag(entry.id) }
                }
                let unnamed = entries.filter(\.unnamed)
                if !unnamed.isEmpty {
                    Section {
                        ForEach(unnamed) { entry in BackgroundEntryRow(entry: entry, marks: marks, queue: queue, targets: targets(entry, byID)).tag(entry.id) }
                    } header: {
                        Text("Im Hintergrund erlauben — ohne Entwicklerangabe")
                    } footer: {
                        Text("Für diese Einträge kennt macOS keinen Entwickler — meist nicht signierte Werkzeuge oder Skripte. Die Systemeinstellung zeigt sie deshalb unter dem Namen des Programms, das sie startet; so können Namen wie „bash“ oder „arch“ mehrfach erscheinen. Die zweite Zeile nennt, was tatsächlich dahintersteckt.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            ContentUnavailableView("Noch nicht eingelesen", systemImage: "clock",
                                   description: Text("Die Ansicht entsteht aus dem Inventar — ⌘R."))
        }
    }

    /// The queue targets a background row stands for: its components' entries.
    private func targets(_ entry: BackgroundEntry, _ byID: [String: BackgroundItem]) -> [QueueTarget] {
        entry.row.components.compactMap { byID[$0.id].map { QueueTarget.entry(key: $0.key) } }
    }
}

/// One background row: the name System Settings shows, what tells it apart
/// (kind, components or the real identity of an unnamed entry), and the switch.
struct BackgroundEntryRow: View {
    let entry: BackgroundEntry
    /// Passed in — list cells read no environment (see `MarkBox`).
    let marks: Marks
    let queue: QueueModel
    /// The queue targets of the row's components.
    let targets: [QueueTarget]

    var body: some View {
        HStack {
            if !entry.row.components.isEmpty { MarkBox(id: entry.id, set: \.background, marks: marks, queue: queue, targets: targets) }
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                Text(entry.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if entry.row.components.contains(where: \.launchdDisabled) {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    .help("Mindestens eine Komponente ist per launchd deaktiviert — in der Systemeinstellung unsichtbar")
            }
            ToggleBadge(toggle: entry.row.toggle)
        }
    }
}

/// The state of a background row's switch as a coloured word.
struct ToggleBadge: View {
    let toggle: BackgroundView.Toggle

    var body: some View {
        switch toggle {
        case .on: Text("an").foregroundStyle(.green)
        case .off: Text("aus").foregroundStyle(.secondary)
        case .mixed: Text("gemischt").foregroundStyle(.orange)
        case .appLevel: Text("App").foregroundStyle(.blue)
        case .none: Text("–").foregroundStyle(.secondary)
        }
    }
}

// MARK: - Pakete (receipts)

/// Installer packages (receipts) behind the inventory: version, install
/// date, files listed vs. missing, and the entries attributed to each.
struct ReceiptsPane: View {
    @Environment(InventoryStore.self) private var store
    @Environment(Marks.self) private var marks
    @Environment(QueueModel.self) private var queue
    /// Selected package id.
    @Binding var selection: String?
    @State private var onlyMissing = false
    @State private var sortOrder = [KeyPathComparator(\ReceiptsView.Row.id)]

    var body: some View {
        if let view = store.receipts, view.indexed {
            let rows = view.rows.filter { !onlyMissing || $0.missingFiles > 0 }.sorted(using: sortOrder)
            VStack(spacing: 0) {
            PaneIntro(text: "Installationspakete (.pkg), die auf diesem Mac Spuren hinterlassen haben. Fehlen Dateien, wurde das Programm meist schon gelöscht — der Beleg bleibt trotzdem liegen. Wähle ein Paket, um es sauber zu entfernen.")
                .padding(12)
            Table(rows, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("") { row in MarkBox(id: row.id, set: \.packages, marks: marks, queue: queue, targets: [.package(id: row.id)]) }.width(22)
                TableColumn("Paket", value: \.id) { row in Text(row.id).textSelection(.enabled) }
                    .width(min: 200, ideal: 300)
                TableColumn("Version") { row in Text(row.version ?? "–") }.width(min: 60, ideal: 90)
                TableColumn("Installiert") { row in Text(row.installedAt.map { String($0.prefix(10)) } ?? "–") }
                    .width(min: 80, ideal: 90)
                TableColumn("Dateien", value: \.fileCount) { row in Text("\(row.fileCount)") }.width(60)
                TableColumn("Fehlen", value: \.missingFiles) { row in
                    Text(row.missingFiles == 0 ? "–" : "\(row.missingFiles)")
                        .foregroundStyle(row.missingFiles == 0 ? Color.secondary : Color.orange)
                }.width(60)
                TableColumn("Einträge") { row in
                    Text(row.items.joined(separator: ", ")).lineLimit(1).foregroundStyle(.secondary)
                }
            }
            }
            .toolbar {
                Toggle(isOn: $onlyMissing) { Label("Nur mit fehlenden Dateien", systemImage: "questionmark.folder") }
                    .help("Nur mit fehlenden Dateien — zeigt nur Pakete, von deren Dateien etwas fehlt: meist Belege längst gelöschter Software.")
            }
        } else {
            ContentUnavailableView("Keine Paket-Belege", systemImage: "shippingbox",
                                   description: Text("pkgutil hat nicht geantwortet oder das Inventar ist noch nicht eingelesen."))
        }
    }
}

// MARK: - App-Reste

/// What gone apps left behind. Loaded on first appearance (about 30 s),
/// shows only apps that are provably gone unless "show all" is on.
struct LeftoversPane: View {
    @Environment(LeftoversModel.self) private var model
    @Environment(Marks.self) private var marks
    @Environment(QueueModel.self) private var queue
    /// Selected bundle id.
    @Binding var selection: String?

    var body: some View {
        @Bindable var model = model
        Group {
            if model.isLoading && model.candidates.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Prüfe, welche Apps wirklich weg sind — LaunchServices, Spotlight, App-Ordner …")
                        .foregroundStyle(.secondary)
                }
            } else if model.visible.isEmpty {
                ContentUnavailableView("Keine Reste gefunden", systemImage: "sparkles",
                                       description: Text("Nichts, dessen App nachweislich fehlt."))
            } else {
                List(selection: $selection) {
                    Section {
                        PaneIntro(text: "Einstellungen, Caches und Daten von Apps, die nicht mehr installiert sind. Angezeigt wird nur, was nachweislich zu einer gelöschten App gehört. Wähle einen Eintrag, um die Reste anzusehen und in die Quarantäne zu verschieben.")
                    }
                    ForEach(model.visible, id: \.bundleIdentifier) { candidate in
                        LeftoverRow(candidate: candidate, marks: marks, queue: queue).tag(candidate.bundleIdentifier)
                    }
                }
            }
        }
        .toolbar {
            Toggle(isOn: $model.showAll) { Label("Auch vorhandene/unklare zeigen", systemImage: "eye") }
                .help("Auch vorhandene/unklare zeigen — listet zusätzlich Reste, deren App noch installiert ist oder bei denen das Urteil unsicher ist.")
            Button { Task { await model.reload() } } label: { Label("Neu prüfen", systemImage: "arrow.clockwise") }
                .disabled(model.isLoading)
                .help("App-Reste neu prüfen — sucht nur die Reste gelöschter Apps erneut; das Inventar liest „Neu einlesen“ weiter links (⌘R).")
        }
        .task { if !model.loaded { await model.reload() } }
    }
}

/// One line per candidate: bundle id, size and verdict. The paths and the
/// reasons are in `LeftoverDetail`.
struct LeftoverRow: View {
    let candidate: AppLeftoverCandidate
    /// Passed in — list cells read no environment (see `MarkBox`).
    let marks: Marks
    let queue: QueueModel

    var body: some View {
        HStack {
            MarkBox(id: candidate.bundleIdentifier, set: \.leftovers, marks: marks, queue: queue,
                    targets: [.leftovers(bundleID: candidate.bundleIdentifier)])
            Text(candidate.bundleIdentifier)
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: Int64(candidate.totalBytes), countStyle: .file))
                .foregroundStyle(.secondary)
            Text(candidate.presence.label).font(.caption)
                .foregroundStyle(candidate.presence.label == "gone" ? .orange : .secondary)
        }
    }
}

// MARK: - Quarantäne

/// What cleanup moved away: one row per quarantine entry with its moved
/// paths. Restore and purge arrive with Phase 4; until then the CLI command
/// is shown.
struct QuarantinePane: View {
    @Environment(QuarantineModel.self) private var model
    @Environment(Marks.self) private var marks
    @Environment(InventoryStore.self) private var store
    @Environment(HelperStatus.self) private var helper
    @Environment(WatchModel.self) private var watch
    @Environment(QueueModel.self) private var queue
    /// The entry whose restore sheet is open.
    @State private var restoring: String?

    /// An entry of the user's quarantine that moves something outside the
    /// home: only root can put it back, and the helper restores only its own
    /// entries (review 2026-09-27) — so the way back is the Terminal.
    private func terminalOnly(_ entry: QuarantineManifest) -> Bool {
        !model.isSystemEntry(entry) && entry.moves.contains { !$0.original.hasPrefix(NSHomeDirectory() + "/") }
    }

    var body: some View {
        Group {
            if model.entries.isEmpty {
                ContentUnavailableView("Quarantäne ist leer", systemImage: "archivebox",
                                       description: Text("Was LaunchKeeper beim Aufräumen wegnimmt, landet hier — wiederherstellbar."))
            } else {
                List(model.entries, id: \.name) { entry in
                    DisclosureGroup {
                        ForEach(entry.moves, id: \.original) { move in
                            Text(move.original).font(.callout).textSelection(.enabled)
                        }
                        if entry.forgot { Text("Paketbeleg vergessen — Kopie liegt in der Quarantäne").font(.caption) }
                        HStack {
                            if terminalOnly(entry) {
                                // The helper restores only entries it keeps itself (root-owned tree);
                                // this one is in the user's quarantine and needs root → Terminal.
                                Text("Nur im Terminal: launchkeeper quarantine restore \(entry.name)")
                                    .font(.caption.monospaced()).textSelection(.enabled)
                                Button("Befehl kopieren") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString("launchkeeper quarantine restore \(entry.name)", forType: .string)
                                }
                            } else {
                                Button("Wiederherstellen…") { restoring = entry.name }
                                    .disabled(entry.status == "restored")
                            }
                            Button("Im Finder zeigen") { revealInFinder(model.directory(of: entry)) }
                            Spacer()
                            Text("Endgültig löschen: im Terminal mit launchkeeper quarantine purge")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } label: {
                        HStack {
                            if entry.status != "restored" && !terminalOnly(entry) {
                                MarkBox(id: entry.name, set: \.quarantine, marks: marks, queue: queue, targets: [.quarantine(name: entry.name)])
                            }
                            Text(entry.packageIdentifier ?? entry.notes.first ?? entry.kind)
                            Spacer()
                            Text("\(entry.moves.count) Pfad(e)").foregroundStyle(.secondary)
                            Text(entry.status).font(.caption).foregroundStyle(entry.status == "applied-ok" ? .green : .secondary)
                            Text(String(entry.createdAt.prefix(10))).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .toolbar {
            Button { model.reload() } label: { Label("Neu laden", systemImage: "arrow.clockwise") }
                .help("Quarantäne neu laden — liest die Einträge der Quarantäne erneut, z. B. nach Änderungen im Terminal.")
        }
        .onAppear { model.reload() }
        .sheet(item: Binding(get: { restoring.map(RestoreTarget.init) }, set: { restoring = $0?.name })) { target in
            ActionSheet(request: .restore(quarantine: target.name), performer: Performer.make(store: store)) {
                model.reload()
                Task { await store.refresh(reuseBTM: true, reason: .action) }
            }
            .environment(helper)
            .environment(watch)
            .environment(queue)
        }
    }
}

/// Receipt rows already carry the package id as `id`.
extension ReceiptsView.Row: @retroactive Identifiable {}

// MARK: - Shared

/// The explanation at the top of a view: what it shows and what can be done there.
struct PaneIntro: View {
    let text: LocalizedStringKey

    var body: some View {
        Label { Text(text).font(.callout).foregroundStyle(.secondary) } icon: {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Detail columns of the dedicated views

/// Detail of one installer package: what it is, how much is left, next steps.
struct PackageDetail: View {
    let row: ReceiptsView.Row

    var body: some View {
        Form {
            QueuedBanner(targets: [.package(id: row.id)])
            SummarySections(title: row.id, summary: PackageSummary.build(for: row))
            if !row.items.isEmpty {
                Section("Startet automatisch") {
                    ForEach(row.items, id: \.self) { Text($0) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Detail of one app's leftovers: verdict with reasons, every path, next steps.
struct LeftoverDetail: View {
    let candidate: AppLeftoverCandidate

    var body: some View {
        Form {
            QueuedBanner(targets: [.leftovers(bundleID: candidate.bundleIdentifier)])
            SummarySections(title: candidate.bundleIdentifier, summary: LeftoverSummary.build(for: candidate))
        }
        .formStyle(.grouped)
    }
}

/// Detail of one background row: the switch, its components and where to change it.
struct BackgroundDetail: View {
    let entry: BackgroundEntry
    private var row: BackgroundView.Row { entry.row }

    var body: some View {
        Form {
            SummarySections(title: entry.unnamed ? "\(row.name) — \(entry.row.components.first?.label ?? "")" : row.name,
                            summary: BackgroundSummary.build(for: entry))
            Section("Komponenten") {
                ForEach(row.components, id: \.id) { component in
                    HStack {
                        Image(systemName: component.enabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(component.enabled ? .green : .secondary)
                        VStack(alignment: .leading) {
                            Text(component.name)
                            Text(component.label ?? component.type).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if component.launchdDisabled { Text("launchd: aus").font(.caption).foregroundStyle(.orange) }
                        if component.running { Text("läuft").font(.caption).foregroundStyle(.green) }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Identifies the quarantine entry of an open restore sheet (`sheet(item:)` needs `Identifiable`).
struct RestoreTarget: Identifiable {
    let name: String
    var id: String { name }
}
