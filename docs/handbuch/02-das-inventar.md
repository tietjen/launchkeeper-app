# Das Inventar lesen

Das **Inventar** ist die Liste von allem, was auf diesem Mac automatisch startet oder geladen
wird. LaunchKeeper liest es beim Start ein und jedes Mal, wenn du es verlangst. Lesen ändert
nichts — das Einlesen schreibt keine einzige Datei.

## Was als Autostart zählt

Mehr, als die Systemeinstellungen zeigen. LaunchKeeper ordnet jeden Fund einer von zwölf
**Kategorien** zu. In der Seitenleiste erscheinen nur die, die auf deinem Mac auch Einträge haben.
Die Kommandozeile `launchkeeper` ([Kapitel 10](10-kommandozeile.md)) nennt dieselben Kategorien
englisch — die rechte Spalte hilft beim Übersetzen:

| Kategorie | Was dazugehört | In der Kommandozeile |
|---|---|---|
| **Hintergrunddienste (launchd)** | LaunchAgents und LaunchDaemons — die klassischen Hintergrunddienste — und ihre laufenden Jobs | Launch Items |
| **Anmeldeobjekte & Hintergrund** | Anmeldeobjekte und Hintergrunddienste, die Apps bei macOS registriert haben | Login Items & Background |
| **App-Erweiterungen** | Quick Look, Spotlight, Teilen, Widgets, Finder-Erweiterungen … | App Extensions |
| **System- und Kernel-Erweiterungen** | Systemerweiterungen (Netzwerkfilter, VPN, Sicherheit, Treiber) und Kernel-Erweiterungen | System Extensions & Kexts |
| **Privilegierte Hilfsprogramme** | Hilfsprogramme mit Administratorrechten, die Apps in `/Library/PrivilegedHelperTools` installieren | Privileged Helper Tools |
| **Geplante Aufgaben** | was zeitgesteuert läuft: cron, at, Wartungsskripte, geplantes Aufwachen — und LaunchAgents mit Zeitplan | Scheduled |
| **Veraltete Autostarts** | veraltete Wege: Anmelde-/Abmelde-Skripte, StartupItems, `rc`-Dateien | Legacy Persistence |
| **Shell-Startdateien** | Startdateien des Terminals (`.zshrc` und Verwandte) und Ergänzungen des Suchpfads | Shell Startup |
| **Plug-in-Ordner** | Plug-ins, die macOS nach ihrem Ort lädt: Audiotreiber, Bildschirmschoner, Eingabemethoden … | Plug-in Directories |
| **Netzwerk** | Programme, die Netzwerkverbindungen annehmen, und Regeln der Firewall | Network |
| **Profile / MDM** | Konfigurationsprofile | Profiles / MDM |
| **Datenschutz (TCC)** | Datenschutz-Freigaben | Privacy (TCC) |

Ein LaunchAgent mit Zeitplan steht in beiden: unter **Hintergrunddienste (launchd)**, weil er
einer ist, und unter **Geplante Aufgaben**, weil er zeitgesteuert läuft.

## Die Seitenleiste

Ganz oben unter **Inventar**:

- **Alle Einträge** — alles, was LaunchKeeper gefunden hat.
- **Verwaist** — Einträge, deren Programm oder Datei fehlt. Typische Reste deinstallierter
  Software.

Darunter die **Kategorien**. Die Zahl hinter jeder Zeile zählt die Einträge; sie richtet sich
nach **Apple ausblenden**, aber nicht nach der Suche — sie bleibt also stehen, während du tippst.

## Die Liste

Jede Zeile ist ein Eintrag. Die Spalten:

| Spalte | Inhalt |
|---|---|
| (Häkchen) | markiert den Eintrag für die Warteschlange ([Kapitel 6](06-die-warteschlange.md)) |
| (Symbole) | bis zu drei Markierungen, das Wichtigste zuerst (siehe unten) |
| **Name** | der Anzeigename; beim Darüberfahren der interne Schlüssel |
| **Kategorie** | eine der Kategorien oben |
| **Herkunft** | woher der Eintrag kommt: `apple`, `homebrew`, `app-store`, `receipt` (aus einem Installationspaket), `manual` (eine App, die kein Beleg kennt) oder `unknown` |
| **Signatur** | der Stand der Code-Signatur, wie die Prüfung ihn meldet |
| **Pfad** | die Datei hinter dem Eintrag, sonst das Programm |

**Sortieren:** Ein Klick auf eine Spaltenüberschrift sortiert danach, ein zweiter dreht die
Reihenfolge um. Am Anfang ist nach Name sortiert.

**Suchen:** Das Suchfeld in der Symbolleiste („Name, Label, Pfad, Team …“) filtert die Liste
beim Tippen. Gesucht wird in Name, Label, Schlüssel, Pfad, Programm, Bundle-ID, Team-ID und
zugehöriger App, ohne Rücksicht auf Groß- und Kleinschreibung.

### Die Symbole

| Symbol | Farbe | Bedeutung |
|---|---|---|
| Warndreieck | orange | **Verwaist** — die Quelle fehlt, das Programm, auf das der Eintrag zeigt, gibt es nicht mehr |
| Blatt | grau | **Rest** — nur noch ein Eintrag in den Hintergrundaufgaben (Background Task Management, kurz BTM) von macOS, ohne Datei dahinter |
| Unterschrift | rot | **Nicht signiert** — das Programm trägt keine Code-Signatur |
| Auge | gelb | **Ansehen empfohlen** — etwas ist auffällig, die Detailspalte sagt, was |
| Pause | grau | **Deaktiviert** — vorhanden, startet aber nicht |
| Wiedergabe | grün | **Läuft** — gerade aktiv |

Ein **Rest** ist genauer als „verwaist“: Die Datei ist schon weg, macOS führt nur noch einen
Datensatz. Solche Zeilen tragen deshalb das Blatt statt des Dreiecks.

> **Rot und gelb sind kein Urteil über Schadsoftware.** Ein nicht signiertes Programm kann ein
> harmloses Werkzeug sein, ein gelb markierter Eintrag ein ganz gewöhnliches Skript. Die Symbole
> sagen: Hier lohnt sich ein Blick.

## Die Detailspalte

Wähle eine Zeile, und rechts steht, was sie bedeutet. Im **Basismodus** — so startet die App —
sind das vier Teile.

### Die Ampel

Ganz oben ein Symbol in einer Farbe und ein kurzer Befund:

| Ampel | Befund |
|---|---|
| grün | „Unauffällig“ |
| grau | „Nur noch ein Rest-Eintrag — harmlos, macOS räumt ihn selbst auf“ |
| gelb | „Ansehen empfohlen: …“ mit dem Grund |
| orange | „Verwaist: …“ mit dem, was fehlt |

Gelb wird es etwa, wenn ein fremder Eintrag ein Programm von macOS startet, wenn eine Shell oder
ein Interpreter als Dienst läuft, wenn das Programm in einem temporären Ordner oder direkt in
„Downloads“ liegt oder wenn es nicht signiert ist.

### Der Satz in Klartext

Darunter in einem Satz, was der Eintrag ist — etwa „Startet beim Anmelden (LaunchAgent)“,
„Systemdienst, startet mit dem Mac (LaunchDaemon)“ oder „App-Erweiterung — wird von anderen Apps
geladen“.

### Die Fakten

Eine graue Zeile mit dem Wichtigsten: läuft er gerade, ist er ausgeschaltet, wer hat ihn signiert
(„signiert von …“, „nicht signiert“, „Teil von macOS“), woher er kommt („aus Paket …“, „über
Homebrew installiert“), zu welcher App er gehört.

Startet der Eintrag nur einen Interpreter wie `bash` oder `python`, steht vorne, was **wirklich**
läuft: „führt aus: Skript … (über bash)“.

### Nächste Schritte

Zuletzt die **Nächsten Schritte** — nur, was für diesen Eintrag sicher möglich ist:

- **Aktionen** wie „Deaktivieren (umkehrbar)“, „Wieder aktivieren“, „Entfernen“ oder „In die
  Quarantäne verschieben“, jede mit einem Satz, was passiert, und dem Knopf **Ausführen…**. Ein
  Schloss neben dem Titel heißt: braucht Administratorrechte. Wie es dann weitergeht, steht in
  [Kapitel 5](05-eintraege-aendern.md).
- **Hash für VirusTotal kopieren** — bei Programmdateien, die nicht zu macOS gehören. **Hash
  kopieren** rechnet den SHA-256 der Datei aus und legt ihn in die Zwischenablage; auf
  virustotal.com fügst du ihn in die Suche ein. Die Datei selbst verlässt den Mac nicht, und
  LaunchKeeper schickt auch den Hash nirgendwohin.
- **Im Finder zeigen** — öffnet ein Finder-Fenster mit der Datei.
- **Hier nicht steuerbar** — wenn LaunchKeeper an dem Eintrag nichts ändern darf, mit dem Grund
  und dem Ort, wo der Schalter stattdessen liegt.

Angeboten wird nur, was dieselbe Prüfung besteht, die auch beim Ausführen greift. Steht eine
Aktion nicht da, würde sie abgelehnt.

### Alle Details und der Expertenmodus

**Alle Details anzeigen** unter den nächsten Schritten klappt für **diesen** Eintrag alles auf,
was LaunchKeeper weiß. Beim nächsten Eintrag ist es wieder zu.

Der **Expertenmodus** zeigt diese Details immer — umschalten mit dem linken Knopf der Symbolleiste,
über **Darstellung › Expertenmodus** oder mit **⌥⌘E**. LaunchKeeper merkt sich die Wahl.

Im Expertenmodus stehen:

- Name, Kategorie, Typ, Label, Schlüssel und der **Zustand** („aktiviert · geladen · läuft (PID …)“),
- **Dateien** — Quelle, Programm, Argumente, App; neben einem vorhandenen Pfad eine Lupe, die ihn
  im Finder zeigt,
- **Befund** — die Gründe für „verwaist“ und „ansehen empfohlen“,
- **Herkunft & Signatur** — Herkunft, Signatur, Team, Entwickler,
- **Steuerung** — was möglich ist, über welchen Mechanismus, und warum,
- **Quellen** — woher LaunchKeeper von dem Eintrag weiß,
- **Details** — alle übrigen Metadaten.

### Die gründliche Signaturprüfung

Unter **Herkunft & Signatur** steht **Signatur gründlich prüfen**. Das prüft das Programm (bei
Erweiterungen, Plug-ins und Treibern das ganze Paket) so streng wie `codesign --verify --strict`,
fragt Gatekeeper und zeigt danach:

- **Siegel** — „intakt“ oder was nicht stimmt,
- **Gatekeeper** — das Urteil und seine Quelle,
- **Hardened Runtime** — ja oder nein,
- **Kette** — die Zertifikatskette,
- **SHA-256** — die Prüfsumme.

Die Prüfung dauert pro Datei einen Moment; deshalb läuft sie nur auf Klick und nicht beim
Einlesen.

## Apple ausblenden

Der mittlere Knopf der Symbolleiste blendet **Apples eigene Systemeinträge** aus. Das ist beim
Start eingeschaltet: Davon gibt es Hunderte, und ändern lässt LaunchKeeper sie ohnehin nicht.

Als Apples Eintrag gilt, was ein Label mit `com.apple.` trägt und als Teil von macOS signiert ist
(oder gar keine Signaturangabe hat). Liegt neben einem `com.apple.`-Eintrag eine Datei, die
**dir** gehört statt dem System, bleibt er sichtbar — das ist dann kein Teil von macOS.

Springst du von woanders zu einem ausgeblendeten Eintrag — etwa aus der Ansicht **Hintergrund**
oder über eine Mitteilung —, blendet LaunchKeeper Apples Einträge dafür von selbst ein.

## Neu einlesen: ⌘R und ⇧⌘R

| Kürzel | Menü | Was passiert |
|---|---|---|
| **⌘R** | **Darstellung › Neu einlesen** | liest neu ein und nimmt die Liste der Hintergrundaufgaben aus dieser Sitzung — in Sekunden |
| **⇧⌘R** | **Darstellung › Vollständig neu einlesen** | fragt auch die Hintergrundaufgaben von macOS frisch ab |

Der Knopf **Neu einlesen** in der Symbolleiste ist ⌘R. Für fast alles genügt das. **⇧⌘R** brauchst
du, wenn du in den Systemeinstellungen unter Anmeldeobjekte & Erweiterungen etwas umgeschaltet
hast und LaunchKeeper das sehen soll.

> Die frische Abfrage der Hintergrundaufgaben kann nach längerer Ruhe Minuten dauern, und ohne
> Hilfsprogramm fragt macOS dafür nach Touch ID oder deinem Passwort
> ([Kapitel 4](04-das-hilfsprogramm.md)).

Während ein Einlesen läuft, ist der Knopf ausgegraut.

## Wenn das Inventar unvollständig ist

Antwortet eine Quelle nicht — die Hintergrundaufgaben, die Liste der Erweiterungen, die Liste
der Netzwerkverbindungen —, fehlt ihr Teil im Inventar. Die Statusleiste unten meldet dann
„Inventar unvollständig: … — ⇧⌘R versucht es erneut“ mit den Quellen, die fehlen.

Das passiert am häufigsten, wenn du die Touch-ID-Abfrage für die Hintergrundaufgaben abbrichst.
**⇧⌘R** versucht es noch einmal. Solange die Meldung steht, fehlen der Liste Einträge — „nicht da“
heißt dann nicht „nicht vorhanden“.

## Weiter

- [Kapitel 3 — Die Ansichten](03-die-ansichten.md)
