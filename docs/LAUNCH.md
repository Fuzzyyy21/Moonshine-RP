# Vor dem Livegang

Der Server ist inhaltlich vollständig: 17 Resources, alle Systeme greifen
ineinander. **Nichts davon lief bisher auf einem laufenden FXServer.** Diese
Liste ist der Weg von „fertig geschrieben" zu „läuft".

## 0. Vorher: die statische Prüfung

```bash
python3 tools/pruefen.py    # Syntax und Verdrahtung
lua5.4 tools/testen.lua     # Rechenlogik, rund 2.700 Zusicherungen
```

Findet Syntaxfehler, kaputte Exporte, fehlende Event-Gegenstellen, falsche
Seitenzuordnung, Command-Kollisionen, Schema-Drift und Globals aus einer
Resource, die gar nicht mitgeladen wird — bevor der Server
überhaupt startet. Der zweite Befehl führt die Rechenlogik der `shared`-Dateien
tatsächlich aus. Beides läuft bei jedem Push ohnehin.

Was sie **nicht** können: Koordinaten prüfen, Spielmechanik testen, Balancing
beurteilen. Dafür ist der Rest dieser Liste da.

## 1. Aufsetzen

```cfg
set mysql_connection_string "mysql://user:passwort@localhost/moonshine?charset=utf8mb4"
```

Die Tabellen legen die Resources beim Start selbst an. Wer lieber manuell
importiert, nimmt [`sql/moonshine.sql`](../sql/moonshine.sql).

Startreihenfolge steht in [`server.cfg.example`](../server.cfg.example). Sie ist
nicht beliebig: `moonshine-core` zuerst, `moonshine-world` vor `moonshine-mystic`
(die Klassenwerte hängen an Mondphase und Ereignis), `moonshine-admin` zuletzt.

Nach dem ersten Join sich selbst zum Owner machen:

```sql
UPDATE ms_users SET admin_level = 4 WHERE license = 'license:deinelizenz';
```

## 2. Beim ersten Start in der Konsole prüfen

Jede Resource meldet sich. Fehlt eine Zeile, hat das Schema nicht geklappt:

```
[Core] Datenbank bereit.
[Welt] Datenbank bereit.        [Welt] Tag 0, 20:00 Uhr, …
[Mystik] Datenbank bereit.
[Progress] Datenbank bereit.
[Fraktionen] Datenbank bereit.  [Fraktionen] 0 Fraktionen geladen.
[Ritualkrieg] Datenbank bereit. [Ritualkrieg] 0 von 6 Punkten sind gebunden.
[Auktion] Datenbank bereit.     [Auktion] 0 offene Auktionen geladen.
[Fahrzeuge] Datenbank bereit.
[Arbeit] Datenbank bereit.
[Dienste] … geladen.            [Admin] Panel und Wachhund geladen.
```

## 3. Koordinaten nachmessen

**Das ist der größte Posten.** Alle Positionen sind Schätzwerte aus der Karte,
keine im Spiel abgelesenen Werte. Mit `/tp` hinfahren, `/coords`-Ausgabe des
eigenen Skripts oder den Adminpanel-Wegpunkt nutzen und in der jeweiligen
Config korrigieren.

| Was | Wo | Anzahl |
|---|---|---|
| Ritualpunkte (auch Ritualkrieg) | `moonshine-mystic/shared/config.lua` | 6 |
| Steinhändler | `moonshine-mystic/shared/config.lua` | 4 |
| Weltboss-Spawns | `moonshine-boss/config.lua` | 6 |
| Krankenhäuser | `moonshine-death/config.lua` | – |
| Fraktionsbasen | `moonshine-factions/shared/config.lua` | 6 |
| Fraktionsgaragen | `moonshine-factions/shared/config.lua` | 4 |
| Gebietsmittelpunkte | `moonshine-factions/shared/territories.lua` | 8 |
| Auktionatoren | `moonshine-auction/shared/config.lua` | 3 |
| Autohäuser + Ausgabe | `moonshine-vehicles/shared/config.lua` | 3 |
| Garagen + Ausgabe | `moonshine-vehicles/shared/config.lua` | 6 |
| Verwahrstelle | `moonshine-vehicles/shared/config.lua` | 1 |
| Tankstellen + Zapfsäulen | `moonshine-services/shared/locations.lua` | 9 (+22) |
| Werkstätten | `moonshine-services/shared/locations.lua` | 4 |
| Bankfilialen | `moonshine-services/shared/locations.lua` | 6 |
| Geldautomaten | `moonshine-services/shared/locations.lua` | 16 |
| Schwarzmarkt-Orte | `moonshine-services/shared/locations.lua` | 6 |
| Jobcenter | `moonshine-jobs/shared/config.lua` | 1 |
| Auftrags-Anmeldungen | `moonshine-jobs/shared/jobs.lua` | 4 |
| Auftrags-Stationen | `moonshine-jobs/shared/jobs.lua` | 40 |
| Naturgebiete | `moonshine-needs/shared/needs.lua` | 8 |
| Friedhöfe | `moonshine-needs/shared/needs.lua` | 4 |
| Kleidungsläden | `moonshine-appearance/shared/config.lua` | 6 |
| Tätowierer | `moonshine-appearance/shared/config.lua` | 5 |
| Friseure | `moonshine-appearance/shared/config.lua` | 5 |
| Umkleiden | `moonshine-appearance/shared/config.lua` | 4 |

Besonders heikel sind die **Fahrzeug-Ausgabepunkte** (Autohäuser, Garagen,
Arbeitsfahrzeuge): Steht der Punkt in einer Wand, erscheint das Fahrzeug gar
nicht oder fällt durch die Welt.

### Und die Tattoo-Aufdrucke

Dieselbe Sorte Arbeit, aber an anderer Stelle: die rund 35 Motive in
`moonshine-appearance/shared/tattoos.lua` benennen GTA-Decorations
(`MP_Bea_M_Chest_000` und so weiter). Die Namen folgen dem Muster der
DLC-Pakete, sind aber nie im Spiel gegengeprüft.

Ein falscher Name wirft **keinen Fehler** — es erscheint nichts. Deshalb:
einmal mit `/gibtattoo <id> <motiv>` durch den Katalog gehen und schauen, was
tatsächlich auftaucht. Was leer bleibt, in der Datei korrigieren oder
streichen.

## 4. Durchspielen

Ein Durchlauf, der alle Systeme berührt:

1. **Charakter anlegen** — der Editor muss von selbst aufgehen. Gesicht
   mischen, Frisur wählen, anziehen. Danach Inventar (`F2`) und Anzeige (`F7`)
2. **Erwecken** an einem Ritualpunkt, Klasse wählen
3. **Steine kaufen** beim Händler, 10+10 zum Klassenstein binden
4. **Ersten Skill** kaufen (5 Steine) — danach muss die Klassenliste
   zusammenklappen
5. **Skillleiste** (`F5`), Skill auf Slot legen, `NUMPAD 1` auslösen
6. **Weltboss** mit `/bossspawn`, mitkämpfen, Beute prüfen
7. **Sterben**, Notruf, Wiederbeleben durch einen zweiten Spieler
8. **Fortschritt** (`F6`): Spielzeit-Meilenstein abholen, Kiste öffnen
9. **Fraktion gründen**, Wappen bauen, Ränge anlegen, Gebiet einnehmen
10. **Ritualpunkt binden** (`/bindung`, zwei Mitglieder, 75.000 $ in der
    Kasse) — nach 180 Sekunden muss der Blip die Wappenfarbe annehmen und
    nach 20 Minuten müssen Steine im Tresor liegen
11. **Fahrzeug kaufen**, tanken, absichtlich schrotten, reparieren lassen
12. **Auktion** einstellen und mit einem zweiten Spieler überbieten
13. **Schicht** beim Postdienst, alle sechs Stationen, Abschlussbonus
14. **Bedürfnis** mit `/setbeduerfnis <id> 10` auf schwach setzen — die
    Klassenwerte müssen sofort schlechter sein, der Balken links unten
    auftauchen. Dann stillen (Item, Passant, Zone) und zusehen, wie es steigt
15. **Weltereignis** mit `/startereignis blutmond` — Werte müssen sofort
    anders sein (`/mystik` zeigt sie)
16. **Kleidungsladen** aufsuchen, etwas kaufen, Outfit sichern, in der
    Umkleide wieder wechseln
17. **Tätowierer** aufsuchen: ein Motiv anklicken (muss sofort am Ped
    erscheinen), stechen, wieder entfernen. Als Erweckter zusätzlich das
    Klassenmal — es darf nur das eigene sichtbar sein
18. **Anzeige** einstellen (`/hudmenu`): Stil auf Balken, Ecke wechseln,
    Größe ziehen, ein paar Elemente abschalten. Danach `/hud` aus und wieder
    an — die Einstellung muss den Neustart des Clients überleben
19. **Gurt** (`B`) im Auto: angeschnallt bei 100 km/h gegen eine Wand darf
    nichts passieren, ohne Gurt muss es den Fahrer hinauswerfen
20. **Adminpanel** (`F9`), Spieler beobachten, Protokoll prüfen

## 5. Zwei Spieler gleichzeitig

Vieles lässt sich allein nicht testen: Wiederbeleben, Fraktionseinladung,
Gebietsstreit (zwei Fraktionen im selben Gebiet müssen den Balken anhalten),
Auktionsgebote, Überweisung, Fahrzeugschlüssel, Fahrzeugübergabe.

Für den Ritualkrieg gilt das doppelt: die Bindung braucht ohnehin zwei
Mitglieder, und Störung wie Wegzoll lassen sich allein gar nicht auslösen.
Zu prüfen ist, dass ein Fremder am gebundenen Punkt (a) den Balken anhält,
(b) nach sechs Sekunden fremde Rituale abbricht und (c) beim eigenen Ritual
25 % in der Kasse des Halters lässt.

## 6. Last

Bei vielen Spielern relevant:

* **Marker-Threads** — jede Resource hat einen `Wait(0)`-Loop, sobald der
  Spieler nah an einem Interaktionspunkt steht. Bei Bedarf die Distanzen in den
  Configs verkleinern.
* **Gebiets-Tick** — läuft alle 2 Sekunden über alle Fraktionsmitglieder. Er
  sammelt die Positionen einmal, nicht je Gebiet; bei über 100 Spielern trotzdem
  im Auge behalten.
* **Ritualkrieg-Ticks** — zwei weitere 2-Sekunden-Läufe über alle Spieler:
  einer für die Bindung, einer für die Anwesenheit an den Punkten.
  `WarConfig.TickInterval` erhöhen, wenn das zu viel wird.
* **Wachhund-Bewegungsprüfung** — alle 5 Sekunden über alle Spieler.
  `AdminConfig.Guard.movement.interval` erhöhen, wenn es stört.

## 7. Balancing scharf stellen

Die Zahlen sind gesetzt, aber nie gegen echtes Spielverhalten geprüft. Die
Punkte stehen in [`ROADMAP.md`](ROADMAP.md#balancing-das-später-aufmerksamkeit-braucht).
Am wichtigsten zuerst:

* **Steinpreise gegen Bossausbeute** — wie lange dauert der erste Skill wirklich?
* **Arbeitslohn gegen Spritkosten** — eine Schicht muss deutlich mehr bringen
  als der Sprit dafür kostet.
* **Weltereignisse** — ein Blutmond darf Vampire stark machen, aber nicht so
  stark, dass sich alle anderen ausloggen.

## 8. Was noch fehlt

Nichts, was den Server unfertig aussehen ließe. Alles Weitere ist Ausbau:
Telefon, Zufluchtsorte, Fahrzeug-Tuning, Discord-Anbindung. Der Server läuft
ohne sie.
