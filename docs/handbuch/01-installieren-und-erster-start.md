# Installieren und der erste Start

LaunchKeeper zeigt alles, was auf deinem Mac **automatisch startet**, und erklärt jeden Eintrag
in Klartext. Ohne dein Zutun ändert es nichts: Jede Änderung zeigt vorher ihren Plan, lässt sich
rückgängig machen und wird danach geprüft.

Dieses Kapitel bringt die App auf den Mac und erklärt das Fenster.

## Voraussetzungen

- **macOS 14** (Sonoma) oder neuer.
- Apple-Silicon- oder Intel-Mac — die App ist universal.

## Installieren

### Über das Disk-Image

1. Lade `LaunchKeeper-<version>.dmg` von den
   [Releases auf GitHub](https://github.com/tietjen/launchkeeper-app/releases).
2. Öffne das Disk-Image und zieh **LaunchKeeper** auf den Ordner **Applications** daneben.

Die App ist mit einer Developer ID signiert und von Apple **notariell beglaubigt**; App und
Disk-Image tragen das Ticket („gestapelt“). Gatekeeper lässt sie deshalb ohne Rückfrage
starten — auch ohne Internetverbindung.

### Mit Homebrew

```bash
brew trust tietjen/tap
brew install --cask tietjen/tap/launchkeeper-app
```

Die erste Zeile brauchst du **einmal** ab Homebrew 7: Fremden Taps vertraut Homebrew sonst nicht.

> **Lass die App im Ordner Programme.** Das Hilfsprogramm für Administratorrechte
> ([Kapitel 4](04-das-hilfsprogramm.md)) startet macOS aus dem Inneren des App-Pakets. Liegt die
> App woanders oder wird sie nicht aus ihrem Paket gestartet, meldet LaunchKeeper beim
> Hilfsprogramm „nicht gefunden — die App muss aus ihrem Bundle gestartet werden“.

## Sprache

LaunchKeeper spricht **Deutsch und Englisch** und richtet sich nach der Sprache von macOS. Bei
jeder anderen Systemsprache erscheint die App auf Englisch.

Auch die **Kategorien** in der Seitenleiste tragen deutsche Namen („Hintergrunddienste (launchd)“,
„App-Erweiterungen“ …). Englisch bleibt nur, was unverändert aus dem Kern (LaunchKeeperKit)
darunter kommt: die **Begründungen**, mit denen eine Änderung abgelehnt wird
([Kapitel 5](05-eintraege-aendern.md)), und einige Rohwerte wie die Herkunft (`homebrew`,
`manual` …) oder der Stand eines Quarantäne-Eintrags (`applied-ok`).

## Der erste Start

### Die Einführung

Beim ersten Start führt dich eine **Einführung** in zehn Schritten durch das Fenster. Jeder
Schritt rahmt den Teil des Fensters ein, um den es geht — die Seitenleiste, die Liste, die
Detailspalte, die drei Knöpfe der Symbolleiste, die Ansichten, die Beobachtung, die
Warteschlange — und erklärt ihn in einer Karte daneben. Begrüßung, Hilfsprogramm und Abschluss
kommen als Blatt in der Fenstermitte.

- **Los geht's** startet, **Weiter** und **Zurück** blättern, **Schließen** hört mittendrin auf.
- **Überspringen** auf der ersten Karte schließt die Einführung gleich.
- Ein Klick neben die Karte oder **Esc** beendet sie ebenfalls.

**Abschalten:** Auf der ersten und der letzten Karte steht **Beim Start zeigen**. Nimm das
Häkchen weg, und die Einführung kommt beim nächsten Start nicht mehr. Dieselbe Einstellung steht
in den Einstellungen (**⌘,**) unter **Hilfe** als **Einführung beim Start zeigen**.

**Zurückholen:** jederzeit über **Hilfe › Einführung zeigen** oder in den Einstellungen unter
**Hilfe** mit **Einführung jetzt zeigen**.

Im selben Menü steht **Hilfe › LaunchKeeper-Hilfe** (**⌘?**): die Kurzfassung dieses Handbuchs,
nach Kapiteln geordnet und durchsuchbar.

### Das erste Einlesen

Gleich nach dem Start liest LaunchKeeper das **Inventar** ein — alles, was auf diesem Mac
automatisch startet. Unten im Fenster steht währenddessen die **Statusleiste** mit
„Inventar wird gelesen …“.

> **Das allererste Einlesen kann Minuten dauern.** Ein Teil des Inventars kommt aus den
> Hintergrundaufgaben (Background Task Management, kurz BTM) von macOS. Hat der Dienst dahinter
> länger geruht, prüft er bei der ersten Abfrage alle registrierten Programme neu. Die
> Statusleiste sagt dann „Inventar
> wird gelesen — die erste Abfrage der Hintergrundaufgaben kann einige Minuten dauern …“. Danach
> geht es in Sekunden.

**Touch ID beim Start?** Die Liste der Hintergrundaufgaben gibt macOS nur mit
Administratorrechten heraus. Ohne eingerichtetes Hilfsprogramm fragt macOS deshalb beim Start nach
Touch ID oder deinem Passwort. Brichst du ab, fehlt dieser Teil, und die Statusleiste meldet das
Inventar als unvollständig
([Kapitel 2](02-das-inventar.md)). Mit dem Hilfsprogramm liest LaunchKeeper diese Liste ohne
Rückfrage ([Kapitel 4](04-das-hilfsprogramm.md)).

## Das Fenster

LaunchKeeper hat **ein Hauptfenster**. Öffnest du es noch einmal — aus der Menüleiste, über eine
Mitteilung oder das Hilfe-Menü —, kommt dasselbe Fenster nach vorn, auch wenn es im Dock liegt.

Drei Spalten:

- **Links** die Seitenleiste: unter **Inventar** „Alle Einträge“ und „Verwaist“, darunter die
  **Kategorien**, die auf diesem Mac vorkommen, dann die **Ansichten** (Hintergrund, Pakete,
  App-Reste, Quarantäne, Beobachtung) und ganz unten unter **Stapelverarbeitung** die
  **Warteschlange**. Die Zahl hinter einer Zeile sagt, wie viele Einträge dahinterstecken.
- **In der Mitte** die Liste der Einträge — oder, bei einer Ansicht, deren eigene Liste.
- **Rechts** die Detailspalte: was der gewählte Eintrag bedeutet und was du tun kannst. Ohne
  Auswahl steht dort „Nichts gewählt“.

### Die Symbolleiste

Oben rechts stehen drei Knöpfe, von links:

| Knopf | Was er tut |
|---|---|
| **Expertenmodus** | schaltet die Detailspalte zwischen Kurzfassung und allen Details um (⌥⌘E) |
| **Apple ausblenden** | blendet Apples eigene Systemeinträge aus oder ein |
| **Neu einlesen** | liest das Inventar neu ein (⌘R) |

Die Symbole zeigen den **aktuellen Zustand**, der Hinweis beim Darüberfahren sagt, was ein Klick
tut. Daneben steht das **Suchfeld**. Einzelne Ansichten bringen eigene Knöpfe mit — etwa
**Nur mit fehlenden Dateien** bei den Paketen ([Kapitel 3](03-die-ansichten.md)).

### Die Statusleiste unten

Die **Statusleiste** schwebt am unteren Fensterrand und erscheint nur, wenn es etwas zu sagen
gibt: während des
Einlesens mit Fortschritt, und danach als Warnung, solange das Inventar **unvollständig** ist.
Sonst ist sie weg.

## Das Auge in der Menüleiste

Solange die **Beobachtung** läuft, steht ein **Auge** in der Menüleiste — auch ohne offenes
Fenster. Darüber öffnest du LaunchKeeper, siehst die letzten Änderungen und schaltest die
Beobachtung aus. Mehr dazu in [Kapitel 7](07-beobachtung.md).

## Updates

LaunchKeeper aktualisiert sich selbst (über das Update-Framework Sparkle):

- **Automatisch:** Die App sucht von sich aus nach neuen Versionen. Abschalten kannst du das in
  den Einstellungen unter **Updates** mit **Automatisch nach Updates suchen**.
- **Von Hand:** **LaunchKeeper › Nach Updates suchen …** oder in den Einstellungen **Jetzt nach
  Updates suchen**. Dort steht auch die installierte **Version**.

Jedes Update ist mit LaunchKeepers Schlüssel **signiert**, und die App prüft diese Signatur, bevor
sie etwas installiert. Gefragt wird dafür bei GitHub, wo die Releases liegen — das ist die einzige
Verbindung ins Internet, die LaunchKeeper von sich aus aufbaut.

Das Hilfsprogramm kommt mit dem Update und wechselt nach einer ruhigen Minute von selbst auf die
neue Version ([Kapitel 4](04-das-hilfsprogramm.md)).

## Die Einstellungen

**LaunchKeeper › Einstellungen …** (**⌘,**) hat vier Bereiche:

| Bereich | Worum es geht |
|---|---|
| **Hilfsprogramm für Administratorrechte** | einrichten, prüfen, entfernen ([Kapitel 4](04-das-hilfsprogramm.md)) |
| **Beobachtung** | Beobachtung, Mitteilungen, Start bei der Anmeldung ([Kapitel 7](07-beobachtung.md)) |
| **Hilfe** | Einführung beim Start, Einführung jetzt zeigen, Hilfe öffnen |
| **Updates** | Version, automatische Suche, jetzt suchen |

## Weiter

- [Kapitel 2 — Das Inventar lesen](02-das-inventar.md)
