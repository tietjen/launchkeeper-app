# Beobachtung und Mitteilungen

Das Inventar zeigt, was jetzt da ist. Die **Beobachtung** sagt dir, wenn sich daran etwas
ändert: wenn etwas Neues automatisch starten will oder ein vorhandener Eintrag sich ändert —
etwa weil ein Installationsprogramm einen Dienst hinterlegt oder eine App sich eine
Hintergrundaufgabe einrichtet.

Die Beobachtung liest nur. Sie verhindert nichts, sondern meldet, was geschehen ist; was du dann
tust, entscheidest du in der Detailspalte des Eintrags.

## Einschalten

Zwei Wege, beide schalten dasselbe:

- In der Seitenleiste unter **Ansichten** auf **Beobachtung**, dann oben den Schalter
  **Beobachtung** umlegen.
- In den **Einstellungen** (⌘,), Abschnitt **Beobachtung**: **Neue Autostart-Einträge beobachten**.

Ab Werk ist die Beobachtung aus. Eingeschaltet bleibt sie es auch nach einem Neustart der App.
Beim ersten Einschalten fragt macOS, ob LaunchKeeper Mitteilungen senden darf.

Der Schalter **Mitteilungen** daneben (in den Einstellungen: **Mitteilung bei neuen oder
geänderten Einträgen**) entscheidet, ob du Banner bekommst. Ohne ihn sammelt die Beobachtung
weiter in ihrer Liste.

## Wann sie hinsieht

| Anlass | Was passiert |
|---|---|
| Eine **Autostart-Stelle wird geschrieben** | LaunchKeeper wartet **5 Sekunden** Ruhe ab (Installationsprogramme schreiben in Schüben) und liest dann neu ein |
| **Alle zehn Minuten** | ein vollständiger Vergleich — für das, was keine Datei hat, die man beobachten könnte |
| **Jedes andere Einlesen** | ⌘R, ⇧⌘R, **Jetzt prüfen** oder das Einlesen nach einer Aktion werden ebenfalls verglichen — nichts wird doppelt eingelesen |

Beobachtet werden die Startordner (`LaunchAgents`, `LaunchDaemons`), `/Library/PrivilegedHelperTools`,
`/Library/StartupItems`, `/Library/SystemExtensions`, die Autorisierungs-Plug-ins
(`/Library/Security/SecurityAgentPlugins`), `/etc/paths.d` und `/etc/manpaths.d`, die
Einstellungen des Anmeldefensters (`com.apple.loginwindow.plist`), `/etc/crontab`, `/etc/rc.local`,
die Shell-Startdateien (`/etc/zshrc`, `/etc/profile`, `~/.zshrc`, `~/.zprofile` und Verwandte) und
die oberste Ebene von `/Applications` und `~/Applications`. Was tief in App-Bundles oder in
anderen Einstellungsdateien geschrieben wird, löst nichts aus.

Kann macOS die Dateiereignisse nicht liefern, läuft nur der Zehn-Minuten-Vergleich; die
Statuszeile sagt dann „nur alle zehn Minuten (Dateiereignisse nicht verfügbar)“.

### Die Hintergrundaufgaben und Touch ID

Ein Teil des Inventars kommt aus den **Hintergrundaufgaben** von macOS (Background Task
Management, kurz BTM: die Anmeldeobjekte und „Im Hintergrund erlauben“). Sie frisch abzufragen kostet
etwas:

- **Mit Hilfsprogramm** liest das Hilfsprogramm sie ohne Rückfrage. Der Zehn-Minuten-Vergleich
  fragt sie dann jedes Mal frisch ab.
- **Ohne Hilfsprogramm** verlangt macOS für jede frische Abfrage Touch ID oder dein Passwort.
  Deshalb fragt der Zehn-Minuten-Vergleich sie dann **höchstens alle sechs Stunden** frisch ab
  und vergleicht sonst mit dem zuletzt gelesenen Stand. Ein abgebrochener Dialog zählt dabei als
  Abfrage — sonst käme er alle zehn Minuten wieder.
- Ist das Hilfsprogramm eingerichtet, antwortet aber nicht, nimmt LaunchKeeper den zuletzt
  gelesenen Stand, statt dich zu fragen — sofern es in dieser Sitzung schon einen gibt; sonst
  fragt macOS. Bis zum nächsten Versuch wartet es dann ebenfalls sechs Stunden.

Ein Einlesen, das eine Dateiänderung auslöst, nimmt den zuletzt gelesenen Stand der
Hintergrundaufgaben — eine kalte Abfrage kann Minuten dauern. Die übrigen Quellen liest es
frisch.

## Was gemeldet wird — und was nicht

Die erste vollständige Prüfung nach dem Einschalten ist der **Ausgangsstand**; die Statuszeile
zeigt dann „Aktiv — N Einträge im Blick, zuletzt geprüft …“. Jede weitere Prüfung wird mit der
vorherigen verglichen, Eintrag für Eintrag. Einträge von Apple und laufende Netzwerkdienste
gehören nicht dazu: Ein Programm, das gerade Verbindungen annimmt, ist kein neuer Autostart.

| Änderung | In der Liste | Mitteilung |
|---|---|---|
| **Neu: …** | ja, orange | ja |
| **Geändert: …** (mit den Feldern, die sich geändert haben) | ja, blau | ja |
| **Entfernt: …** | ja, grau | nein — was nicht mehr startet, ist kein Risiko |
| eigene Änderung, „durch LaunchKeeper“ | ja, grau | nein |

**Eigene Änderungen.** Was LaunchKeeper auf deinen Klick selbst geändert hat — eine einzelne
Aktion oder ein Lauf der Warteschlange —, steht mit „durch LaunchKeeper“ in der Liste und wird
nicht gemeldet. Das gilt auch für Unterschiede, die bis zu **30 Sekunden** nach dem Ende der
Aktion auftauchen: Ein Einlesen, das vor der Aktion begann, kann nach ihr fertig werden.

**Unvollständige Prüfungen werden nicht verglichen.** Hat eine Quelle nicht geantwortet — etwa
die Hintergrundaufgaben nach einer Zeitüberschreitung —, fehlen ganze Schichten. Ein Vergleich
meldete dann lauter „Entfernt“. Stattdessen sagt die Statuszeile „Letzte Prüfung unvollständig,
nicht verglichen: …“, und der Ausgangsstand bleibt, wie er war.

**Ausschalten vergisst den Ausgangsstand.** Schaltest du die Beobachtung wieder ein, ist die
nächste vollständige Prüfung der neue Ausgangsstand — was dazwischen geschah, meldet sie nicht.

## Die Liste und die Einzelheiten

Die Ansicht **Beobachtung** listet die Änderungen, die neueste oben, höchstens 200. Die Zahl
neben **Beobachtung** in der Seitenleiste zählt neue und geänderte Einträge, die nicht von
LaunchKeeper selbst kamen. **Liste leeren** leert die Liste; die Protokolldatei (siehe unten)
bleibt.

Ein Klick auf eine Zeile zeigt rechts:

- **Was** — **Kategorie** (hier als Rohwert des Kerns, etwa `launch-items`), **Pfad**, **Kennung** und bei Änderungen jedes Feld mit altem und
  neuem Wert.
- **Bemerkt** — **Wann**, den **Anlass** (zum Beispiel `fsevents: <Pfad>` für eine
  Dateiänderung, `interval` für den Zehn-Minuten-Vergleich, `manual rescan` für ⌘R) und die
  Zeile **Mitteilung**.
- **Im Inventar zeigen** — dort steht, was der Eintrag ist und was du tun kannst. Ist er nicht
  mehr da, steht „Der Eintrag ist im aktuellen Inventar nicht (mehr) vorhanden.“

### Die Zeile „Mitteilung“

Sie sagt nur, was sich messen lässt — was aus der Mitteilung zu diesem Eintrag geworden ist:

| Text (Beispiele) | Bedeutung |
|---|---|
| „keine — LaunchKeeper hat das selbst geändert“ | eigene Änderung |
| „keine — Entfernungen werden nur aufgelistet“ | Entfernung |
| „nicht gesendet: Mitteilungen sind in LaunchKeeper ausgeschaltet“ | Schalter **Mitteilungen** aus |
| „nicht gesendet: macOS erlaubt LaunchKeeper keine Mitteilungen (…)“ | keine Erlaubnis in macOS |
| „von macOS abgelehnt: …“ | macOS hat die Mitteilung mit einem Fehler zurückgewiesen |
| „an macOS übergeben um …; steht in der Mitteilungszentrale.“ | angekommen |
| „an macOS übergeben um …; nicht in der Mitteilungszentrale — schon weggeklickt oder von macOS zurückgehalten.“ | übergeben, aber nicht (mehr) sichtbar |
| „um … zur Anzeige freigegeben (LaunchKeeper war vorne; …)“ | LaunchKeeper war gerade im Vordergrund |
| „angezeigt und um … angeklickt“ | du hast darauf geklickt |
| „unbekannt (vor dem letzten Start der App bemerkt)“ | aus der Zeit vor dem letzten Start |

Ein Klick auf eine Mitteilung holt LaunchKeeper nach vorn und wählt den Eintrag aus — oder, wenn
er nicht mehr da ist, die Ansicht **Beobachtung**.

## Menüleiste und Start bei der Anmeldung

Solange die Beobachtung läuft, steht ein **Auge in der Menüleiste**, auch wenn kein Fenster offen
ist. Sein Menü zeigt „Beobachtung aktiv“, die letzten fünf fremden Änderungen (ein Klick öffnet
den Eintrag), **LaunchKeeper öffnen**, **Beobachtung ausschalten** und **LaunchKeeper beenden**.

Schließt du das Fenster, beobachtet die App weiter. Damit sie das auch nach einem Neustart des
Macs tut, schalte in den Einstellungen unter **Beobachtung** **Bei der Anmeldung starten** ein.
LaunchKeeper öffnet dann bei der Anmeldung sein Fenster; schließt du es, läuft die Beobachtung
weiter. Verlangt macOS eine Freigabe, erscheint **In den Systemeinstellungen erlauben**.

## Mitteilungen prüfen

Fehlt eine Mitteilung, hilft der Abschnitt **Beobachtung** in den Einstellungen:

- **Mitteilungen laut macOS** zeigt, was macOS erlaubt: „erlaubt“, „erlaubt, aber ohne Banner
  (Stil „Ohne“)“, „nicht erlaubt“ oder „noch nicht gefragt“. Die Zeile liest den Stand neu, wenn
  du aus den Systemeinstellungen zurückkommst.
- **Test-Mitteilung senden** schickt eine Mitteilung „LaunchKeeper-Test“, ohne dass sich etwas
  ändern muss. Darunter steht, was aus ihr wurde — dieselben Texte wie in der Zeile
  **Mitteilung**.
- **Erlaubnis anfragen** erscheint, solange macOS noch nicht gefragt hat.
- **Mitteilungseinstellungen öffnen** springt zu Systemeinstellungen › Mitteilungen ›
  LaunchKeeper: Erlaubnis, Stil, Ton.

> **Kein Banner, obwohl die Mitteilung freigegeben wurde?** Beim Teilen oder Spiegeln des
> Bildschirms — etwa über die Bildschirmfreigabe — unterdrückt macOS Banner standardmäßig.
> Einstellung: Systemeinstellungen › Mitteilungen › „Beim Spiegeln oder Teilen des Bildschirms“.
> Auch ein aktiver **Fokus** hält Banner zurück. Die Mitteilung steht dann trotzdem in der
> Mitteilungszentrale.

## Das gemeinsame Protokoll mit der Kommandozeile

Jede Änderung, die die Beobachtung bemerkt, hängt LaunchKeeper als eine JSON-Zeile an

```
~/Library/Logs/launchkeeper/watch.log
```

Dieselbe Datei schreibt auch `launchkeeper watch` im Terminal ([Kapitel 10](10-kommandozeile.md)),
im selben Format. Eigene Änderungen der App tragen dort einen Vermerk, damit sie auch nach einem
Neustart als „durch LaunchKeeper“ erkannt werden. Beim Start liest die App die letzten 200
Änderungen aus dieser Datei in ihre Liste — auch solche, die `launchkeeper watch` notiert hat.

## Weiter

- [Kapitel 8 — Quarantäne und Rückwege](08-quarantaene-und-rueckwege.md)
