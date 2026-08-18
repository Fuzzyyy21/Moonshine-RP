# Welt – Zeit, Wetter, Mondphasen und Ereignisse

Resource: `moonshine-world`
Widget: oben rechts, umschaltbar mit `/welt`

Der Server gibt Uhrzeit und Wetter vor, die Clients halten nur nach. Darauf
setzen Mondphasen und mystische Weltereignisse auf, die die Kräfte der Klassen
verschieben und in die anderen Systeme eingreifen.

## Zeit

Eine Ingame-Minute dauert 2 Sekunden – ein voller Tag also 48 Minuten Echtzeit.
Zwischen 01:00 und 05:00 läuft die Uhr um ein Viertel schneller, damit niemand
ewig im Dunkeln sitzt. Uhrzeit, Tageszähler und Wetter stehen in `ms_world` und
überleben einen Neustart.

Der Tageszähler treibt die Mondphase. Ein Zyklus dauert acht Ingame-Tage, also
rund sechseinhalb Stunden Echtzeit.

## Wetter

Alle 20 bis 45 Minuten wechselt das Wetter, gewichtet ausgewählt: klarer Himmel
und heiter am häufigsten, Gewitter und Aufklaren selten. Der Übergang läuft über
45 Sekunden. Während eines Ereignisses bestimmt das Ereignis das Wetter; danach
kehrt das vorherige zurück.

## Mondphasen

| Phase | Wer profitiert |
|---|---|
| 🌑 Neumond | Nekromant, Hexer (Werwolf geschwächt) |
| 🌒 Zunehmende Sichel | Werwolf, Fee |
| 🌓 Erstes Viertel | Magier, Jäger |
| 🌔 Zunehmender Mond | Werwolf, Vampir |
| 🌕 **Vollmond** | Werwolf stark, Vampir, Jäger – dazu +10 % XP für alle |
| 🌖 Abnehmender Mond | Werwolf, Nekromant |
| 🌗 Letztes Viertel | Hexer, Fee |
| 🌘 Abnehmende Sichel | Nekromant, Dämon, +10 % Meditationspunkte |

Die Boni sind klein gehalten – niemand soll auf eine bestimmte Nacht warten
müssen, aber der Vollmond soll sich anfühlen wie einer.

## Weltereignisse

Alle 45 bis 90 Minuten passiert etwas. Zwei Minuten vorher gibt es eine
Vorwarnung, beim Start eine Einblendung mit den konkreten Auswirkungen auf die
eigene Klasse. Was zuletzt lief, kommt die nächsten drei Male nicht wieder.

| Ereignis | Dauer | Wirkung |
|---|---|---|
| 🌕 **Blutmond** | 20 Min | Vampire und Werwölfe deutlich stärker, Jäger kritischer. Bosse doppelt so oft, +1 Stein, Rituale +50 % |
| 🌘 **Sonnenfinsternis** | 12 Min | Vampire immun gegen Sonnenlicht, Magier und Hexer billiger. Rituale +75 % |
| 🌫 **Nebelnacht** | 18 Min | Nekromanten und Hexer stark, alle etwas schneller. +1 Stein |
| ✨ **Sternenfall** | 15 Min | +40 % XP und +60 % Meditationspunkte für alle, Feen und Magier stark. Rituale verdoppelt |
| 🔥 **Aschesturm** | 14 Min | Dämonen stark und feuerimmun, Feen geschwächt, alle etwas weniger Schaden |
| 👻 **Geisterstunde** | 10 Min | Nekromanten sehr stark, +2 Steine bei Bossen |
| 🌌 **Nordlicht** | 20 Min | Feen und Magier stark, Essenzregeneration für alle hoch |
| 🐺 **Wilde Jagd** | 16 Min | Werwölfe und Jäger stark, Bosse zweieinhalbmal so oft, +20 % Geld |

Jedes Ereignis setzt Wetter, Uhrzeit und einen Timecycle-Effekt. Blutmond,
Sonnenfinsternis, Sternenfall, Geisterstunde und Nordlicht halten die Uhr an –
das Ereignis findet also wirklich zu seiner Zeit statt, egal wann es startet.

## Wie es in die anderen Systeme greift

* **Mystik** – Die Modifikatoren aus Phase und Ereignis werden in
  `Profile:GetModifiers()` aufaddiert. Ändert sich etwas, bekommen alle Spieler
  sofort neue Werte. Damit wirken sie automatisch auf Schaden, Tempo, Essenz,
  Abklingzeiten, Beute, XP und Geld.
* **Weltbosse** – `bossInterval` verkürzt die Wartezeit, `stoneBonus` legt bei
  jedem Reward-Item etwas drauf.
* **Rituale** – `ritualBonus` erhöht den Ertrag am Ritualpunkt.
* **Sonnenlicht** – Bei der Sonnenfinsternis bekommen Vampire `sunImmune`, das
  bestehende Sonnenschaden-Script greift dann nicht.
* **Missionen** – Wer beim Start eines Ereignisses online ist, erfüllt *Zeuge*
  (täglich) und *Sterndeuter* (wöchentlich). Für Fraktionen zählt jedes
  anwesende Mitglied auf *Sternwarte*.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/welt` | – | Widget ein-/ausblenden |
| `/zeit` | – | Uhrzeit, Tag, Mondphase und Wetter |
| `/ereignis` | – | Laufendes Ereignis oder Zeit bis zum nächsten |
| `/setzeit [stunde] [minute]` | 2 | Uhrzeit setzen |
| `/setwetter [typ] [minuten]` | 2 | Wetter setzen |
| `/setmond [phase\|tag]` | 3 | Mondphase setzen |
| `/startereignis [id] [minuten]` | 3 | Ereignis auslösen |
| `/stopereignis` | 3 | Laufendes Ereignis beenden |

## API

```lua
local World = exports['moonshine-world']:GetWorldObject()

exports['moonshine-world']:GetTime()              --> stunde, minute, tag
exports['moonshine-world']:SetTime(22, 30)
exports['moonshine-world']:GetWeather()
exports['moonshine-world']:SetWeather('THUNDER', 20)
exports['moonshine-world']:GetMoonPhase()         --> 'vollmond'
exports['moonshine-world']:IsFullMoon()
exports['moonshine-world']:IsNight()
exports['moonshine-world']:GetActiveEvent()       --> 'blutmond' oder nil
exports['moonshine-world']:IsEventActive('blutmond')
exports['moonshine-world']:GetModifiers('vampir') --> Werte fuer diese Klasse
exports['moonshine-world']:GetModifiersForPlayer(source)
exports['moonshine-world']:GetWorldEffects()      --> bossInterval, stoneBonus, …
exports['moonshine-world']:StartEvent('blutmond', 25)
exports['moonshine-world']:StopEvent()
```

Clientseitig gibt es `GetTime`, `IsNight`, `GetMoonPhase`, `GetActiveEvent`,
`GetWorldModifiers` und `SetWorldHudVisible`.

Ereignisse: `world:server:eventStarted`, `world:server:eventEnded`,
`world:server:phaseChanged`, `world:server:weatherChanged`,
`world:server:timeChanged`. Auf dem Client zusätzlich
`world:client:eventStarted` und `world:client:eventEnded`.

## Eigene Ereignisse

Ein neues Ereignis ist ein Eintrag in `shared/events.lua`:

```lua
{
    id = 'meinereignis', label = 'Mein Ereignis', icon = '🌠',
    headline = 'Kurzer Satz fuer die Einblendung.',
    description = 'Zwei Saetze, worum es geht.',
    duration = 15, weight = 10,
    weather = 'CLEAR', forceHour = 4, freezeTime = true,
    timecycle = 'lightning', tint = '#5fc9a6',
    races  = { magier = { damageMult = 0.15 } },
    global = { xpBonus = 0.20 },
    world  = { bossInterval = 0.6, stoneBonus = 1 },
}
```

Mehr braucht es nicht – Auswahl, Ankündigung, Anzeige, Wirkung und Abbau laufen
danach von selbst.

## Tabelle

`ms_world` mit genau einem Datensatz (Tag, Uhrzeit, Wetter, Ereignis-Chronik).
