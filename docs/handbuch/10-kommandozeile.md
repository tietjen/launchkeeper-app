# Die Kommandozeile `launchkeeper`

Unter der App arbeitet ein Kommandozeilenwerkzeug: `launchkeeper`. Es liest dasselbe Inventar,
geht durch dieselbe Prüfung und schreibt in dieselben Ablagen — die App benutzt seine Bausteine.
Es ist der Weg für Skripte, für einen schnellen Blick per SSH und für die wenigen Dinge, die es
nur im Terminal gibt.

Dieses Kapitel zeigt die wichtigsten Befehle. Das vollständige englische Handbuch steht im
[README des Werkzeugs](https://github.com/tietjen/launchkeeper#readme).

## Installieren

Mit Homebrew:

```bash
brew trust tietjen/tap          # einmal, ab Homebrew 7 — fremden Taps wird sonst nicht vertraut
brew install tietjen/tap/launchkeeper
```

Homebrew installiert das fertige, von Apple beglaubigte Programm für Apple-Chips und Intel.
Neue Versionen holst du mit `brew upgrade launchkeeper`. Ob alles stimmt:

```bash
launchkeeper --version     # 0.12.2
launchkeeper doctor        # welche Quellen antworten
```

Es läuft ab macOS 14. Die App braucht das Werkzeug nicht — es ist ein eigener Weg zu denselben
Daten.

## Zwei Regeln vorweg

**Ohne `--apply` passiert nichts.** Jeder Befehl, der etwas ändert, zeigt ohne `--apply` nur den
Plan — jeden Schritt mit dem genauen Befehl, und den Rückweg:

```
DRY-RUN — nothing executed (dry-run is the default).
plan:
  1. /bin/launchctl disable gui/501/com.example.script
  2. /bin/launchctl bootout gui/501/com.example.script

undo later with: launchkeeper enable com.example.script
execute for real with: --apply
```

**Du startest es als du selbst, nicht mit `sudo`.** Braucht ein Schritt root — ein Dienst im
Systembereich, eine Datei unter `/Library`, die Firewall, ein Paket —, ruft `launchkeeper` für
genau diesen Schritt `sudo` auf, und das Terminal fragt nach deinem Passwort. Pauschale
Administratorrechte verlangt es nie, und es benutzt nie eine Shell.

Die Prüfung ist dieselbe wie in der App: Einträge von Apple und alles unter `/System` lehnt sie
ab, und es gibt keine Option, die das umgeht.

## Nachsehen

```bash
launchkeeper list                       # das Inventar als Tabelle (auch ohne „list“)
launchkeeper list --orphans             # nur verwaiste Einträge, mit Grund
launchkeeper list --running             # nur Einträge, die gerade laufen
launchkeeper list --disabled            # nur deaktivierte
launchkeeper list --user                # nur dein Bereich (--system: nur der des Systems)
launchkeeper list --category network    # eine Kategorie
launchkeeper list --origin manual       # nach Herkunft: apple, homebrew, app-store, receipt, manual, unknown
launchkeeper list --all                 # auch Apples interne Einträge

launchkeeper inspect 07                 # alles zu einem Eintrag
launchkeeper inspect 07 --verify        # Signatur in der Tiefe: Siegel, Zertifikatskette, Gatekeeper, SHA-256
launchkeeper background                 # wie Systemeinstellungen › Anmeldeobjekte & Erweiterungen
launchkeeper receipts                   # die Installationspakete hinter dem Inventar (--missing, --all)
launchkeeper leftovers                  # was gelöschte Apps zurückgelassen haben (--all: auch Unklares)
launchkeeper doctor                     # Selbsttest: welche Quelle hat geantwortet
```

Einen Eintrag sprichst du mit seiner Nummer aus `list`, seinem Label, seinem Namen oder einem
eindeutigen Teil davon an. Die Nummern sind in allen Befehlen gleich, solange das Inventar
vollständig ist. Hat eine Quelle nicht geantwortet — meist die Hintergrundaufgaben
(Background Task Management, kurz BTM) nach einer Zeitüberschreitung —, sagt `list` das, und Befehle, die etwas ändern, nehmen dann keine Nummern
an. Das Label geht immer.

> Die erste Abfrage der Hintergrundaufgaben kann nach längerer Ruhe Minuten dauern — wie in
> der App. Danach geht es in Sekunden.

### Für Skripte

Fast jeder Befehl kann `--json`: `list`, `inspect`, `doctor`, `background`, `receipts`,
`leftovers`, `diff`, `snapshot`, `quarantine list`, `watch` und alle Befehle, die etwas ändern.
Dazu kommen `list --csv` für eine Tabellenkalkulation und `list --markdown` für einen Bericht.

## Vergleichen

```bash
launchkeeper snapshot --name vor-dem-update     # das ganze Inventar sichern
launchkeeper snapshot list                      # was gesichert ist
launchkeeper diff                               # was sich seit der letzten Sicherung geändert hat
launchkeeper diff vor-dem-update --exit-code    # Rückgabewert 1 bei Unterschieden
```

Die Sicherungen liegen unter `~/Library/Application Support/launchkeeper/inventory/`. `diff`
vergleicht Eintrag für Eintrag: neu, verschwunden, und welche Felder sich geändert haben.
`--state` nimmt hinzu, ob etwas geladen ist oder läuft. Mit `--exit-code` merkt ein nächtliches
Skript, wenn ein neuer Autostart-Eintrag dazugekommen ist.

## Ändern

```bash
launchkeeper disable 07                     # Plan
launchkeeper disable 07 --apply             # ausführen, danach prüfen
launchkeeper enable 07 --now --apply        # Rückweg; --now lädt den Dienst wieder
launchkeeper disable a b c --apply          # mehrere auf einmal, mit einem einzigen Einlesen

launchkeeper remove <Eintrag>               # eine verwaiste Startdatei löschen — nach einer Sicherung
launchkeeper remove <Eintrag> --working     # einen funktionierenden Eintrag deaktivieren und
                                            #   seine Startdatei in die Quarantäne verschieben
```

`disable` und `enable` erreichen mehr als `launchd`: App-Erweiterungen, Zeilen deiner crontab,
Anmelde-Skripte des Anmeldefensters und Regeln der Firewall — jeweils mit Kopie der Quelle vor
der ersten Änderung, wo es eine Datei zu verlieren gibt. `remove` ohne `--working` lehnt alles
ab, was noch funktioniert, und nennt den Befehl, der stattdessen geht.

Jede Aktion wird danach überprüft, und jede — auch eine abgelehnte oder ein bloßer Plan — steht
im Protokoll `~/Library/Logs/launchkeeper/operations.log`.

## Aufräumen

```bash
launchkeeper uninstall <Paket-ID>                   # was wegkäme, was bleibt und warum
launchkeeper uninstall <Paket-ID> --list            # jede einzelne Datei
launchkeeper uninstall <Paket-ID> --apply           # in die Quarantäne verschieben

launchkeeper leftovers <Bundle-ID>                  # Reste einer gelöschten App: Plan
launchkeeper leftovers <Bundle-ID> --apply          # in die Quarantäne verschieben
```

Das Paket sprichst du mit seiner genauen ID an (aus `launchkeeper receipts`), nie mit einem Teil
davon. Verschoben wird nur, was nachweislich noch so ist, wie das Paket es installiert hat.

## Die Quarantäne

```bash
launchkeeper quarantine                          # = quarantine list: beide Ablagen
launchkeeper quarantine restore <Name>           # Plan
launchkeeper quarantine restore <Name> --apply   # zurücklegen — überschreibt nie
launchkeeper quarantine purge <Name>             # Plan
launchkeeper quarantine purge <Name> --apply     # endgültig löschen — NICHT wiederherstellbar
```

`purge` ist die einzige echte Löschung in LaunchKeeper; seit App 1.2 gibt es sie auch in der
Ansicht **Quarantäne** (**Endgültig löschen…**). Einen Eintrag deiner Ablage, der durch und durch
dir gehört, löscht `purge` ohne `sudo`; sonst fragt `sudo` nach deinem Passwort. Was die beiden
Ablagen sind und wann Zurücklegen oder Löschen nur im Terminal geht, steht in
[Kapitel 8](08-quarantaene-und-rueckwege.md).

## Sicherungen der Startordner

```bash
launchkeeper backup --label vorher        # Startordner und Deaktivierungen sichern (ändert nichts)
launchkeeper restore <Sicherung>          # Plan
launchkeeper restore <Sicherung> --apply  # zurückkopieren
```

`restore` findet auch die Sicherungen, die das Hilfsprogramm der App unter
`/Library/Application Support/launchkeeper/backups` angelegt hat. Zurückgelegt wird nur in die
vier Startordner (`~/Library/LaunchAgents`, `~/Library/LaunchDaemons`, `/Library/LaunchAgents`,
`/Library/LaunchDaemons`), und jede Datei wird vor und nach dem Schreiben gegen die Prüfsumme der
Sicherung geprüft.

## Beobachten

```bash
launchkeeper watch                          # neue, entfernte und geänderte Einträge, laufend
launchkeeper watch --notify                 # dazu eine Mitteilung je Änderung
launchkeeper watch --interval 600           # vollständiger Vergleich alle 600 Sekunden (Standard 300)
launchkeeper watch --json                   # als JSON-Zeilen
```

Wie in der App ist die erste vollständige Prüfung der Ausgangsstand; unvollständige Prüfungen
werden übersprungen, nie als „entfernt“ gemeldet. `Ctrl-C` beendet die Beobachtung.

## Was App und Kommandozeile teilen

| | Gemeinsam |
|---|---|
| **Quarantäne** | Beide sehen beide Ablagen. Die Kommandozeile schreibt in deine (`~/Library/Application Support/launchkeeper/quarantine`), das Hilfsprogramm der App in die des Systems. In die des Systems wird nur als root geschrieben — vom Hilfsprogramm oder über `sudo` von der Kommandozeile (`quarantine restore/purge --apply`); ohne `sudo` liest die Kommandozeile sie nur. |
| **Beobachtung** | Beide hängen ihre Funde an `~/Library/Logs/launchkeeper/watch.log`, im selben Format. Die App zeigt nach dem Start auch, was `launchkeeper watch` notiert hat. |
| **Protokoll** | Aktionen ohne Administratorrechte — aus der App wie aus dem Terminal — stehen in `~/Library/Logs/launchkeeper/operations.log`; die des Hilfsprogramms in `/Library/Logs/launchkeeper/operations.log`. |
| **Sicherungen** | `launchkeeper restore` findet deine und die des Hilfsprogramms. |

In der Warteschlange steht zu jedem Eintrag unter **Befehl** die passende Befehlszeile zum
Markieren — mit `--apply`, sie führt also aus. Wo die Detailspalte einen Schritt nicht selbst ausführt, bietet sie **Befehl
kopieren** an — ohne `--apply` zeigt der Befehl im Terminal erst den Plan.

## Wann was

| Aufgabe | Besser |
|---|---|
| Überblick, Einträge verstehen, einzeln oder gesammelt ändern | die App |
| Viele Änderungen mit Administratorrechten | die App — eine Touch-ID-Abfrage für die ganze Warteschlange |
| Beobachten mit Mitteilungen, auch mit geschlossenem Fenster | die App |
| Skripte, nächtliche Vergleiche, JSON, CSV | die Kommandozeile |
| Aus der Quarantäne endgültig löschen | die App (**Endgültig löschen…**), einzeln |
| Einträge deiner Ablage endgültig löschen, die Dateien enthalten, die nur root löschen darf | **nur** die Kommandozeile |
| Einträge deiner Ablage zurücklegen, die Pfade außerhalb deines Benutzerordners haben | **nur** die Kommandozeile |
| Sicherungen der Startordner anlegen und zurückkopieren | die Kommandozeile |
| Ein anderes System aus seinen Dateien prüfen (Time-Machine-Backup, Laufwerk) | **nur** die Kommandozeile: `launchkeeper list --root <Ordner>` |

> Die Kommandozeile kennt außerdem `launchkeeper resetbtm` — das Zurücksetzen der
> Hintergrundaufgaben von macOS. Das ist der eine Befehl **ohne Rückweg**: macOS kann den
> vorherigen Stand nicht wieder einlesen, die Registrierungen kommen erst zurück, wenn die
> zugehörigen Apps wieder laufen. Lies vorher den Abschnitt dazu im README.

## Weiter

- [Zurück zur Übersicht des Handbuchs](README.md)
