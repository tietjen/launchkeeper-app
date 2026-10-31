# Einträge ändern

Jede Änderung in LaunchKeeper geht denselben Weg: **erst der Plan, dann dein zweiter Klick, dann
die Prüfung.** Nichts passiert nebenbei, und das meiste lässt sich zurücknehmen.

Dieses Kapitel beschreibt die einzelne Aktion. Viele Einträge auf einmal erledigst du über die
Warteschlange ([Kapitel 6](06-die-warteschlange.md)) — mit denselben Prüfungen.

## Der Ablauf

### 1. Ausführen…

In der Detailspalte stehen unter **Nächste Schritte** die Aktionen, die für diesen Eintrag
möglich sind. Jede hat rechts den Knopf **Ausführen…**. Ein Klick darauf ändert noch nichts — er
öffnet ein Blatt.

### 2. Der Plan

Das Blatt trägt den Namen der Aktion, etwa „Deaktivieren“. Zuerst steht dort „Plan wird berechnet
— das Inventar wird dafür neu gelesen …“: LaunchKeeper rechnet den Plan gegen den **aktuellen**
Stand des Macs, nicht gegen den von vor fünf Minuten.

Dann kommt der Plan unter der Überschrift „Das würde passieren — noch ist nichts geändert:“:

- **jeder Schritt in Worten**, nummeriert,
- darunter **klein der Befehl**, der dafür läuft — zum Nachlesen und Kopieren,
- ein **Schloss** neben jedem Schritt, der Administratorrechte braucht,
- **Hinweise** des Kerns (LaunchKeeperKit): was bleibt, was übersprungen wird, worauf zu achten ist,
- der **Rückweg**: „Rückweg: …“ — wie du die Änderung zurücknimmst.

Lehnt die Prüfung die Aktion ab, steht statt des Plans die **Begründung** mit einer erhobenen Hand
(siehe [Die Prüfung](#die-prüfung)).

### 3. Der zweite Klick

Unten stehen **Abbrechen** und **Ausführen**. Braucht der Plan Administratorrechte, heißt der
Knopf **Ausführen (Touch ID)**, und darüber steht „Braucht Administratorrechte — nach dem Klick
fragt macOS nach Touch ID oder deinem Passwort.“

Erst dieser Klick ändert etwas. Während es läuft: „Wird ausgeführt und danach überprüft …“.

### 4. Die Prüfung danach

LaunchKeeper vertraut keinem Rückgabewert. Nach dem Ausführen liest es nach, ob der Eintrag
**wirklich** im erwarteten Zustand ist — launchd fragt es nach dem Zustand des Dienstes, beim
Entfernen sieht es im Dateisystem nach. Das Ergebnis:

| Meldung | Bedeutung |
|---|---|
| „Erledigt und überprüft“ | geändert, und die Änderung ist sichtbar |
| „Nicht vollständig: …“ | ein Schritt ist fehlgeschlagen oder die Prüfung sieht die Änderung nicht |
| Begründung mit erhobener Hand | abgelehnt — nichts ist gelaufen |

Hinweise und Rückweg stehen auch hier.

### 5. Fertig

**Fertig** schließt das Blatt. Danach liest LaunchKeeper das Inventar neu ein und lädt App-Reste
und Quarantäne neu, damit alle Ansichten den neuen Stand zeigen.

> Läuft gerade die Warteschlange, bleibt **Ausführen** ausgegraut: „Die Warteschlange läuft
> gerade — danach geht es weiter.“ Zwei Änderungen auf einmal würden sich gegenseitig die Prüfung
> verderben.

## Die Aktionen

| Nächster Schritt | Wo | Was passiert |
|---|---|---|
| **Deaktivieren (umkehrbar)** | Inventar | verhindert den automatischen Start; **Wieder aktivieren** macht es rückgängig |
| **Wieder aktivieren** | Inventar | hebt die Deaktivierung auf |
| **Entfernen** | Inventar, nur bei nachweislich verwaisten Einträgen | nimmt den Rest weg (siehe unten) |
| **In die Quarantäne verschieben** | Inventar, bei funktionierenden Einträgen | deaktiviert und verschiebt die Startdatei in die Quarantäne |
| **Deinstallieren (Vorschau)** | Pakete | verschiebt die unveränderten Dateien eines Pakets in die Quarantäne |
| **Beleg entfernen** | Pakete | vergisst einen Beleg ohne Dateien, Kopie in der Quarantäne |
| **In die Quarantäne verschieben** | App-Reste | verschiebt die Reste einer gelöschten App in die Quarantäne |
| **Wiederherstellen…** | Quarantäne | setzt einen Eintrag der Quarantäne an seinen alten Ort zurück |

### Deaktivieren und aktivieren

Was „deaktivieren“ heißt, hängt davon ab, wer den Schalter des Eintrags hält:

| Art | Deaktivieren | Aktivieren |
|---|---|---|
| LaunchAgent, LaunchDaemon | Sperre bei launchd setzen und den Dienst stoppen | Sperre aufheben |
| App-Erweiterung | auf „nicht verwenden“ stellen | wieder auf „verwenden“ |
| Zeile in deiner crontab | auskommentieren, mit Markierung | Markierung entfernen |
| Anmelde-/Abmelde-Skript | beiseitelegen | zurücklegen |
| Regel der Firewall | eingehende Verbindungen sperren | wieder erlauben |

Ein deaktivierter Eintrag bleibt im Inventar sichtbar, mit dem grauen Pause-Symbol — so findet
**Wieder aktivieren** ihn wieder.

> Eine launchd-Sperre sehen die Systemeinstellungen nicht. Unter Anmeldeobjekte & Erweiterungen
> kann ein so deaktivierter Dienst weiter „an“ zeigen. Die Ansicht **Hintergrund** markiert das
> ([Kapitel 3](03-die-ansichten.md)).

### Entfernen

**Entfernen** gibt es nur für Einträge, die nachweislich nichts mehr tun — das Programm ist weg,
nur die Startdatei ist übrig. Was dann passiert, sagt der Satz unter dem Schritt:

- **„Löscht die verwaiste Startdatei; vorher wird eine Sicherung angelegt.“** — bei einer
  verwaisten Startdatei (`.plist`) in einem der Launch-Ordner. Vor dem Löschen sichert LaunchKeeper
  den ganzen Ordner. Lässt sich diese Sicherung nicht schreiben, wird nichts gelöscht. Der Rückweg
  im Plan nennt die Sicherung.
- **„Verschiebt den Rest in die Quarantäne — jederzeit wiederherstellbar.“** — bei anderen Resten:
  einem Hilfsprogramm, das kein Dienst mehr startet, einem veralteten Startobjekt, einer
  Suchpfad-Datei, deren Ordner alle fehlen.

Etwas, das noch funktioniert, löscht LaunchKeeper nie.

### In die Quarantäne verschieben (funktionierende Einträge)

Soll ein Eintrag, der noch funktioniert, ganz verschwinden, steht nach **Deaktivieren** dieser
Schritt. Er **deaktiviert** den Eintrag und **verschiebt** seine Startdatei in die Quarantäne —
gelöscht wird nichts. Das Programm selbst bleibt.

Weil die Sperre bestehen bleibt, startet der Eintrag auch dann nicht, wenn eine App ihre
Startdatei neu anlegt. Deaktivieren ist der sanftere Schritt und genügt meistens; deshalb steht es
zuerst.

Einträge, die ein Konfigurationsprofil (MDM) verwaltet, bekommen diesen Schritt nicht: Da
entscheidet das Profil.

## Die Prüfung

Hinter jeder Aktion steht **dieselbe Prüfung wie bei der Kommandozeile** `launchkeeper`. Sie ist
eine Liste dessen, was erlaubt ist — nicht eine Liste dessen, was verboten ist —, und sie hat keine
Hintertür: Es gibt keinen Schalter, der sie übergeht.

Fest geschützt sind:

- **Einträge von Apple** (`com.apple.*`),
- **alles unter `/System`**,
- Apples eigene Erweiterungen und Programme.

Die App bietet unter **Nächste Schritte** nur an, was diese Prüfung besteht. Abgelehnt werden kann
trotzdem — dann, wenn sich zwischen Einlesen und Plan etwas geändert hat, denn der Plan rechnet mit
dem neuen Stand.

Die Begründungen kommen aus dem Kern (LaunchKeeperKit) und sind englisch. Einige Beispiele:

| Begründung | Was sie heißt |
|---|---|
| „Apple system component (com.apple.*) — read-only by policy“ | ein Eintrag von Apple |
| „not orphaned — a working component must be disabled (reversible), not deleted; …“ | er funktioniert noch — deaktivieren statt entfernen |
| „managed by a configuration profile (MDM) — the profile decides, not launchkeeper“ | ein Profil verwaltet ihn |

Zwei Meldungen kommen von der App selbst:

- „Anmeldung abgebrochen oder abgelehnt — nichts geändert“ — du hast die Touch-ID-Abfrage
  abgebrochen.
- „Das Hilfsprogramm hat nichts ausgeführt — auf dem Mac ist nichts geändert.“ — das
  Hilfsprogramm war nicht erreichbar. Meist hilft **Neu starten und erneut versuchen**: LaunchKeeper
  startet das Hilfsprogramm neu und rechnet den Plan noch einmal. **Einstellungen öffnen** führt zu
  den Einstellungen des Hilfsprogramms.

## Wann Administratorrechte nötig sind

| Braucht Administratorrechte | Braucht keine |
|---|---|
| Systemdienste (LaunchDaemons und andere Dienste der Systemdomäne) | deine eigenen LaunchAgents in `~/Library/LaunchAgents` |
| Dateien in `/Library`, auch LaunchAgents in `/Library/LaunchAgents` | App-Erweiterungen |
| systemweite Anmelde-/Abmelde-Skripte | Zeilen in deiner crontab |
| Regeln der Firewall | App-Reste in `~/Library` |
| Paket-Deinstallationen und das Entfernen von Belegen | Wiederherstellen aus deiner eigenen Quarantäne, wenn alles in deinem Benutzerordner lag |
| Reste außerhalb deines Benutzerordners | |

**Mit Hilfsprogramm** führt LaunchKeeper Schritte mit Administratorrechten darüber aus und fragt
dafür **einmal pro Aktion** nach Touch ID oder deinem Passwort, direkt vor dem Ausführen. Die
Freigabe gilt nur für diese eine Aktion.

**Ohne Hilfsprogramm** zeigt das Blatt den Plan, führt ihn aber nicht aus. Darunter steht
„Braucht Administratorrechte“ mit **Hilfsprogramm einrichten** (oder **In den Systemeinstellungen
erlauben**, wenn es nur noch auf die Freigabe wartet), **Einstellungen öffnen** und „Oder jetzt im
Terminal:“ mit dem fertigen Befehl und **Kopieren**. Im Terminal fragt macOS dann nach deinem
Passwort. Das Einrichten steht in [Kapitel 4](04-das-hilfsprogramm.md).

**Ohne Administratorrechte** läuft alles direkt aus der App. Es kommt keine Abfrage, und das
Hilfsprogramm ist nicht beteiligt.

> **App-Reste in `/Library`** führt die App auch mit Hilfsprogramm nicht mit Administratorrechten
> aus: Ob die App wirklich weg ist, kann nur die App in deiner Sitzung prüfen, nicht ein
> Systemdienst. Das Blatt sagt dann „Diese Aktion führt die App noch nicht mit
> Administratorrechten aus. Im Terminal geht es; dort fragt macOS nach deinem Passwort:“ und nennt
> den Befehl.

## Quarantäne statt Papierkorb

Was LaunchKeeper wegnimmt, **verschiebt** es in die Quarantäne, statt es zu löschen: Reste,
Startdateien funktionierender Einträge, Paketdateien, App-Reste. Von dort holst du es mit
**Wiederherstellen…** zurück ([Kapitel 3](03-die-ansichten.md),
[Kapitel 8](08-quarantaene-und-rueckwege.md)).

Die einzige Ausnahme ist die verwaiste Startdatei beim **Entfernen** — und die wird vorher
gesichert. Endgültig gelöscht wird aus der Quarantäne nur im Terminal, mit
`launchkeeper quarantine purge`.

## Sicherungen

Bevor LaunchKeeper etwas überschreibt oder löscht, sichert es den Stand:

- vor dem Entfernen einer Startdatei den ganzen Launch-Ordner,
- vor dem Ändern deiner crontab oder der Anmelde-/Abmelde-Skripte deren vollständigen Inhalt.

Die Sicherungen liegen in `~/Library/Application Support/launchkeeper/` (`backups`,
`config-snapshots`). Was das Hilfsprogramm sichert, liegt in
`/Library/Application Support/launchkeeper/`. Wie du eine Sicherung zurückspielst, nennt der
Rückweg im Plan.

## Das Protokoll

Jede Aktion hinterlässt eine Zeile im Protokoll — auch Pläne und Ablehnungen:

| Protokoll | Was darin steht |
|---|---|
| `~/Library/Logs/launchkeeper/operations.log` | was die App ohne Administratorrechte tut; dieselbe Datei wie bei der Kommandozeile |
| `/Library/Logs/launchkeeper/operations.log` | was das Hilfsprogramm mit Administratorrechten tut |

## Hier nicht steuerbar

Manche Schalter verwaltet macOS allein und lässt keine andere App daran: Anmeldeobjekte und
Hintergrunddienste von Apps, Systemerweiterungen, Kernel-Erweiterungen, Konfigurationsprofile,
Datenschutz-Freigaben. Bei solchen Einträgen steht unter **Nächste Schritte** **Hier nicht
steuerbar** mit dem Grund und dem Ort, wo der Schalter liegt.

Das ist keine Lücke, sondern Absicht: LaunchKeeper schreibt nicht in die Hintergrundaufgaben
(Background Task Management, kurz BTM) von macOS. Den Weg zeigt es trotzdem. Markierst du solche Einträge und legst sie mit **Als „Von Hand“
in die Warteschlange** dorthin, steht im Abschnitt **Von Hand** eine Anleitung mit einem Knopf, der
die richtige Stelle der Systemeinstellungen öffnet. Nach **Jetzt prüfen** hakt LaunchKeeper ab,
was sich erledigt hat. Mehr in [Kapitel 6](06-die-warteschlange.md).

## Weiter

- [Kapitel 6 — Die Warteschlange](06-die-warteschlange.md)
