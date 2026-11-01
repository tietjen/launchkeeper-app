# Sicherheit und Datenschutz

Ein Programm, das Systemdienste abschaltet und Dateien in `/Library` verschiebt, braucht
Rechte, die man nicht leichtfertig vergibt. Dieses Kapitel sagt, wie LaunchKeeper mit diesen
Rechten umgeht, was es liest, was den Mac verlässt — und wovor es dich nicht schützt.

## Die Leitsätze

1. **Lesen ist der Normalfall.** Das Inventar, die Ansichten und die Beobachtung ändern nichts.
2. **Erst der Plan, dann die Ausführung.** Jede Änderung zeigt vorher jeden Schritt und den
   Rückweg; ausgeführt wird erst auf deinen zweiten Klick.
3. **Eine Prüfung für alles.** App, Hilfsprogramm und Kommandozeile gehen durch dieselbe Prüfung
   mit denselben Regeln.
4. **Verschieben statt löschen.** Was wegkommt, landet in der Quarantäne
   ([Kapitel 8](08-quarantaene-und-rueckwege.md)).
5. **Geprüft, nicht geglaubt.** Nach jeder Änderung liest LaunchKeeper nach, ob der Eintrag
   wirklich im erwarteten Zustand ist. Ein Befehl, der „erfolgreich“ meldet, beweist nichts.

## Die Prüfung

Bevor ein Plan entsteht, entscheidet eine einzige Prüfung, ob eine Aktion überhaupt erlaubt ist.
Sie ist eine Erlaubnisliste, keine Verbotsliste, und hat **keinen Schalter, der sie umgeht** —
weder in der App noch als Option auf der Kommandozeile.

- **Einträge von Apple** (`com.apple.*`) und **alles unter `/System`** sind ausgeschlossen. Die
  App bietet für sie nicht einmal „Von Hand“ an.
- **Entfernen** löscht nur eine einzelne Startdatei, die nachweislich verwaist ist — und nur,
  nachdem eine Sicherung geschrieben wurde. Was noch funktioniert, wird deaktiviert oder in die
  Quarantäne verschoben, nie gelöscht.
- **Deinstallieren** nimmt nur Dateien, die nachweislich noch so sind, wie das Paket sie
  installiert hat (Größe und Prüfsumme); was ein anderes Paket ebenfalls aufführt, bleibt.
- **Ziele werden aus dem eigenen Inventar aufgelöst**, nie aus einer Befehlszeile. Eingaben
  werden nie zu Shell-Befehlen.

Die App selbst führt nie einen Schritt mit Administratorrechten aus: Ein Plan, der `sudo`
enthält, geht an das Hilfsprogramm, und der Teil der App, der Befehle ausführt, weist `sudo`
zusätzlich ab.

## Das Hilfsprogramm

Das Hilfsprogramm ist der einzige Teil von LaunchKeeper, der mit Administratorrechten läuft
([Kapitel 4](04-das-hilfsprogramm.md)). Es wird nicht von selbst eingerichtet: Wer nur schauen
will, bekommt keinen Dienst mit Administratorrechten.

### Wer mit wem spricht

Beide Seiten prüfen die Code-Signatur der anderen:

- Das Hilfsprogramm nimmt nur Verbindungen der LaunchKeeper-App an — Kennung
  `de.paranoidsecurity.LaunchKeeper`, signiert mit einem von Apple ausgestellten Zertifikat des
  Entwicklerteams `Y2LTPLFG6D`. Jedes andere Programm wird abgewiesen, auch eines, das unter
  deinem Namen läuft.
- Die App spricht nur mit dem echten Hilfsprogramm
  (`de.paranoidsecurity.LaunchKeeper.Helper`, gleiches Team).
- Wer fragt, entnimmt das Hilfsprogramm der Verbindung selbst, nie dem Inhalt der Anfrage.

### Was es annimmt

**Keine Befehle.** Eine Anfrage enthält nur „was mit welchem Eintrag“: Deaktivieren,
Wieder aktivieren, Entfernen, In die Quarantäne verschieben, Wiederherstellen, Endgültig löschen, Deinstallieren —
und den Namen des Eintrags, der Quarantäne oder des Pakets. Das Hilfsprogramm liest selbst ein,
löst den Eintrag selbst auf und schickt ihn durch dieselbe Prüfung wie die Kommandozeile.

Dazu kommen zwei Grenzen, die nur für das Hilfsprogramm gelten:

- **Einträge, die nur dir gehören** — deine LaunchAgents, Einstellungen in deinem
  Benutzerordner —, ändert es nicht. Das ist Sache der App, die das als du tut.
- **Aus Orten, in die Benutzer schreiben können** (`/Users/`, temporäre Ordner, `/Volumes/`,
  `/opt/homebrew/`, oder unter einem Ordner, den ein Benutzer ohne Administratorrechte ändern
  kann), verschiebt es nichts und legt dort nichts zurück.

### Touch ID — jedes Mal

Jede Änderung über das Hilfsprogramm braucht ein eigenes Recht,
`de.paranoidsecurity.LaunchKeeper.modify`. macOS fragt dafür nach Touch ID oder dem Passwort
eines **Administrators** — bei einer einzelnen Aktion mit dem Text „LaunchKeeper möchte einen
Autostart-Eintrag auf Systemebene ändern.“

- **Keine Schonfrist.** Eine Bestätigung gilt für genau eine Anfrage; die nächste fragt wieder.
- **Nicht geteilt.** Die Bestätigung gilt nicht für andere Programme.
- **Die Warteschlange** fragt einmal für den ganzen Lauf — für genau die Liste, deren Plan du
  vorher gesehen hast. Der Dialog nennt die Anzahl: „LaunchKeeper möchte N Autostart-Einträge
  ändern.“, bei einem einzigen Eintrag „LaunchKeeper möchte einen Autostart-Eintrag ändern.“
  ([Kapitel 6](06-die-warteschlange.md#alle-ausführen)).

Brichst du den Dialog ab, ändert das Hilfsprogramm nichts.

### Ein Baum, nur root schreibt

Was das Hilfsprogramm aufbewahrt — Quarantäne, Sicherungen, Kopien von Konfigurationsdateien —,
liegt unter `/Library/Application Support/launchkeeper/`, nie in deinem Benutzerordner. Der
Grund: In deinem Benutzerordner kann jedes Programm, das unter deinem Namen läuft, Ordner
umbenennen oder Verweise unterschieben. Ein Hilfsprogramm, das dort prüft und dann schreibt,
ließe sich zwischen beidem umlenken — auf Systemdateien.

Deshalb gilt:

- Der Baum gehört root und ist für niemanden sonst beschreibbar. Das Hilfsprogramm legt ihn an
  und prüft vor **jeder** Anfrage den ganzen Weg von `/` aus: echte Ordner, keine Verweise,
  Besitzer root, für Gruppe und andere nicht beschreibbar.
- **Geschrieben wird dort nur als root** — vom Hilfsprogramm oder über `sudo` von der
  Kommandozeile (`quarantine restore/purge --apply`); die App und `launchkeeper` ohne `sudo`
  lesen nur.
- Vor dem Wiederherstellen prüft das Hilfsprogramm jeden Eintrag noch einmal: Besitzer, keine
  Verweise, jeder Pfad passt zu seinem Ursprung, kein Ursprung in deinem Benutzerordner oder
  unter `/System`.
- **Endgültig löschen** (seit 1.2) nur Einträge dieses Baums: Das Hilfsprogramm prüft vorher,
  dass der Eintrag einer seiner eigenen ist — gehört root, für niemand sonst schreibbar — und fragt jedes Mal nach
  Touch ID. Einträge deiner eigenen Quarantäne löscht es nicht.
- Sicherungen folgen nie Verweisen, kopieren nur gewöhnliche Dateien, und keine Kopie ist für
  mehr Leute lesbar als ihr Original.

Stimmt am Baum etwas nicht, lehnt das Hilfsprogramm ab und nennt die Reparatur:

```bash
sudo chown -R root:wheel '/Library/Application Support/launchkeeper' && sudo chmod -R go-w '/Library/Application Support/launchkeeper'
```

### Die Hintergrundaufgaben lesen

Seit Version 0.2.0 liest das Hilfsprogramm auch die Hintergrundaufgaben (Background Task
Management, kurz BTM) von macOS (`sfltool dumpbtm`). Als du gestartet, verlangt dieser Befehl Touch ID; als root fragt er nichts.
Weil das Lesen nichts ändert, fragt das Hilfsprogramm dafür nicht nach Touch ID.

Im Gegenzug gibt es nur zurück, was du sehen darfst: die Abschnitte des Systems (Benutzerkennungen
unter 500 — root und die Dienstkonten) und **deine eigenen**. Die Anmeldeobjekte anderer Benutzer
dieses Macs bekommst du nicht zu sehen.

> **Eine bewusste Abwägung:** Auf einem Mac mit mehreren Benutzern sieht damit auch ein Benutzer
> **ohne** Administratorrechte, sofern das Hilfsprogramm eingerichtet ist, die systemweiten
> Hintergrundeinträge — ohne Rückfrage. Die meisten davon sind ohnehin in `/Library` lesbar.

## Festplattenvollzugriff

LaunchKeeper braucht den **Festplattenvollzugriff** nicht, um zu laufen, und fragt nicht von sich
aus danach. Ihn zu geben ist deine Entscheidung. Er wird nur für eines gebraucht: um die Reste
gelöschter Apps zu verschieben, die in `~/Library/Containers` (oder `~/Library/Group Containers`)
liegen. Diese Daten schützt macOS vor anderen Apps, auch wenn die App gelöscht ist; ohne die
Freigabe verweigert macOS das Verschieben, und es wird nichts verschoben.

- **Ohne** Festplattenvollzugriff lassen sich Reste außerhalb der Behälter — Caches,
  Einstellungen und Ähnliches — weiter verschieben. Ein Lauf hält aber beim ersten verweigerten
  Schritt an; die Reste einer App mit Behälter brauchen deshalb die Freigabe.
- **Geben:** Systemeinstellungen › Datenschutz & Sicherheit › Festplattenvollzugriff →
  LaunchKeeper einschalten (oder mit **+** hinzufügen), dann LaunchKeeper neu starten. Den Knopf
  **Festplattenvollzugriff öffnen** zeigt die App, wenn ein Schritt daran gescheitert ist (seit
  1.2.1).
- **Widerrufen:** an derselben Stelle ausschalten.

Die Reste gelöschter Apps verschiebt immer die App selbst, nie das Hilfsprogramm. Einzelheiten
in [Kapitel 5](05-eintraege-aendern.md#app-reste-und-der-festplattenvollzugriff).

## Was den Mac verlässt

| | Verlässt den Mac? |
|---|---|
| Inventar, Ansichten, Beobachtung, Warteschlange | **nein**, alles lokal |
| Mitteilungen | nein — sie gehen an die Mitteilungszentrale von macOS |
| Updates suchen | ja: zu GitHub, wo der Update-Katalog der neuesten Version liegt. Ab Werk sucht LaunchKeeper selbst; abschalten unter Einstellungen › **Updates** › **Automatisch nach Updates suchen**. **Nach Updates suchen …** im App-Menü fragt, wenn du es wählst |
| Hash für VirusTotal | **nein** — **Hash kopieren** legt die SHA-256-Prüfsumme nur in die Zwischenablage. Ob du sie bei VirusTotal einfügst, entscheidest du |
| Handbuch | nur wenn du in der Hilfe den Link zum Handbuch anklickst — er öffnet GitHub im Browser |
| Telemetrie, Absturzberichte, Nutzungsstatistik | **gibt es nicht** |

Jedes Update ist signiert und wird vor der Installation gegen LaunchKeepers Signaturschlüssel
geprüft. Das Hilfsprogramm kommt mit dem Update und startet nach einer Minute Leerlauf in der
neuen Version; bis dahin führt die App über eine ältere Version nichts aus.

Die Kommandozeile `launchkeeper` enthält selbst keinen Netzwerkcode.

## Was wo liegt

| Datei | Inhalt |
|---|---|
| `~/Library/Logs/launchkeeper/operations.log` | Protokoll jeder Aktion der App ohne Administratorrechte und der Kommandozeile — auch Ablehnungen und Pläne |
| `/Library/Logs/launchkeeper/operations.log` | Protokoll jeder Aktion des Hilfsprogramms |
| `~/Library/Logs/launchkeeper/watch.log` | was die Beobachtung bemerkt hat ([Kapitel 7](07-beobachtung.md)) |
| `~/Library/Application Support/launchkeeper/` | deine Quarantäne, Sicherungen, Kopien von Konfigurationsdateien |
| `/Library/Application Support/launchkeeper/` | dasselbe für das Hilfsprogramm (root) |
| `~/Library/Application Support/de.paranoidsecurity.LaunchKeeper/queue.json` | die Warteschlange, nur für dich lesbar |

Das Protokoll hält fest, **was** mit **welchem** Eintrag geschah und mit welchem Ergebnis. Das
Protokoll nennt den Schlüssel des Eintrags — bei crontab-Zeilen enthält der die Befehlszeile (und
damit, was darin steht). Derselbe Schlüssel steht auch in der Warteschlange (`queue.json`) und in
`watch.log`.

## Die Grenzen

LaunchKeeper ist ein Werkzeug für den Überblick und für vorsichtiges Aufräumen. Es ist **kein**
Virenscanner und kein Schutzprogramm. Was das konkret heißt:

- **Die Beobachtung meldet, sie verhindert nicht.** Wenn sie „Neu: …“ meldet, ist der Eintrag
  schon da. Sie verlässt sich auf Dateiereignisse und einen Vergleich alle zehn Minuten; was
  zwischendurch kommt und wieder geht, kann ihr entgehen.
- **Hinweise sind keine Urteile.** Ein Eintrag mit „Ansehen empfohlen“ — etwa ein Programm unter
  `/tmp` oder ein Dienst, der eine Shell startet — ist ein Anlass zum Nachsehen, kein Befund.
  Umgekehrt heißt „unauffällig“ nicht „harmlos“.
- **Was root kontrolliert, kann sich verstecken.** LaunchKeeper sieht, was macOS ihm zeigt. Ein
  Programm, das bereits mit Administratorrechten läuft, kann Einträge und Dateien so verändern,
  dass kein Werkzeug auf demselben System sie zuverlässig findet.
- **Deine Bestätigung ist die letzte Hürde.** Touch ID schützt davor, dass etwas ohne dich
  geschieht — nicht davor, einen Plan zu bestätigen, den du nicht gelesen hast.
- **Deine Ablagen sind so sicher wie dein Benutzerkonto.** Deine Quarantäne, deine Protokolle
  und die Warteschlange liegen in deinem Benutzerordner. Andere Benutzer lesen die
  Warteschlange nicht; Programme, die unter deinem Namen laufen, können es.
- **Manches verwaltet macOS allein.** Anmeldeobjekte, Systemerweiterungen, Profile und
  Datenschutz-Freigaben schaltet LaunchKeeper nicht selbst — es zeigt nur, wo es geht.

## Weiter

- [Kapitel 10 — Die Kommandozeile `launchkeeper`](10-kommandozeile.md)
