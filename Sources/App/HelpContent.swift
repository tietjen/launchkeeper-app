//
//  HelpContent.swift
//  LaunchKeeper — the text of the help window, chapter by chapter.
//
//  Kept apart from the rendering (Help.swift) so it reads like a document.
//  Every string goes through the string catalog (German source, English
//  translation); Markdown marks **bold** words and `code`.
//

import SwiftUI

/// The help's content.
enum HelpContent {
    /// The sections of one chapter.
    static func sections(for topic: HelpTopic) -> [HelpSection] {
        switch topic {
        case .overview: return overview
        case .inventory: return inventory
        case .views: return views
        case .actions: return actions
        case .helper: return helper
        case .queue: return queue
        case .watch: return watch
        case .shortcuts: return shortcuts
        case .commandLine: return commandLine
        case .faq: return faq
        }
    }

    // MARK: Overview

    private static var overview: [HelpSection] {
        [
            HelpSection(blocks: [
                .text(String(localized: "LaunchKeeper zeigt alles, was auf diesem Mac **automatisch startet** — Hintergrunddienste, Anmeldeobjekte, Erweiterungen, geplante Aufgaben, Netzwerkdienste und mehr — und erklärt jeden Eintrag in Klartext: was er ist, woher er kommt und ob er noch gebraucht wird.")),
                .text(String(localized: "Ohne dein Zutun ändert LaunchKeeper nichts. Jede Änderung zeigt vorher ihren Plan, lässt sich rückgängig machen und wird danach geprüft.")),
            ]),
            HelpSection(title: String(localized: "So arbeitest du damit"), blocks: [
                .item(symbol: "1.circle.fill", color: .accentColor, title: String(localized: "Einlesen"),
                      text: String(localized: "Beim Start liest LaunchKeeper das Inventar ein; ⌘R liest neu.")),
                .item(symbol: "2.circle.fill", color: .accentColor, title: String(localized: "Ansehen"),
                      text: String(localized: "Links eine Ansicht wählen, in der Mitte einen Eintrag — rechts steht, was er bedeutet. Symbole markieren, was Aufmerksamkeit verdient.")),
                .item(symbol: "3.circle.fill", color: .accentColor, title: String(localized: "Entscheiden"),
                      text: String(localized: "Unter **Nächste Schritte** stehen nur Aktionen, die für diesen Eintrag sicher möglich sind.")),
                .item(symbol: "4.circle.fill", color: .accentColor, title: String(localized: "Ausführen"),
                      text: String(localized: "Einzeln über **Ausführen…**, oder viele auf einmal: Häkchen setzen, in die **Warteschlange** legen, dort **Alle ausführen**.")),
                .item(symbol: "5.circle.fill", color: .accentColor, title: String(localized: "Zurück, falls nötig"),
                      text: String(localized: "Entferntes liegt in der **Quarantäne** und lässt sich wiederherstellen; Deaktiviertes wieder aktivieren.")),
            ]),
            HelpSection(blocks: [
                .tip(String(localized: "Die Einführung zeigt das Ganze am Fenster selbst: Hilfe › **Einführung zeigen**.")),
            ]),
        ]
    }

    // MARK: Inventory

    private static var inventory: [HelpSection] {
        [
            HelpSection(blocks: [
                .text(String(localized: "**Alle Einträge** listet alles, was LaunchKeeper gefunden hat, sortierbar nach jeder Spalte. **Verwaist** zeigt Einträge, deren Programm oder Datei fehlt — typische Reste deinstallierter Software. Darunter stehen die **Kategorien**, die auf diesem Mac vorkommen.")),
            ]),
            HelpSection(title: String(localized: "Die Symbole in der Liste"), blocks: [
                .item(symbol: "exclamationmark.triangle.fill", color: .orange, title: String(localized: "Verwaist"),
                      text: String(localized: "Die Quelle fehlt — das Programm, auf das der Eintrag zeigt, gibt es nicht mehr.")),
                .item(symbol: "leaf.fill", color: .secondary, title: String(localized: "Rest"),
                      text: String(localized: "Nur noch ein Eintrag in der Hintergrundverwaltung von macOS, ohne Datei dahinter.")),
                .item(symbol: "signature", color: .red, title: String(localized: "Nicht signiert"),
                      text: String(localized: "Das Programm trägt keine Code-Signatur — kein Beweis für Böses, aber ein Grund hinzusehen.")),
                .item(symbol: "eye.fill", color: .yellow, title: String(localized: "Ansehen empfohlen"),
                      text: String(localized: "Etwas ist auffällig, z. B. ein Skript-Interpreter als Programm. Die Detailspalte sagt, was.")),
                .item(symbol: "pause.circle.fill", color: .gray, title: String(localized: "Deaktiviert"),
                      text: String(localized: "Vorhanden, startet aber nicht.")),
                .item(symbol: "play.circle.fill", color: .green, title: String(localized: "Läuft"),
                      text: String(localized: "Gerade aktiv.")),
            ]),
            HelpSection(title: String(localized: "Die Detailspalte"), blocks: [
                .text(String(localized: "Rechts steht zum gewählten Eintrag eine Ampel, ein Satz in Klartext, die wichtigsten Fakten (Zustand, Signierer, Herkunft, zugehörige App) und die **Nächsten Schritte**. **Alle Details anzeigen** oder der **Expertenmodus** (⌥⌘E) zeigen alles, was LaunchKeeper weiß, bis hin zur gründlichen Signaturprüfung und dem Hash zum Nachschlagen bei VirusTotal.")),
            ]),
            HelpSection(title: String(localized: "Die Symbolleiste"), blocks: [
                .item(symbol: "text.below.photo", color: .accentColor, title: String(localized: "Basis- oder Expertenmodus"),
                      text: String(localized: "Kurzfassung oder alle Details in der rechten Spalte (⌥⌘E).")),
                .item(symbol: "apple.logo", color: .secondary, title: String(localized: "Apple ausblenden"),
                      text: String(localized: "Von Apple signierte Systemeinträge aus- oder einblenden. Ausgeblendet bleibt die Liste übersichtlich; ändern lassen sie sich ohnehin nicht.")),
                .item(symbol: "arrow.clockwise", color: .accentColor, title: String(localized: "Neu einlesen"),
                      text: String(localized: "⌘R liest schnell neu. ⇧⌘R fragt auch die Hintergrundverwaltung von macOS frisch ab.")),
            ]),
        ]
    }

    // MARK: Views

    private static var views: [HelpSection] {
        [
            HelpSection(blocks: [
                .text(String(localized: "Unter **Ansichten** in der Seitenleiste ordnen eigene Bereiche das Inventar so, wie man darüber nachdenkt:")),
                .item(symbol: "switch.2", color: .accentColor, title: String(localized: "Hintergrund"),
                      text: String(localized: "Wie in den Systemeinstellungen unter Anmeldeobjekte & Erweiterungen: welche App was im Hintergrund darf — und ob der Schalter von macOS oder eine launchd-Einstellung ihn abschaltet.")),
                .item(symbol: "shippingbox", color: .accentColor, title: String(localized: "Pakete"),
                      text: String(localized: "Mit dem Installationsprogramm installierte Pakete und ihre Dateien. Hier lässt sich ein Paket vollständig deinstallieren oder nur sein Beleg entfernen, wenn die Dateien längst fehlen.")),
                .item(symbol: "leaf", color: .accentColor, title: String(localized: "App-Reste"),
                      text: String(localized: "Einstellungen, Caches und Hintergrunddienste von Apps, die nicht mehr installiert sind — mit Urteil und Begründung, warum etwas als Rest gilt.")),
                .item(symbol: "archivebox", color: .accentColor, title: String(localized: "Quarantäne"),
                      text: String(localized: "Alles, was LaunchKeeper entfernt hat, mit dem Ort, von dem es kam. Von hier aus wiederherstellen; endgültig löschen geht im Terminal (siehe Kommandozeile).")),
                .item(symbol: "eye", color: .accentColor, title: String(localized: "Beobachtung"),
                      text: String(localized: "Was neu hinzukam oder sich geändert hat, seit die Beobachtung läuft (siehe eigenes Kapitel).")),
                .item(symbol: "tray.full", color: .accentColor, title: String(localized: "Warteschlange"),
                      text: String(localized: "Gesammelte Aktionen aus allen Ansichten, zum gemeinsamen Ausführen (siehe eigenes Kapitel).")),
            ]),
        ]
    }

    // MARK: Actions

    private static var actions: [HelpSection] {
        [
            HelpSection(title: String(localized: "Erst der Plan, dann die Ausführung"), blocks: [
                .text(String(localized: "**Ausführen…** an einem nächsten Schritt öffnet ein Blatt mit dem Plan: jeder Schritt in Worten, darunter der Befehl, Hinweise und der Rückweg. Erst ein zweiter Klick führt aus. Danach prüft LaunchKeeper, ob der Eintrag wirklich im erwarteten Zustand ist, und liest neu ein.")),
                .text(String(localized: "Nur Aktionen, die dieselbe Prüfung wie die Kommandozeile bestehen, werden angeboten. Einträge von Apple und alles unter /System bleiben unangetastet.")),
            ]),
            HelpSection(title: String(localized: "Nichts geht verloren"), blocks: [
                .item(symbol: "archivebox", color: .accentColor, title: String(localized: "Entfernen heißt: in die Quarantäne"),
                      text: String(localized: "Dateien werden verschoben, nicht gelöscht, und lassen sich wiederherstellen. Endgültig gelöscht wird nur auf ausdrücklichen Wunsch — im Terminal mit `launchkeeper quarantine purge`.")),
                .item(symbol: "arrow.uturn.backward", color: .accentColor, title: String(localized: "Deaktivieren lässt sich umkehren"),
                      text: String(localized: "Aktivieren stellt den vorherigen Zustand wieder her.")),
                .item(symbol: "doc.text", color: .accentColor, title: String(localized: "Protokoll"),
                      text: String(localized: "Änderungen mit Administratorrechten stehen im Protokoll unter `/Library/Logs/launchkeeper`.")),
            ]),
            HelpSection(title: String(localized: "Wann Touch ID kommt"), blocks: [
                .text(String(localized: "Änderungen an Systemdiensten, an Dateien in /Library, an der Firewall und Paket-Deinstallationen brauchen Administratorrechte. Sie laufen über das **Hilfsprogramm** und fragen **jedes Mal** nach Touch ID oder dem Passwort — eine Aktion, eine Abfrage. Die Warteschlange fragt einmal für den ganzen Lauf.")),
                .text(String(localized: "Änderungen in deinem eigenen Benutzerordner brauchen keine Administratorrechte und fragen nicht.")),
            ]),
        ]
    }

    // MARK: Helper

    private static var helper: [HelpSection] {
        [
            HelpSection(blocks: [
                .text(String(localized: "Das Hilfsprogramm ist ein kleiner Dienst, der mit Administratorrechten läuft. Über ihn ändert LaunchKeeper, was nur ein Administrator ändern darf — und liest die Hintergrundverwaltung von macOS, ohne dass macOS dafür jedes Mal nach Touch ID fragt.")),
                .text(String(localized: "Es nimmt keine Befehle entgegen, nur „was mit welchem Eintrag“, prüft selbst und nimmt nur Verbindungen der echten, signierten LaunchKeeper-App an.")),
            ]),
            HelpSection(title: String(localized: "Einrichten"), blocks: [
                .item(symbol: "1.circle.fill", color: .accentColor, title: String(localized: "Einstellungen öffnen (⌘,)"),
                      text: String(localized: "Unter **Hilfsprogramm für Administratorrechte** auf **Einrichten** klicken — oder bei der ersten Aktion, die es braucht, **Hilfsprogramm einrichten** wählen.")),
                .item(symbol: "2.circle.fill", color: .accentColor, title: String(localized: "In den Systemeinstellungen erlauben"),
                      text: String(localized: "macOS öffnet Allgemein › Anmeldeobjekte & Erweiterungen; dort LaunchKeeper im Hintergrund erlauben.")),
                .item(symbol: "3.circle.fill", color: .accentColor, title: String(localized: "Neu prüfen"),
                      text: String(localized: "Zurück in LaunchKeeper steht dann „eingerichtet und erlaubt“ mit der Version.")),
            ]),
            HelpSection(blocks: [
                .tip(String(localized: "LaunchKeeper richtet das Hilfsprogramm bewusst nicht von selbst ein: wer nur schauen will, bekommt keinen Dienst mit Administratorrechten. Nach einem Update der App wechselt es nach einer ruhigen Minute von selbst auf die neue Version.")),
            ]),
        ]
    }

    // MARK: Queue

    private static var queue: [HelpSection] {
        [
            HelpSection(title: String(localized: "Sammeln"), blocks: [
                .text(String(localized: "In jeder Ansicht haben die Zeilen ein Häkchen. Sobald eines gesetzt ist, zeigt die rechte Spalte die passenden Aktionen mit einem Zähler wie „3 von 4“ (nicht jede Aktion passt zu jedem Eintrag) und legt sie mit einem Klick in die **Warteschlange**. Eingereihte Zeilen tragen statt des Häkchens ein Warteschlangen-Symbol; ein Klick darauf nimmt sie wieder heraus.")),
            ]),
            HelpSection(title: String(localized: "Ausführen"), blocks: [
                .item(symbol: "checklist", color: .accentColor, title: String(localized: "Plan prüfen"),
                      text: String(localized: "Rechnet für alle Einträge in einem Durchgang durch, was geschehen würde — ohne etwas zu ändern. Ein Schloss markiert Schritte mit Administratorrechten.")),
                .item(symbol: "play.fill", color: .accentColor, title: String(localized: "Alle ausführen (↩)"),
                      text: String(localized: "Zuerst alle Schritte mit Administratorrechten — mit **einer** Touch-ID-Abfrage, die die Anzahl nennt —, danach die übrigen. Ein Fehler hält die anderen nicht an; **Anhalten** stoppt nach dem laufenden Eintrag.")),
                .item(symbol: "arrow.uturn.backward", color: .accentColor, title: String(localized: "Rückwege hinzufügen"),
                      text: String(localized: "Legt für alles, was in dieser Sitzung erledigt wurde, den Weg zurück in die Warteschlange.")),
                .text(String(localized: "Die Warteschlange bleibt über einen Neustart der App erhalten.")),
            ]),
            HelpSection(title: String(localized: "Von Hand"), blocks: [
                .text(String(localized: "Manches verwaltet macOS allein — Anmeldeobjekte, Systemerweiterungen, Profile, Datenschutz-Freigaben. Solche Einträge stehen im Abschnitt **Von Hand** mit einer Anleitung und einem Knopf, der die richtige Stelle der Systemeinstellungen öffnet. Nach **Jetzt prüfen** hakt LaunchKeeper ab, was sich erledigt hat.")),
                .tip(String(localized: "Netzwerkdienste hakst du selbst ab: sie verschwinden auch, wenn das Programm nur beendet wurde.")),
            ]),
        ]
    }

    // MARK: Watch

    private static var watch: [HelpSection] {
        [
            HelpSection(blocks: [
                .text(String(localized: "Die Beobachtung meldet, wenn etwas Neues automatisch starten will oder sich ein Eintrag ändert. Einschalten im Bereich **Beobachtung** oder in den Einstellungen.")),
                .item(symbol: "bolt", color: .accentColor, title: String(localized: "Sofort"),
                      text: String(localized: "Sobald eine Autostart-Stelle geschrieben wird, liest LaunchKeeper nach wenigen Sekunden neu ein und vergleicht.")),
                .item(symbol: "clock", color: .accentColor, title: String(localized: "Regelmäßig"),
                      text: String(localized: "Alle zehn Minuten ein vollständiger Vergleich. Ohne Hilfsprogramm fragt LaunchKeeper die Hintergrundverwaltung dabei höchstens alle sechs Stunden frisch ab, weil macOS dafür Touch ID verlangt.")),
                .item(symbol: "person.fill.checkmark", color: .secondary, title: String(localized: "Eigene Änderungen"),
                      text: String(localized: "Was LaunchKeeper selbst geändert hat, steht mit „durch LaunchKeeper“ in der Liste und wird nicht gemeldet. Entfernungen werden nur aufgelistet.")),
                .item(symbol: "eye", color: .secondary, title: String(localized: "Menüleiste und Anmeldung"),
                      text: String(localized: "Solange die Beobachtung läuft, steht ein Auge in der Menüleiste. Mit „Bei der Anmeldung starten“ beobachtet LaunchKeeper auch mit geschlossenem Fenster.")),
            ]),
            HelpSection(title: String(localized: "Mitteilungen"), blocks: [
                .text(String(localized: "Ein Klick auf eine Mitteilung öffnet den Eintrag. In den Einstellungen zeigt **Mitteilungen laut macOS**, was macOS erlaubt; **Test-Mitteilung senden** prüft den Weg, und jeder Eintrag der Beobachtung sagt unter **Mitteilung**, was aus seiner Mitteilung wurde.")),
                .tip(String(localized: "Kein Banner? Beim Teilen oder Spiegeln des Bildschirms — etwa per Bildschirmfreigabe — und bei aktivem Fokus zeigt macOS keine Banner. Einstellung: Systemeinstellungen › Mitteilungen › „Beim Spiegeln oder Teilen des Bildschirms“.")),
            ]),
        ]
    }

    // MARK: Shortcuts

    private static var shortcuts: [HelpSection] {
        [
            HelpSection(blocks: [
                .keys([
                    (keys: "⌘R", meaning: String(localized: "Neu einlesen (schnell)")),
                    (keys: "⇧⌘R", meaning: String(localized: "Vollständig neu einlesen, auch die Hintergrundverwaltung")),
                    (keys: "⌥⌘E", meaning: String(localized: "Basis- oder Expertenmodus")),
                    (keys: "⌘,", meaning: String(localized: "Einstellungen: Hilfsprogramm, Beobachtung, Updates, Einführung")),
                    (keys: "⌘?", meaning: String(localized: "Diese Hilfe")),
                    (keys: "↩", meaning: String(localized: "In der Warteschlange: Alle ausführen")),
                ]),
            ]),
        ]
    }

    // MARK: Command line

    private static var commandLine: [HelpSection] {
        [
            HelpSection(blocks: [
                .text(String(localized: "Unter der App arbeitet das Kommandozeilenwerkzeug **launchkeeper** mit denselben Prüfungen. Installation mit Homebrew:")),
                .text("`brew trust tietjen/tap`"),
                .text("`brew install tietjen/tap/launchkeeper`"),
                .text(String(localized: "Die erste Zeile braucht es einmal ab Homebrew 7, das fremden Taps sonst nicht vertraut.")),
                .keys([
                    (keys: "launchkeeper list", meaning: String(localized: "Das Inventar als Tabelle")),
                    (keys: "launchkeeper inspect <id>", meaning: String(localized: "Alles zu einem Eintrag")),
                    (keys: "launchkeeper disable|enable|remove", meaning: String(localized: "Ändern — ohne `--apply` nur der Plan")),
                    (keys: "launchkeeper quarantine list|restore", meaning: String(localized: "Die Quarantäne")),
                    (keys: "launchkeeper quarantine purge <name>", meaning: String(localized: "Endgültig löschen — ohne `--apply` nur der Plan")),
                    (keys: "launchkeeper watch", meaning: String(localized: "Beobachten im Terminal")),
                    (keys: "launchkeeper doctor", meaning: String(localized: "Selbsttest: welche Quellen antworten")),
                ]),
                .tip(String(localized: "App und Kommandozeile sehen dieselbe Quarantäne. Was das Hilfsprogramm dort abgelegt hat, liegt in einem Ordner, der root gehört — die Kommandozeile ändert es nur mit `sudo`, also nach deinem Passwort.")),
            ]),
        ]
    }

    // MARK: FAQ

    private static var faq: [HelpSection] {
        [
            HelpSection(title: String(localized: "Warum dauert das erste Einlesen manchmal Minuten?"), blocks: [
                .text(String(localized: "Die Hintergrundverwaltung von macOS prüft nach längerer Ruhe beim ersten Abfragen alle registrierten Programme neu. Danach geht es in Sekunden.")),
            ]),
            HelpSection(title: String(localized: "Warum kann LaunchKeeper ein Anmeldeobjekt nicht selbst abschalten?"), blocks: [
                .text(String(localized: "Diesen Schalter verwaltet macOS allein und lässt keine andere App daran. LaunchKeeper zeigt den Weg und öffnet die richtige Stelle der Systemeinstellungen (Abschnitt **Von Hand** in der Warteschlange).")),
            ]),
            HelpSection(title: String(localized: "Sieht LaunchKeeper die Einträge anderer Benutzer?"), blocks: [
                .text(String(localized: "Nein. Das Hilfsprogramm gibt aus der Hintergrundverwaltung nur die systemweiten Einträge und deine eigenen zurück.")),
            ]),
            HelpSection(title: String(localized: "Sendet LaunchKeeper Daten ins Internet?"), blocks: [
                .text(String(localized: "Nein. Nur die Suche nach Updates fragt bei GitHub nach einer neuen Version; jedes Update ist signiert und wird vor der Installation geprüft. Den Hash für VirusTotal kopiert LaunchKeeper nur in die Zwischenablage.")),
            ]),
            HelpSection(title: String(localized: "Was heißt „Verwaist“?"), blocks: [
                .text(String(localized: "Der Eintrag verweist auf ein Programm oder eine Datei, die es nicht mehr gibt — meist ein Rest einer deinstallierten App. Er startet nichts Brauchbares mehr; die Detailspalte sagt, was fehlt, und bietet meist an, ihn in die Quarantäne zu verschieben — von wo er sich wiederherstellen lässt.")),
            ]),
        ]
    }
}
