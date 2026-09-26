import SwiftUI
import AppKit
import AppCore
import LaunchKeeperKit

/// LaunchServices and running apps come from AppKit — only the app links it.
enum LivePresence {
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

func revealInFinder(_ path: String) {
    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
}

// MARK: - Hintergrund (System Settings › Login Items & Extensions, rebuilt)

struct BackgroundPane: View {
    @Environment(InventoryStore.self) private var store

    var body: some View {
        if let view = store.background {
            List {
                Section("Beim Anmelden öffnen") {
                    if view.loginItems.isEmpty { Text("Keine").foregroundStyle(.secondary) }
                    ForEach(view.loginItems, id: \.identifier) { item in
                        Label(item.name, systemImage: "person.crop.circle.badge.checkmark")
                            .help(item.bundlePath ?? item.identifier)
                    }
                }
                Section("Im Hintergrund erlauben") {
                    ForEach(view.background, id: \.identifier) { row in
                        DisclosureGroup {
                            ForEach(row.components, id: \.id) { component in
                                HStack {
                                    Image(systemName: component.enabled ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(component.enabled ? .green : .secondary)
                                    Text(component.name)
                                    if component.launchdDisabled {
                                        Text("launchd: deaktiviert").font(.caption).foregroundStyle(.orange)
                                    }
                                    if component.leftover { Text("Rest").font(.caption).foregroundStyle(.secondary) }
                                    else if component.orphaned { Text("verwaist").font(.caption).foregroundStyle(.orange) }
                                    Spacer()
                                    Text(component.type).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        } label: {
                            HStack {
                                Text(row.name)
                                Spacer()
                                ToggleBadge(toggle: row.toggle)
                            }
                        }
                    }
                }
                Section {
                    Text("Der Schalter ist das, was die Systemeinstellung zeigt. Ein launchd-Override ist dort unsichtbar und wird hier getrennt angezeigt. LaunchKeeper schreibt nicht in die Hintergrundaufgaben-Verwaltung — umschalten in Systemeinstellungen › Allgemein › Anmeldeobjekte & Erweiterungen.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        } else {
            ContentUnavailableView("Noch nicht eingelesen", systemImage: "clock",
                                   description: Text("Die Ansicht entsteht aus dem Inventar — ⌘R."))
        }
    }
}

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

struct ReceiptsPane: View {
    @Environment(InventoryStore.self) private var store
    @State private var onlyMissing = false
    @State private var sortOrder = [KeyPathComparator(\ReceiptsView.Row.id)]

    var body: some View {
        if let view = store.receipts, view.indexed {
            let rows = view.rows.filter { !onlyMissing || $0.missingFiles > 0 }.sorted(using: sortOrder)
            Table(rows, sortOrder: $sortOrder) {
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
            .toolbar {
                Toggle(isOn: $onlyMissing) { Label("Nur mit fehlenden Dateien", systemImage: "questionmark.folder") }
            }
        } else {
            ContentUnavailableView("Keine Paket-Belege", systemImage: "shippingbox",
                                   description: Text("pkgutil hat nicht geantwortet oder das Inventar ist noch nicht eingelesen."))
        }
    }
}

// MARK: - App-Reste

struct LeftoversPane: View {
    @Environment(LeftoversModel.self) private var model

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
                List(model.visible, id: \.bundleIdentifier) { candidate in
                    LeftoverRow(candidate: candidate)
                }
            }
        }
        .toolbar {
            Toggle(isOn: $model.showAll) { Label("Auch vorhandene/unklare zeigen", systemImage: "eye") }
            Button { Task { await model.reload() } } label: { Label("Neu prüfen", systemImage: "arrow.clockwise") }
                .disabled(model.isLoading)
        }
        .task { if !model.loaded { await model.reload() } }
    }
}

struct LeftoverRow: View {
    let candidate: AppLeftoverCandidate

    var body: some View {
        DisclosureGroup {
            ForEach(candidate.paths, id: \.path) { path in
                HStack {
                    Text(path.kind).font(.caption).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
                    Text(path.path).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    if path.needsRoot { Image(systemName: "lock").help("liegt in /Library — Entfernen braucht Admin-Rechte") }
                    Spacer()
                    Button { revealInFinder(path.path) } label: { Image(systemName: "magnifyingglass") }
                        .buttonStyle(.borderless).help("Im Finder zeigen")
                }
            }
            Text(reason).font(.callout).foregroundStyle(.secondary)
        } label: {
            HStack {
                Text(candidate.bundleIdentifier)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: Int64(candidate.totalBytes), countStyle: .file))
                    .foregroundStyle(.secondary)
                Text(candidate.presence.label).font(.caption)
                    .foregroundStyle(candidate.presence.label == "gone" ? .orange : .secondary)
            }
        }
    }

    private var reason: String {
        switch candidate.presence {
        case .present(let why), .unknown(let why): return why
        case .noAppEvidence: return String(localized: "Keine App gefunden — aber nichts zeigt, dass es je eine App war.")
        case .gone(let proofs):
            return proofs.joined(separator: " · ") + " — " + String(localized: "war eine App: ")
                + candidate.appEvidence.joined(separator: ", ")
        }
    }
}

// MARK: - Quarantäne

struct QuarantinePane: View {
    @Environment(QuarantineModel.self) private var model

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
                            Button("Im Finder zeigen") { revealInFinder(model.directory(of: entry)) }
                            Text("Wiederherstellen/Endgültig löschen folgt in Phase 4 — bis dahin: launchkeeper quarantine restore \(entry.name)")
                                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    } label: {
                        HStack {
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
        .toolbar { Button { model.reload() } label: { Label("Neu laden", systemImage: "arrow.clockwise") } }
        .onAppear { model.reload() }
    }
}

/// Receipt rows already carry the package id as `id`.
extension ReceiptsView.Row: @retroactive Identifiable {}
