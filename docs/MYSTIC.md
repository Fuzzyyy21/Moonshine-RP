# Moonshine Mystik – Klassen, Skilltree und Perks

`moonshine-mystic` baut auf `moonshine-core` auf: Wesen mit eigenen Kräften, ein
Skilltree mit Stufen, den man an Ritualpunkten mit Klassensteinen ausbaut, und
persönliche Werte, die man sich über Onlinezeit erspielt.

## Kernregel: Die Klasse bindet sich mit der ersten Fähigkeit

Nach der Erweckung bleibt die Klasse **frei wechselbar**, solange noch keine
einzige Fähigkeit geskillt wurde. In der Oberfläche sind dann alle acht Klassen
in der linken Spalte sichtbar und mit einem Klick wählbar.

Sobald die **erste Stufe einer Fähigkeit** gekauft ist, ist die Wahl endgültig:
die Seitenleiste zeigt nur noch die eigene Klasse, alle anderen sind verborgen.

Steuern lässt sich das über `MysticConfig.Awakening`:

```lua
lockAfterFirstSkill = true,   -- Kernregel; false = Wechsel bleibt offen
allowRaceChange     = false,  -- true = Wechsel auch danach, gegen Steine
raceChangeStones    = { seelenstein = 3 },
```

Beim erlaubten Wechsel verfallen alle Stufen, die ausgegebenen Klassensteine
werden vollständig erstattet.

## Ablauf für Spieler

1. **Erwecken** – Am Ritualpunkt `E`, Klasse links auswählen. Zum Start gibt es
   20 Klassensteine.
2. **Steine sammeln** – Reiter *Steine*: am Ritualpunkt meditieren, oder
   5 Runensteine in 1 Klassenstein umwandeln (`+` in der Kopfzeile).
3. **Skillen** – Reiter *Skilltree*: Knoten anklicken, Stufenliste prüfen,
   *Skillen*. Kostet Klassensteine; hohe Knoten zusätzlich eine Klassenstufe.
4. **Leiste belegen** – Im Detailfenster oder im Reiter *Skillleiste*.
   `F5` klappt die Leiste im Spiel aus, `NUMPAD 1–6` lösen die Slots aus.
5. **Persönliche Skills** – Reiter *Persönliche Skills*, bezahlt aus
   persönlichen Punkten (unabhängig von der Klasse).

`/mystik` öffnet dieselbe Oberfläche überall – nur ohne Skillen.

## Klassenstufe und XP

Jede Klasse hat eine eigene Stufe (max. 50). XP kommen aus:

| Quelle | XP |
|---|---|
| Onlinezeit | 12 pro Minute |
| Fähigkeit eingesetzt | 8 |
| je getroffenem Ziel | 6 |
| Meditation abgeschlossen | 120 |
| Stufe geskillt | 150 |

Benötigte XP für den nächsten Aufstieg: `500 + Stufe × 650`. Alles in
`MysticConfig.Progression`.

Die Stufe schaltet die unteren Baumreihen frei: Reihe 4 ab Stufe 10 bzw. 15,
der Abschlussknoten ab Stufe 25. Gesperrte Knoten zeigen ein Schloss.

## Klassen

| Klasse | Ressource | Klassenstein | Stärken |
|---|---|---|---|
| 🩸 Vampir | Blut | Blutstein | Nahkampf, Tempo, Lebensentzug; tagsüber verwundbar |
| 🐺 Werwolf | Wut | Mondstein | Höchster Nahkampfschaden, Gestaltwandel, nachts stärker |
| 🔥 Dämon | Höllenfeuer | Flammenstein | Flächenschaden, Feuer, Weste |
| 🧚 Fee | Feenstaub | Feenstaub | Heilung, Sprünge, Tempo; wenig Leben |
| 🪄 Magier | Mana | Arkanstein | Größter Vorrat, Teleport, Schild, Zeitdehnung |
| 🜏 Hexer | Hexenkraft | Hexenstein | Flüche, Gift, Entwaffnen |
| 💀 Nekromant | Seelen | Schattenstein | Lebensentzug, Wiederbelebung |
| 🏹 Jäger | Fokus | Silberstein | Höchster Schusswaffenschaden, volle Weste |

Jede Klasse hat **11 Knoten in 5 Reihen**: ein Wurzelknoten, drei Zweige mit je
zwei Ausbaustufen, drei starke Knoten ab Stufe 10/15 und ein Abschlussknoten ab
Stufe 25. Fähigkeiten haben 1, 3 oder 5 Stufen; jede Stufe verbessert die Werte
und wird im Detailfenster einzeln aufgelistet.

## Steine

| Stein | Verwendung |
|---|---|
| Klassenstein (siehe Tabelle) | einzige Währung im Skilltree |
| Runenstein | wird am Ritualpunkt in Klassensteine umgewandelt (5 : 1) |
| Seelenstein | Klassenwechsel, wenn erlaubt |

Alle Steine sind normale Items im Core-Inventar und werden beim Start über
`exports['moonshine-core']:RegisterItem` registriert – `moonshine-core` bleibt
unverändert.

## Persönliche Skills

| Perk | Wirkung pro Stufe | Max |
|---|---|---|
| Vitalität | +12 max. Leben | 10 |
| Ausdauer | längerer Sprint | 8 |
| Stärke | +4 % Waffen-, +5 % Nahkampfschaden | 10 |
| Regeneration | +1 Leben alle 5 Sekunden | 8 |
| Essenz | +10 max. Essenz | 10 |
| Fokus | +0,4 Essenz pro Tick | 8 |
| Zähigkeit | +8 Weste beim Spawn | 6 |
| Schnelligkeit | +2 % Tempo | 5 |
| Meisterung | −4 % Abklingzeit | 5 |

Punkte gibt es alle 15 Minuten Onlinezeit (3 zum Start). Zurücksetzen geht am
Ritualpunkt und erstattet alles.

## Ritualpunkte

Sechs Standorte in `MysticConfig.RitualPoints` (Vinewood Friedhof, Mount
Chiliad, Altruisten-Lager, Kirche Sandy Shores, Leuchtturm Paleto, Steinkreis
bei Zancudo), jeweils mit Blip und Bodenmarker. Koordinaten sind Richtwerte –
vor dem Livegang einmal im Spiel prüfen.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/mystik` | – | Skilltree-Übersicht öffnen |
| `/skillleiste` | – | Leiste aus-/einklappen (F5) |
| `/setrasse [id] [klasse]` | 3 | Klasse setzen |
| `/givexp [id] [xp]` | 3 | Klassen-XP vergeben |
| `/setlevel [id] [stufe]` | 3 | Klassenstufe setzen |
| `/givepunkte [id] [n]` | 3 | Persönliche Punkte vergeben |
| `/givestein [id] [stein] [n]` | 3 | Steine vergeben |
| `/unlockall [id]` | 3 | Alle Knoten auf Maximalstufe (Test) |
| `/resetmystic [id]` | 3 | Klasse, Skills, Stufe und Perks zurücksetzen |

## Balancing anpassen

* **Klassenwerte** – `shared/races.lua`: `stats` und `essence`.
* **Baum** – `shared/skills.lua`: Position (`row`, `col`), `maxRank`,
  `requires`, `level`, `stones`, `essence`, `cooldown`, `effect`.
* **Fortschritt** – `MysticConfig.Progression` (XP-Kurve und Quellen),
  `MysticConfig.Stones` (Startguthaben, Umwandlung), `MysticConfig.Meditation`.
* **Perks** – `shared/perks.lua`.
* **Schutzzonen** – `MysticConfig.Combat.safeZones`.

Nach Änderungen reicht `restart moonshine-mystic`.

### Werte pro Stufe

Jedes numerische Feld eines Effekts darf eine Liste sein – ein Eintrag je Stufe:

```lua
node{ id = 'vampir_lebensentzug', race = 'vampir', row = 1, col = 2, maxRank = 5,
      label = 'Lebensentzug', icon = '💉',
      description = 'Reisst einem Ziel die Lebenskraft heraus.',
      requires = { 'vampir_blutdurst' }, stones = { base = 18, step = 6 },
      essence = { 24, 26, 28, 30, 32 }, cooldown = { 30, 28, 26, 24, 20 },
      effect = { kind = 'drain', single = true, range = 25.0,
                 damage = { 20, 26, 32, 38, 45 },
                 heal   = { 20, 26, 32, 38, 45 } } }
```

Skalare Werte (`range`, `kind`, `model`, …) gelten für alle Stufen. Die
Stufenliste im Detailfenster wird daraus automatisch erzeugt
(`Mystic.DescribeRank`), es braucht also keine Extra-Texte.

Kosten: `stones = { base = 18, step = 6 }` bedeutet 18 / 24 / 30 / 36 / 42
Klassensteine für die Stufen 1–5. Alternativ eine feste Liste: `stones = { 15 }`.

## Wirkungsarten

| kind | Parameter | Wirkung |
|---|---|---|
| `drain` | `radius` oder `range`+`single`, `damage`, `heal` | Schaden im Umkreis oder am Ziel, heilt den Wirker |
| `aoe_damage` | `radius`, `damage`, `fire`, `ragdoll` | Flächenschaden |
| `projectile` | `damage`, `element`, `range` | Geschoss auf das anvisierte Ziel |
| `curse` | `range` oder `radius`, `duration`, `slow`, `damageOverTime`, `disarm` | Einzel- oder Flächenfluch |
| `poison` | `radius`, `duration`, `damagePerTick` | Giftwolke |
| `fear` | `radius`, `duration` | Ragdoll und Panik |
| `heal_self` | `amount`, `cleanse`, `buff` | Selbstheilung |
| `heal_target` | `range`, `amount` | Heilt das Ziel |
| `revive_target` | `range`, `health` | Belebt das Ziel wieder |
| `self_buff` | `duration`, `damageMult`, `meleeMult`, `speedMult`, `armor`, `timeScale` | Zeitlich begrenzter Buff |
| `shield` | `armor`, `duration` | Weste |
| `blink` | `distance` | Teleport nach vorn |
| `leap` | `force`, `noFallDamage` | Sprung |
| `stealth` | `duration`, `alpha`, `speedMult` | Fast unsichtbar |
| `reveal` | `radius`, `duration` | Zeigt Spieler in der Umgebung |
| `nightvision` | `duration` | Nachtsicht |
| `transform` | `duration`, `model`, `healthBonus`, `meleeMult`, `speedMult` | Gestaltwandel |
| `passive` | `healthBonus`, `armorBonus`, `stamina`, `essenceBonus`, `essenceRegen`, `regenPerTick`, `damageMult`, `meleeMult`, `speedMult`, `costMult`, `cooldownMult`, `sunImmune`, `fireImmune`, `noFallDamage` | Dauerhafte Boni je Stufe |

Für etwas völlig Neues kommt der serverseitige Teil nach `server/skills.lua`
(`applySkillEffects`) und die Darstellung nach `client/abilities.lua`.

## API

```lua
-- Server
local Mystic = exports['moonshine-mystic']:GetMysticObject()

local profile = Mystic.GetProfile(source)
profile.race                            -- 'vampir', 'werwolf', ...
profile:GetRank('vampir_blutsinn')      -- 0 = nicht gelernt
profile:GetLevel()
profile:AddXp(250)
profile:GetModifiers()
profile:CanSwitchClass()
profile:Sync()
```

| Export (Server) | Rückgabe |
|---|---|
| `GetMysticObject()` | Mystik-Objekt |
| `GetProfile(source)` | Profil |
| `GetRace(source)` | Klassenname |
| `IsRace(source, race)` | boolean |
| `HasSkill(source, skillId)` | boolean |
| `GetSkillRank(source, skillId)` | number |
| `GetLevel(source)` | number |
| `AddXp(source, n)` | boolean |
| `GetModifiers(source)` | Tabelle |
| `AddPersonalPoints(source, n)` | boolean |
| `AddEssence(source, n)` | boolean |
| `SetRace(source, race)` | boolean |

**Events (Server)**

| Event | Argumente |
|---|---|
| `mystic:server:profileLoaded` | `source, profile` |
| `mystic:server:playerAwakened` | `source, race` |
| `mystic:server:skillUpgraded` | `source, skillId, rank` |
| `mystic:server:skillUsed` | `source, skillId, targetSource, hits` |
| `mystic:server:levelUp` | `source, level` |
| `mystic:server:perkUpgraded` | `source, perkId, level` |

**Events (Client)**

| Event | Argumente |
|---|---|
| `mystic:client:profileChanged` | `data` |
| `mystic:client:raceChanged` | `race` |
| `mystic:client:levelUp` | `level` |
| `mystic:client:transformEnded` | – |

## Bekannte Grenzen

* Der Gestaltwandel tauscht das Spielermodell. Ein Kleidungsscript sollte auf
  `mystic:client:transformEnded` hören und das Outfit neu setzen.
* Schaden an anderen Spielern wird beim Ziel angewendet (üblich in FiveM); der
  Server prüft vorher Klasse, Stufe, Essenz, Abklingzeit, Distanz und Zonen.
* Es gibt noch kein Fraktions- oder Clansystem, keine Quests und keine
  Blutlinien – dafür ist die API vorbereitet.
