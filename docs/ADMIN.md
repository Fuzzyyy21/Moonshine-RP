# Administration – Panel und Wachhund

Resource: `moonshine-admin`
Panel: `F9` oder `/admin` (ab Adminlevel 2)

Die Commands aus dem Core gibt es weiterhin. Das Panel macht dieselben Dinge
schneller und protokolliert sie mit Namen.

## Panel

**Spieler** – Liste aller Online-Spieler mit ID, Name, Job, Klasse und
Strike-Zahl. Rechts die Detailspalte mit:

| Gruppe | Aktionen | Level |
|---|---|---|
| Bewegung | Hin, Herholen, Beobachten, Wegpunkt setzen | 2 |
| Zustand | Heilen, Wiederbeleben, Einfrieren, Auftauen | 2 |
| Geld | Geben und Setzen je Konto | 3 / 4 |
| Items | Item aus der Liste geben | 3 |
| Job | Job und Rang setzen | 3 |
| Adminlevel | Level 0–4 vergeben | 4 |
| Maßnahmen | Verwarnen, Kicken, Bannen mit Grund und Dauer | 2 / 3 |

Zwei Regeln gelten immer: Niemand kann jemanden mit höherem Adminlevel
anfassen, und niemand vergibt ein Level, das seinem eigenen entspricht oder
darüber liegt.

**Protokoll** – die letzten 60 Einträge aus `ms_logs`, filterbar nach
Kategorie. Anticheat-Meldungen sind rot abgesetzt.

**Werkzeuge** – Noclip und Unsichtbarkeit für einen selbst, Bann per Lizenz
aufheben, und eine Liste aller gerade auffälligen Spieler.

### Noclip

`W A S D` bewegen, `Q` hoch, `E` runter, `Shift` schneller, Mausrad regelt das
Grundtempo. Auch per `/noclip` erreichbar.

### Beobachten

Setzt den eigenen Charakter unsichtbar und kollisionsfrei zum Ziel und
aktiviert den Spectator-Modus. Ein zweiter Klick beendet es und teleportiert
zurück an den Ausgangspunkt.

## Wachhund

Bewusst zurückhaltend: Er meldet und sammelt **Strikes**, statt sofort zu
kicken. Ein Fehlalarm soll niemanden aus dem Spiel werfen. Admins ab Level 3
werden gar nicht geprüft.

Er steht auf vier Schichten.

### Schicht 1 — Der Server sieht selbst nach

`server/watch.lua`, alle 6 Sekunden über alle Spieler:

| Prüfung | Was auffällt | Gewicht |
|---|---|---|
| **Leben** | mehr als 200 + Klassenbonus + 60 Puffer | 2 |
| **Weste** | über 105 | 2 |
| **Waffen** | Railgun, Minigun, RPG, Werfer, Raumwaffen, Minen | 3 (+ Entzug) |

> **Das war vorher andersherum**, und das war der wichtigste Fehler im alten
> Wachhund: der *Client* meldete alle zwölf Sekunden sein eigenes Leben,
> seine Weste und seine Waffe an den Server — und der Server glaubte ihm.
> Wer cheatet, meldet eben saubere Werte, oder schaltet die Meldung ganz ab,
> dann fällt es überhaupt nicht auf.
>
> Der Server kann all das selbst vom Ped ablesen (`GetEntityHealth`,
> `GetPedArmour`, `GetSelectedPedWeapon` gibt es serverseitig). Er braucht
> den Client dafür gar nicht. `client/guard.lua` schickt heute nichts mehr.

### Schicht 2 — Ortswechsel

| Prüfung | Was auffällt | Gewicht |
|---|---|---|
| **Bewegung** | über 190 m/s im Fahrzeug bzw. 300 m Sprung zu Fuß | 1 |

Läuft ebenfalls serverseitig über `GetEntityCoords`. Nach einem
Admin-Teleport wird die letzte Position verworfen, damit das keinen
Fehlalarm auslöst.

### Schicht 3 — Was das Spiel dem Server meldet

`server/events.lua`. Diese Ereignisse kommen **aus dem Spiel, nicht aus einem
Skript** — ein Client kann sie weder fälschen noch abschalten, nur auslösen
oder nicht. Das ist die verlässlichste Quelle, die es gibt, und genau die
Stelle, an der der alte Wachhund nichts gesehen hat.

| Ereignis | Was auffällt | Gewicht | Maßnahme |
|---|---|---|---|
| `explosionEvent` | Railgun, Orbitalkanone, Flugabwehr, Valkyrie, Raygun | 4 | melden |
| `weaponDamageEvent` | über 250 Schaden, oder Treffer über 500 m | 3 | abbrechen |
| `entityCreating` | Panzer, Kampfjets, Oppressor, Deluxo, APC … | 4 | abbrechen |
| `giveWeaponEvent` | Waffe per Ereignis gegeben | 3 | abbrechen |
| `removeAllWeaponsEvent` | alle Waffen per Ereignis entfernt | 3 | abbrechen |
| `clearPedTasksEvent` | Aufgaben per Ereignis abgebrochen | 3 | abbrechen |

Die letzten drei löst ein Spieler im normalen Spiel nie selbst aus — sie
stehen in jedem Cheatmenü an erster Stelle.

> **Die Explosionsnummern stehen auf „melden", nicht auf „abbrechen".**
> Sie sind die Typennummern aus GTA und in diesem Repo **nicht im Spiel
> gegengeprüft**. Eine falsche Nummer würde sonst normales Spiel
> unterbinden. Vor dem Scharfstellen einmal ins Log sehen, was tatsächlich
> aufläuft — dann `AdminConfig.Guard.explosionen.aktion` auf `'abbrechen'`.

### Schicht 4 — Beweise

`server/evidence.lua`. Jede Meldung landet in `ms_flags`: Lizenz, Name,
Grund, Gewicht, Strike-Stand zum Zeitpunkt und die gemessenen Werte als
JSON.

`/verdacht [id]` zeigt einem Admin die letzten zehn Meldungen und die
Gesamtzahl. Eine einzelne Zeile im Chat sagt wenig — wichtig ist, ob
derselbe Spieler dreimal in zehn Minuten auffiel oder einmal vor drei
Wochen. Nach 30 Tagen werden alte Zeilen gelöscht.

### Wann es knallt

Ab **6 Strikes** (`AdminConfig.Guard.schwelle`) greift die konfigurierte
Maßnahme (`log`, `kick` oder `ban`). Strikes verfallen nach 30 Minuten.

**Kein einzelnes Gewicht erreicht die Schwelle allein** — das ist der ganze
Grund, warum es Strikes gibt und keinen Sofortkick. `tools/testen.lua`
besteht darauf.

Jede Meldung geht in die Serverkonsole, nach `ms_logs` unter `anticheat`,
nach `ms_flags` und an alle Admins ab Level 2.

### Ratenbegrenzung für eigene Resources

Der wichtigste Teil für andere Skripte: jedes Netzwerkereignis, das Geld oder
Items bewegt, sollte begrenzt sein.

```lua
RegisterNetEvent('meinshop:server:kaufen', function(item, menge)
    local source = source

    -- Höchstens 10 Käufe in 5 Sekunden.
    if not MS.RateLimit(source, 'meinshop:kaufen', 10, 5) then return end

    -- … weiter wie gewohnt
end)
```

`MS.RateLimit` **rechnet der Core selbst** (`Config.RateLimit`). Das war
früher andersherum: die Rechnung lag hier, und der Core holte sie sich per
Export. Das hatte zwei Haken — fiel diese Resource aus, waren sämtliche
Limits im ganzen Framework still aus, und `moonshine-admin` startet als
**letzte** Resource, also war zwischen Serverstart und Adminstart ohnehin
nichts begrenzt.

Jetzt greift die Begrenzung ab der ersten Sekunde und auch ohne diese
Resource. Was hier bleibt, ist die Meldung: wird die Grenze dreimal
überschritten, ruft der Core `Admin.Flag` und es setzt Strikes.

Im Framework selbst hängt die Begrenzung bereits an allen Ereignissen, die
Geld oder Items bewegen: Auktionsgebote, Bank, Schwarzmarkt, Tanken,
Fahrzeugkauf, Fraktionskasse und -tresor, Steinkauf, Kistenöffnung,
Belohnungsabholung und Arbeitsstationen.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/admin` (`F9`) | 2 | Panel öffnen |
| `/noclip` | 2 | Noclip umschalten |
| `/unsichtbar` | 2 | Unsichtbarkeit umschalten |
| `/adminliste` | 2 | Welche Admins sind online |
| `/strikes [id]` | 2 | Strikes eines Spielers |
| `/verdacht [id]` | 2 | Vorgeschichte aus `ms_flags` |
| `/clearstrikes [id]` | 3 | Strikes zurücksetzen |
| `/wachhund [an\|aus]` | 4 | Anticheat umschalten |

## API

```lua
-- Ratenbegrenzung (ueber den Core, damit sie ohne diese Resource nicht bricht)
MS.RateLimit(source, 'key', 10, 5)

-- Verdacht selbst melden
exports['moonshine-admin']:Flag(source, 'Unmoegliche Distanz', 2)

exports['moonshine-admin']:GetStrikes(source)
exports['moonshine-admin']:ClearStrikes(source)

-- Vorgeschichte einer Lizenz aus ms_flags
exports['moonshine-admin']:GetFlagHistory(license, 20)

-- Praktisch fuer eigene Ortspruefungen
exports['moonshine-admin']:IsNear(source, { x = 0, y = 0, z = 0 }, 3.0)
```

Ereignis: `admin:server:flagged` mit `source`, `reason` und der Strike-Zahl.

## Was der Wachhund nicht ist

Kein Ersatz für einen kommerziellen Anticheat mit eigenem Client-Modul. Was
er **nicht** kann:

* **Injizierte Clients erkennen.** Er sieht, was jemand *tut*, nicht womit.
* **Menüs erkennen, die nichts auslösen.** Wer nur zusieht, fällt nicht auf.
* **Aimbots und Wallhacks.** Beides erzeugt völlig normale Spielereignisse.

Was er kann, kann er dafür verlässlich: Er hängt an Quellen, die der Client
nicht abschalten kann, und er sammelt Beweise statt nur zu kicken.

Die zweite Hälfte der Absicherung steckt ohnehin nicht hier, sondern in
jeder einzelnen Resource: **der Client schickt nur Absichten, der Server
prüft Distanz, Geld, Besitz und Rechte selbst.** Dass das durchgehend
passiert, prüft `tools/pruefen.py` — unter anderem darüber, dass jedes
Netz-Event, das Geld oder Items bewegt, eine Ratenbegrenzung hat.
