//
//  InventoryStore.swift
//  AppCore — UI-free state of the inventory window.
//
//  The store owns the result of the last scan and answers everything the
//  sidebar and the table ask: which rows are visible, how many entries a
//  sidebar item has, which categories exist at all. It holds no SwiftUI
//  types, so it is tested with plain XCTest.
//

import Foundation
import Observation
import LaunchKeeperKit

// MARK: - Row

/// One row of the inventory table, wrapping one `BackgroundItem`.
///
/// The identity is the item's **stable entry key** (`BackgroundItem.key`).
/// The CLI's display ids ("01", "02" …) are positional per scan and would
/// point at a different entry after the next rescan, so the app never uses them.
public struct InventoryRow: Identifiable {
    /// The stable entry key — survives rescans, used for selection.
    public var id: String { item.key }

    /// The scanned entry this row shows.
    public let item: BackgroundItem

    /// Creates a row for one scanned entry.
    /// - Parameter item: The entry as the scan returned it.
    public init(item: BackgroundItem) { self.item = item }

    // Sortable column values. `Table` sorts through key paths, so each
    // column needs a plain, comparable property rather than a formatter.

    /// Display name of the entry.
    public var name: String { item.displayName }
    /// Human title of the entry's category ("Launch Items", "App Extensions" …).
    public var category: String { item.category.title }
    /// The entry type in the tool's vocabulary ("user-agent", "cron-job" …).
    public var kind: String { item.type.rawValue }
    /// Provenance kind ("receipt", "manual", "apple" …), "unknown" when none was resolved.
    public var origin: String { item.provenance?.kind.rawValue ?? "unknown" }
    /// Code-signature status as the scan recorded it, or an en dash.
    public var signature: String { item.codeSignatureStatus ?? "–" }
    /// The backing file, else the executable, else an en dash.
    public var path: String { item.path ?? item.executable ?? "–" }
    /// `true` for Apple's own entries, which the "hide Apple" toggle removes.
    public var isAppleInternal: Bool { ListFilter.isAppleInternal(item) }

    /// Status badges for the table's colour codes, most important first.
    ///
    /// A BTM leftover is reported instead of "orphan": both flags are set on
    /// such an entry, but "leftover" is the more precise statement (the
    /// source is already gone, only a record remains).
    public var badges: [Badge] {
        var out: [Badge] = []
        if item.metadata["btm-leftover"] == "true" { out.append(.leftover) }
        else if item.orphaned { out.append(.orphan) }
        if item.codeSignatureStatus?.contains("unsigned") == true || item.codeSignatureStatus?.contains("not signed") == true {
            out.append(.unsigned)
        }
        if !item.riskFlags.isEmpty { out.append(.review) }
        if !item.enabled { out.append(.disabled) }
        if item.running { out.append(.running) }
        return out
    }

    /// The status markers a row can carry.
    public enum Badge: String, Sendable, CaseIterable {
        /// The entry's source is provably gone.
        case orphan
        /// Only a Background Task Management record is left.
        case leftover
        /// The executable carries no code signature.
        case unsigned
        /// A review hint (temp path, shell interpreter as a service …) — never a malware verdict.
        case review
        /// Switched off (launchd override, pluginkit election, commented cron line …).
        case disabled
        /// A process is running for it right now.
        case running
    }
}

// MARK: - Sidebar

/// What the sidebar selects: a slice of the inventory table or one of the
/// dedicated views beside it.
public enum SidebarSelection: Hashable, Sendable {
    /// Every entry.
    case all
    /// Entries whose source is provably gone.
    case orphans
    /// One Autoruns-style category.
    case category(ItemCategory)
    /// System Settings › Login Items & Extensions, rebuilt from the inventory.
    case background
    /// Installer packages (receipts) behind the inventory.
    case receipts
    /// What gone apps left behind.
    case leftovers
    /// What cleanup moved away and can bring back.
    case quarantine
    /// What the watch noticed since it was switched on (Phase 7).
    case watch

    /// `true` when the selection filters the inventory table; `false` for a dedicated view.
    public var isInventory: Bool {
        switch self {
        case .all, .orphans, .category: return true
        case .background, .receipts, .leftovers, .quarantine, .watch: return false
        }
    }
}

// MARK: - Scan reasons

/// Why a scan runs. The watch (Phase 7) compares every scan with the one
/// before; the reason decides whether a difference was caused by
/// LaunchKeeper itself and how the event is labelled.
public enum ScanReason: Equatable, Sendable {
    /// The first scan after launch.
    case launch
    /// The user asked (⌘R, toolbar).
    case user
    /// After an action LaunchKeeper executed — its differences are LaunchKeeper's own.
    case action
    /// The watch: a file-system event or the periodic check (the text says which).
    case watch(String)

    /// The trigger text stored with watch events (same style as the CLI's `watch`).
    public var trigger: String {
        switch self {
        case .launch: return "start"
        case .user: return "manual rescan"
        case .action: return "LaunchKeeper action"
        case .watch(let text): return text
        }
    }

    /// Merges two queued reasons into one rescan. An action wins, so its
    /// differences are never reported as someone else's.
    func merged(with other: ScanReason) -> ScanReason {
        if self == .action || other == .action { return .action }
        return other
    }
}

// MARK: - Store

/// Carries the results of one scan from the background task to the main actor.
///
/// `ReceiptsView` and `BackgroundView` are not `Sendable`. They are built
/// once inside the task and never mutated afterwards, so handing them over
/// unchecked is safe; the box exists only to say that to the compiler.
struct ScanBox: @unchecked Sendable {
    let report: ScanReport
    let background: BackgroundView
    let receipts: ReceiptsView
}

/// The app's view of the inventory: scan results plus the window's filter state.
///
/// Scans run in a detached task, never on the main thread — a scan spawns
/// `launchctl`, `sfltool`, `pluginkit`, `codesign` … and takes seconds, the
/// first Background Task Management dump after idle even minutes. The dump
/// is kept for the session (`BTMDumpCache`, CLI V0.9) so quick refreshes
/// do not pay for it again.
@MainActor
@Observable
public final class InventoryStore {
    /// All entries of the last complete or partial scan.
    public private(set) var rows: [InventoryRow] = []
    /// `true` while a scan runs; a second refresh is ignored meanwhile.
    public private(set) var isScanning = false
    /// When the last scan finished.
    public private(set) var lastScan: Date?
    /// The scan's self-check lines (the CLI's `doctor` output).
    public private(set) var checks: [String] = []
    /// Non-fatal problems the scan reported.
    public private(set) var warnings: [String] = []
    /// Sources that did not answer — the inventory is incomplete while this is non-empty.
    public private(set) var incompleteLayers: [String] = []
    /// System Settings › Login Items & Extensions, rebuilt (CLI V0.5 view).
    public private(set) var background: BackgroundView?
    /// Installer packages behind the inventory (CLI V0.6 view).
    public private(set) var receipts: ReceiptsView?
    /// Progress text while scanning; explains a slow first Background Task Management dump.
    public private(set) var status = ""

    /// The sidebar's current selection.
    public var selection: SidebarSelection = .all
    /// The selected inventory row, by stable entry key. Lives in the store
    /// (not the view) so other views can jump to an entry (`show(displayID:)`).
    public var selectedKey: String?
    /// The search field's text; matched against names, labels, keys, paths, ids.
    public var search = ""
    /// Hides Apple's own entries — on by default, like the CLI's `list`.
    public var hideApple = true

    private let btmCache = BTMDumpCache()

    /// The session's Background Task Management dump, shared with actions
    /// (`EnginePerformer`) so they do not pay a cold dump of their own.
    public var btmDumpCache: BTMDumpCache { btmCache }
    private let scanner: @Sendable (BTMDumpCache) -> ScanReport

    /// Called on the main actor after every finished scan, with its reason.
    /// The watch hangs itself in here, so every scan — manual, after an
    /// action or its own — is compared once and nothing is scanned twice.
    public var onScan: ((ScanReport, ScanReason) -> Void)?

    /// A rescan requested while a scan was running (watch or action only).
    /// Dropping it could hide a change that happened during the scan.
    private var queued: (reuseBTM: Bool, reason: ScanReason)?

    /// Creates the store.
    /// - Parameter scanner: Produces a scan report. Defaults to a full
    ///   `ScanCoordinator` scan of this Mac; tests inject a stub.
    public init(scanner: (@Sendable (BTMDumpCache) -> ScanReport)? = nil) {
        self.scanner = scanner ?? { cache in
            ScanCoordinator(environment: ScanEnvironment(btmCache: cache)).perform(options: ScanOptions())
        }
    }

    /// Scans the Mac again and replaces the store's contents.
    ///
    /// - Parameters:
    ///   - reuseBTM: `true` reuses the session's Background Task
    ///     Management dump (quick refresh, ⌘R); `false` asks the daemon again
    ///     (⇧⌘R), which can take minutes after the daemon sat idle.
    ///   - reason: Why the scan runs; passed to `onScan`. A watch or action
    ///     rescan that arrives while a scan runs is queued, not dropped.
    public func refresh(reuseBTM: Bool = false, reason: ScanReason = .user) async {
        guard !isScanning else {
            if reason != .user && reason != .launch {
                queued = queued.map { (reuseBTM: $0.reuseBTM && reuseBTM, reason: $0.reason.merged(with: reason)) }
                    ?? (reuseBTM: reuseBTM, reason: reason)
            }
            return
        }
        isScanning = true
        status = reuseBTM || btmCache.text != nil
            ? String(localized: "Inventar wird gelesen …")
            : String(localized: "Inventar wird gelesen — die erste Abfrage der Hintergrundaufgaben kann einige Minuten dauern …")
        btmCache.preferCached = reuseBTM
        let scanner = self.scanner
        let cache = btmCache
        let box = await Task.detached(priority: .userInitiated) { () -> ScanBox in
            let report = scanner(cache)
            // The receipts view checks every path each receipt lists (tens of
            // thousands) — it belongs in the background task, not on the main actor.
            return ScanBox(report: report, background: BackgroundView.build(from: report),
                           receipts: ReceiptsView.build(from: report))
        }.value
        apply(box.report)
        background = box.background
        receipts = box.receipts
        isScanning = false
        status = ""
        onScan?(box.report, reason)
        if let next = queued {
            queued = nil
            await refresh(reuseBTM: next.reuseBTM, reason: next.reason)
        }
    }

    /// Replaces the rows and scan diagnostics with a finished report.
    ///
    /// Also the seam tests use to fill the store without scanning.
    /// - Parameter report: A finished scan.
    public func apply(_ report: ScanReport) {
        rows = report.items.map(InventoryRow.init)
        checks = report.checks
        warnings = report.warnings
        incompleteLayers = report.incompleteLayers
        lastScan = Date()
    }

    /// The rows the table shows: sidebar selection, then the Apple toggle, then the search.
    public var visibleRows: [InventoryRow] {
        rows.filter { row in
            if hideApple && row.isAppleInternal { return false }
            switch selection {
            case .all: break
            case .orphans: guard row.item.orphaned else { return false }
            case .category(let category): guard matches(row, category) else { return false }
            // Dedicated views do not filter the table (it is not shown for them).
            case .background, .receipts, .leftovers, .quarantine, .watch: break
            }
            return Self.matches(row, search: search)
        }
    }

    /// Number of entries behind a sidebar item.
    ///
    /// Honours the Apple toggle but not the search, so the counts stay
    /// stable while typing.
    /// - Parameter selection: The sidebar item.
    /// - Returns: The entry count; 0 for dedicated views.
    public func count(_ selection: SidebarSelection) -> Int {
        rows.filter { row in
            if hideApple && row.isAppleInternal { return false }
            switch selection {
            case .all: return true
            case .orphans: return row.item.orphaned
            case .category(let category): return matches(row, category)
            case .background, .receipts, .leftovers, .quarantine, .watch: return false
            }
        }.count
    }

    /// Whether a row belongs to a category.
    ///
    /// "Scheduled" is a view, as in the CLI: its own entries (cron, at,
    /// pmset …) plus launch items that carry a schedule. A launchd timer
    /// stays a launch item and appears in both.
    private func matches(_ row: InventoryRow, _ category: ItemCategory) -> Bool {
        if category == .scheduled, row.item.metadata["schedule"] != nil { return true }
        return row.item.category == category
    }

    /// Case-insensitive search over name, label, key, path, executable, bundle id, team and app.
    /// - Parameters:
    ///   - row: The row to test.
    ///   - search: The search text; empty or whitespace matches everything.
    /// - Returns: `true` when any of the fields contains the text.
    public static func matches(_ row: InventoryRow, search: String) -> Bool {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return true }
        let item = row.item
        return [item.displayName, item.label, item.key, item.path, item.executable, item.bundleIdentifier,
                item.teamIdentifier, item.parentApplication]
            .compactMap { $0?.lowercased() }
            .contains { $0.contains(needle) }
    }

    /// Categories that currently have entries — empty ones stay out of the sidebar.
    public var categories: [ItemCategory] {
        ItemCategory.allCases.filter { count(.category($0)) > 0 }
    }

    /// Jumps to an inventory entry: all entries, no search filter, the entry selected.
    ///
    /// The dedicated views refer to entries by the display id of the scan
    /// they were built from — the same scan the rows come from, so the id is
    /// unambiguous here (it would not be across scans).
    /// - Parameter displayID: `BackgroundItem.id` from the current scan.
    public func show(displayID: String) {
        guard let row = rows.first(where: { $0.item.id == displayID }) else { return }
        search = ""
        if hideApple && row.isAppleInternal { hideApple = false }
        selection = .all
        selectedKey = row.id
    }

    /// Selects an entry by its stable key (a watch event, a notification).
    ///
    /// Clears the search and shows Apple's entries when needed, so the row
    /// is visible in the table.
    /// - Parameter key: The entry key.
    /// - Returns: `false` when the entry is not in the inventory (any more).
    @discardableResult
    public func reveal(key: String) -> Bool {
        guard let row = rows.first(where: { $0.id == key }) else { return false }
        search = ""
        if hideApple && row.isAppleInternal { hideApple = false }
        selection = .all
        selectedKey = row.id
        return true
    }

    /// The current scan's entries by display id — for views built from the
    /// same scan that refer to entries that way (background components).
    public var itemsByDisplayID: [String: BackgroundItem] {
        Dictionary(rows.map { ($0.item.id, $0.item) }, uniquingKeysWith: { first, _ in first })
    }

    /// Looks up a row by its stable key.
    /// - Parameter key: The table selection; `nil` when nothing is selected.
    /// - Returns: The row, or `nil` when the key is unknown (e.g. gone after a rescan).
    public func row(for key: String?) -> InventoryRow? {
        guard let key else { return nil }
        return rows.first { $0.id == key }
    }
}
