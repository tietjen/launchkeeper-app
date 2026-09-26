//
//  ViewSummaries.swift
//  AppCore — basic-mode summaries for the dedicated views: a package
//  (receipt), an app's leftovers, a row of the background view.
//
//  Same shape as `EntrySummary`: plain-language headline, verdict, facts and
//  next steps — so every view answers "what is this, and what can I do?".
//

import Foundation
import LaunchKeeperKit

// MARK: - Packages

/// What an installer package is and what can be done with it.
public enum PackageSummary {
    /// Builds the summary for one receipt row.
    /// - Parameter row: A row of the packages view.
    /// - Returns: Headline, verdict, facts and next steps.
    public static func build(for row: ReceiptsView.Row) -> EntrySummary {
        let present = row.fileCount - row.missingFiles
        let headline: String
        let verdict: EntrySummary.Verdict
        if row.fileCount > 0, row.missingFiles == row.fileCount {
            // Typical after an app was dragged to the Trash: the receipt stays forever.
            headline = String(localized: "Installationsbeleg ohne Dateien — das Programm wurde entfernt, der Beleg blieb")
            verdict = .leftover
        } else if row.missingFiles > 0 {
            headline = String(localized: "Teilweise noch installiert")
            verdict = .review(String(localized: "\(row.missingFiles) von \(row.fileCount) Dateien fehlen"))
        } else {
            headline = String(localized: "Installiertes Paket")
            verdict = .ok
        }
        var facts: [String] = []
        if let version = row.version { facts.append(String(localized: "Version \(version)")) }
        if let installed = row.installedAt { facts.append(String(localized: "installiert am \(String(installed.prefix(10)))")) }
        facts.append(String(localized: "\(present) von \(row.fileCount) Dateien vorhanden"))
        if !row.items.isEmpty { facts.append(String(localized: "startet: \(row.items.joined(separator: ", "))")) }

        var steps: [EntrySummary.NextStep] = []
        if present > 0 {
            steps.append(EntrySummary.NextStep(
                title: String(localized: "Deinstallieren (Vorschau)"),
                detail: String(localized: "Nimmt nur Dateien, die noch unverändert vom Paket stammen, und verschiebt sie in die Quarantäne — wiederherstellbar. Veränderte und geteilte Dateien bleiben."),
                kind: .operation("uninstall"), requiresAdmin: true,
                command: "launchkeeper uninstall \(EntrySummary.quote(row.id))"))
        } else {
            steps.append(EntrySummary.NextStep(
                title: String(localized: "Beleg entfernen"),
                detail: String(localized: "Vergisst den Installationsbeleg; eine Kopie bleibt in der Quarantäne."),
                kind: .operation("uninstall"), requiresAdmin: true,
                command: "launchkeeper uninstall \(EntrySummary.quote(row.id))"))
        }
        return EntrySummary(headline: headline, facts: facts, verdict: verdict, nextSteps: steps)
    }
}

// MARK: - App leftovers

/// What a gone app left behind and what can be done with it.
public enum LeftoverSummary {
    /// Builds the summary for one leftover candidate.
    /// - Parameter candidate: A checked bundle id with its paths and verdict.
    /// - Returns: Headline, verdict, facts and next steps.
    public static func build(for candidate: AppLeftoverCandidate) -> EntrySummary {
        let size = ByteCountFormatter.string(fromByteCount: Int64(candidate.totalBytes), countStyle: .file)
        var facts = [String(localized: "\(candidate.paths.count) Ordner/Dateien, \(size)")]
        var steps: [EntrySummary.NextStep] = []
        let headline: String
        let verdict: EntrySummary.Verdict
        switch candidate.presence {
        case .gone(let proofs):
            headline = String(localized: "Reste einer gelöschten App")
            verdict = .orphan(String(localized: "die App ist nicht mehr installiert"))
            facts.append(proofs.joined(separator: " · "))
            facts.append(String(localized: "war eine App: \(candidate.appEvidence.joined(separator: ", "))"))
            steps.append(EntrySummary.NextStep(
                title: String(localized: "In die Quarantäne verschieben"),
                detail: String(localized: "Räumt Einstellungen, Caches und App-Daten weg — wiederherstellbar, falls die App zurückkommt."),
                kind: .operation("leftovers"), requiresAdmin: candidate.paths.contains(where: \.needsRoot),
                command: "launchkeeper leftovers \(EntrySummary.quote(candidate.bundleIdentifier))"))
        case .present(let why):
            headline = String(localized: "Daten einer installierten App")
            verdict = .ok
            facts.append(why)
        case .unknown(let why):
            headline = String(localized: "Nicht sicher zuzuordnen")
            verdict = .review(why)
        case .noAppEvidence:
            headline = String(localized: "Daten eines Werkzeugs oder Frameworks")
            verdict = .ok
            facts.append(String(localized: "keine App gefunden — aber nichts zeigt, dass es je eine App war"))
        }
        for path in candidate.paths {
            steps.append(EntrySummary.NextStep(title: String(localized: "\(path.kind) im Finder zeigen"),
                                               detail: path.path, kind: .reveal(path.path),
                                               requiresAdmin: false, command: nil))
        }
        return EntrySummary(headline: headline, facts: facts, verdict: verdict, nextSteps: steps)
    }
}

// MARK: - Background rows

/// One app or developer row of System Settings › Login Items & Extensions.
public enum BackgroundSummary {
    /// Deep link to System Settings › General › Login Items & Extensions.
    public static let settingsURL = "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"

    /// Builds the summary for one background row.
    /// - Parameter row: A row of the background view.
    /// - Returns: Headline, verdict, facts and next steps (open System
    ///   Settings, jump to each component's inventory entry).
    public static func build(for row: BackgroundView.Row) -> EntrySummary {
        let headline: String
        switch row.toggle {
        case .on: headline = String(localized: "Darf im Hintergrund laufen")
        case .off: headline = String(localized: "Im Hintergrund ausgeschaltet")
        case .mixed: headline = String(localized: "Teilweise eingeschaltet")
        case .appLevel: headline = String(localized: "Die App selbst ist als Hintergrundobjekt registriert")
        case .none: headline = String(localized: "Nichts registriert")
        }
        let overridden = row.components.filter(\.launchdDisabled)
        let verdict: EntrySummary.Verdict
        if row.components.contains(where: { $0.orphaned && !$0.leftover }) {
            verdict = .orphan(String(localized: "mindestens eine Komponente hat keine Quelle mehr"))
        } else if !overridden.isEmpty {
            verdict = .review(String(localized: "\(overridden.count) Komponente(n) per launchd deaktiviert — in den Systemeinstellungen unsichtbar"))
        } else {
            verdict = .ok
        }
        var facts = [row.kind == .developer ? String(localized: "Entwickler-Eintrag") : String(localized: "App-Eintrag")]
        if let team = row.teamIdentifier { facts.append(String(localized: "Team \(team)")) }
        facts.append(String(localized: "\(row.components.count) Komponente(n)"))

        var steps = [EntrySummary.NextStep(
            title: String(localized: "In den Systemeinstellungen umschalten"),
            detail: String(localized: "Den Schalter dieser Zeile verwaltet macOS selbst — LaunchKeeper schreibt dort nicht hinein."),
            kind: .openURL(settingsURL), requiresAdmin: false, command: nil)]
        for component in row.components {
            steps.append(EntrySummary.NextStep(
                title: String(localized: "„\(component.name)“ im Inventar zeigen"),
                detail: String(localized: "Dort lässt sich die Komponente einzeln steuern."),
                kind: .showEntry(component.id), requiresAdmin: false, command: nil))
        }
        return EntrySummary(headline: headline, facts: facts, verdict: verdict, nextSteps: steps)
    }
}
