//
//  Help.swift
//  LaunchKeeper — the help window (Help › LaunchKeeper-Hilfe, ⌘?): topics on
//  the left, the explanation on the right, a search over all of it.
//
//  The content lives in code, not in an Apple Help Book: it is localized
//  through the same string catalog as the rest of the app (German source,
//  English translation), so help and interface can never drift apart in
//  wording, and no help indexer is needed (TJ 2026-09-30).
//

import SwiftUI
import AppKit

// MARK: - Topics

/// The help's chapters, in reading order.
enum HelpTopic: String, CaseIterable, Identifiable, Hashable {
    case overview, inventory, views, actions, helper, queue, watch, shortcuts, commandLine, faq

    var id: String { rawValue }

    /// The chapter title.
    var title: String {
        switch self {
        case .overview: return String(localized: "Überblick")
        case .inventory: return String(localized: "Das Inventar")
        case .views: return String(localized: "Die Ansichten")
        case .actions: return String(localized: "Aktionen und Sicherheit")
        case .helper: return String(localized: "Das Hilfsprogramm")
        case .queue: return String(localized: "Die Warteschlange")
        case .watch: return String(localized: "Beobachtung und Mitteilungen")
        case .shortcuts: return String(localized: "Tastenkürzel")
        case .commandLine: return String(localized: "Kommandozeile")
        case .faq: return String(localized: "Häufige Fragen")
        }
    }

    /// SF Symbol of the chapter.
    var symbol: String {
        switch self {
        case .overview: return "sparkles"
        case .inventory: return "list.bullet"
        case .views: return "rectangle.3.group"
        case .actions: return "checkmark.shield"
        case .helper: return "lock.shield"
        case .queue: return "tray.full"
        case .watch: return "eye"
        case .shortcuts: return "keyboard"
        case .commandLine: return "terminal"
        case .faq: return "questionmark.bubble"
        }
    }

    /// The chapter's content.
    var sections: [HelpSection] { HelpContent.sections(for: self) }

    /// Whether the chapter mentions `query` (title or any text, case- and diacritic-insensitive).
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        // Searched as displayed: without Markdown marks ("**", backticks).
        let haystack = ([title] + sections.flatMap(\.searchText))
            .map { String(markdown($0).characters) }.joined(separator: "\n")
        return haystack.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

/// One headed part of a chapter (identified by its position — the content
/// is rebuilt on every access, a fresh UUID would rebuild every view).
struct HelpSection {
    /// Optional sub-heading.
    var title: String?
    /// The content, in order.
    var blocks: [HelpBlock]

    /// Everything searchable in this section.
    var searchText: [String] {
        [title ?? ""] + blocks.flatMap { block -> [String] in
            switch block {
            case .text(let text), .tip(let text): return [text]
            case .item(_, _, let title, let text): return [title, text]
            case .keys(let rows): return rows.flatMap { [$0.keys, $0.meaning] }
            }
        }
    }
}

/// A piece of help content. Texts may use Markdown (**bold**, `code`).
enum HelpBlock {
    /// A paragraph.
    case text(String)
    /// A symbol with a short title and explanation — for lists of views, badges, steps.
    case item(symbol: String, color: Color, title: String, text: String)
    /// A highlighted hint.
    case tip(String)
    /// A table of keyboard shortcuts.
    case keys([(keys: String, meaning: String)])
}

// MARK: - Routing

/// Which chapter the help window shows; set by the Help menu, the Settings
/// and the introduction before they open the window.
@MainActor
@Observable
final class HelpRouter {
    /// The chapter to show.
    var topic: HelpTopic? = .overview
}

// MARK: - Window

/// The help window: chapters with search on the left, the chapter on the right.
struct HelpView: View {
    /// The `Window` scene's id.
    static let windowID = "help"

    @Environment(HelpRouter.self) private var router
    @State private var search = ""

    var body: some View {
        @Bindable var router = router
        NavigationSplitView {
            List(HelpTopic.allCases.filter { $0.matches(search) }, selection: $router.topic) { topic in
                Label(topic.title, systemImage: topic.symbol).tag(topic)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
            .searchable(text: $search, placement: .sidebar, prompt: "Hilfe durchsuchen")
        } detail: {
            if let topic = router.topic {
                HelpTopicView(topic: topic)
            } else {
                ContentUnavailableView("Kapitel wählen", systemImage: "book",
                                       description: Text("Links steht, was LaunchKeeper kann und wie man damit arbeitet."))
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

/// One chapter, rendered.
struct HelpTopicView: View {
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(topic.title, systemImage: topic.symbol)
                    .font(.largeTitle.bold())
                    .padding(.bottom, 4)
                ForEach(Array(topic.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 10) {
                        if let title = section.title {
                            Text(title).font(.title3.bold())
                        }
                        ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                            HelpBlockView(block: block)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }
}

/// One block of help content.
struct HelpBlockView: View {
    let block: HelpBlock

    var body: some View {
        switch block {
        case .text(let text):
            Text(markdown(text)).fixedSize(horizontal: false, vertical: true)
        case .item(let symbol, let color, let title, let text):
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: symbol).foregroundStyle(color).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(markdown(title)).bold()
                    Text(markdown(text)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        case .tip(let text):
            Label { Text(markdown(text)).fixedSize(horizontal: false, vertical: true) } icon: {
                Image(systemName: "lightbulb").foregroundStyle(.yellow)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        case .keys(let rows):
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        Text(row.keys).font(.body.monospaced()).bold()
                        Text(markdown(row.meaning))
                    }
                }
            }
        }
    }
}

/// Renders an already localized text with its Markdown (bold, code) — an
/// `AttributedString`, not a `LocalizedStringKey`, so it is not looked up twice.
func markdown(_ text: String) -> AttributedString {
    (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
        ?? AttributedString(text)
}

// MARK: - Menu

/// Help menu: the help window and the introduction, instead of the standard
/// "search the help book" item (there is no help book).
struct HelpCommands: Commands {
    let router: HelpRouter
    let tour: TourModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("LaunchKeeper-Hilfe") {
                router.topic = router.topic ?? .overview
                openWindow(id: HelpView.windowID)
            }
            .keyboardShortcut("?", modifiers: .command)
            Button("Einführung zeigen") {
                // Brings a main window to the front first (the introduction points at it).
                tour.start()
            }
        }
    }
}
