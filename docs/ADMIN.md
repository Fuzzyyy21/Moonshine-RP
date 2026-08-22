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

Er steht auf sechs Schichten.

### Schicht 1 — Der Server sieht selbst nach

`server/watch.lua`, alle 6 Sekunden über alle Spieler:

| Prüfung | Was auffällt | Gewicht |
|---|---|---|
| **Leben** | mehr als 200 + Klassenbonus + 60 Puffer | 2 |
| **Weste** | über 105 | 2 |
| **Waffen** | Railgun, Minigun, RPG, Werfer, Raumwaffen, Minen | 3 (+ Entzug) |
| **Godmode** | `GetPlayerInvincible` steht auf wahr | 4 |
| **Spielermodell** | etwas anderes als die beiden Freemode-Peds | 3 |

> **Das war vorher andersherum**, und das war der wichtigste Fehler im alten
> Wachhund: der *Client* meldete alle zwölf Sekunden sein eigenes Leben,
> seine Weste und seine Waffe an den Server — und der Server glaubte ihm.
> Wer cheatet, meldet eben saubere Werte, oder schaltet die Meldung ganz ab,
> dann fällt es überhaupt nicht auf.
>
> Der Server kann all das selbst vom Ped ablesen (`GetEntityHealth`,
> `GetPedArmour`, `GetSelectedPedWeapon`, `GetPlayerInvincible` gibt es
> serverseitig). Er braucht den Client dafür gar nicht. `client/guard.lua`
> schickt heute nichts mehr.

> **Zur Modellprüfung:** die Liste erlaubter Peds ist bewusst kurz — die
> beiden Freemode-Modelle, sonst nichts. Wer eigene Modelle einbaut
> (Uniformen als eigenes Ped, Tiere für Verwandlungen), trägt sie in
> `erlaubteModelle` nach. Sonst läuft der Wachhund gegen die eigenen Leute.

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
| `giveWeaponEvent` | Waffe per Ereignis gegeben | 3 | **aus** |
| `removeAllWeaponsEvent` | alle Waffen per Ereignis entfernt | 3 | abbrechen |
| `clearPedTasksEvent` | Aufgaben per Ereignis abgebrochen | 3 | **aus** |

Die letzten drei löst ein Spieler im normalen Spiel nie selbst aus — sie
stehen in jedem Cheatmenü an erster Stelle.

> **Zwei davon stehen trotzdem auf `false`.**
> Diese Ereignisse feuert FiveM, sobald *irgendein* Client den passenden
> Native aufruft — auch unser eigener Code. `ClearPedTasks` steht bei uns an
> vierzehn Stellen (Tod, Wiederbelebung, Ritual, Tanken, Reparieren,
> Charaktereditor), `GiveWeaponToPed` gibt dem Endgegner in `moonshine-boss`
> seine Waffe. Scharf gestellt bricht der Wachhund genau diese Aufrufe ab
> und verteilt dafür Strafpunkte an Spieler, die nichts getan haben.
>
> `tools/pruefen.py` prüft das dauerhaft: wer einen der Schalter auf `true`
> setzt, bekommt jede Stelle im Code aufgelistet, die dagegen läuft
> (`WACHHUND-SELBSTBESCHUSS`).

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

### Schicht 5 — Herzschlag

`server/heartbeat.lua`. Der Server erwartet alle 20 Sekunden ein
Lebenszeichen vom Client. Bleibt es aus, **ist genau das die Meldung**.

Das ist die Antwort auf die größte Lücke eines Anticheats in reinem Lua: ein
Cheatmenü kann die clientseitigen Skripte anhalten, bevor sie etwas melden —
danach ist der Spieler unsichtbar für alles, was vom Client kommt. Dagegen
hilft nur die Umkehrung. Wer den Anticheat abschaltet, fällt dadurch auf,
dass er still wird.

Das Zeichen trägt einen Wert, den nur der Server kennt und der sich bei
jedem Schlag ändert. Ein Cheater müsste also nicht irgendetwas schicken,
sondern das Richtige — und das bekommt er nur, wenn das echte Skript läuft.
Ein **falscher** Wert wiegt schwerer als gar keiner.

Nach dem Verbinden gibt es 60 Sekunden Schonfrist, damit niemand auffällt,
bevor sein Client überhaupt geladen hat.

### Schicht 6 — Bann über alle Kennungen

`moonshine-core/server/bans.lua`, Tabelle `ms_bans`.

Ein Bann hing vorher allein an der **Rockstar-Lizenz**. Neuer Account — oder
ein Spoofer — und derselbe Mensch war wieder da. Jetzt wird auf allen
Kennungen gesperrt, die FiveM beim Verbinden liefert:

`license` · `steam` · `discord` · `fivem` · `xbl` · `live` · `ip`

Beim Verbinden werden **alle** geprüft, nicht nur eine. `/ban` und der
Wachhund benutzen denselben Weg; `/unban license:…` hebt alle Kennungen
dieser Lizenz auf einmal auf.

> Die **IP** ist mit Absicht abschaltbar (`Config.Bans.useIp`) — hinter einer
> IP können Mitbewohner sitzen.

### Kulanz — was der Server selbst erlaubt hat

`server/allow.lua`. Ein Wachhund, der die eigenen Spieler kickt, ist
schlimmer als keiner — und genau das würde ohne diese Schicht passieren:

| Was der Server tut | Was der Wachhund sähe |
|---|---|
| Charaktereditor | unverwundbar + fremdes Ped-Modell |
| Rast im Zufluchtsort | unverwundbar |
| Verwandlung (Werwolf) | fremdes Ped-Modell + 290 Leben |
| Schattenschritt | Ortswechsel + zwei Explosionen |
| Respawn, `/bring`, `/tp` | Ortswechsel über die halbe Karte |

Deshalb sagt der **Server** dem Wachhund vorher Bescheid. Nicht der Client —
der dürfte sich sonst selbst freischalten. Jede Ausnahme kommt von der
Stelle, die die Handlung ohnehin schon geprüft hat:

```lua
exports['moonshine-admin']:Allow(source, 'godmode', 900)   -- Editor auf
exports['moonshine-admin']:Deny(source, 'godmode')         -- Editor zu
exports['moonshine-admin']:IsAllowed(source, 'godmode')    -- gilt gerade?
```

Arten: `godmode`, `teleport`, `explosion`, `modell`, `leben`.

Drei Eigenschaften, auf denen `tools/testen.lua` besteht:

- **Ab Werk gilt nichts.** Eine Kulanz, die von selbst greift, wäre ein Loch
  statt einer Ausnahme.
- **Sie läuft ab.** Ohne Zeitangabe nach 15 Sekunden.
- **Sie wird nie verkürzt.** Rast und Schattenschritt dürfen sich die
  Ausnahme nicht gegenseitig wegnehmen — die längere gewinnt.

Ein Sonderfall steckt in `moonshine-mystic`: die Sicht-Effekte einer
Fähigkeit zünden ihre Explosion auf dem Rechner **jedes Zuschauers**. Für den
Server ist damit der Zuschauer der Verursacher. Ohne die Kulanz sammelt jeder
Umstehende die Strafpunkte für einen fremden Zauber ein.

### Probelauf

`AdminConfig.Guard.probelauf` steht ab Werk auf **`true`**: der Wachhund
meldet alles, aber kickt und bannt niemanden. Das ist die einzig ehrliche
Voreinstellung, solange nichts davon auf einem echten Server gelaufen ist.

Ein paar Tage mitlesen, `/verdacht` und `ms_flags` durchsehen — und erst dann
auf `false` stellen.

### Wann es knallt

Ab **6 Strikes** (`AdminConfig.Guard.schwelle`) greift die konfigurierte
Maßnahme (`log`, `kick` oder `ban`) — sofern der Probelauf aus ist. Strikes
verfallen nach 30 Minuten.

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

Er ist **kein Ersatz für einen kommerziellen Anticheat** wie Electron,
FiveGuard oder Wave — und das lässt sich in reinem Lua auch nicht ändern.
Der Unterschied ist keine Frage des Aufwands, sondern der Ebene:

| | kommerzieller Anticheat | dieser Wachhund |
|---|---|---|
| **Client-Modul** | kompiliert, verschleiert, teils mit Kernel-Treiber | Lua-Skript, für jeden lesbar |
| **Speicher lesen** | ja — findet injizierte DLLs und bekannte Menüs | nein, geht aus Lua nicht |
| **Prozesse prüfen** | ja | nein |
| **Hardware-Kennung** | echte HWID über Systemwerte | nur die Kennungen, die FiveM liefert |
| **Signaturen** | Datenbank, laufend gepflegt von einem Team | keine |
| **Screenshots** | eingebaut | nur wenn `screenshot-basic` läuft |
| **Verhalten prüfen** | ja | **ja — hier ist er ebenbürtig** |
| **Serverseitige Prüfung** | ja | **ja — hier ist er ebenbürtig** |

Der Kern des Unterschieds: ein Cheatmenü läuft **über** der CitizenFX-Runtime
und hat vollen Zugriff auf den Speicher des Spiels. Jedes Lua-Skript, das ich
schreibe, kann es lesen, verändern oder anhalten. Deshalb hängt hier alles
Wichtige an Quellen, die der Client nicht abschalten kann — und deshalb gibt
es Schicht 5: wer die Skripte anhält, wird still, und Stille ist die Meldung.

### Was er dadurch konkret nicht findet

* **Injizierte Clients.** Er sieht, was jemand *tut*, nicht womit.
* **Menüs, die nichts auslösen.** Wer nur zusieht, fällt nicht auf.
* **Aimbots und Wallhacks.** Beides erzeugt völlig normale Spielereignisse —
  ein Kopfschuss sieht aus wie ein Kopfschuss.
* **Spoofer.** Wer alle Kennungen fälscht, kommt an Schicht 6 vorbei.

### Was er dafür zuverlässig findet

Alles, was sich im Spiel **auswirkt**: Godmode, unmöglicher Schaden,
gesperrte Waffen und Fahrzeuge, Teleports, Explosionen aus Waffen, die es
nicht geben dürfte, die Standard-Ereignisse jedes Cheatmenüs — und den
Versuch, den Anticheat selbst loszuwerden.

### Die zweite Hälfte steckt nicht hier

Die wirksamste Absicherung dieses Frameworks ist nicht der Wachhund, sondern
dass **jede Resource ihre eigenen Eingaben prüft**: der Client schickt nur
Absichten, der Server prüft Distanz, Geld, Besitz und Rechte selbst. Ein
Cheatmenü kann dann beliebig Events feuern und bekommt trotzdem nichts.

Dass das durchgehend passiert, prüft `tools/pruefen.py` — unter anderem
darüber, dass jedes Netz-Event, das Geld oder Items bewegt, eine
Ratenbegrenzung hat.

### Wenn du mehr brauchst

Für einen Server mit vielen Spielern und echtem Cheat-Druck ist ein
kommerzielles Produkt zusätzlich sinnvoll. Es ersetzt diesen Wachhund nicht,
sondern ergänzt ihn: der eine prüft den *Rechner*, der andere prüft das
*Spielgeschehen*. Beide zusammen decken ab, was keiner allein kann.
