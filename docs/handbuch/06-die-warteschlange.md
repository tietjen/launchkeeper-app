# Die Warteschlange

Einen Eintrag ändert man über seine Detailspalte ([Kapitel 5](05-eintraege-aendern.md)). Für
zwanzig Einträge ist das mühsam — und jeder mit Administratorrechten fragt einzeln nach Touch ID.
Dafür gibt es die **Warteschlange**: In jeder Ansicht sammelst du, was geschehen soll, prüfst
den Plan für alles auf einmal und führst es in einem Lauf aus.

## Einträge markieren

Jede Zeile hat vorne ein **Häkchen** — im Inventar, in den Kategorien, in **Hintergrund**,
**Pakete**, **App-Reste** und **Quarantäne**. Die Häkchen merkt sich jede Ansicht für sich: Du
kannst im Inventar sammeln, in **Pakete** weitermachen und zurückkommen, ohne dass etwas verloren
geht.

Sobald etwas markiert ist, steht oben auf der Detailspalte das **Auswahlfeld**: „N markiert“ und
darunter **Zur Warteschlange hinzufügen**. Hast du zusätzlich eine Zeile angeklickt, steht
darunter weiterhin deren Erklärung; die Trennlinie dazwischen lässt sich verschieben. So kannst
du einen einzelnen Eintrag nachlesen, während die Auswahl stehen bleibt.

### Was angeboten wird

Unter **Zur Warteschlange hinzufügen** steht je Aktion ein Knopf mit einem Zähler, etwa
**Deaktivieren — 3 von 4**. Nicht jede Aktion passt zu jedem Eintrag; der Knopf legt nur die
Einträge ab, zu denen sie passt. Angeboten wird, was auch die Detailspalte als nächsten Schritt
anbietet — dieselbe Prüfung, dieselben Regeln.

| Ansicht | Aktionen |
|---|---|
| Inventar, Kategorien, Hintergrund | **Deaktivieren**, **Wieder aktivieren**, **Entfernen**, **In die Quarantäne verschieben** — je nach Eintrag |
| Pakete | **Paket deinstallieren** |
| App-Reste | **Reste in die Quarantäne verschieben** |
| Quarantäne | **Aus der Quarantäne wiederherstellen** |

Gibt es für keinen markierten Eintrag eine automatische Aktion, steht dort „Für keinen der
markierten Einträge gibt es eine automatische Aktion.“ Einträge, deren Schalter macOS selbst
verwaltet, sammelt die Liste **„N ohne automatische Aktion“**; der Knopf **Als „Von Hand“ in die
Warteschlange** legt sie in den Abschnitt [Von Hand](#von-hand). Einträge von Apple tauchen dort
nicht auf — an denen soll niemand etwas ändern.

Eine Zeile in **Hintergrund** steht für alle **Komponenten** einer App. Markierst du sie, landen
deren Komponenten einzeln in der Warteschlange; der Zähler zählt dann Komponenten, nicht Zeilen.

Nach dem Klick steht „N zur Warteschlange hinzugefügt“ mit dem Knopf **Warteschlange öffnen**.
Die verwendeten Häkchen verschwinden — auch in anderen Ansichten, wenn derselbe Eintrag dort
ebenfalls markiert war. **Markierung aufheben** entfernt die Häkchen der aktuellen Ansicht;
was schon in der Warteschlange steht, bleibt dort.

> Ein Eintrag steht nie zweimal in der Warteschlange. Fügst du ihn mit einer anderen Aktion
> erneut hinzu, behält er seine Zeile und bekommt die neue Aktion.

### Woran du Eingereihtes erkennst

Eine Zeile, die schon in der Warteschlange steht, zeigt statt des Häkchens ein
**Warteschlangen-Symbol**. Die Farbe sagt, wie es steht:

| Farbe | Bedeutung |
|---|---|
| blau | offen |
| grün | erledigt |
| orange | abgelehnt oder fehlgeschlagen |

Fährst du mit der Maus darüber, nennt der Tipp die Aktion. **Ein Klick auf das Symbol nimmt den
Eintrag wieder heraus** — ausgeführt wird dabei nichts. Dasselbe kann die Detailspalte: oben
steht „In der Warteschlange: …“ mit dem Knopf **Herausnehmen**.

Bei einer Zeile in **Hintergrund**, von der erst ein Teil der Komponenten eingereiht ist,
bleibt das Häkchen stehen und daneben steht ein Bruch wie **2/3**: zwei von drei Komponenten
sind in der Warteschlange, der Rest lässt sich noch markieren.

## Die Warteschlange

Du findest sie in der Seitenleiste unter **Stapelverarbeitung › Warteschlange**. Die Zahl
daneben zählt die Einträge, die noch nicht abgeschlossen sind.

Die Liste hat bis zu vier Abschnitte (seit 1.2.1; vorher standen die ersten drei zusammen unter
„Automatisch“). Leere Abschnitte fehlen.

- **Offen** — was LaunchKeeper selbst ausführt und noch nicht gelaufen ist.
- **Fehlgeschlagen oder abgelehnt** — was beim letzten Lauf oder der letzten Prüfung nicht ging,
  mit der Ursache und dem, was du tun kannst (siehe [unten](#fehlgeschlagen-oder-abgelehnt)).
- **Erledigt** — was ausgeführt und überprüft ist.
- **Von Hand** — was du selbst an der genannten Stelle erledigst (siehe [unten](#von-hand)).

Jede Zeile in den ersten drei Abschnitten zeigt den Namen des Eintrags, die Ansicht, aus der er
kam, den Stand in Worten und rechts die gewählte Aktion. Bietet der Eintrag mehr als eine
Aktion, ist das ein Auswahlmenü: Du kannst etwa von **Deaktivieren** auf **In die Quarantäne
verschieben** umstellen. Der Plan wird danach neu geprüft. Das **×** am Ende nimmt die Zeile
heraus.

Das Symbol vorne zeigt den Stand:

| Symbol | Stand |
|---|---|
| leerer Kreis | „Plan noch nicht geprüft“ |
| gefüllter Kreis, blau | „bereit“ |
| Schloss, blau | „bereit · Touch ID“ — braucht Administratorrechte |
| Häkchen, grün | „erledigt und überprüft“ |
| Warndreieck, orange | „fehlgeschlagen: …“ |
| erhobene Hand, orange | „abgelehnt: …“ — nichts wurde ausgeführt |

Hinter „fehlgeschlagen:“ und „abgelehnt:“ steht seit 1.2.1 ein kurzer Grund in Worten, wenn
LaunchKeeper die Ursache erkennt — etwa „macOS verweigert den Zugriff — Festplattenvollzugriff
fehlt“ oder „nichts mehr zu tun“ —, sonst die Meldung des Kerns.
| zeigende Hand, lila | „von Hand“ |

Ein Klick auf eine Zeile zeigt rechts die Einzelheiten: **Aktion**, **Aus der Ansicht**, den
**Befehl**, mit dem du dasselbe im Terminal ausführen würdest (mit `--apply`), und — nach der Prüfung — den **Plan** mit jedem
Schritt (ein Schloss markiert Schritte mit Administratorrechten), nach dem Lauf das
**Ergebnis** mit dem **Rückweg**. **Im Inventar zeigen** springt zum Eintrag. Bei einem
fehlgeschlagenen oder abgelehnten Eintrag steht zusätzlich ein Abschnitt **Fehlgeschlagen** bzw.
**Abgelehnt** (siehe [unten](#fehlgeschlagen-oder-abgelehnt)).

### Fehlgeschlagen oder abgelehnt

Seit 1.2.1 stehen Einträge, die fehlgeschlagen sind oder abgelehnt wurden, in einem eigenen
Abschnitt: Ein fehlgeschlagener Eintrag ist keine offene Aufgabe, und ein weiterer Klick auf
**Alle ausführen** hilft nicht, solange die Ursache besteht.

Unter dem Abschnitt steht, dass diese Einträge nicht oder nicht ganz ausgeführt sind. Ist die häufigste
Ursache dabei — macOS verweigert den Zugriff auf die Daten anderer Apps, weil LaunchKeeper der
Festplattenvollzugriff fehlt ([Kapitel 5](05-eintraege-aendern.md#app-reste-und-der-festplattenvollzugriff)) —,
nennt der Text sie und den Weg: Festplattenvollzugriff geben, LaunchKeeper neu starten, dann
„Erneut versuchen“. Darunter die Knöpfe:

- **Festplattenvollzugriff öffnen** — nur, wenn diese Ursache vorliegt; öffnet Systemeinstellungen
  › Datenschutz & Sicherheit › Festplattenvollzugriff. Dort LaunchKeeper einschalten (oder mit
  **+** hinzufügen).
- **Erneut versuchen** setzt die fehlgeschlagenen und abgelehnten Einträge zurück auf offen;
  **Alle ausführen** versucht sie dann noch einmal.
- **Aus der Liste nehmen** entfernt die fehlgeschlagenen und abgelehnten Einträge. Nichts wird
  ausgeführt.

Ein Klick auf eine Zeile zeigt den Grund des einzelnen Eintrags: In der Detailspalte steht der
Abschnitt **Fehlgeschlagen** bzw. **Abgelehnt** mit der Erklärung in Worten (wenn LaunchKeeper die
Ursache erkennt), der unveränderten **Meldung** des Kerns und den Knöpfen **Festplattenvollzugriff
öffnen** (wenn das die Ursache ist), **Erneut versuchen** (nur für diesen Eintrag; fehlt, wenn
nichts mehr zu tun ist) und **Aus der Liste nehmen**. Das gilt auch nach einem Neustart der App:
Das Ergebnis des Laufs wird nicht gespeichert, der Stand des Eintrags samt Meldung schon.

### Widersprüche

Steht ein Paket zum Deinstallieren in der Warteschlange und zugleich ein Eintrag, den dieses
Paket installiert hat, erscheint beim Eintrag in Orange: „Das Paket … wird in derselben
Warteschlange deinstalliert — diese Aktion ist dann überflüssig.“ Die Deinstallation nimmt
dessen Dateien ohnehin mit. Nimm den Eintrag dann heraus.

## Plan prüfen

**Plan prüfen** rechnet für alle offenen Einträge in einem Durchgang durch, was geschehen würde
— ohne etwas zu ändern. Dafür liest LaunchKeeper das Inventar einmal ein, nicht einmal je
Eintrag. Während er rechnet, steht unten „Plan wird für alle Einträge berechnet …“.

Danach ist jede Zeile entweder **bereit**, **bereit · Touch ID** oder **abgelehnt** mit
Begründung. Abgelehnte und fehlgeschlagene Einträge prüft ein erneutes **Plan prüfen** wieder —
vielleicht hast du inzwischen das Hilfsprogramm eingerichtet oder eine Datei ist zurück. Um sie
gleich noch einmal auszuführen, setzt **Erneut versuchen** sie auf offen
([oben](#fehlgeschlagen-oder-abgelehnt)).

Unter der Liste steht eine Zeile wie „12 Einträge · 9 offen · 2 erledigt · 1 abgelehnt oder
fehlgeschlagen“.

## Alle ausführen

**Alle ausführen** (oder **↩**) führt alle offenen automatischen Einträge aus. Hast du den Plan
noch nicht geprüft, holt LaunchKeeper das vorher nach; ausgeführt wird nur, was die Prüfung
erlaubt hat. Stehen Schritte mit Administratorrechten an, heißt der Knopf **Alle ausführen
(Touch ID)**.

Die Reihenfolge:

1. **Zuerst alle Schritte mit Administratorrechten** — über das Hilfsprogramm, mit **einer**
   Touch-ID-Abfrage für alle zusammen. Der Dialog nennt die Anzahl: „LaunchKeeper möchte 7
   Autostart-Einträge ändern.“ (bei einem einzigen: „LaunchKeeper möchte einen Autostart-Eintrag
   ändern.“). So fragt LaunchKeeper, solange du noch vor dem Bildschirm sitzt.
2. **Dann die übrigen**, die ohne Administratorrechte auskommen.

Innerhalb jeder Gruppe laufen Entfernen und Deaktivieren vor Wiederherstellen und Deinstallieren.
Der Fortschritt steht unten als „N von M erledigt“.

- **Ein Fehler hält die übrigen nicht an.** Jeder Eintrag hat sein eigenes Ergebnis.
- **Anhalten** stoppt nach dem Eintrag, der gerade läuft. Halbe Sachen gibt es nicht; der Rest
  wird als „angehalten — nicht ausgeführt“ gemeldet.
- **Brichst du die Touch-ID-Abfrage ab**, wird nichts mit Administratorrechten geändert („Anmeldung
  abgebrochen oder abgelehnt — nichts geändert“). Dann laufen auch die übrigen Einträge nicht
  („nicht ausgeführt — Anmeldung abgebrochen“): Abbrechen heißt „nichts tun“.

Wird ein Schritt mit Administratorrechten gebraucht, aber das Hilfsprogramm ist nicht
eingerichtet (oder noch die alte Version nach einem Update), lehnt LaunchKeeper den Eintrag ab:
„braucht Administratorrechte — Hilfsprogramm in den Einstellungen einrichten“. Wie das geht, steht
in [Kapitel 4](04-das-hilfsprogramm.md). App-Reste, deren Plan Administratorrechte braucht, führt
das Hilfsprogramm nicht aus; sie bekommen „braucht Administratorrechte — nur im Terminal möglich“.

> Ein Lauf mit Administratorrechten nimmt höchstens **500** Einträge. Bei mehr lehnt LaunchKeeper
> sie ab, bevor Touch ID gefragt wird („zu viele Einträge für einen Lauf (höchstens 500) — bitte
> in Teilen ausführen“).

Nach dem Lauf liest LaunchKeeper das Inventar, die Quarantäne und die App-Reste einmal neu ein.
Die [Beobachtung](07-beobachtung.md) führt alles, was der Lauf geändert hat, als „durch
LaunchKeeper“ und meldet es nicht.

## Aufräumen und Rückwege

Unter der Liste stehen drei Knöpfe:

- **Leeren** nimmt alle Einträge aus der Warteschlange — nach der Rückfrage „Warteschlange
  leeren?“ mit **Leeren — nichts wird ausgeführt**. Was schon ausgeführt ist, bleibt ausgeführt.
- **Erledigte entfernen** nimmt alle erfolgreich ausgeführten und abgehakten Einträge heraus.
  Offene, abgelehnte und fehlgeschlagene bleiben stehen — für diese gibt es **Aus der Liste
  nehmen** unter ihrem Abschnitt ([oben](#fehlgeschlagen-oder-abgelehnt)).
- **Rückwege hinzufügen (N)** legt für jede Aktion, die **in dieser Sitzung** erledigt wurde, den
  Weg zurück in die Warteschlange: **Deaktivieren** ↔ **Wieder aktivieren**, und für alles, was in
  die Quarantäne gewandert ist, **Aus der Quarantäne wiederherstellen**. Der Knopf erscheint nur,
  wenn es solche Rückwege gibt.

> Rückwege gibt es nur für Läufe dieser Sitzung. Ein „erledigt“, das nach einem Neustart aus der
> gespeicherten Warteschlange kommt, beweist nichts über den Zustand des Macs — dafür bietet
> LaunchKeeper keinen Rückweg an. Den Weg zurück findest du dann in der
> [Quarantäne](08-quarantaene-und-rueckwege.md) oder an der Detailspalte des Eintrags.

## Was nach einem Neustart bleibt

Die Warteschlange überlebt einen Neustart der App: Einträge und ihr Stand liegen in

```
~/Library/Application Support/de.paranoidsecurity.LaunchKeeper/queue.json
```

Die Datei kann nur ihr Besitzer lesen — sie führt auf, was mit Administratorrechten laufen soll.
Die Pläne selbst werden nicht gespeichert; nach dem Neustart steht wieder „Plan noch nicht
geprüft“, und ein Lauf, den das Beenden unterbrochen hat, gilt wieder als offen.

Kann LaunchKeeper einzelne Einträge der Datei nicht lesen — etwa weil eine neuere Version sie
geschrieben hat und du zurückgewechselt bist —, fehlen nur diese, nicht die ganze Warteschlange.
Oben erscheint dann ein Hinweis, und die unveränderte Datei liegt als
`queue-unreadable-<Datum>.json` daneben, ebenfalls nur für dich lesbar. Lässt sich diese Kopie
nicht anlegen, speichert LaunchKeeper die Warteschlange bis zum nächsten Start gar nicht, damit
nichts überschrieben wird. **OK** blendet den Hinweis aus.

## Von Hand

Manche Schalter verwaltet macOS allein und lässt keine andere App daran — Anmeldeobjekte,
Systemerweiterungen, Konfigurationsprofile, Datenschutz-Freigaben, Kernel-Erweiterungen.
LaunchKeeper schreibt dort absichtlich nicht. Solche Einträge stehen im Abschnitt **Von Hand**,
jeweils mit einer kurzen Anleitung und, wo es eine gibt, einem Knopf **Systemeinstellungen
öffnen**, der die richtige Stelle öffnet:

| Art | Wo |
|---|---|
| Anmeldeobjekte, Hintergrund-Registrierungen | Systemeinstellungen › Allgemein › Anmeldeobjekte & Erweiterungen — bei der App oder dem Entwickler ausschalten, oder die App löschen |
| Systemerweiterungen | die zugehörige App löschen oder die Erweiterung in ihr abschalten; Schalter unter Anmeldeobjekte & Erweiterungen › Erweiterungen (macOS 14: Datenschutz & Sicherheit › Erweiterungen) |
| Konfigurationsprofile | Systemeinstellungen › Allgemein › Geräteverwaltung — von einer Verwaltung (MDM) installierte Profile lassen sich dort nicht entfernen |
| Datenschutz-Freigaben | Systemeinstellungen › Datenschutz & Sicherheit, in der passenden Rubrik ausschalten |
| Netzwerkdienste | das Programm beenden oder in seinen eigenen Einstellungen abschalten; eingehende Verbindungen sperrt die Firewall (Systemeinstellungen › Netzwerk › Firewall) |
| Kernel-Erweiterungen | nur das Deinstallationsprogramm des Herstellers (oder dessen App), danach neu starten — ohne Knopf |

In der Detailspalte stehen dieselbe Anleitung, der Knopf, **Im Finder zeigen** und der Schalter
**Erledigt**.

### Abhaken

Du musst nicht selbst abhaken. **Jetzt prüfen** unter dem Abschnitt liest das Inventar frisch
ein — auch die Schalter der Systemeinstellungen, die **⌘R** aus dem Zwischenspeicher nimmt — und
hakt ab, was **verschwunden** ist oder **ausgeschaltet**, wenn es beim Einreihen eingeschaltet
war. Dasselbe passiert nach jedem anderen fertigen Einlesen, während die Warteschlange offen ist.

Zwei Ausnahmen:

- War das Einlesen **unvollständig** (eine Quelle hat nicht geantwortet), zählt „verschwunden“
  nicht — nur „ausgeschaltet“.
- **Netzwerkdienste hakst du selbst ab.** Ein Programm, das Verbindungen annimmt, steht nur im
  Inventar, solange es läuft. Verschwindet es, ist es vielleicht nur beendet. Die Zeile sagt dann
  „lauscht gerade nicht — vielleicht nur beendet; selbst abhaken“. Hake erst ab, wenn es auch
  nach dem nächsten Start nicht wieder lauscht.

Mit dem Häkchen vorne in der Zeile hakst du selbst ab oder öffnest einen Eintrag wieder.
**Erledigte entfernen** räumt abgehakte Einträge mit weg.

## Weiter

- [Kapitel 7 — Beobachtung und Mitteilungen](07-beobachtung.md)
