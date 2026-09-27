//
//  ManualGuide.swift
//  AppCore — "Von Hand" (Phase 10, step 4): how to take care of an entry
//  that neither the app nor the helper may change.
//
//  macOS keeps some switches to itself — Background Task Management login
//  items, system extensions, configuration profiles, privacy grants, kernel
//  extensions. LaunchKeeper does not write there on purpose; the queue lists
//  such entries with the one place where the user can act, and ticks them
//  off by itself once a new scan shows the change.
//

import Foundation
import LaunchKeeperKit

/// What to do by hand for one entry, and where.
public struct ManualGuide: Equatable, Sendable {
    /// One or two sentences in the user's language.
    public var text: String
    /// Button title for `url`.
    public var linkTitle: String?
    /// Where to do it (a System Settings pane), if there is such a place.
    public var url: String?

    /// System Settings panes used below.
    static let loginItems = "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
    static let profiles = "x-apple.systempreferences:com.apple.Profiles-Settings.extension"
    static let privacy = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
    static let network = "x-apple.systempreferences:com.apple.Network-Settings.extension"

    /// The guide for an entry, from its category and type.
    /// - Parameter item: The inventory entry.
    /// - Returns: What to do and where.
    public static func `for`(_ item: BackgroundItem) -> ManualGuide {
        let settings = String(localized: "Systemeinstellungen öffnen")
        switch (item.category, item.type) {
        case (_, .kernelExtension):
            return ManualGuide(text: String(localized: "Kernel-Erweiterungen entfernt nur das Deinstallationsprogramm des Herstellers (oder dessen App). Danach neu starten."),
                               linkTitle: nil, url: nil)
        case (.systemExtensions, _), (_, .systemExtension):
            return ManualGuide(text: String(localized: "Systemerweiterungen entfernt man, indem man die zugehörige App löscht oder in ihr die Erweiterung abschaltet; ein-/ausschalten unter Systemeinstellungen › Allgemein › Anmeldeobjekte & Erweiterungen › Erweiterungen (macOS 14: Datenschutz & Sicherheit › Erweiterungen)."),
                               linkTitle: settings, url: loginItems)
        case (.profiles, _):
            return ManualGuide(text: String(localized: "Konfigurationsprofile entfernen: Systemeinstellungen › Allgemein › Geräteverwaltung. Von einer Verwaltung (MDM) installierte Profile lassen sich dort nicht entfernen."),
                               linkTitle: settings, url: profiles)
        case (.privacy, _):
            return ManualGuide(text: String(localized: "Freigaben widerrufen: Systemeinstellungen › Datenschutz & Sicherheit, dort in der passenden Rubrik (z. B. Bedienungshilfen, Festplattenvollzugriff) den Schalter ausschalten."),
                               linkTitle: settings, url: privacy)
        case (.network, .listener):
            return ManualGuide(text: String(localized: "Ein Programm, das Verbindungen annimmt, lässt sich hier nur beenden oder in seinen eigenen Einstellungen abschalten; eingehende Verbindungen sperrt die Firewall (Systemeinstellungen › Netzwerk › Firewall)."),
                               linkTitle: settings, url: network)
        case (.loginItems, _), (_, .loginItem), (_, .smappservice), (_, .btmEntry):
            return ManualGuide(text: String(localized: "Diesen Schalter verwaltet macOS selbst: Systemeinstellungen › Allgemein › Anmeldeobjekte & Erweiterungen, bei der App oder dem Entwickler ausschalten — oder die App löschen."),
                               linkTitle: settings, url: loginItems)
        default:
            let reason = item.control?.reason ?? String(localized: "LaunchKeeper kann diesen Eintrag nicht ändern.")
            return ManualGuide(text: String(localized: "Von Hand: \(reason)"), linkTitle: nil, url: nil)
        }
    }
}
