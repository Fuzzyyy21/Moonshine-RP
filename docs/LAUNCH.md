# Vor dem Livegang

Der Server ist inhaltlich vollständig: 17 Resources, alle Systeme greifen
ineinander. **Nichts davon lief bisher auf einem laufenden FXServer.** Diese
Liste ist der Weg von „fertig geschrieben" zu „läuft".

## 0. Vorher: die statische Prüfung

```bash
python3 tools/pruefen.py       # Syntax und Verdrahtung, 17 Prüfungen
lua5.4 tools/testen.lua        # Rechenlogik, rund 3.100 Zusicherungen
node tools/vorschau/laden.js   # lädt alle 16 Oberflächen im Browser
```

Der erste Befehl findet Syntaxfehler, kaputte Exporte, fehlende
Event-Gegenstellen, falsche Seitenzuordnung, Command-Kollisionen,
Schema-Drift, Globals aus einer Resource die gar nicht mitgeladen wird,
Netz-Events die Geld oder Items ungebremst bewegen, Anticheat-Prüfungen die
gegen den eigenen Code laufen, Wertbewegungen hinter einem Warten auf die
Datenbank, und Element-Namen die das JavaScript sucht ohne dass es sie gibt
— alles bevor der Server überhaupt startet.

Der zweite führt die Rechenlogik der `shared`-Dateien tatsächlich aus. Der
dritte lädt jede Oberfläche in einem echten Browser und horcht auf Fehler
(braucht `npm install playwright`, der Browser liegt schon bereit).

Alle drei laufen bei jedem Push ohnehin.

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
[Zuflucht] Datenbank bereit.    [Zuflucht] 0 von 14 Plaetzen sind vergeben.
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
| Auftrags-Anmeldungen | `moonshine-jobs/shared/jobs.lua` | 7 |
| Auftrags-Stationen | `moonshine-jobs/shared/jobs.lua` | 66 |
| Kleidungsläden | `moonshine-appearance/shared/config.lua` | 6 |
| Tätowierer | `moonshine-appearance/shared/config.lua` | 5 |
| Zufluchtsorte (Zutritt + Aufwachen) | `moonshine-refuge/shared/places.lua` | 14 (×2) |
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
12. **Tuning** an derselben Werkstatt (`G`): eine Felge anklicken — sie muss
    sofort am Auto sitzen — dann abbrechen (alter Zustand kommt zurück),
    danach etwas einbauen, einparken, wieder ausparken. Der Umbau muss noch
    dran sein
13. **Auktion** einstellen und mit einem zweiten Spieler überbieten
14. **Schicht** beim Postdienst, alle sechs Stationen, Abschlussbonus
15. **Abschleppdienst**: nach der ersten Station muss die Route zurück zum
    Hof zeigen, nicht zur nächsten Panne. **Nachtwache** tagsüber im
    Jobcenter aufrufen — sie muss gesperrt sein mit Begründung, nachts nicht
16. **Weltereignis** mit `/startereignis blutmond` — Werte müssen sofort
    anders sein (`/mystik` zeigt sie)
17. **Kleidungsladen** aufsuchen, etwas kaufen, Outfit sichern, in der
    Umkleide wieder wechseln
18. **Tätowierer** aufsuchen: ein Motiv anklicken (muss sofort am Ped
    erscheinen), stechen, wieder entfernen. Als Erweckter zusätzlich das
    Klassenmal — es darf nur das eigene sichtbar sein
19. **Anzeige** einstellen (`/hudmenu`): alle sechs Darstellungen
    durchklicken, Ecke wechseln, Größe ziehen, ein paar Elemente
    abschalten. Als Erweckter muss das Klassenband den richtigen Namen
    zeigen (Blut, Mana …) und die Zahlen müssen zur Essenz passen. Danach
    `/hud` aus und wieder an — die Einstellung muss den Neustart des
    Clients überleben
20. **Gurt** (`B`) im Auto: angeschnallt bei 100 km/h gegen eine Wand darf
    nichts passieren, ohne Gurt muss es den Fahrer hinauswerfen
21. **Zufluchtsort** kaufen, umbenennen, etwas einlagern, rasten (Bildschirm
    muss abblenden, danach Leben und Essenz voll). Als Vampir in einer Gruft
    muss der Segen stärker sein als in einer Hütte — `/mystik` zeigt es
22. **Zuflucht im Tod**: bewusstlos hinlegen, `H` drücken. Man muss am
    eigenen Ort aufwachen, ohne Behandlungskosten; direkt danach darf `H`
    20 Minuten lang nicht mehr gehen
23. **Adminpanel** (`F9`), Spieler beobachten, Protokoll prüfen

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

## 7. Den Wachhund einstellen

Er läuft ab Werk im **Probelauf** (`AdminConfig.Guard.probelauf = true`): er
meldet alles, kickt und bannt aber niemanden. Das bleibt so, bis du ein paar
Tage mitgelesen hast — dann auf `false`.

Zwei Prüfungen der Schicht 3 stehen aus demselben Grund ab Werk aus:
`clearPedTasks` und `giveWeapon` würden gegen den eigenen Code laufen
(Details in [`ADMIN.md`](ADMIN.md#schicht-3--was-das-spiel-dem-server-meldet)).
Wer sie einschaltet, lässt vorher `python3 tools/pruefen.py` laufen — der
listet jede Stelle auf, die dagegen läuft.

`/wachhund` (ab Level 3) zeigt jederzeit, was gerade gilt: Einstellungen,
wer wie viele Strikes hat, was mit ihm passieren *würde*, und welche Kulanzen
laufen. Das ist der schnellste Weg zu der Frage „warum meldet der nicht" bzw.
„warum meldet der schon wieder".

Vier Bremsen stehen vor jeder Maßnahme, jede verhindert sie für sich allein:
dieselbe Art zählt nur alle 2 Minuten, es braucht zwei *verschiedene* Arten,
zwischen erster und letzter Meldung müssen 60 Sekunden liegen, und nach einem
Neustart gibt es 90 Sekunden Schonfrist. Ein Bann braucht zusätzlich die
doppelte Schwelle und mindestens einen *sicheren* Fund — und geht nie über
die IP. Details in [`ADMIN.md`](ADMIN.md#wann-es-knallt--und-die-vier-bremsen-davor).

Was du im Probelauf durchsehen solltest — vor allem:

* **Explosionen.** Die Typennummern in `AdminConfig.Guard.explosionen.gesperrt`
  sind nicht im Spiel gegengeprüft. Sie stehen deshalb auf `'melden'`. Erst
  wenn im Log nur echte Fälle stehen, auf `'abbrechen'` umstellen.
* **Leben.** Klassenboni aus `moonshine-mystic` heben das Maximum. Der Puffer
  von 60 sollte reichen — wenn Vampire mit Blutmond-Bonus trotzdem auflaufen,
  `lebenPuffer` erhöhen statt die Prüfung abzuschalten.
* **Bewegung.** 190 m/s im Fahrzeug lässt Flugzeuge durch. Wer Bahnen oder
  schnelle Addon-Fahrzeuge einbaut, prüft das nach.

* **Spielermodelle.** Nur die beiden Freemode-Peds sind erlaubt. Die
  Verwandlung der Werwölfe läuft über die Kulanz (`Allow(source, 'modell')`)
  und braucht keinen Eintrag. Wer *eigene* Modelle einbaut — Job-Uniformen
  als eigenes Ped etwa —, trägt sie in `erlaubteModelle` nach, sonst läuft
  der Wachhund gegen die eigenen Leute.
* **Kulanz.** Editor, Rast, Verwandlung, Schattenschritt und jeder Respawn
  melden sich beim Wachhund an. Wenn im Log trotzdem „Unverwundbar" oder
  „Fremdes Spielermodell" für harmlose Spieler auftaucht, fehlt an einer
  Stelle das `Allow` — nicht die Prüfung abschalten, sondern die Stelle
  nachtragen.
* **Herzschlag.** 60 Sekunden Schonfrist nach dem Verbinden. Auf einem
  Server mit langen Ladezeiten eher erhöhen als abschalten.

`/verdacht [id]` zeigt die Vorgeschichte aus `ms_flags` — damit lässt sich
ein Fehlalarm von einem echten Fund unterscheiden, bevor jemand fliegt.

**Banne gehen über alle Kennungen.** Zum Prüfen: jemanden testweise bannen
und mit einem zweiten Rockstar-Account vom selben Rechner verbinden — er
muss über die IP oder Steam-Id abgewiesen werden. Wenn nicht, liefert der
Server die Kennungen nicht; dann `Config.Bans.useIp` prüfen.

## 8. Balancing scharf stellen

Die Zahlen sind gesetzt, aber nie gegen echtes Spielverhalten geprüft. Die
Punkte stehen in [`ROADMAP.md`](ROADMAP.md#balancing-das-später-aufmerksamkeit-braucht).
Am wichtigsten zuerst:

* **Steinpreise gegen Bossausbeute** — wie lange dauert der erste Skill wirklich?
* **Arbeitslohn gegen Spritkosten** — eine Schicht muss deutlich mehr bringen
  als der Sprit dafür kostet.
* **Weltereignisse** — ein Blutmond darf Vampire stark machen, aber nicht so
  stark, dass sich alle anderen ausloggen.

## 9. Was noch fehlt

Nichts, was den Server unfertig aussehen ließe. Alles Weitere ist Ausbau:
Telefon, Zufluchtsorte, Fahrzeug-Tuning, Discord-Anbindung. Der Server läuft
ohne sie.
