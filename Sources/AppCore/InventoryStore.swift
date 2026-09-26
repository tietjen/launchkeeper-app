import Foundation
import Observation
import LaunchKeeperKit

/// One table row. The stable entry key is the identity — display ids are
/// positional per scan and never used in the app.
public struct InventoryRow: Identifiable {
    public var id: String { item.key }
    public let item: BackgroundItem

    public init(item: BackgroundItem) { self.item = item }

    public var name: String { item.displayName }
    public var category: String { item.category.title }
    public var kind: String { item.type.rawValue }
    public var origin: String { item.provenance?.kind.rawValue ?? "unknown" }
    public var signature: String { item.codeSignatureStatus ?? "–" }
    public var path: String { item.path ?? item.executable ?? "–" }
    public var isAppleInternal: Bool { ListFilter.isAppleInternal(item) }

    /// Badges, most important first — the table's colour codes.
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

    public enum Badge: String, Sendable, CaseIterable {
        case orphan, leftover, unsigned, review, disabled, running
    }
}

/// What the sidebar selects.
public enum SidebarSelection: Hashable, Sendable {
    case all
    case orphans
    case category(ItemCategory)
    /// Phase 2 views beside the inventory table.
    case background, receipts, leftovers, quarantine

    public var isInventory: Bool {
        switch self {
        case .all, .orphans, .category: return true
        case .background, .receipts, .leftovers, .quarantine: return false
        }
    }
}

/// Moves finished results across the actor boundary. Built once in the
/// background task, never mutated afterwards; the box only carries them.
struct ScanBox: @unchecked Sendable {
    let report: ScanReport
    let background: BackgroundView
    let receipts: ReceiptsView
}

/// The app's view of the inventory. Scans run off the main thread; the BTM
/// dump is kept for the session (a cold one takes minutes, V0.9 cache).
@MainActor
@Observable
public final class InventoryStore {
    public private(set) var rows: [InventoryRow] = []
    public private(set) var isScanning = false
    public private(set) var lastScan: Date?
    public private(set) var checks: [String] = []
    public private(set) var warnings: [String] = []
    public private(set) var incompleteLayers: [String] = []
    /// System Settings › Login Items & Extensions, rebuilt (V0.5 view).
    public private(set) var background: BackgroundView?
    /// Installer packages behind the inventory (V0.6 view).
    public private(set) var receipts: ReceiptsView?
    /// Shown while scanning — a cold BTM dump explains itself.
    public private(set) var status = ""

    public var selection: SidebarSelection = .all
    public var search = ""
    public var hideApple = true

    private let btmCache = BTMDumpCache()
    private let scanner: @Sendable (BTMDumpCache) -> ScanReport

    public init(scanner: (@Sendable (BTMDumpCache) -> ScanReport)? = nil) {
        self.scanner = scanner ?? { cache in
            ScanCoordinator(environment: ScanEnvironment(btmCache: cache)).perform(options: ScanOptions())
        }
    }

    /// Full rescan. `reuseBTM` keeps the session's dump (quick refresh).
    public func refresh(reuseBTM: Bool = false) async {
        guard !isScanning else { return }
        isScanning = true
        status = reuseBTM || btmCache.text != nil
            ? String(localized: "Inventar wird gelesen …")
            : String(localized: "Inventar wird gelesen — die erste Abfrage der Hintergrundaufgaben kann einige Minuten dauern …")
        btmCache.preferCached = reuseBTM
        let scanner = self.scanner
        let cache = btmCache
        let box = await Task.detached(priority: .userInitiated) { () -> ScanBox in
            let report = scanner(cache)
            // The receipts view probes every listed path — off the main thread too.
            return ScanBox(report: report, background: BackgroundView.build(from: report),
                           receipts: ReceiptsView.build(from: report))
        }.value
        apply(box.report)
        background = box.background
        receipts = box.receipts
        isScanning = false
        status = ""
    }

    /// Takes a finished report (also the seam for tests).
    public func apply(_ report: ScanReport) {
        rows = report.items.map(InventoryRow.init)
        checks = report.checks
        warnings = report.warnings
        incompleteLayers = report.incompleteLayers
        lastScan = Date()
    }

    /// The rows the table shows for the current sidebar selection, search and Apple toggle.
    public var visibleRows: [InventoryRow] {
        rows.filter { row in
            if hideApple && row.isAppleInternal { return false }
            switch selection {
            case .all: break
            case .orphans: guard row.item.orphaned else { return false }
            case .category(let category): guard matches(row, category) else { return false }
            case .background, .receipts, .leftovers, .quarantine: break
            }
            return Self.matches(row, search: search)
        }
    }

    /// Count per sidebar entry, honouring the Apple toggle (not the search).
    public func count(_ selection: SidebarSelection) -> Int {
        rows.filter { row in
            if hideApple && row.isAppleInternal { return false }
            switch selection {
            case .all: return true
            case .orphans: return row.item.orphaned
            case .category(let category): return matches(row, category)
            case .background, .receipts, .leftovers, .quarantine: return false
            }
        }.count
    }

    /// "scheduled" is a view (category OR a schedule on a launch item), as in the CLI.
    private func matches(_ row: InventoryRow, _ category: ItemCategory) -> Bool {
        if category == .scheduled, row.item.metadata["schedule"] != nil { return true }
        return row.item.category == category
    }

    /// Case-insensitive over name, label, key, path, executable, bundle id, team.
    public static func matches(_ row: InventoryRow, search: String) -> Bool {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return true }
        let item = row.item
        return [item.displayName, item.label, item.key, item.path, item.executable, item.bundleIdentifier,
                item.teamIdentifier, item.parentApplication]
            .compactMap { $0?.lowercased() }
            .contains { $0.contains(needle) }
    }

    /// Sidebar entries that have something to show (plus "all").
    public var categories: [ItemCategory] {
        ItemCategory.allCases.filter { count(.category($0)) > 0 }
    }

    public func row(for key: String?) -> InventoryRow? {
        guard let key else { return nil }
        return rows.first { $0.id == key }
    }
}
