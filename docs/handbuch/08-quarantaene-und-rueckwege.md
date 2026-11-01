# Quarantäne und Rückwege

LaunchKeeper löscht fast nie. Was beim Aufräumen wegkommt — ein Paket, die Reste einer gelöschten
App, ein Dienst, den du loswerden willst —, wird **verschoben**, nicht gelöscht: in die
**Quarantäne**. Von dort lässt es sich zurückholen. Dieses Kapitel erklärt, wo die Quarantäne
liegt, wie du etwas wiederherstellst und welche anderen Rückwege es gibt.

## Was die Quarantäne ist

Jede Aktion, die etwas wegnimmt, legt in der Quarantäne einen **Eintrag** an: einen Ordner mit

- `manifest.json` — was verschoben wurde, von wo, wann und mit welchem Ergebnis; geschrieben,
  bevor die erste Datei sich bewegt,
- `files/` — die Dateien selbst, unter ihrem **ursprünglichen Pfad**: aus
  `/Library/LaunchDaemons/com.example.plist` wird `files/Library/LaunchDaemons/com.example.plist`,
- bei Paketen `receipt/` — eine Kopie des Paketbelegs, falls er vergessen wurde.

Verschieben heißt in der Regel umbenennen auf demselben Laufwerk: Dann geht es sofort, braucht
keinen zusätzlichen Platz, und Besitzer und Rechte bleiben, wie sie waren. Liegt eine Datei auf
einem anderen Laufwerk als die Quarantäne, kopiert `mv` sie hinüber und entfernt danach das
Original.

## Zwei Ablagen

Es gibt zwei Quarantänen, je nachdem, wer etwas weggenommen hat:

| Ablage | Ort | Wer schreibt dort |
|---|---|---|
| **deine** | `~/Library/Application Support/launchkeeper/quarantine` | die App bei Aktionen ohne Administratorrechte (etwa App-Reste in `~/Library`) und die Kommandozeile `launchkeeper` |
| **die des Systems** | `/Library/Application Support/launchkeeper/quarantine` | **nur root** — das Hilfsprogramm bei allem, was Administratorrechte braucht (Paket-Deinstallationen, Dienste in `/Library`), und die Kommandozeile über `sudo` (`quarantine restore/purge --apply`) |

Neben der Quarantäne des Systems liegen dort zwei weitere Ordner des Hilfsprogramms:

```
/Library/Application Support/launchkeeper/
├── quarantine/         was das Hilfsprogramm weggenommen hat
├── backups/            Sicherungen der Startordner vor dem Entfernen
└── config-snapshots/   Kopien von Konfigurationsdateien vor einer Änderung
```

Dieser Baum gehört root, und niemand sonst darf hineinschreiben. Das ist Absicht: Würde das
Hilfsprogramm mit Administratorrechten in deinem Benutzerordner arbeiten, könnte jedes Programm,
das unter deinem Namen läuft, zwischen Prüfen und Schreiben einen Ordner umbenennen oder einen
Verweis unterschieben — und so das Hilfsprogramm dazu bringen, Systemdateien zu überschreiben.
Mehr dazu in [Kapitel 9](09-sicherheit-und-datenschutz.md#ein-baum-nur-root-schreibt).

Die App und die Kommandozeile **sehen beide Ablagen**; die Ansicht **Quarantäne** zeigt alle
Einträge zusammen, die neuesten oben.

## Die Ansicht Quarantäne

In der Seitenleiste unter **Ansichten › Quarantäne**. Seit 1.2.1 ist sie eine Liste mit Auswahl
wie die anderen Ansichten: Ein Klick auf eine Zeile zeigt rechts in der Detailspalte alles zu
diesem Eintrag; aufklappen musst du nichts mehr.

Jede Zeile zeigt

- ein **Häkchen** — nur bei Einträgen, die sich in der App wiederherstellen lassen (nicht bei
  leeren, wiederhergestellten und solchen, die nur im Terminal zurückgehen),
- den **Titel**: das Paket, die Bundle-ID der App oder den Eintrag, darunter klein die **Art**:
  „App-Reste“, „Paket deinstalliert“ oder „Eintrag entfernt“,
- rechts den **Zustand** und das **Datum**.

### Gruppiert nach dem, was wirklich dort liegt

Die Abschnitte richten sich danach, was ein Eintrag **jetzt** enthält — LaunchKeeper sieht dafür
auf der Festplatte nach, ob jeder verschobene Pfad in der Quarantäne liegt, und verlässt sich
nicht auf den Stand im `manifest.json` (dort steht etwa `applied-fail(5)` sowohl für einen
Eintrag, der nichts enthält, als auch für einen, dem nur ein Pfad fehlt):

| Abschnitt | Zustand in der Zeile | Bedeutung |
|---|---|---|
| **In der Quarantäne** | „in der Quarantäne“ (grün) | alle Pfade liegen dort und lassen sich wiederherstellen |
| **Unvollständig — nur ein Teil kam an** | „N von M Pfaden“ (orange) | ein Teil kam an, der Rest blieb an seinem Ort — meist, weil macOS das Verschieben verweigert hat ([Festplattenvollzugriff](05-eintraege-aendern.md#app-reste-und-der-festplattenvollzugriff)) |
| **Leer — nichts verschoben** | „leer“ | Versuche, bei denen macOS schon den ersten Schritt verweigert hat; sie enthalten keine Dateien |
| **Wiederhergestellt** | „wiederhergestellt“ | die Dateien sind zurück; der Eintrag ist nur noch das Protokoll davon |

Leere Abschnitte fehlen. Innerhalb eines Abschnitts stehen die neuesten Einträge oben.

### Die Detailspalte

Zum gewählten Eintrag stehen rechts:

- der Titel, **Art**, **Zustand**, **Angelegt** (Datum und Uhrzeit) und **Ablage** — „deine
  Quarantäne“ oder „Quarantäne des Systems (Hilfsprogramm)“, siehe [oben](#zwei-ablagen) —,
  darunter ein Satz, was der Zustand bedeutet;
- **Pfade**: jeder ursprüngliche Pfad, davor ein Symbol, ob er in der Quarantäne liegt oder nicht;
  bei Paketen zusätzlich „Paketbeleg vergessen — Kopie liegt in der Quarantäne“;
- **Begründung**: die Belege, die zur Aktion geführt haben — bei App-Resten etwa, warum die App
  als gelöscht gilt;
- die Knöpfe:
  - **Wiederherstellen…** öffnet das Blatt mit dem Plan — wie bei jeder Aktion
    ([Kapitel 5](05-eintraege-aendern.md)). Erst ein zweiter Klick führt aus. Bei leeren und
    wiederhergestellten Einträgen fehlt der Knopf; bei Einträgen, die nur im Terminal zurückgehen,
    steht an seiner Stelle der Befehl mit **Befehl kopieren** ([unten](#wer-was-wiederherstellt)).
  - **Im Finder zeigen** öffnet den Ordner des Eintrags.
  - **Endgültig löschen…** (seit 1.2) löscht den Eintrag ohne Rückweg — erst nach dem Plan,
    siehe [unten](#endgültig-löschen).

### Symbolleiste

- **Leere Einträge entfernen (N)** (seit 1.2.1) erscheint nur, wenn **deine** Quarantäne leere
  Einträge hat. Nach einer Rückfrage („N leere Einträge entfernen?“) löscht es genau die Einträge,
  in denen keine Datei liegt — gescheiterte Versuche —, unter deinem Namen, ohne Touch ID.
  Einträge mit Dateien bleiben; es geht nichts verloren, was sich wiederherstellen ließe. Danach
  steht unter der Einleitung „N leere Einträge entfernt.“ Leere Einträge der Ablage **des
  Systems** räumt der Knopf nicht mit weg — sie bleiben eine Entscheidung je Eintrag mit
  **Endgültig löschen…** und Touch ID.
- **Neu laden** liest die Quarantäne erneut, etwa nachdem du im Terminal etwas geändert hast.

Seit LaunchKeeperKit 0.13.1 entstehen keine neuen leeren Einträge mehr: Verschiebt ein Lauf
nichts, behält der Kern auch keinen Eintrag. Vorher legte jeder erneute Versuch einen leeren
Eintrag mit dem Stand `applied-fail` an; diese alten räumt **Leere Einträge entfernen** weg.

Mehrere Einträge auf einmal: Häkchen setzen, rechts **Aus der Quarantäne wiederherstellen**,
dann in der [Warteschlange](06-die-warteschlange.md) ausführen — Einträge des Systems mit einer
einzigen Touch-ID-Abfrage.

### Wer was wiederherstellt

| Eintrag | Wiederherstellen |
|---|---|
| in **deiner** Ablage, alle Pfade in deinem Benutzerordner | die App selbst, ohne Administratorrechte |
| in der Ablage **des Systems** | das Hilfsprogramm, nach Touch ID oder Passwort |
| in **deiner** Ablage, aber mit Pfaden außerhalb deines Benutzerordners | **nur im Terminal** |

Die letzte Zeile betrifft vor allem Pakete, die du mit der Kommandozeile deinstalliert hast:
Die Kommandozeile legt auch solche Einträge in deine Ablage, das Zurücklegen braucht aber
Administratorrechte. Das Hilfsprogramm stellt nur Einträge wieder her, die es selbst angelegt
hat. Statt **Wiederherstellen…** zeigt die Detailspalte deshalb „Wiederherstellen nur im
Terminal: launchkeeper quarantine restore <Name>“ mit dem Knopf **Befehl kopieren**:

```bash
launchkeeper quarantine restore 2026-09-27-101500Z-uninstall-com.example.tool    # erst der Plan
launchkeeper quarantine restore 2026-09-27-101500Z-uninstall-com.example.tool --apply
```

Für die Schritte, die root brauchen, fragt `launchkeeper` per `sudo` nach deinem Passwort.

### Was das Hilfsprogramm ablehnt

Auch bei Einträgen seiner eigenen Ablage prüft das Hilfsprogramm unmittelbar vor dem
Zurücklegen, ob es dem Eintrag trauen kann. Es lehnt ab, wenn

- ein ursprünglicher Pfad **in deinem Benutzerordner** liegt — root schreibt dort nicht,
- ein ursprünglicher Pfad **dort liegt, wo Benutzer schreiben können**: `/Users/`, die
  temporären Ordner, `/Volumes/`, `/opt/homebrew/` oder unter einem Ordner, den ein Benutzer
  ohne Administratorrechte ändern kann,
- ein Pfad unter `/System` liegt oder kein sauberer absoluter Pfad ist,
- im Eintrag etwas nicht root gehört, ein Verweis (Symlink) steckt oder ein Pfad nicht zu seinem
  Ursprung passt.

In den ersten beiden Fällen nennt die Begründung den Weg, der noch geht: `launchkeeper quarantine
restore <Name>` im Terminal.

> **Wiederherstellen überschreibt nie.** Liegt am ursprünglichen Ort inzwischen etwas Neues, wird
> dieser Pfad übersprungen und im Ergebnis genannt.

## Endgültig löschen

Einen Eintrag der Quarantäne endgültig zu löschen ist die einzige echte Löschung in LaunchKeeper.
Danach gibt es keinen Rückweg mehr. Deshalb geschieht es nur ausdrücklich und einen Eintrag nach
dem anderen — in der App oder im Terminal.

### In der App

Seit 1.2 gibt es in der Ansicht **Quarantäne** **Endgültig löschen…** — seit 1.2.1 in der
Detailspalte des gewählten Eintrags. Der Knopf öffnet das gewohnte Blatt:

- **Erst der Plan.** Ein einziger Schritt, `rm -rf -- <Ordner des Eintrags>` — „delete the
  quarantine entry for good — NOT restorable“ (Meldungen des Kerns bleiben englisch); dazu der
  Hinweis des Kerns, wie viele Pfade gelöscht würden, und eine Warnung, wenn der Eintrag nicht
  vollständig angelegt wurde.
- **Ein roter Hinweis** über den Knöpfen: „Nicht wiederherstellbar: Die Dateien dieses Eintrags
  werden gelöscht, nicht in den Papierkorb gelegt. Es gibt danach keinen Rückweg.“
- **Endgültig löschen** führt aus — „Endgültig löschen (Touch ID)“, wenn es über das
  Hilfsprogramm geht. Die Eingabetaste löst diesen Knopf nicht aus; es braucht einen bewussten
  Klick.

Es gibt dafür keine Häkchen und keinen Platz in der Warteschlange. Auch wiederhergestellte
Einträge lassen sich löschen; dann verschwindet, was von ihnen noch übrig ist.

### Wer was löscht

| Eintrag | Endgültig löschen |
|---|---|
| in der Ablage **des Systems** | das Hilfsprogramm, nach Touch ID oder Passwort — jedes Mal |
| in **deiner** Ablage, durch und durch deiner | die App selbst, ohne Administratorrechte und ohne Touch ID |
| in **deiner** Ablage, mit Dateien, die nur root löschen darf | **nur im Terminal** |

- **Ablage des Systems:** Alles, was die App mit Administratorrechten getan hat. Bevor das
  Hilfsprogramm löscht, prüft es, dass der Eintrag einer seiner eigenen ist — er gehört root und
  war für niemand sonst schreibbar.
- **Durch und durch deiner** heißt: Jeder Ordner im Eintrag gehört dir und ist für dich
  schreibbar, und keine Datei ist gesperrt oder unveränderbar. Das ist der typische Fall bei
  App-Resten.
- **Mit Dateien, die nur root löschen darf** — etwa ein Paket, das du mit der Kommandozeile über
  `sudo` deinstalliert hast: Das Blatt zeigt den Plan, kann ihn aber nicht ausführen. Unter
  „Braucht Administratorrechte“ erklärt es, dass das Hilfsprogramm nur Einträge löscht, die es
  selbst angelegt hat, und nennt den Befehl `launchkeeper quarantine purge <Name> --apply` mit
  **Kopieren**; im Terminal fragt macOS nach deinem Passwort (gesperrte Dateien vorher mit
  `chflags -R nouchg` entsperren). Es ist dieselbe Regel wie beim
  [Wiederherstellen](#wer-was-wiederherstellt) solcher Einträge.

### Im Terminal

```bash
launchkeeper quarantine list                     # was liegt dort, mit Namen
launchkeeper quarantine purge <Name>             # nur der Plan, nichts wird gelöscht
launchkeeper quarantine purge <Name> --apply     # endgültig löschen — NICHT wiederherstellbar
```

- **Ohne `--apply` passiert nichts.** Der Plan nennt, wie viele Pfade gelöscht würden, und warnt,
  wenn der Eintrag nicht vollständig angelegt wurde — dann erst `quarantine restore` prüfen.
- Gelöscht wird genau dieser eine Ordner; vorher prüft `launchkeeper`, dass er direkt in einer
  der beiden Quarantänen liegt. Einen Eintrag deiner Ablage, der durch und durch dir gehört,
  löscht es ohne `sudo` (seit LaunchKeeperKit 0.13); sonst mit `sudo rm -rf`, und das Terminal
  fragt nach deinem Passwort.
- Danach prüft `launchkeeper`, dass der Ordner wirklich weg ist.

## Andere Rückwege

Nicht alles geht über die Quarantäne. Jede Aktion nennt ihren Rückweg schon im Plan und im
Ergebnis (Zeile **Rückweg**).

### Deaktivieren ↔ Wieder aktivieren

**Deaktivieren** ändert nur einen Zustand, keine Datei. Der Rückweg ist **Wieder aktivieren** am
selben Eintrag — in der Detailspalte oder in der Warteschlange. Deaktivierte Einträge bleiben im
Inventar sichtbar.

### Sicherungen der Startordner

**Entfernen** einer verwaisten Startdatei ist die eine Aktion, die eine Datei löscht. Vorher
sichert LaunchKeeper die Startordner — ohne Sicherung keine Löschung:

| Wer | Wohin |
|---|---|
| App ohne Administratorrechte, Kommandozeile | `~/Library/Application Support/launchkeeper/backups` |
| Hilfsprogramm | `/Library/Application Support/launchkeeper/backups` |

Der Rückweg im Ergebnis nennt die Sicherung beim Namen. Zurückgelegt wird im Terminal; der
Befehl findet Sicherungen in beiden Orten:

```bash
launchkeeper restore <Sicherung>              # Plan
launchkeeper restore <Sicherung> --apply      # zurückkopieren
launchkeeper enable <Label> --now --apply     # und wieder laden
```

### Kopien von Konfigurationsdateien

Bevor LaunchKeeper eine Konfigurationsdatei ändert — deine crontab, die Einstellungen des
Anmeldefensters —, legt es eine Kopie ab: in deinem Benutzerordner unter
`~/Library/Application Support/launchkeeper/config-snapshots`, beim Hilfsprogramm unter
`/Library/Application Support/launchkeeper/config-snapshots`. Der Rückweg im Plan nennt den
Befehl, der den alten Stand aus dieser Kopie wiederherstellt.

### Rückwege in der Warteschlange

Nach einem Lauf der Warteschlange legt **Rückwege hinzufügen** für alles, was in dieser Sitzung
erledigt wurde, den Rückweg als neue Einträge an: **Deaktivieren** ↔ **Wieder aktivieren**, und
**Aus der Quarantäne wiederherstellen** für alles, was in die Quarantäne ging. Für gelöschte
verwaiste Startdateien gibt es dort keinen Eintrag — deren Rückweg ist die Sicherung oben.
Einzelheiten in [Kapitel 6](06-die-warteschlange.md#aufräumen-und-rückwege).

## Weiter

- [Kapitel 9 — Sicherheit und Datenschutz](09-sicherheit-und-datenschutz.md)
