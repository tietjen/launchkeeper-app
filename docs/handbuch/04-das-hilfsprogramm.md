# Das Hilfsprogramm einrichten

Manches darf auf einem Mac nur ein Administrator ändern: Systemdienste, Dateien in `/Library`,
die Firewall, installierte Pakete. Dafür bringt LaunchKeeper ein **Hilfsprogramm** mit. Wer nur
schauen will, braucht es nicht.

## Was es ist

Das Hilfsprogramm ist ein kleiner Dienst, der im App-Paket mitkommt und mit **root-Rechten**
läuft. LaunchKeeper meldet ihn über die dafür vorgesehene Schnittstelle von macOS an
(`SMAppService`); danach startet macOS ihn bei Bedarf, und nach einer **ruhigen Minute** beendet
er sich von selbst wieder. Er läuft also nicht ständig im Hintergrund.

Über das Hilfsprogramm macht LaunchKeeper zweierlei:

- **Ändern, was Administratorrechte braucht** — jedes Mal erst nach Touch ID oder deinem Passwort.
- **Die Hintergrundaufgaben (Background Task Management, kurz BTM) von macOS lesen**, ohne dass
  macOS dafür jedes Mal nach Touch ID fragt (siehe unten).

## Warum es nicht von selbst kommt

LaunchKeeper richtet das Hilfsprogramm **bewusst nicht von selbst** ein. Ein Dienst mit
root-Rechten ist eine Tür, und die soll nur offen stehen, wenn du sie brauchst. Wer LaunchKeeper
nur zum Nachsehen benutzt, bekommt keinen.

## Einrichten

1. **Einstellungen öffnen** (**⌘,**). Im Bereich **Hilfsprogramm für Administratorrechte** auf
   **Einrichten** klicken.

   Oder bei der ersten Aktion, die Administratorrechte braucht: Das Blatt dieser Aktion zeigt
   „Braucht Administratorrechte“ und den Knopf **Hilfsprogramm einrichten**
   ([Kapitel 5](05-eintraege-aendern.md)).

2. **In den Systemeinstellungen erlauben.** macOS öffnet von selbst **Allgemein › Anmeldeobjekte &
   Erweiterungen**. Dort unter **Im Hintergrund erlauben** den Schalter bei **LaunchKeeper**
   einschalten. Ist das Fenster schon zu, öffnet es der Knopf **In den Systemeinstellungen
   erlauben** wieder.

3. **Neu prüfen.** Zurück in LaunchKeeper auf **Neu prüfen** klicken. Dann steht bei **Zustand**
   „eingerichtet und erlaubt“, darunter die **Version** des Hilfsprogramms.

Das ist einmalig. Danach bleibt das Hilfsprogramm eingerichtet, auch über Updates der App hinweg.

## Die Zustände

| Zustand | Was es heißt | Was zu tun ist |
|---|---|---|
| „nicht eingerichtet“ | es gibt kein Hilfsprogramm | **Einrichten** |
| „wartet auf deine Freigabe in den Systemeinstellungen“ | angemeldet, aber noch nicht erlaubt | **In den Systemeinstellungen erlauben**, dann **Neu prüfen** |
| „eingerichtet und erlaubt“ | bereit | nichts |
| „nicht gefunden — die App muss aus ihrem Bundle gestartet werden“ | macOS findet das Hilfsprogramm nicht im App-Paket | die App aus dem Ordner Programme starten |

Schlägt etwas fehl, steht die Meldung von macOS rot darunter.

## Versionen und Updates

Das Hilfsprogramm hat eine eigene Versionsnummer (derzeit **0.2.0**), die in die App
eingebaut ist. LaunchKeeper vergleicht sie mit dem laufenden Hilfsprogramm und schickt einem
Hilfsprogramm **anderer Version nie etwas** — ein altes könnte die Anmeldung anders prüfen und nach
deiner Touch-ID-Bestätigung scheitern.

Nach einem Update der App läuft das so:

1. Das Update ersetzt das ganze App-Paket — das neue Hilfsprogramm steckt darin.
2. Das alte, noch laufende Hilfsprogramm beendet sich nach einer **ruhigen Minute**.
3. Bei der nächsten Anfrage startet macOS das neue aus dem Paket.

Du musst dafür nichts tun. Läuft trotzdem noch ein älteres, zeigen die Einstellungen in Orange „Es
läuft noch eine ältere Version des Hilfsprogramms (…). Bis zum Neustart führt LaunchKeeper
darüber nichts aus.“ und den Knopf **Hilfsprogramm neu starten**. Dasselbe bietet das Blatt einer
Aktion an („Hilfsprogramm veraltet“). Nötig ist das vor allem bei sehr alten Hilfsprogrammen, die
sich noch nicht von selbst beendet haben.

## Entfernen

Ist das Hilfsprogramm eingerichtet, steht in den Einstellungen **Entfernen** statt
**Einrichten**. Danach:

- führt LaunchKeeper keine Änderungen mit Administratorrechten mehr aus — das Blatt einer solchen
  Aktion nennt stattdessen den Befehl fürs Terminal,
- fragt macOS beim Lesen der Hintergrundaufgaben wieder nach Touch ID.

Alles, was du ohne Administratorrechte tust, geht weiter wie bisher. Mit **Einrichten** kommt das
Hilfsprogramm jederzeit zurück.

## Was es annimmt — und was nicht

Das Hilfsprogramm nimmt **keine Befehle** entgegen. Es versteht nur „was mit welchem Eintrag“:

| Anfrage | Ziel |
|---|---|
| deaktivieren, aktivieren, entfernen, in die Quarantäne verschieben | ein Eintrag des Inventars |
| wiederherstellen, endgültig löschen (seit 1.2) | ein Eintrag seiner eigenen Quarantäne |
| deinstallieren | ein Paket, über seine genaue Paket-ID |

Endgültig löschen (`purge`) schickt die App nur für Einträge, die das Hilfsprogramm selbst
verwahrt; vor dem Löschen prüft es, dass der Eintrag root gehört und für niemand sonst schreibbar war. Einträge
deiner eigenen Quarantäne löscht die App selbst oder, wenn darin Dateien liegen, die nur root
löschen darf, das Terminal ([Kapitel 8](08-quarantaene-und-rueckwege.md#endgültig-löschen)).

Alles andere rechnet es **selbst** aus: Es liest den Mac selbst ein, sucht den Eintrag selbst
heraus und lässt ihn durch dieselbe Prüfung laufen wie die Kommandozeile. Was dort nicht
durchkommt, führt es nicht aus. Ein Ziel, das leer ist, überlang, Steuerzeichen enthält oder wie
eine Option mit `-` beginnt, weist es schon vorher ab.

Weitere Grenzen, die es sich selbst setzt:

- **Wer fragt, sagt die Verbindung, nicht die Anfrage.** Benutzer und Benutzerordner ermittelt es
  aus der Verbindung selbst.
- **Nur systemweite Einträge.** Was einem einzelnen Benutzer gehört — deine eigenen LaunchAgents,
  deine crontab, Erweiterungs-Einstellungen in deinem Konto —, ändert es nicht. Das macht die App
  selbst, ohne Administratorrechte.
- **Entfernt wird nur in `/Library/LaunchAgents` und `/Library/LaunchDaemons`.**
- **Root bewahrt nichts in deinem Benutzerordner auf.** Quarantäne, Sicherungen und Kopien
  geänderter Einstellungen legt es unter `/Library/Application Support/launchkeeper` ab, einem
  Ordner, in den nur root schreiben kann. Vor jeder Anfrage prüft es, dass das so ist.
- **Wiederhergestellt wird nur, was es selbst verwahrt** — nach einer Prüfung von Eigentümer und
  Inhalt des Quarantäne-Eintrags.
- **Deinstallieren nur aus geschützten Orten.** Pakete, deren Dateien an Stellen liegen, die ein
  normaler Benutzer ändern kann (etwa `/Users`, temporäre Ordner, `/Volumes`, `/opt/homebrew`),
  lehnt es ab.
- **Nur feste Werkzeuge.** Die Schritte eines Plans führt es nur aus, wenn sie eines von wenigen
  Systemwerkzeugen an festem Ort aufrufen (`launchctl`, `mv`, `rm`, `cp`, `pkgutil`, die Firewall
  …) — nie eine Shell.
- **Eins nach dem anderen.** Zwei Änderungen laufen nie gleichzeitig.
- **Protokoll.** Jede Änderung steht in `/Library/Logs/launchkeeper/operations.log`.

### Code-Signatur auf beiden Seiten

Das Hilfsprogramm nimmt nur Verbindungen der **echten LaunchKeeper-App** an — mit Apples
Developer-ID-Zertifikat vom selben Entwicklerteam signiert. Jedes andere Programm wird abgewiesen,
auch wenn es unter deinem Benutzer läuft. Umgekehrt spricht die App nur mit dem echten, vom selben
Team signierten Hilfsprogramm.

## Die Hintergrundaufgaben lesen, ohne Touch ID

Die Liste der Hintergrundaufgaben (`sfltool dumpbtm`) gibt macOS nur mit Administratorrechten
heraus. Ohne Hilfsprogramm fragt macOS deshalb bei jedem **frischen** Einlesen nach Touch ID:
beim Start der App, bei **⇧⌘R**, bei **Jetzt prüfen** in der Warteschlange und, mit eingeschalteter
Beobachtung, bei deren regelmäßiger Prüfung — die holt die Liste ohne Hilfsprogramm deshalb
höchstens alle sechs Stunden frisch.

Mit eingerichtetem Hilfsprogramm liest es diese Liste als root, und **niemand wird gefragt**. Das
ist reines Lesen; eine Anmeldung verlangt das Hilfsprogramm dafür nicht.

Zum Ausgleich gibt es nur zurück, was du sehen darfst: die **systemweiten** Einträge und **deine
eigenen** — nie die Anmeldeobjekte anderer Benutzer dieses Macs.

> Auf einem Mac mit mehreren Benutzern heißt das: Auch ein Benutzer ohne Administratorrechte sieht
> über LaunchKeeper die systemweiten Hintergrundobjekte, ohne gefragt zu werden. Die meisten davon
> kann er ohnehin in `/Library` lesen.

Antwortet das Hilfsprogramm einmal nicht, nimmt LaunchKeeper die Liste vom letzten Mal, statt
dich mit einer Abfrage zu überraschen — sofern es in dieser Sitzung schon eine gibt; sonst fragt
macOS.

## Was trotzdem nach Touch ID fragt

Das Hilfsprogramm spart nur die Abfragen beim **Lesen**. Für **Änderungen** fragt es immer:

- **Jede einzelne Aktion** mit Administratorrechten fragt einmal, direkt vor dem Ausführen. Die
  Freigabe gilt nur für diese eine Aktion; die nächste fragt wieder. macOS zeigt dabei „LaunchKeeper
  möchte einen Autostart-Eintrag auf Systemebene ändern.“
- **Ein Lauf der Warteschlange** fragt einmal für alle Schritte mit Administratorrechten, und der
  Dialog nennt, wie viele es sind: „LaunchKeeper möchte 7 Autostart-Einträge ändern.“ — bei einem
  einzigen „LaunchKeeper möchte einen Autostart-Eintrag ändern.“
  ([Kapitel 6](06-die-warteschlange.md)).

Dafür sind die Anmeldedaten eines Administrators nötig — Touch ID oder Passwort.

Änderungen in deinem eigenen Benutzerordner laufen gar nicht über das Hilfsprogramm und fragen
nicht ([Kapitel 5](05-eintraege-aendern.md)).

## Weiter

- [Kapitel 5 — Einträge ändern](05-eintraege-aendern.md)
