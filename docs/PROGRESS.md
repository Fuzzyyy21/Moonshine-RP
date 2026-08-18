# Fortschritt – Spielzeit, Missionen, Battle Pass, Kisten

Resource: `moonshine-progress`
Oberfläche: `F6` oder `/fortschritt`

Alles in dieser Resource hängt am Charakter, nicht am Account. Wer den
Charakter wechselt, fängt mit eigener Spielzeit, eigenen Missionen und eigenem
Pass an.

## Belohnungsformat

Jede Belohnung im System hat dieselbe Form. `Progress.GiveReward` gibt sie aus.

```lua
reward = {
    money = 5000,                                   -- Bank
    cash  = 500,                                    -- Bargeld
    items = { { name = 'runenstein', count = 2 } }, -- Inventar
    bpxp  = 200,                                    -- Battle-Pass-XP
    cases = { holz = 1 },                           -- Kisten
    xp    = 300,                                    -- Mystik-XP (persönlicher Baum)
}
```

Passt ein Item nicht ins Inventar, landet es als Bodenitem vor dem Spieler –
verloren geht nichts.

## Spielzeit

Die Spielzeit zählt in vollen Minuten, solange ein Charakter geladen ist. Um
4 Uhr (`ProgressConfig.Missions.resetHour`) fällt der Tageszähler auf 0 und die
Meilensteine sind wieder abholbar.

| Minuten | Titel | Belohnung |
|---|---|---|
| 15 | Aufgewärmt | 1.500 $ bar, 50 Pass-XP |
| 30 | Dabei | 4.000 $, 100 Pass-XP |
| 60 | Eine Stunde | 8.000 $, 200 Pass-XP, 1x Runenstein |
| 120 | Zwei Stunden | 15.000 $, 350 Pass-XP, 1x Holzkiste |
| 180 | Drei Stunden | 22.000 $, 500 Pass-XP, 2x Seelenstein |
| 240 | Vier Stunden | 30.000 $, 700 Pass-XP, 1x Silberkiste |
| 360 | Sechs Stunden | 50.000 $, 1.000 Pass-XP, 1x Goldkiste |

Meilensteine muss man selbst abholen. Wer sie liegen lässt, verliert sie beim
nächsten Tagesreset.

## Missionen

Jeder Charakter zieht drei tägliche und drei wöchentliche Missionen. Die
Auswahl wird aus Charakter-ID und Zeitraum berechnet – ein Relog würfelt also
nicht neu, und alle Server-Neustarts ändern nichts.

Der Fortschritt kommt aus den Ereignissen der anderen Resources:

| Ereignis | Quelle |
|---|---|
| `playtime` | Minutentick des Fortschrittssystems |
| `meditate` | `mystic:server:meditated` |
| `ritual` | `mystic:server:ritualPerformed` |
| `craft` | `mystic:server:stoneCrafted` |
| `skillUpgrade` | `mystic:server:skillUpgraded` |
| `skillUsed` | `mystic:server:skillUsed` |
| `buyStone` | `mystic:server:stoneBought` |
| `revive` | `moonshine-death:server:playerRevived` |
| `boss` | `boss:server:participantRewarded` |

Neue Missionen kommen in `shared/missions.lua` dazu. Ein neues Ereignis braucht
nur einen `AddEventHandler` in `server/missions.lua`, der `Progress.Advance`
aufruft.

## Battle Pass

* 50 Stufen, jede Stufe hat eine kostenlose und eine Premium-Spur.
* XP je Stufe: `800 + Stufe × 120`.
* Premium kostet 250.000 $ von der Bank und schaltet rückwirkend alle bereits
  erreichten Premium-Stufen frei.
* Ein Saisonwechsel (`ProgressConfig.BattlePass.season` hochzählen) setzt XP,
  Premium und abgeholte Stufen zurück.

Stufen mit eigener Belohnung stehen in `shared/battlepass.lua`; alle anderen
bekommen `Progress.DefaultTierReward`.

## Kisten

Vier Kisten mit gewichteter Ausbeute:

| Kiste | Bestes Los |
|---|---|
| Holzkiste | 1x Seelenstein |
| Silberkiste | Goldkiste, 5x Seelenstein |
| Goldkiste | Mystische Kiste, 10x Runenstein |
| Mystische Kiste | 200.000 $, 20x Runen- und Seelenstein |

Kisten liegen als Zähler im Profil. Über *Einpacken* werden sie zum Item
(`kiste_holz`, `kiste_silber`, …) und damit handelbar; wer das Item benutzt,
legt es wieder in den Bestand. Die Rollenanimation läuft im NUI, gewürfelt wird
serverseitig, bevor die Animation startet.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/fortschritt` | – | Oberfläche öffnen (auch `F6`) |
| `/spielzeit` | – | Eigene Spielzeit anzeigen |
| `/givecase [id] [kiste] [menge]` | 3 | Kiste geben |
| `/givepassxp [id] [menge]` | 3 | Battle-Pass-XP geben |
| `/resetmissions [id]` | 4 | Missionsfortschritt zurücksetzen |

## API

```lua
local Progress = exports['moonshine-progress']:GetProgressObject()

exports['moonshine-progress']:GiveReward(source, reward, 'grund')
exports['moonshine-progress']:AddBattlePassXp(source, 250)
exports['moonshine-progress']:GiveCase(source, 'gold', 1)
exports['moonshine-progress']:AdvanceMission(source, 'boss', 1)
exports['moonshine-progress']:GetPlaytime(source)   --> heute, gesamt
exports['moonshine-progress']:IsPremium(source)
```

Ereignisse: `progress:server:battlePassLevel`, `progress:server:caseOpened`,
`progress:server:profileLoaded`.

## Tabellen

`ms_progress` (ein Datensatz je Charakter) und `ms_missions` (ein Datensatz je
Charakter, Mission und Zeitraum). Beide legt die Resource beim Start selbst an.
