# Die Ansichten

Die Liste aller Einträge beantwortet die Frage „Was startet hier?“. Für andere Fragen hat
LaunchKeeper eigene **Ansichten** — in der Seitenleiste unter **Ansichten** und, ganz unten, die
**Warteschlange**. Jede beginnt mit einem grauen Satz, der sagt, was sie zeigt und was du dort
tun kannst.

| Ansicht | Die Frage dahinter |
|---|---|
| **Hintergrund** | Welche App darf was im Hintergrund — und warum ist etwas aus? |
| **Pakete** | Was hat ein Installationsprogramm hinterlassen? |
| **App-Reste** | Was blieb von gelöschten Apps übrig? |
| **Quarantäne** | Was hat LaunchKeeper weggenommen, und wie kommt es zurück? |
| **Beobachtung** | Was ist neu dazugekommen oder hat sich geändert? |
| **Warteschlange** | Was soll in einem Rutsch erledigt werden? |

## Hintergrund

Diese Ansicht baut nach, was macOS unter **Systemeinstellungen › Allgemein › Anmeldeobjekte &
Erweiterungen** zeigt — dieselbe Liste, mit dem, was dahintersteckt.

- **Beim Anmelden öffnen** — Apps, die du (oder sie selbst) als Anmeldeobjekt eingetragen hast.
- **Im Hintergrund erlauben — Apps und Entwickler** — eine Zeile je App oder Entwickler, wie in
  den Systemeinstellungen, mit dem Zustand des Schalters rechts:

  | Anzeige | Bedeutung |
  |---|---|
  | **an** (grün) | darf im Hintergrund laufen |
  | **aus** (grau) | in den Systemeinstellungen ausgeschaltet |
  | **gemischt** (orange) | ein Teil der Komponenten an, ein Teil aus |
  | **App** (blau) | die App selbst ist als Hintergrundobjekt registriert |
  | **–** (grau) | nichts registriert — weder Komponenten noch die App selbst |

- **Im Hintergrund erlauben — ohne Entwicklerangabe** — Einträge, für die macOS keinen
  Entwickler kennt, meist nicht signierte Werkzeuge oder Skripte. Die Systemeinstellungen nennen
  sie nach dem Programm, das sie startet; deshalb tauchen dort Namen wie „bash“ oder „arch“
  mehrfach auf. LaunchKeeper schreibt in die zweite Zeile, was tatsächlich dahintersteckt.

### Schalter oder launchd

Ein Eintrag kann auf zwei Wegen abgeschaltet sein, und die Systemeinstellungen zeigen nur einen
davon:

- **Der Schalter von macOS** — das, was du in den Systemeinstellungen umlegst. Ihn zeigt diese
  Ansicht als „an“ oder „aus“.
- **Eine launchd-Einstellung** — so schaltet LaunchKeeper (oder `launchctl disable`) einen
  Dienst ab. Die Systemeinstellungen sehen das nicht: Dort kann „an“ stehen, während der Dienst
  trotzdem nicht startet. LaunchKeeper markiert solche Zeilen mit einem **orangen Ausrufezeichen**
  („Mindestens eine Komponente ist per launchd deaktiviert — in der Systemeinstellung unsichtbar“).

### Die Detailspalte

Zu einer Zeile zeigt die rechte Spalte die Ampel, die Fakten (App- oder Entwickler-Eintrag, Team,
Anzahl der Komponenten) und darunter **Komponenten** — jede mit ihrem Zustand, „launchd: aus“ und
„läuft“, wo es zutrifft.

Unter den nächsten Schritten:

- **In den Systemeinstellungen umschalten** — **Öffnen** führt dich an die richtige Stelle.
  Diesen Schalter verwaltet macOS selbst; LaunchKeeper schreibt dort nicht hinein.
- **„…“ im Inventar zeigen** — springt zu der einzelnen Komponente in der Liste aller Einträge.
  Dort lässt sie sich einzeln steuern, etwa per launchd deaktivieren.

## Pakete

Installationspakete (`.pkg`) hinterlassen einen **Beleg**: eine Liste aller Dateien, die sie
installiert haben. Diese Ansicht zeigt jeden Beleg auf dem Mac mit **Paket** (der genauen
Paket-ID), **Version**, **Installiert** (Datum), **Dateien**, **Fehlen** und den **Einträgen** im
Inventar, die zu dem Paket gehören.

Fehlen Dateien, wurde das Programm meist schon gelöscht — etwa in den Papierkorb gezogen —, und
der Beleg ist liegen geblieben. Der Knopf **Nur mit fehlenden Dateien** in der Symbolleiste zeigt
nur solche Pakete.

Die Detailspalte urteilt nach den **eigenen** Dateien des Pakets. Geteilte Ordner wie
`/Applications`, die ein Beleg mitführt, zählen dabei nicht — sie gibt es immer.

| Befund | Bedeutung |
|---|---|
| „Installiertes Paket“ | alle eigenen Dateien sind da |
| „Teilweise noch installiert“ | ein Teil fehlt („… von … eigenen Dateien fehlen“) |
| „Installationsbeleg ohne Dateien …“ | das Programm ist weg, nur der Beleg blieb |

Darunter steht, was zu dem Paket **automatisch startet**, und einer von zwei Schritten:

- **Deinstallieren (Vorschau)** — solange noch Dateien da sind. Genommen wird nur, was noch
  **unverändert** vom Paket stammt; veränderte und mit anderen Paketen geteilte Dateien bleiben.
  Was genommen wird, wandert in die Quarantäne und lässt sich wiederherstellen. Erst wenn nichts
  Eigenes mehr übrig ist, wird auch der Beleg vergessen.
- **Beleg entfernen** — wenn alle Dateien längst fehlen. LaunchKeeper vergisst den Beleg und legt
  eine Kopie in die Quarantäne.

Beides braucht Administratorrechte und läuft über das Hilfsprogramm
([Kapitel 4](04-das-hilfsprogramm.md)). Der Plan zeigt vorher Datei für Datei, was sich bewegt und
was bleibt ([Kapitel 5](05-eintraege-aendern.md)).

> Ein App-Paket, das sich seit der Installation selbst aktualisiert hat, bleibt **ganz** stehen.
> Die unveränderte Hälfte herauszunehmen hinterließe eine kaputte App.

## App-Reste

Löscht man eine App, bleiben ihre Einstellungen, Caches und Daten in `~/Library` (und manchmal in
`/Library`) liegen. Diese Ansicht sucht sie.

Beim ersten Öffnen prüft LaunchKeeper, welche Apps **wirklich** weg sind — in den
Programme-Ordnern, bei LaunchServices und bei Spotlight („Prüfe, welche Apps wirklich weg sind —
LaunchServices, Spotlight, App-Ordner …“). Das dauert etwa eine halbe Minute.

Jede Zeile nennt die Bundle-ID, die Größe und das Urteil. Gezeigt wird zunächst nur, was
nachweislich zu einer gelöschten App gehört (Urteil `gone`, orange).

### Urteil und Begründung

In der Detailspalte steht das Urteil mit seiner Begründung:

| Überschrift | Urteil |
|---|---|
| „Reste einer gelöschten App“ | die App ist nicht mehr installiert — mit den Belegen dafür und dem, woran man erkennt, dass es eine App war |
| „Daten einer installierten App“ | die App ist noch da, mit dem Grund |
| „Nicht sicher zuzuordnen“ | das Urteil ist unsicher, etwa weil eine andere App desselben Herstellers noch installiert ist |
| „Daten eines Werkzeugs oder Frameworks“ | keine App gefunden — aber nichts zeigt, dass es je eine App war |

Die Hürde ist absichtlich hoch: Antwortet Spotlight nicht, heißt das „unsicher“, nie „weg“. Und
ohne Spuren einer echten App (Sandbox-Container, gespeicherter Fensterzustand, typische
Einstellungen grafischer Apps) gilt ein Ordner nicht als App-Rest.

**Auch vorhandene/unklare zeigen** in der Symbolleiste listet zusätzlich alles, was nicht
eindeutig weg ist — nützlich, wenn du wissen willst, warum etwas **nicht** angeboten wird.

**Neu prüfen** sucht die App-Reste noch einmal. Das Inventar liest es nicht neu ein; dafür ist
**Neu einlesen** (⌘R) da.

### In die Quarantäne verschieben

Bei einer gelöschten App steht unter den nächsten Schritten **In die Quarantäne verschieben**:
Einstellungen, Caches und App-Daten wandern in die Quarantäne und lassen sich zurückholen, falls
die App zurückkommt. Darunter steht jeder einzelne Pfad mit **… im Finder zeigen**.

> Liegen Reste auch in `/Library`, braucht das Verschieben Administratorrechte. Diese Aktion führt
> die App selbst nicht mit Administratorrechten aus; das Blatt nennt dann den Befehl für das
> Terminal ([Kapitel 5](05-eintraege-aendern.md)).

## Quarantäne

Alles, was LaunchKeeper wegnimmt, landet hier — **verschoben, nicht gelöscht**. Jede Zeile ist
ein **Eintrag** der Quarantäne: das Paket oder die Bundle-ID, die Anzahl der Pfade („… Pfad(e)“), der Status (etwa
`applied-ok` oder `restored`) und das Datum.

Ein Klick auf das Dreieck klappt den Eintrag auf: die ursprünglichen Pfade, ein Hinweis, wenn
dabei ein Paketbeleg vergessen wurde („Paketbeleg vergessen — Kopie liegt in der Quarantäne“),
und die Knöpfe:

- **Wiederherstellen…** — öffnet das Blatt mit dem Plan, wie bei jeder Aktion
  ([Kapitel 5](05-eintraege-aendern.md)). Wiederherstellen überschreibt nie: Steht am alten Ort
  inzwischen etwas Neues, wird dieser Pfad übersprungen und genannt.
- **Im Finder zeigen** — öffnet den Ordner des Eintrags.

**Neu laden** in der Symbolleiste liest die Quarantäne neu, etwa nachdem du im Terminal etwas
geändert hast.

### Zwei Quarantänen

App und Kommandozeile teilen sich die Quarantäne. Es gibt davon zwei:

| Ort | Was dort liegt |
|---|---|
| `~/Library/Application Support/launchkeeper/quarantine` | was die App ohne Administratorrechte weggenommen hat, und was die Kommandozeile dort ablegt |
| `/Library/Application Support/launchkeeper/quarantine` | was das Hilfsprogramm weggenommen hat; der Ordner gehört root |

Die Ansicht zeigt beide zusammen. Wiederherstellen aus der zweiten läuft über das Hilfsprogramm
und fragt nach Touch ID.

> Einen Eintrag in **deiner** Quarantäne, der Dateien außerhalb deines Benutzerordners bewegt hat
> — meist mit der Kommandozeile angelegt —, stellt das Hilfsprogramm nicht wieder her: Es setzt
> nur zurück, was es selbst verwahrt. Statt **Wiederherstellen…** steht dann „Nur im Terminal:
> launchkeeper quarantine restore …“ mit **Befehl kopieren**.

### Endgültig löschen

In der App gibt es das nicht, mit Absicht. Endgültig gelöscht wird nur im Terminal, ein Eintrag
nach dem anderen:

```bash
launchkeeper quarantine purge <name>          # zeigt nur den Plan
launchkeeper quarantine purge <name> --apply  # löscht wirklich
```

`purge` löscht immer über `sudo`; das Terminal fragt nach deinem Passwort. Mehr zu
Rückwegen in [Kapitel 8](08-quarantaene-und-rueckwege.md), zur Kommandozeile in
[Kapitel 10](10-kommandozeile.md).

## Beobachtung

Die Beobachtung meldet, wenn etwas Neues automatisch starten will oder sich ein Eintrag ändert —
auf Wunsch auch mit geschlossenem Fenster. Die Zahl hinter **Beobachtung** in der Seitenleiste
zählt die neuen und geänderten Einträge, die nicht von LaunchKeeper selbst stammen. Wie du sie einschaltest und was sie meldet, steht in
[Kapitel 7](07-beobachtung.md).

## Warteschlange

In jeder Ansicht haben die Zeilen ein Häkchen. Markierst du welche, steht oben auf der
Detailspalte das **Auswahlfeld** („N markiert“) mit **Zur Warteschlange hinzufügen** und den
passenden Aktionen; **Markierung aufheben** nimmt die Häkchen wieder weg. In der Warteschlange
rechnest du alles mit **Plan prüfen** durch und führst es mit **Alle ausführen** aus — mit einer einzigen Touch-ID-Abfrage für den ganzen Lauf. Die
Zahl hinter **Warteschlange** zählt die offenen Einträge. Alles Weitere in
[Kapitel 6](06-die-warteschlange.md).

## Weiter

- [Kapitel 4 — Das Hilfsprogramm einrichten](04-das-hilfsprogramm.md)
