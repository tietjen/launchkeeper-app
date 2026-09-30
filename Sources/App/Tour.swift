//
//  Tour.swift
//  LaunchKeeper — the introduction at launch (TJ 2026-09-30): step by step,
//  each part of the real window is outlined and explained in a popover next
//  to it; steps that belong to no single place (welcome, helper, end) come
//  as a sheet. It can be switched off (in the tour, in Settings) and started
//  again from the Help menu.
//
//  Popovers on the real views rather than a drawn overlay: the window's
//  columns are hosted separately, so geometry from one column does not reach
//  an overlay of the window — a popover is anchored by AppKit itself.
//

import SwiftUI
import AppCore

// MARK: - Steps

/// Where a step points in the main window.
enum TourSpot: Hashable {
    case sidebar, content, detail, refresh, viewsRow, watchRow, queueRow
}

/// One step of the introduction.
enum TourStep: Int, CaseIterable {
    case welcome, sidebar, list, detail, toolbar, views, watch, queue, helper, done

    /// The part of the window the step points at; `nil` = shown as a sheet.
    var spot: TourSpot? {
        switch self {
        case .welcome, .helper, .done: return nil
        case .sidebar: return .sidebar
        case .list: return .content
        case .detail: return .detail
        case .toolbar: return .refresh
        case .views: return .viewsRow
        case .watch: return .watchRow
        case .queue: return .queueRow
        }
    }

    /// Symbol at the top of the card.
    var symbol: String {
        switch self {
        case .welcome: return "hand.wave"
        case .sidebar: return "sidebar.left"
        case .list: return "list.bullet"
        case .detail: return "sidebar.right"
        case .toolbar: return "arrow.clockwise"
        case .views: return "rectangle.3.group"
        case .watch: return "eye"
        case .queue: return "tray.full"
        case .helper: return "lock.shield"
        case .done: return "checkmark.seal"
        }
    }

    /// The card's heading.
    var title: String {
        switch self {
        case .welcome: return String(localized: "Willkommen bei LaunchKeeper")
        case .sidebar: return String(localized: "Links: was du sehen willst")
        case .list: return String(localized: "In der Mitte: die Einträge")
        case .detail: return String(localized: "Rechts: was ein Eintrag bedeutet")
        case .toolbar: return String(localized: "Oben: Darstellung und Neu einlesen")
        case .views: return String(localized: "Ansichten für bestimmte Fragen")
        case .watch: return String(localized: "Beobachtung")
        case .queue: return String(localized: "Warteschlange: vieles auf einmal")
        case .helper: return String(localized: "Für Änderungen am System: das Hilfsprogramm")
        case .done: return String(localized: "Das war's")
        }
    }

    /// The card's text (Markdown).
    var text: String {
        switch self {
        case .welcome:
            return String(localized: "LaunchKeeper zeigt alles, was auf diesem Mac automatisch startet, und erklärt es in Klartext. **Ohne dein Zutun ändert es nichts** — jede Änderung zeigt vorher ihren Plan und lässt sich rückgängig machen.\n\nDiese Einführung zeigt in einer Minute, wo was ist.")
        case .sidebar:
            return String(localized: "**Alle Einträge**, nur die **verwaisten** (deren Programm fehlt) oder eine **Kategorie** wie Hintergrunddienste, Anmeldeobjekte oder Erweiterungen. Die Zahl sagt, wie viele es sind.")
        case .list:
            return String(localized: "Jede Spalte lässt sich sortieren. Symbole markieren, was Aufmerksamkeit verdient: ⚠︎ verwaist, rot nicht signiert, gelb ansehen empfohlen.\n\nDas **Häkchen** vorne sammelt Einträge für die Warteschlange.")
        case .detail:
            return String(localized: "Ampel, ein Satz in Klartext, die Fakten — und die **Nächsten Schritte**: nur Aktionen, die hier sicher möglich sind.\n\n**Ausführen…** zeigt erst den Plan; ein zweiter Klick führt aus. Änderungen am System fragen nach Touch ID.")
        case .toolbar:
            return String(localized: "Basis- oder **Expertenmodus** (⌥⌘E), **Apple-Einträge** aus- oder einblenden und **Neu einlesen** (⌘R; ⇧⌘R fragt auch die Hintergrundverwaltung von macOS neu ab).")
        case .views:
            return String(localized: "**Hintergrund** wie in den Systemeinstellungen, **Pakete** mit Deinstallation, **App-Reste** gelöschter Apps und die **Quarantäne**: alles Entfernte, jederzeit wiederherstellbar.")
        case .watch:
            return String(localized: "Einmal eingeschaltet, meldet LaunchKeeper per Mitteilung, wenn etwas Neues automatisch starten will — auch mit geschlossenem Fenster (Auge in der Menüleiste).")
        case .queue:
            return String(localized: "Häkchen setzen, rechts **Zur Warteschlange hinzufügen**, hier **Plan prüfen** und **Alle ausführen**: eine Touch-ID-Abfrage für den ganzen Lauf. Was nur in den Systemeinstellungen geht, steht mit Anleitung unter **Von Hand**.")
        case .helper:
            return String(localized: "Änderungen an Systemdiensten und in /Library brauchen Administratorrechte. Dafür richtest du **einmal** das Hilfsprogramm ein: Einstellungen (⌘,) › **Einrichten**, dann in den Systemeinstellungen erlauben.\n\nDanach liest LaunchKeeper auch ohne Touch-ID-Abfrage ein; gefragt wird nur noch vor echten Änderungen.")
        case .done:
            return String(localized: "Alles Weitere steht in der Hilfe (⌘?). Die Einführung findest du jederzeit unter Hilfe › **Einführung zeigen**.")
        }
    }

    /// Prepares the window so the step's part is visible (and has content).
    @MainActor
    func prepare(_ store: InventoryStore) {
        switch self {
        case .sidebar, .list, .toolbar:
            store.selection = .all
        case .detail:
            store.selection = .all
            // The table sorts by name: take the row it shows at the top.
            if store.row(for: store.selectedKey) == nil {
                store.selectedKey = store.visibleRows.min { $0.name.localizedStandardCompare($1.name) == .orderedAscending }?.id
            }
        default:
            break
        }
    }
}

// MARK: - Model

/// One shown step: what the card says, and which switch it belongs to.
/// Presented by item, so a closing card keeps its content while the next
/// one waits, and a late "closed" from an older card is recognisable.
struct TourPresentation: Identifiable, Equatable {
    /// Increases with every step switch.
    let id: Int
    let step: TourStep
}

/// The running introduction.
@MainActor
@Observable
final class TourModel {
    /// `@AppStorage` key: show the introduction at launch.
    static let showAtLaunchKey = "showTourAtLaunch"

    /// The step on screen; `nil` = no introduction running.
    private(set) var step: TourStep?
    /// The card on screen; `nil` while one step's card closes and the next
    /// one waits — two presentations switching in the same update can drop
    /// the second.
    private(set) var presentation: TourPresentation?
    /// The main window that shows the introduction (there is one; after it
    /// was closed and opened again, the new one takes over).
    private(set) var owner: UUID?
    /// The step's card could not appear at its place (collapsed column,
    /// hidden toolbar …): it shows as a sheet instead (review 2026-09-30, N2).
    private(set) var asSheet = false
    /// The presentation whose card last appeared on screen.
    @ObservationIgnored private var appeared: Int?
    /// The current step was shown again after a too-early close (at most once).
    @ObservationIgnored private var representedOnce = false
    /// Set once the introduction started by itself in this app session.
    @ObservationIgnored private var startedAtLaunch = false
    @ObservationIgnored private var generation = 0
    /// When the current card appeared — a "closed" arriving right after is
    /// the previous card's animation ending, not the user (review S5).
    @ObservationIgnored private var presentedAt = Date.distantPast
    /// Per window: prepares it for a step (selection, visible columns).
    @ObservationIgnored private var preparers: [UUID: (TourStep) -> Void] = [:]
    /// Brings a main window to the front (opens one if none is open); set by the app.
    @ObservationIgnored var bringMainWindowToFront: (() -> Void)?

    /// A main window appeared: it can show the introduction.
    /// - Parameters:
    ///   - window: The window's token.
    ///   - prepare: Prepares that window for a step.
    func register(window: UUID, prepare: @escaping (TourStep) -> Void) {
        preparers[window] = prepare
        // The newest window takes over — a closed one may not have said goodbye.
        owner = window
        // A tour started while no window was open continues here.
        if let step { prepare(step) }
    }

    /// The main window closed: the introduction ends with it.
    func unregister(window: UUID) {
        preparers[window] = nil
        guard owner == window else { return }
        owner = nil
        end()
    }

    /// A card is on screen (called by the card itself).
    func cardAppeared(_ id: Int) { appeared = id }

    /// Starts from the beginning, in front of a main window.
    func start() {
        representedOnce = false
        bringMainWindowToFront?()
        go(to: .welcome)
    }

    /// Starts once per app session if the user wants it at launch.
    func startAtLaunchIfWanted() {
        guard !startedAtLaunch else { return }
        startedAtLaunch = true
        if UserDefaults.standard.object(forKey: Self.showAtLaunchKey) as? Bool ?? true { go(to: .welcome) }
    }

    /// The next step, or the end after the last.
    func next() {
        guard let step else { return }
        representedOnce = false
        if let following = TourStep(rawValue: step.rawValue + 1) { go(to: following) } else { end() }
    }

    /// The previous step.
    func back() {
        guard let step, let previous = TourStep(rawValue: step.rawValue - 1) else { return }
        representedOnce = false
        go(to: previous)
    }

    /// Ends the introduction.
    func end() {
        generation += 1
        presentation = nil
        asSheet = false
        step = nil
    }

    /// The card for `spot` in `window`, if it is on screen there.
    func presentation(at spot: TourSpot?, in window: UUID) -> TourPresentation? {
        guard owner == window, let presentation, shownSpot == spot else { return nil }
        return presentation
    }

    /// Where the current card is shown: its place, or the sheet (`nil`).
    private var shownSpot: TourSpot? { asSheet ? nil : presentation?.step.spot }

    /// Whether `spot` is outlined in `window`.
    func isOutlined(_ spot: TourSpot, in window: UUID) -> Bool { owner == window && step?.spot == spot }

    /// A card was closed. It ends the introduction only when it is the card
    /// on screen — same place — and has been there a moment: a click outside
    /// or Esc, not the previous card's closing animation.
    /// - Parameter spot: Where the closed card was (`nil` = the sheet).
    func closed(at spot: TourSpot?) {
        // A card that never appeared cannot have been closed by the user:
        // such a report is the previous card's closing animation (review L1).
        guard let presentation, shownSpot == spot, appeared == presentation.id, let step else { return }
        guard Date().timeIntervalSince(presentedAt) > 0.4 else {
            // Too early for a deliberate click, but AppKit closed it: show the
            // step once more instead of an "open" binding with nothing on
            // screen — once per step, so it can never loop.
            guard !representedOnce else { return }
            go(to: step)
            representedOnce = true
            return
        }
        end()
    }

    /// Switches to a step: the old card goes, the window is prepared, then
    /// the new card comes a moment later.
    private func go(to target: TourStep) {
        generation += 1
        let current = generation
        presentation = nil
        asSheet = false
        step = target
        if let owner { preparers[owner]?(target) }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard self.generation == current, self.step == target else { return }
            self.presentedAt = Date()
            self.presentation = TourPresentation(id: current, step: target)
            // A popover whose place is not on screen never appears: after a
            // second without the card, the step comes as a sheet.
            guard target.spot != nil else { return }
            try? await Task.sleep(for: .seconds(1))
            guard self.generation == current, self.appeared != current else { return }
            self.presentedAt = Date()
            self.asSheet = true
        }
    }
}

// MARK: - Card

/// The content of a step: symbol, heading, text, progress and the buttons.
struct TourCard: View {
    let tour: TourModel
    let step: TourStep
    /// Opens the help window (the last step offers it).
    let openHelp: () -> Void
    @AppStorage(TourModel.showAtLaunchKey) private var showAtLaunch = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(step.title, systemImage: step.symbol).font(.headline)
                Spacer()
                Text("\(step.rawValue + 1) von \(TourStep.allCases.count)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Text(markdown(step.text)).fixedSize(horizontal: false, vertical: true)
            if step == .welcome || step == .done {
                Toggle("Beim Start zeigen", isOn: $showAtLaunch).toggleStyle(.checkbox)
            }
            HStack {
                if step == .welcome {
                    Button("Überspringen") { tour.end() }
                } else if step != .done {
                    Button("Beenden") { tour.end() }
                }
                Spacer()
                if step != .welcome { Button("Zurück") { tour.back() } }
                if step == .helper {
                    SettingsLink { Text("Einstellungen öffnen") }
                }
                if step == .done {
                    Button("Hilfe öffnen") { openHelp(); tour.end() }
                    Button("Fertig") { tour.end() }.keyboardShortcut(.defaultAction)
                } else {
                    Button(step == .welcome ? "Los geht's" : "Weiter") { tour.next() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}

// MARK: - Placing it on the window

extension View {
    /// Marks a part of the main window as a stop of the introduction: an
    /// outline while the step is on, and the step's popover next to it.
    /// - Parameters:
    ///   - spot: Which stop this view is.
    ///   - tour: The introduction (passed in: list rows read no environment).
    ///   - window: The main window's token (only the owning window presents).
    ///   - arrowEdge: Where the popover's arrow points from.
    ///   - openHelp: Opens the help window.
    func tourSpot(_ spot: TourSpot, tour: TourModel, window: UUID, arrowEdge: Edge = .trailing,
                  openHelp: @escaping () -> Void) -> some View {
        modifier(TourSpotModifier(spot: spot, tour: tour, window: window, arrowEdge: arrowEdge, openHelp: openHelp))
    }
}

/// The outline and popover of one stop.
struct TourSpotModifier: ViewModifier {
    let spot: TourSpot
    let tour: TourModel
    let window: UUID
    let arrowEdge: Edge
    let openHelp: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if tour.isOutlined(spot, in: window) {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                        .allowsHitTesting(false)
                }
            }
            .popover(item: Binding(get: { tour.presentation(at: spot, in: window) },
                                   set: { if $0 == nil { tour.closed(at: spot) } }),
                     arrowEdge: arrowEdge) { shown in
                // The card keeps the step it was shown for, also while it closes.
                TourCard(tour: tour, step: shown.step, openHelp: openHelp)
                    .onAppear { tour.cardAppeared(shown.id) }
            }
    }
}

/// The sheet for the steps without a place (welcome, helper, end).
struct TourSheetModifier: ViewModifier {
    let tour: TourModel
    let window: UUID
    let openHelp: () -> Void

    func body(content: Content) -> some View {
        content.sheet(item: Binding(get: { tour.presentation(at: nil, in: window) },
                                    set: { if $0 == nil { tour.closed(at: nil) } })) { shown in
            TourCard(tour: tour, step: shown.step, openHelp: openHelp)
                .onAppear { tour.cardAppeared(shown.id) }
        }
    }
}
