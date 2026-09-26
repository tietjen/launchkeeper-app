//
//  EntrySummary.swift
//  AppCore — the basic-mode view of one entry: what it is in plain words,
//  a traffic-light verdict, the key facts and the sensible next steps.
//
//  Expert mode shows everything the scan knows; basic mode shows only what
//  a user needs to decide. The rules for that live here, UI-free and
//  tested, so the view only renders.
//

import Foundation
import LaunchKeeperKit

/// The condensed, plain-language description of one inventory entry.
public struct EntrySummary: Equatable, Sendable {

    /// Traffic-light verdict for an entry.
    public enum Verdict: Equatable, Sendable {
        /// Nothing stands out.
        case ok
        /// A review hint (unsigned, temp path, shell interpreter as a service …) — never a malware verdict.
        case review(String)
        /// The entry's source is provably gone.
        case orphan(String)
        /// Only a Background Task Management record is left; nothing to do but wait.
        case leftover

        /// Severity for sorting and colour: 0 ok, 1 leftover, 2 review, 3 orphan.
        public var severity: Int {
            switch self {
            case .ok: return 0
            case .leftover: return 1
            case .review: return 2
            case .orphan: return 3
            }
        }
    }

    /// One suggested next step.
    public struct NextStep: Equatable, Sendable, Identifiable {
        /// What the step does.
        public enum Kind: Equatable, Sendable {
            /// A launchkeeper operation ("disable", "enable", "remove").
            case operation(String)
            /// Show a file in the Finder.
            case reveal(String)
            /// Nothing launchkeeper can do — the text says where the switch lives.
            case info
            /// Compute the SHA-256 of this program file and copy it for a VirusTotal search.
            case copyHash(String)
            /// Open a URL (e.g. a System Settings pane).
            case openURL(String)
            /// Jump to an inventory entry, by display id of the same scan.
            case showEntry(String)
        }

        /// Stable id for SwiftUI lists.
        public var id: String { title }
        /// Button or row title, e.g. "Deaktivieren (umkehrbar)".
        public var title: String
        /// One sentence: what happens, and how to undo it.
        public var detail: String
        /// What kind of step this is.
        public var kind: Kind
        /// `true` when the step needs administrator rights (Touch ID once the helper exists).
        public var requiresAdmin: Bool
        /// The equivalent CLI command, dry-run form — offered for copying until
        /// the app runs actions itself.
        public var command: String?
        /// What "Ausführen…" asks the engines to do (Phase 4a); `nil` for steps that are not actions.
        public var action: ActionRequest?

        /// Creates a step.
        public init(title: String, detail: String, kind: Kind, requiresAdmin: Bool, command: String?,
                    action: ActionRequest? = nil) {
            self.title = title; self.detail = detail; self.kind = kind
            self.requiresAdmin = requiresAdmin; self.command = command; self.action = action
        }
    }

    /// Plain-language headline, e.g. "Startet beim Anmelden".
    public var headline: String
    /// Short facts under the headline: state, signature, origin, app.
    public var facts: [String]
    /// The traffic light.
    public var verdict: Verdict
    /// Suggested next steps, most useful first.
    public var nextSteps: [NextStep]

    /// Creates a summary (the view summaries build theirs with it).
    public init(headline: String, facts: [String], verdict: Verdict, nextSteps: [NextStep]) {
        self.headline = headline; self.facts = facts; self.verdict = verdict; self.nextSteps = nextSteps
    }

    // MARK: - Building

    /// Builds the summary for one entry.
    ///
    /// Next steps come from the entry's control matrix (`BackgroundItem.control`),
    /// which the scan computes with the **same gate** the mutating commands
    /// consult — so the app never offers an action the gate would refuse.
    /// - Parameter item: A scanned entry.
    /// - Returns: The basic-mode summary.
    public static func build(for item: BackgroundItem) -> EntrySummary {
        EntrySummary(headline: headline(for: item), facts: facts(for: item), verdict: verdict(for: item),
                     nextSteps: nextSteps(for: item, hashTarget: VirusTotalHash.target(of: item)))
    }

    /// What the entry is and when it runs, in one phrase.
    static func headline(for item: BackgroundItem) -> String {
        let runsAtLoad = item.metadata["schedule"] == nil
        switch item.type {
        case .launchAgentUser, .launchAgentSystem:
            return runsAtLoad ? String(localized: "Startet beim Anmelden (LaunchAgent)")
                              : String(localized: "Startet zeitgesteuert (LaunchAgent)")
        case .launchDaemon:
            return runsAtLoad ? String(localized: "Systemdienst, startet mit dem Mac (LaunchDaemon)")
                              : String(localized: "Systemdienst, zeitgesteuert (LaunchDaemon)")
        case .loginItem: return String(localized: "Anmeldeobjekt — öffnet beim Anmelden")
        case .smappservice: return String(localized: "Hintergrunddienst einer App")
        case .btmEntry: return String(localized: "Eintrag der Hintergrundaufgaben-Verwaltung")
        case .appExtension: return String(localized: "App-Erweiterung — wird von anderen Apps geladen")
        case .systemExtension: return String(localized: "Systemerweiterung (Netzwerk, Sicherheit, Treiber)")
        case .kernelExtension: return String(localized: "Kernel-Erweiterung (Treiber)")
        case .privilegedHelper: return String(localized: "Hilfsprogramm mit Administratorrechten")
        case .cronJob: return String(localized: "Geplante Aufgabe (cron)")
        case .atJob: return String(localized: "Einmalige geplante Aufgabe (at)")
        case .periodicScript: return String(localized: "Wartungsskript (periodic)")
        case .powerEvent: return String(localized: "Geplantes Aufwachen oder Einschalten")
        case .loginHook: return String(localized: "Anmelde-/Abmelde-Skript (veraltete Methode)")
        case .startupItem: return String(localized: "Veraltetes Startobjekt — wird nicht mehr ausgeführt")
        case .rcScript, .emondRule: return String(localized: "Veraltete Startdatei")
        case .plugin: return String(localized: "Plug-in — wird von macOS oder Apps geladen")
        case .shellProfile: return String(localized: "Startdatei des Terminals (Shell)")
        case .pathEntry: return String(localized: "Ergänzt den Suchpfad für Programme")
        case .listener: return String(localized: "Programm, das Netzwerkverbindungen annimmt")
        case .firewallRule: return String(localized: "Regel der Firewall")
        case .helper, .script, .unknown: return String(localized: "Hintergrundkomponente")
        }
    }

    /// What an interpreter or launcher entry really runs, in plain words —
    /// e.g. "führt aus: Skript /usr/local/bin/sync.sh (über bash)".
    ///
    /// Reads the kit's `runs-kind`/`runs-target` metadata (LaunchKeeperKit
    /// 0.9.4, `EffectiveProgram`). `nil` when the executable is the program.
    /// - Parameter item: The entry.
    public static func runsFact(for item: BackgroundItem) -> String? {
        guard let kind = item.metadata["runs-kind"].flatMap(EffectiveProgram.Kind.init(rawValue:)) else { return nil }
        let target = item.metadata["runs-target"] ?? ""
        let via = item.executable.map { ($0 as NSString).lastPathComponent } ?? "?"
        switch kind {
        case .script: return String(localized: "führt aus: Skript \(target) (über \(via))")
        case .module: return String(localized: "führt aus: Modul \(target) (über \(via))")
        case .binary: return String(localized: "führt aus: Programm \(target) (über \(via))")
        case .app: return String(localized: "öffnet: \(target) (über \(via))")
        case .inline: return String(localized: "führt eine Befehlszeile aus (über \(via)): \(oneLine(target))")
        case .none: return String(localized: "startet \(via) ohne erkennbares Skript")
        }
    }

    /// Inline code as one readable line of at most 80 characters.
    static func oneLine(_ code: String) -> String {
        let flat = code.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return flat.count > 80 ? String(flat.prefix(77)) + "…" : flat
    }

    /// State, signature, origin and app as short facts.
    static func facts(for item: BackgroundItem) -> [String] {
        var out: [String] = []
        // What really runs comes first when the executable is only an interpreter.
        if let runs = runsFact(for: item) { out.append(runs) }
        // State first: that is what users look for ("does this run?").
        if item.running { out.append(String(localized: "läuft gerade")) }
        else if item.loaded { out.append(String(localized: "geladen")) }
        if !item.enabled { out.append(String(localized: "ausgeschaltet")) }
        if let schedule = item.metadata["schedule"] { out.append(schedule) }

        if ListFilter.isAppleInternal(item) {
            out.append(String(localized: "Teil von macOS"))
        } else if let status = item.codeSignatureStatus {
            if status.contains("unsigned") || status.contains("not signed") {
                out.append(String(localized: "nicht signiert"))
            } else if let team = item.teamIdentifier ?? item.metadata["signature-team"] {
                let who = item.developer ?? item.metadata["signature-authority"].map(Self.authorityName) ?? team
                out.append(String(localized: "signiert von \(who)"))
            } else {
                out.append(status)
            }
        }

        if let provenance = item.provenance {
            switch provenance.kind {
            case .receipt: out.append(String(localized: "aus Paket \(provenance.packageIdentifier ?? "?")"))
            case .appStore: out.append(String(localized: "aus dem App Store"))
            case .homebrew: out.append(String(localized: "über Homebrew installiert"))
            case .manual: out.append(String(localized: "App ohne Installationsbeleg"))
            case .apple, .unknown: break
            }
        }
        if let app = item.parentApplication { out.append(String(localized: "gehört zu \(app)")) }
        return out
    }

    /// "Developer ID Application: Vendor Inc (TEAM)" → "Vendor Inc".
    static func authorityName(_ authority: String) -> String {
        var name = authority
        if let colon = name.range(of: ": ") { name = String(name[colon.upperBound...]) }
        if let paren = name.range(of: " (", options: .backwards) { name = String(name[..<paren.lowerBound]) }
        return name
    }

    /// Orphan beats review beats leftover-free "ok"; a leftover is its own, harmless state.
    static func verdict(for item: BackgroundItem) -> Verdict {
        if item.metadata["btm-leftover"] == "true" { return .leftover }
        if item.orphaned { return .orphan(item.orphanReasons.first ?? String(localized: "Quelle fehlt")) }
        if let flag = item.riskFlags.first { return .review(flag) }
        if let status = item.codeSignatureStatus, status.contains("unsigned") || status.contains("not signed"),
           !ListFilter.isAppleInternal(item) {
            return .review(String(localized: "nicht signiert — Herkunft prüfen"))
        }
        return .ok
    }

    /// Next steps from the control matrix, plus the VirusTotal hash and "show in Finder".
    /// - Parameters:
    ///   - item: The entry.
    ///   - hashTarget: The program file worth a VirusTotal lookup (`VirusTotalHash.target`), if any.
    static func nextSteps(for item: BackgroundItem, hashTarget: String? = nil) -> [NextStep] {
        var steps: [NextStep] = []
        let control = item.control
        let actions = Set(control?.actions ?? [])
        let admin = requiresAdmin(item)
        let address = cliAddress(item)

        // Removal first when the entry is a provable leftover: that is the
        // step that actually cleans up. Disabling comes second.
        if actions.contains("remove") {
            steps.append(NextStep(
                title: String(localized: "Entfernen"),
                detail: control?.mechanism == .quarantine
                    ? String(localized: "Verschiebt den Rest in die Quarantäne — jederzeit wiederherstellbar.")
                    : String(localized: "Löscht die verwaiste Startdatei; vorher wird eine Sicherung angelegt."),
                kind: .operation("remove"), requiresAdmin: admin,
                command: "launchkeeper remove \(address)",
                action: .remediation(operation: "remove", key: item.key)))
        }
        if actions.contains("disable"), item.enabled {
            steps.append(NextStep(
                title: String(localized: "Deaktivieren (umkehrbar)"),
                detail: String(localized: "Verhindert den automatischen Start; Aktivieren macht es rückgängig."),
                kind: .operation("disable"), requiresAdmin: admin,
                command: "launchkeeper disable \(address)",
                action: .remediation(operation: "disable", key: item.key)))
        }
        if actions.contains("enable"), !item.enabled {
            steps.append(NextStep(
                title: String(localized: "Wieder aktivieren"),
                detail: String(localized: "Hebt die Deaktivierung auf."),
                kind: .operation("enable"), requiresAdmin: admin,
                command: "launchkeeper enable \(address)",
                action: .remediation(operation: "enable", key: item.key)))
        }
        if let hashTarget {
            steps.append(NextStep(
                title: String(localized: "Hash für VirusTotal kopieren"),
                detail: String(localized: "Legt den SHA-256 von \((hashTarget as NSString).lastPathComponent) in die Zwischenablage — auf virustotal.com in die Suche einfügen. Die Datei selbst verlässt den Mac nicht."),
                kind: .copyHash(hashTarget), requiresAdmin: false, command: nil))
        }
        if let path = item.path ?? item.executable, path.hasPrefix("/") {
            steps.append(NextStep(title: String(localized: "Im Finder zeigen"),
                                  detail: path, kind: .reveal(path), requiresAdmin: false, command: nil))
        }
        // Nothing switchable: say where the switch is instead of offering nothing.
        if actions.isEmpty, let reason = control?.reason {
            steps.append(NextStep(title: String(localized: "Hier nicht steuerbar"), detail: reason, kind: .info,
                                  requiresAdmin: false, command: nil))
        }
        return steps
    }

    /// Whether acting on the entry needs administrator rights.
    ///
    /// Mirrors the engine's sudo decisions: system-domain launchd jobs,
    /// files in root-owned locations, system loginwindow hooks, the
    /// firewall and quarantined leftovers outside the home folder.
    static func requiresAdmin(_ item: BackgroundItem) -> Bool {
        switch item.controlMechanism {
        case .pluginkit, .cron: return false
        case .firewall: return true
        case .loginHook: return item.domain == .system
        case .quarantine: return !(item.path ?? "").hasPrefix(NSHomeDirectory() + "/")
        case .launchd:
            if item.launchdDomainKind == .system { return true }
            return (item.path ?? "").hasPrefix("/Library/")
        case nil: return false
        }
    }

    /// The address the CLI resolves reliably: label, pluginkit id or key —
    /// never the positional display id — shell-quoted when needed.
    static func cliAddress(_ item: BackgroundItem) -> String {
        quote(item.label ?? item.metadata["ext-identifier"] ?? item.key)
    }

    /// Shell-quotes a CLI argument unless it is plainly safe.
    /// - Parameter raw: The argument.
    /// - Returns: The argument, single-quoted when it contains anything but `[A-Za-z0-9-_./:@%+=]`.
    static func quote(_ raw: String) -> String {
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./:@%+="))
        if !raw.isEmpty, raw.unicodeScalars.allSatisfy({ safe.contains($0) }) { return raw }
        return "'" + raw.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
