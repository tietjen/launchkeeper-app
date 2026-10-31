# LaunchKeeper — Handbuch

In der Reihenfolge, in der man es braucht. Die ersten drei Kapitel reichen, um loszulegen.

| | Kapitel | Worum es geht |
|---|---|---|
| 1 | [Installieren und der erste Start](01-installieren-und-erster-start.md) | Homebrew oder DMG, warum die App nach /Applications gehört, das erste Einlesen, die Einführung |
| 2 | [Das Inventar lesen](02-das-inventar.md) | Kategorien, die Symbole in der Liste, Basis- und Expertenmodus, die nächsten Schritte |
| 3 | [Die Ansichten](03-die-ansichten.md) | Hintergrund, Pakete, App-Reste, Quarantäne — je eine Frage, je eine Ansicht |
| 4 | [Das Hilfsprogramm einrichten](04-das-hilfsprogramm.md) | Wofür es Administratorrechte braucht, Einrichten und Erlauben, Updates, Neustart |
| 5 | [Einträge ändern](05-eintraege-aendern.md) | Deaktivieren, Aktivieren, Entfernen, Deinstallieren — erst der Plan, dann die Ausführung |
| 6 | [Die Warteschlange](06-die-warteschlange.md) | Markieren, sammeln, ein gemeinsamer Plan, eine Touch-ID-Abfrage, Rückwege, „Von Hand“ |
| 7 | [Beobachtung und Mitteilungen](07-beobachtung.md) | Was gemeldet wird und was nicht, Menüleiste, Start bei der Anmeldung, fehlende Banner |
| 8 | [Quarantäne und Rückwege](08-quarantaene-und-rueckwege.md) | Wohin Entferntes geht, wie es zurückkommt, was nur im Terminal geht |
| 9 | [Sicherheit und Datenschutz](09-sicherheit-und-datenschutz.md) | Was das Hilfsprogramm darf und was nicht, was den Mac verlässt, die Grenzen |
| 10 | [Die Kommandozeile `launchkeeper`](10-kommandozeile.md) | Dasselbe Inventar im Terminal, Skripte, die Quarantäne leeren |

**In der App:** **⌘?** öffnet die Hilfe im Programm — dieselben Themen in Kurzform und
durchsuchbar, mit einem Link hierher. Den Rundgang vom ersten Start holst du über
**Hilfe › Einführung zeigen** zurück.

**Zum Nachschlagen:** [Funktionsreferenz](../funktionen.md) — jede Funktion mit ihren Grenzen.

**Zum Verstehen:** [Wie LaunchKeeper gebaut ist](../architektur.md) — die Teile, die Wege und
die Gründe dahinter.

## Die fünf Leitsätze

Wenn LaunchKeeper sich einmal anders verhält als erwartet, liegt es fast immer an einem davon:

1. **Ohne dein Zutun ändert sich nichts.** Einlesen und Beobachten lesen nur. Auch das
   Hilfsprogramm richtet LaunchKeeper nicht von selbst ein — wer nur schauen will, bekommt
   keinen Dienst mit Administratorrechten.
2. **Plan → Ausführen → Prüfen.** Jede Änderung zeigt vorher ihren Plan; ausgeführt wird erst
   nach einem zweiten Klick, und danach prüft LaunchKeeper, ob der Eintrag wirklich im
   erwarteten Zustand ist.
3. **Entfernen heißt Quarantäne — es gibt immer einen Rückweg.** Dateien werden verschoben oder
   vorher gesichert, nicht einfach gelöscht. Endgültig löschen geht nur ausdrücklich, im
   Terminal mit `launchkeeper quarantine purge`.
4. **Root nur über das Hilfsprogramm — und das nimmt nur „was mit welchem Eintrag“, nie
   Befehle.** Jede Ausführung fragt neu nach Touch ID oder Passwort; das Hilfsprogramm sucht
   den Eintrag selbst, prüft selbst und hält Quarantäne und Sicherungen nur in einem Ordner,
   den allein root schreiben kann.
5. **Dieselbe Prüfung wie die Kommandozeile; Apple und /System bleiben unangetastet.** Die App
   bietet nur an, was die Prüfung von `launchkeeper` besteht — ohne Ausnahme und ohne
   Umgehung.
