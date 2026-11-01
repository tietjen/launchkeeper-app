# Funktionsreferenz

Jede Funktion nach Bereich: **wo** sie steckt, **was** sie tut, **wo ihre Grenze** ist. Zum
Nachschlagen — zum Lernen ist das [Handbuch](handbuch/) da, zum Verstehen
[Wie LaunchKeeper gebaut ist](architektur.md).

Zwei Begriffe kommen oft vor: Die **Hintergrundaufgaben** (Background Task Management, kurz BTM)
sind die Liste, in der macOS Anmeldeobjekte und Hintergrunddienste von Apps führt. Der **Abzug**
ist die von `sfltool dumpbtm` gelesene Liste der Hintergrundaufgaben.

- [Fenster und Ansichten](#fenster-und-ansichten)
- [Inventar und Detailspalte](#inventar-und-detailspalte)
- [Aktionen](#aktionen)
- [Warteschlange](#warteschlange)
- [Beobachtung und Mitteilungen](#beobachtung-und-mitteilungen)
- [Hilfsprogramm](#hilfsprogramm)
- [Quarantäne](#quarantäne)
- [Einstellungen](#einstellungen)
- [Hilfe und Einführung](#hilfe-und-einführung)
- [Tastenkürzel](#tastenkürzel)
- [Grenzen und feste Werte](#grenzen-und-feste-werte)
- [Was LaunchKeeper nicht tut](#was-launchkeeper-nicht-tut)

## Fenster und Ansichten

| Was | Wo | Grenze |
|---|---|---|
| **Hauptfenster** | — | Es gibt **ein** Hauptfenster (seit 1.1.0). Öffnen aus der Menüleiste, einer Mitteilung oder dem Hilfe-Menü holt es nach vorne, auch aus dem Dock. Mindestgröße 980 × 560. |
| **Seitenleiste** | links | Abschnitte *Inventar* (Alle Einträge, Verwaist), *Kategorien*, *Ansichten* (Hintergrund, Pakete, App-Reste, Quarantäne, Beobachtung) und *Stapelverarbeitung* (Warteschlange). Die Zahlen folgen „Apple ausblenden“, nicht der Suche — sie bleiben beim Tippen stehen. |
| **Kategorien** | Seitenleiste | nur Kategorien mit Einträgen: Hintergrunddienste (launchd), Anmeldeobjekte & Hintergrund, App-Erweiterungen, System- und Kernel-Erweiterungen, Privilegierte Hilfsprogramme, Geplante Aufgaben, Veraltete Autostarts, Shell-Startdateien, Plug-in-Ordner, Netzwerk, Profile / MDM, Datenschutz (TCC). „Geplante Aufgaben“ zeigt zusätzlich launchd-Dienste mit Zeitplan. Die Kommandozeile nennt dieselben Kategorien englisch. |
| **Inventartabelle** | Mitte | Spalten: Häkchen, Symbole (höchstens drei), Name, Kategorie, Herkunft, Signatur, Pfad. Alle außer Häkchen und Symbolen sortierbar; Standard: Name aufsteigend. Die Auswahl hängt am stabilen Schlüssel und übersteht ein Neueinlesen. |
| **Suche** | Symbolleiste, nur bei Inventar-Ansichten | durchsucht Name, Label, Schlüssel, Pfad, Programm, Bundle-ID, Team und App; Groß- und Kleinschreibung egal |
| **Apple ausblenden** | Symbolleiste | Standard **an**. Springt man zu einem Apple-Eintrag (Beobachtung, Mitteilung, „Im Inventar zeigen“), schaltet es sich aus. |
| **Basis- / Expertenmodus** | Symbolleiste, *Darstellung › Expertenmodus* (⌥⌘E) | wird gemerkt; gilt für die Detailspalte des Inventars |
| **Neu einlesen** | Symbolleiste, *Darstellung* (⌘R) | nimmt den Abzug der Hintergrundaufgaben dieser Sitzung wieder; gesperrt, solange eingelesen wird |
| **Vollständig neu einlesen** | *Darstellung* (⇧⌘R) | fragt auch die Hintergrundaufgaben (`sfltool dumpbtm`) neu ab — das erste Mal nach längerer Ruhe kann Minuten dauern |
| **Statusleiste** | unten, schwebend | erscheint nur während des Einlesens (mit Fortschrittstext) oder bei unvollständigem Inventar — dann nennt sie die Quellen, die nicht geantwortet haben |
| **Hintergrund** | Seitenleiste › Ansichten | dieselbe Liste wie *Systemeinstellungen › Allgemein › Anmeldeobjekte & Erweiterungen*: „Beim Anmelden öffnen“, dann je App oder Entwickler eine Zeile mit Schalter (an, aus, gemischt, App, –). Ein oranges Zeichen markiert Komponenten, die per launchd aus sind — in den Systemeinstellungen unsichtbar. Einträge ohne Entwicklerangabe stehen in einem eigenen Abschnitt. |
| **Pakete** | Seitenleiste › Ansichten | Installationsbelege (`pkgutil`): Paket, Version, Installiert, Dateien, Fehlen, Einträge. „Nur mit fehlenden Dateien“ zeigt nur Pakete, von denen etwas fehlt. |
| **App-Reste** | Seitenleiste › Ansichten | lädt beim ersten Öffnen (rund 30 s: LaunchServices, Spotlight, App-Ordner). Zeigt nur Apps, die **nachweislich** weg sind; „Auch vorhandene/unklare zeigen“ zeigt alle Urteile. „Neu prüfen“ sucht nur die Reste erneut, nicht das Inventar. |
| **Quarantäne** | Seitenleiste › Ansichten | beide Quarantänen in einer Liste — siehe [Quarantäne](#quarantäne). Keine Detailspalte. |
| **Beobachtung** | Seitenleiste › Ansichten | die Zahl zählt neue und geänderte Einträge, die LaunchKeeper nicht selbst verursacht hat |
| **Warteschlange** | Seitenleiste › Stapelverarbeitung | die Zahl zählt offene Einträge |
| **Nach Updates suchen …** | Menü *LaunchKeeper* | nur in der installierten App (einem Bundle mit Update-Feed); in einer Entwicklerversion ausgegraut |

## Inventar und Detailspalte

### Die Symbole in der Liste

| Symbol | Bedeutet | Grenze |
|---|---|---|
| ⚠︎ orange | **Verwaist** — die Quelle fehlt nachweislich | — |
| Blatt, grau | **Rest** — nur noch ein Eintrag der Hintergrundaufgaben | ersetzt „Verwaist“, wenn beides zutrifft; macOS räumt solche Einträge selbst auf |
| Signatur, rot | **Nicht signiert** | — |
| Auge, gelb | **Ansehen empfohlen** | ein Prüfhinweis, **kein** Schadsoftware-Urteil |
| Pause, grau | **Deaktiviert** | launchd-Override, pluginkit-Wahl, auskommentierte cron-Zeile … |
| Play, grün | **Läuft** gerade | — |

### Die Prüfhinweise

| Hinweis (Kern) | In der App |
|---|---|
| `third-party-plist-runs-system-binary` | fremder Eintrag startet ein macOS-Programm |
| `shell-interpreter-service` | startet eine Shell oder einen Interpreter |
| `unsigned-executable` | Programm ist nicht (oder nur ad hoc) signiert |
| `temp-or-hidden-path` | Programm liegt in einem temporären oder versteckten Ordner |
| `user-writable-daemon-binary` | Systemdienst, dessen Programm ohne Administratorrechte geändert werden kann |
| `downloads-executable` | Programm wird direkt aus „Downloads“ gestartet |

### Detailspalte

| Was | Wo | Grenze |
|---|---|---|
| **Basismodus** | rechts, Standard | Ampel (Unauffällig · Rest · Ansehen empfohlen · Verwaist), ein Satz in Klartext, die Fakten (läuft, signiert von, aus Paket …) und die **Nächsten Schritte**. „Alle Details anzeigen“ klappt die Expertenabschnitte für diesen einen Eintrag auf. |
| **Expertenmodus** | ⌥⌘E | Identität und Zustand, Dateien (mit „Im Finder zeigen“), Befund, Herkunft & Signatur, Steuerung (Stufe, Aktionen, Mechanismus, Grund), Quellen, alle Metadaten |
| **Signatur gründlich prüfen** | Expertenmodus › Herkunft & Signatur | auf Knopfdruck, nicht beim Einlesen: `codesign --verify --strict`, Gatekeeper, Hardened Runtime, Zertifikatskette, SHA-256 |
| **Nächste Schritte** | Basismodus | nur, was die Prüfung erlaubt: Entfernen · Deaktivieren (umkehrbar) · Wieder aktivieren · In die Quarantäne verschieben · Hash für VirusTotal kopieren · Im Finder zeigen · „Hier nicht steuerbar“ mit Grund. Ein Schloss markiert Schritte mit Administratorrechten. |
| **Ausführen…** | an einem nächsten Schritt | öffnet das Plan-Blatt (siehe [Aktionen](#aktionen)) |
| **Befehl kopieren** | an einem nächsten Schritt ohne App-Aktion | der `launchkeeper`-Befehl ohne `--apply` — im Terminal zeigt er erst den Plan |
| **Hash für VirusTotal kopieren** | nächster Schritt | nur für Programmcode (Mach-O oder Hauptprogramm eines Bundles); nicht für Konfigurationsdateien und nicht für Apples Plattformpfade (`/System`, `/usr`, `/bin`, `/sbin`). Kein Netz: der Hash landet nur in der Zwischenablage. |
| **Markierte Zeilen** | Häkchen in jeder Ansicht | oben auf der Detailspalte das **Auswahlfeld** („N markiert“), darunter weiter die Erklärung der angeklickten Zeile (Trenner verschiebbar, seit 1.1.2) |
| **In der Warteschlange: …** | Detailspalte | steht der Eintrag in der Warteschlange, nennt ein Hinweis die Aktion; „Herausnehmen“ nimmt ihn wieder heraus |

## Aktionen

Jede Aktion läuft über dasselbe Blatt: **Plan** (Probelauf, nichts ändert sich) → **Ausführen**
(zweiter Klick) → **überprüftes Ergebnis**.

| Was | Wo | Grenze |
|---|---|---|
| **Deaktivieren** | Nächste Schritte, Warteschlange | nur für aktive Einträge; umkehrbar mit Aktivieren |
| **Wieder aktivieren** | Nächste Schritte, Warteschlange | nur für deaktivierte Einträge |
| **Entfernen** | Nächste Schritte, Warteschlange | nur, wenn die Prüfung es erlaubt — bei launchd-Einträgen nur für **verwaiste**. Ein Rest geht in die Quarantäne; eine verwaiste Startdatei wird gelöscht, vorher wird eine Sicherung angelegt. |
| **In die Quarantäne verschieben** | Nächste Schritte (nach „Deaktivieren“), Warteschlange | für funktionierende Einträge: erst deaktiviert, dann wandert die Startdatei in die Quarantäne. Das Programm selbst bleibt. |
| **Reste in die Quarantäne verschieben** | App-Reste | nie über das Hilfsprogramm (die Prüfung „App ist weg“ braucht LaunchServices des Benutzers); bräuchte der Plan Administratorrechte, zeigt das Blatt den Terminal-Befehl |
| **Aus der Quarantäne wiederherstellen** | Quarantäne, Warteschlange | siehe [Quarantäne](#quarantäne) |
| **Paket deinstallieren** | Pakete › Detailspalte, Warteschlange | braucht **immer** Administratorrechte. Nimmt nur Dateien, die noch unverändert vom Paket stammen; veränderte und geteilte bleiben. Alles geht in die Quarantäne des Hilfsprogramms. |
| **Beleg entfernen** | Pakete, wenn keine eigene Datei mehr da ist | vergisst den Installationsbeleg; eine Kopie bleibt in der Quarantäne |
| **Plan-Blatt** | nach „Ausführen…“ | jeder Schritt in Worten, darunter der Befehl; Hinweise des Kerns und der Rückweg. Während Plan und Ausführung lässt es sich nicht abbrechen. Warum „Ausführen“ fehlt, steht immer sichtbar unter dem Plan. |
| **Ausführen (Touch ID)** | Plan-Blatt | erscheint, wenn der Plan Schritte mit Administratorrechten hat und das Hilfsprogramm eingerichtet, erlaubt und in der Version dieser App ist |
| **Ohne Hilfsprogramm** | Plan-Blatt | Knopf „Hilfsprogramm einrichten“ bzw. „In den Systemeinstellungen erlauben“, „Einstellungen öffnen“ und der Terminal-Befehl mit `--apply` zum Kopieren |
| **Veraltetes Hilfsprogramm** | Plan-Blatt | „Hilfsprogramm neu starten“; bis dahin schickt die App ihm nichts |
| **Hilfsprogramm hat nichts ausgeführt** | Ergebnis | „Neu starten und erneut versuchen“ rechnet danach den Plan neu |
| **Während die Warteschlange läuft** | Plan-Blatt | „Ausführen“ ist gesperrt, bis der Lauf vorbei ist |
| **Protokoll** | — | eigene Aktionen der App: `~/Library/Logs/launchkeeper/operations.log` (dieselbe Datei wie die Kommandozeile); Aktionen des Hilfsprogramms: `/Library/Logs/launchkeeper/operations.log` |

Was Administratorrechte braucht, entscheidet derselbe Kern wie im Terminal: Systemdienste
(launchd-Domäne `system`), Startdateien unter `/Library/`, systemweite Anmelde-Skripte, die
Firewall, Quarantäne-Reste außerhalb deines Benutzerordners und jede Paket-Deinstallation.
App-Erweiterungen (pluginkit) und deine crontab brauchen keine.

## Warteschlange

| Was | Wo | Grenze |
|---|---|---|
| **Markieren** | Häkchen in Inventar, Hintergrund, Pakete, App-Reste, Quarantäne | Häkchen sind je Ansicht getrennt und überstehen den Wechsel zwischen Ansichten. Eine Hintergrund-Zeile steht für ihre Komponenten. |
| **Zur Warteschlange hinzufügen** | rechte Spalte, sobald etwas markiert ist | ein Knopf je möglicher Aktion mit „n von m“ — nur die Einträge, zu denen die Aktion passt. Danach verschwinden die verwendeten Häkchen. |
| **Als „Von Hand“ in die Warteschlange** | rechte Spalte | für markierte Einträge ohne automatische Aktion; **nie** für Apples eigene |
| **Eingereihte Zeilen** | in jeder Ansicht | statt des Häkchens ein Warteschlangen-Symbol (blau offen, grün erledigt, orange abgelehnt); ein Klick nimmt die Zeile heraus. Eine Hintergrund-Zeile mit nur einem Teil ihrer Komponenten zeigt „x/y“. |
| **Ein Ziel, ein Eintrag** | — | ein Eintrag steht nie zweimal in der Warteschlange; erneutes Hinzufügen ersetzt die Aktion |
| **Aktion wechseln** | Zeile in der Warteschlange | unter den Aktionen, die der Eintrag anbietet; der Plan wird neu geprüft |
| **Plan prüfen** | unten | rechnet alle offenen Einträge in **einem** Durchgang durch — ein Einlesen für alle Deaktivieren/Aktivieren/Entfernen. Abgelehnte und fehlgeschlagene werden neu geprüft. |
| **Alle ausführen** | unten, ↩ | prüft offene Pläne zuerst. Dann alle Einträge mit Administratorrechten in **einem** Aufruf des Hilfsprogramms mit **einer** Touch-ID-Abfrage, die die Anzahl nennt — danach die übrigen. Ein Fehler hält die anderen nicht an. |
| **Touch ID abgebrochen** | — | kommen alle Administrator-Einträge als „nicht autorisiert“ zurück, laufen auch die übrigen nicht: „nicht ausgeführt — Anmeldung abgebrochen“ |
| **Ohne Hilfsprogramm** | — | Einträge mit Administratorrechten werden mit Grund abgelehnt; die übrigen laufen |
| **Anhalten** | unten, während des Laufs | nach dem laufenden Eintrag; der Rest wird als „nicht ausgeführt“ gemeldet. Gilt auch für den Teil im Hilfsprogramm. |
| **Reihenfolge** | — | zuerst alle Schritte mit Administratorrechten, dann die übrigen; innerhalb davon Entfernen, Deaktivieren und Aktivieren vor Wiederherstellen und Deinstallieren. Ein Eintrag bekommt je Lauf nur eine Aktion. |
| **Hinweis auf Überschneidungen** | Zeile | steht ein Paket zur Deinstallation an und zugleich ein Eintrag aus diesem Paket, sagt die Zeile, dass dessen Aktion überflüssig wird |
| **Rückwege hinzufügen (n)** | unten, nach einem Lauf | nur für Einträge, die **in dieser Sitzung** erledigt wurden: Deaktivieren ↔ Aktivieren, und Wiederherstellen für alles, was in die Quarantäne ging |
| **Von Hand** | eigener Abschnitt | Anleitung und ein Knopf zur richtigen Stelle der Systemeinstellungen. Abgehakt wird von selbst, wenn ein **vollständiges** Einlesen den Eintrag nicht mehr findet oder ein beim Einreihen aktiver Eintrag jetzt aus ist; bei unvollständigem Einlesen zählt nur „aus“. |
| **Jetzt prüfen** | Abschnitt *Von Hand* | liest frisch ein, auch die Schalter der Hintergrundaufgaben, die ⌘R aus dem Zwischenspeicher nimmt |
| **Netzwerkdienste** | Abschnitt *Von Hand* | werden **nie** von selbst abgehakt — ein beendetes Programm verschwindet auch aus der Liste; abhaken (und wieder öffnen) tust du selbst |
| **Leeren** | unten | mit Rückfrage; nichts wird ausgeführt, Ausgeführtes bleibt ausgeführt |
| **Erledigte entfernen** | unten | nimmt erfolgreiche und abgehakte Einträge heraus; offene, abgelehnte und fehlgeschlagene bleiben |
| **Speichern** | automatisch | `~/Library/Application Support/de.paranoidsecurity.LaunchKeeper/queue.json`, nur für dich lesbar (0600, Ordner 0700). Gespeichert werden Einträge und Zustände, nicht die Pläne; ein unterbrochener Lauf steht nach dem Start wieder auf „offen“. |
| **Unlesbare Einträge** | Hinweis oben | ein Eintrag, den diese Version nicht lesen kann (etwa von einer neueren), fällt allein weg. Die Datei bleibt unverändert als `queue-unreadable-<Datum>.json` daneben; lässt sich diese Kopie nicht anlegen, speichert LaunchKeeper die Warteschlange bis zum nächsten Start nicht. |

## Beobachtung und Mitteilungen

| Was | Wo | Grenze |
|---|---|---|
| **Beobachtung ein/aus** | Ansicht *Beobachtung* (Schalter oben), Einstellungen › Beobachtung, Menüleiste („Beobachtung ausschalten“) | die Einstellung wirkt auch ohne offenes Fenster; beim Einschalten fragt macOS einmal nach der Erlaubnis für Mitteilungen |
| **Sofort** | — | Schreibt jemand an eine Autostart-Stelle (LaunchAgents/-Daemons, PrivilegedHelperTools, StartupItems, SystemExtensions, paths.d, Programme-Ordner, loginwindow, crontab, Shell-Startdateien …), liest LaunchKeeper nach **5 s** Ruhe neu ein — mit dem gespeicherten Abzug der Hintergrundaufgaben |
| **Regelmäßig** | — | alle **10 Minuten** ein vollständiger Vergleich. Mit Hilfsprogramm immer mit frischem Abzug der Hintergrundaufgaben; ohne höchstens alle **6 Stunden** (macOS fragt dafür nach Touch ID — auch ein abgebrochener Dialog zählt) |
| **Vergleich** | — | gegen das letzte **vollständige** Inventar; ein unvollständiges wird nie verglichen („Letzte Prüfung unvollständig, nicht verglichen“). Apples eigene Einträge und reine Laufzustände (läuft, geladen) zählen nicht. |
| **Eigene Änderungen** | Liste | was LaunchKeeper selbst geändert hat (auch bis **30 s** nach einer Aktion), steht mit „durch LaunchKeeper“ da und wird **nie** gemeldet |
| **Liste** | Ansicht *Beobachtung* | neueste zuerst, höchstens **200**; „Liste leeren“ leert nur die Anzeige, nicht die Protokolldatei. Beim Start liest die App die letzten Einträge aus dem Protokoll. |
| **Protokoll** | — | `~/Library/Logs/launchkeeper/watch.log` — dieselben JSON-Zeilen wie `launchkeeper watch` |
| **Detail eines Eintrags** | rechte Spalte | Kategorie, Pfad, Kennung, geänderte Felder, wann und warum bemerkt, was aus der Mitteilung wurde; „Im Inventar zeigen“ |
| **Mitteilung** | macOS | nur für **neue** und **geänderte** Einträge, nicht für eigene und nicht für Entfernungen. Ein Klick öffnet den Eintrag (oder die Beobachtung, wenn er weg ist). |
| **Was aus der Mitteilung wurde** | Detail › Bemerkt › Mitteilung | nur Messbares: nicht gesendet und warum, von macOS abgelehnt (mit Fehler), übergeben und in der Mitteilungszentrale oder nicht, freigegeben, während LaunchKeeper vorne war, angeklickt. Gilt für diese Sitzung, höchstens **200** Einträge. |
| **Menüleiste** | Auge, solange die Beobachtung an ist | Zustand, die letzten **5** fremden Änderungen, „LaunchKeeper öffnen“, „Beobachtung ausschalten“, „LaunchKeeper beenden“ |
| **Bei der Anmeldung starten** | Einstellungen › Beobachtung | über `SMAppService.mainApp`; LaunchKeeper öffnet dann sein Fenster und beobachtet weiter, wenn du es schließt |
| **Ausschalten** | — | vergisst den Ausgangsstand; das nächste Einschalten nimmt einen neuen |

## Hilfsprogramm

| Was | Wo | Grenze |
|---|---|---|
| **Einrichten** | Einstellungen (⌘,) › Hilfsprogramm für Administratorrechte, oder im Plan-Blatt | danach in *Systemeinstellungen › Allgemein › Anmeldeobjekte & Erweiterungen* erlauben, dann „Neu prüfen“. LaunchKeeper richtet es nie von selbst ein. |
| **Zustand** | Einstellungen | eingerichtet und erlaubt · wartet auf deine Freigabe · nicht eingerichtet · nicht gefunden (App nicht aus ihrem Bundle gestartet); dazu die Version |
| **Entfernen** | Einstellungen | Administrator-Aktionen gehen danach nicht mehr; Einlesen fragt wieder selbst nach den Hintergrundaufgaben |
| **Hilfsprogramm neu starten** | Einstellungen, Plan-Blatt | erscheint, wenn eine andere Version als die der App läuft; bis dahin schickt die App ihm nichts |
| **Touch ID / Passwort** | macOS-Dialog | bei **jeder** Ausführung neu, ohne Schonfrist; die Warteschlange fragt einmal je Lauf und nennt die Anzahl |
| **Was es ausführt** | — | Deaktivieren, Aktivieren, Entfernen, In die Quarantäne verschieben für systemweite Einträge — Startdateien entfernt und sichert es nur in `/Library/LaunchAgents` und `/Library/LaunchDaemons`; Wiederherstellen und endgültig Löschen nur eigener Quarantäne-Einträge; Paket-Deinstallation |
| **Was es ablehnt** | — | Einträge eines Benutzers (Benutzer-Domäne, App-Erweiterungen, Dateien im Benutzerordner) — die ändert die App selbst ohne Administratorrechte; Verschieben aus Orten, die Nicht-Administratoren ändern können (`/Users`, temporäre Ordner, `/Volumes`, `/opt/homebrew`, jeder Ordner auf dem Weg, der nicht root gehört oder für alle schreibbar ist) |
| **Werkzeuge** | — | nur `launchctl`, `rm`, `cp`, `mv`, `mkdir`, `defaults`, `pkgutil`, `cksum` und `socketfilterfw`, an festen Pfaden; jeder andere Schritt wird abgelehnt |
| **Hintergrundaufgaben lesen** | bei jedem frischen Einlesen | als root, ohne Touch ID; gibt nur die systemweiten Abschnitte und deine eigenen zurück, nie die anderer Benutzer |
| **Updates** | — | kommt mit der App; beendet sich nach **60 s** Leerlauf, launchd startet beim nächsten Aufruf die neue Version |
| **Ablage** | — | Quarantäne, Sicherungen und Konfigurationskopien unter `/Library/Application Support/launchkeeper` (nur root schreibt dort); Protokoll unter `/Library/Logs/launchkeeper` |

## Quarantäne

| Was | Wo | Grenze |
|---|---|---|
| **Zwei Quarantänen** | Ansicht *Quarantäne* | deine eigene (`~/Library/Application Support/launchkeeper/quarantine`, dieselbe wie die der Kommandozeile) und die des Hilfsprogramms (`/Library/Application Support/launchkeeper/quarantine`, gehört root) — in einer Liste, neueste zuerst |
| **Zeile** | Liste | Paket oder Notiz, Anzahl der Pfade, Status, Datum; aufgeklappt jeder verschobene Pfad und „Paketbeleg vergessen“, wenn ein Beleg dabei ist |
| **Wiederherstellen…** | aufgeklappte Zeile | öffnet das Plan-Blatt; ausgegraut bei bereits wiederhergestellten Einträgen. Einträge des Hilfsprogramms gehen über das Hilfsprogramm (Touch ID), deine eigenen mit Dateien im Benutzerordner ohne Administratorrechte. |
| **Nur im Terminal** | aufgeklappte Zeile | ein Eintrag **deiner** Quarantäne, der Dateien außerhalb deines Benutzerordners zurücklegen müsste (von der Kommandozeile oder einer älteren Version): „Befehl kopieren“ gibt `launchkeeper quarantine restore <name>` |
| **Was das Hilfsprogramm zurücklegt** | — | nur Einträge, die es selbst angelegt hat, nach Prüfung von Besitz und Bedeutung: jede Datei genau an ihren Ursprung, nie nach `/System`, nie in deinen Benutzerordner, nie an Orte, die Benutzer ändern können |
| **Im Finder zeigen** | aufgeklappte Zeile | den Ordner des Eintrags |
| **Endgültig löschen…** | aufgeklappte Zeile, rechts | seit 1.2; öffnet das Plan-Blatt: ein Schritt `rm -rf -- <Ordner des Eintrags>`, die Zahl der Pfade, roter Hinweis „Nicht wiederherstellbar …“. Ausführen mit **Endgültig löschen** bzw. „Endgültig löschen (Touch ID)“ — nur per Klick, nie mit ↩. Einträge des Hilfsprogramms löscht das Hilfsprogramm (nur eigene, Touch ID jedes Mal); deine eigenen, die dir durch und durch gehören, die App ohne Administratorrechte; deine mit Dateien, die nur root löschen darf, nur das Terminal (`launchkeeper quarantine purge <name> --apply`). Einzeln, nicht in der Warteschlange; auch bei wiederhergestellten Einträgen |
| **Neu laden** | Symbolleiste | liest die Einträge neu, etwa nach Änderungen im Terminal |
| **Markieren** | Häkchen | nicht bei wiederhergestellten und nicht bei „Nur im Terminal“ |

## Einstellungen

Einstellungen (⌘,) haben vier Abschnitte:

| Abschnitt | Inhalt |
|---|---|
| **Hilfsprogramm für Administratorrechte** | Zustand, Version, Einrichten / In den Systemeinstellungen erlauben / Entfernen, Neu prüfen, Neu starten bei veralteter Version |
| **Beobachtung** | „Neue Autostart-Einträge beobachten“, „Mitteilung bei neuen oder geänderten Einträgen“ (Standard **an**), „Mitteilungen laut macOS“ (erlaubt · nicht erlaubt · noch nicht gefragt · erlaubt, aber ohne Banner), „Test-Mitteilung senden“, „Erlaubnis anfragen“ (nur solange unentschieden), „Mitteilungseinstellungen öffnen“, der Hinweis zu Bannern bei Bildschirmfreigabe, „Bei der Anmeldung starten“ |
| **Hilfe** | „Einführung beim Start zeigen“ (Standard **an**), „Einführung jetzt zeigen“, „Hilfe öffnen“ |
| **Updates** | Version und Build, „Automatisch nach Updates suchen“, „Jetzt nach Updates suchen“ — nur in der installierten App |

## Hilfe und Einführung

| Was | Wo | Grenze |
|---|---|---|
| **LaunchKeeper-Hilfe** | *Hilfe* (⌘?), Einstellungen › Hilfe | eigenes Fenster, **10** Kapitel (Überblick, Das Inventar, Die Ansichten, Aktionen und Sicherheit, Das Hilfsprogramm, Die Warteschlange, Beobachtung und Mitteilungen, Tastenkürzel, Kommandozeile, Häufige Fragen), Suche über alle Texte; jedes Kapitel verlinkt den passenden Teil der Dokumentation — „Tastenkürzel“ den Abschnitt [Tastenkürzel](#tastenkürzel) dieser Referenz, die übrigen ein Kapitel des Handbuchs |
| **Handbuch öffnen …** | *Hilfe* | dieses Handbuch auf GitHub — deutsch oder englisch, wie die Oberfläche; ebenso „Im Handbuch weiterlesen“ in jedem Hilfekapitel |
| **Einführung** | beim ersten Start, *Hilfe › Einführung zeigen*, Einstellungen › Hilfe | **10** Schritte: 7 als Karte am Fenster (Seitenleiste, Liste, Detailspalte, Symbolleiste, Ansichten, Beobachtung, Warteschlange), Willkommen, Hilfsprogramm und Ende als Blatt. Sie öffnet ausgeblendete Spalten und rollt die Seitenleiste zur passenden Zeile; erscheint eine Karte nach **1 s** nicht, kommt der Schritt als Blatt. Startet von selbst einmal je Sitzung, abschaltbar in der Einführung („Beim Start zeigen“) und in den Einstellungen. |
| **Sprache** | — | Oberfläche, Hilfe und der Touch-ID-Dialog des Hilfsprogramms auf Deutsch oder Englisch nach Systemsprache, sonst Englisch. Die Kategorien heißen deutsch (die Kommandozeile nennt sie englisch). Meldungen des Kerns (Pläne, Ablehnungsgründe) bleiben englisch, wie in der Kommandozeile. |

## Tastenkürzel

| | |
|---|---|
| ⌘R | Neu einlesen (gespeicherter Abzug der Hintergrundaufgaben) |
| ⇧⌘R | Vollständig neu einlesen, auch die Hintergrundaufgaben |
| ⌥⌘E | Basis- oder Expertenmodus |
| ⌘, | Einstellungen |
| ⌘? | LaunchKeeper-Hilfe |
| ↩ | im Plan-Blatt: Ausführen (nicht bei **Endgültig löschen**) · in der Warteschlange: Alle ausführen |
| esc | im Plan-Blatt: Abbrechen |

## Grenzen und feste Werte

| | |
|---|---|
| Regelmäßiger Vergleich der Beobachtung | 600 s (10 Minuten) |
| Ruhezeit nach einer Dateiänderung | 5 s (dazu 2 s Bündelung durch FSEvents) |
| Frischer Abzug der Hintergrundaufgaben ohne Hilfsprogramm (Beobachtung) | höchstens alle 6 Stunden |
| Eigene Änderung nach Ende einer Aktion | 30 s |
| Liste der Beobachtung | 200 Einträge |
| Gemerkte Mitteilungs-Ergebnisse | 200, nur diese Sitzung |
| Einträge in der Menüleiste | 5 |
| `sfltool dumpbtm` beim Einlesen und im Hilfsprogramm | 150 s (Umgebungsvariable `LAUNCHKEEPER_BTM_TIMEOUT`) |
| Warten der App auf den Abzug des Hilfsprogramms | 200 s |
| Warten auf eine Aktion des Hilfsprogramms | 900 s; auf einen Lauf der Warteschlange 3 600 s |
| Versionsabfrage beim Hilfsprogramm | 5 s |
| Leerlauf, nach dem sich das Hilfsprogramm beendet | 60 s |
| Einträge je Lauf des Hilfsprogramms | 500 |
| Dialogtext eines Laufs | höchstens 200 Zeichen, muss bei mehr als einem Eintrag die Anzahl nennen |
| Ziel einer Anfrage | höchstens 1 024 Byte, keine Steuerzeichen, beginnt nicht mit „-“ |
| Anmeldeversuche im Touch-ID-/Passwort-Dialog | 3, keine Schonfrist |
| Systemweite Abschnitte der Hintergrundaufgaben | UIDs unter 500 |
| Prüfung der App-Reste | rund 30 s |
| Einführung | 10 Schritte, 1 s bis zum Ersatz-Blatt |
| Hilfe | 10 Kapitel |

## Was LaunchKeeper nicht tut

- **Schalter, die macOS selbst verwaltet** — Anmeldeobjekte und Hintergrunddienste in den
  Hintergrundaufgaben, System- und Kernel-Erweiterungen, Konfigurationsprofile,
  Datenschutz-Freigaben, Programme, die Netzwerkverbindungen annehmen. Dafür gibt es „Von Hand“
  in der Warteschlange.
- **Einträge von Apple** (`com.apple.*`) und alles unter `/System` — nur lesen, auch mit
  Administratorrechten.
- **Endgültig löschen ohne deinen ausdrücklichen Klick** — nur einzeln, nach dem Plan, nie mit ↩
  und nie in der Warteschlange.
- **Etwas hochladen** — auch nicht zu VirusTotal. Ins Netz geht nur die Suche nach Updates.
- **Einträge anderer Benutzer zeigen** — das Hilfsprogramm gibt sie nicht heraus.
- **Befehle an das Hilfsprogramm schicken** — es nimmt nur „was mit welchem Eintrag“ und plant selbst.
