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
2. **Grundsteine sammeln** – beim Weltboss (1–4 Runen- und 1–4 Seelensteine)
   oder beim Steinhändler (je 1000 $). Daraus am Ritualpunkt einen Klassenstein
   binden: **10 + 10 → 1**. Der erste Skill kostet 5 Klassensteine.
3. **Skillen** – Reiter *Skilltree*: Knoten anklicken, Stufenliste prüfen,
   *Skillen*. Kostet ausschließlich Klassensteine; tiefe Knoten zusätzlich eine
   Mindest-Klassenstufe (= Anzahl bereits geskillter Stufen).
4. **Leiste belegen** – Im Detailfenster oder im Reiter *Skillleiste*.
   `F5` klappt die Leiste im Spiel aus, `NUMPAD 1–6` lösen die Slots aus.
5. **Persönliche Skills** – Reiter *Persönliche Skills*, bezahlt aus
   Erfahrung (XP), unabhängig von der Klasse.

`/mystik` öffnet dieselbe Oberfläche überall – nur ohne Skillen.

## Zwei getrennte Währungen

Das ist die wichtigste Regel des Systems:

| Baum | Währung | Quelle |
|---|---|---|
| **Klassenbaum** (Fähigkeiten der Klasse) | **Klassensteine** | aus 10 Runen- + 10 Seelensteinen gebunden |
| **Persönlicher Baum** (Leben, Ausdauer, Schaden, …) | **Erfahrung (XP)** | Onlinezeit und Aktivität |

XP können **nicht** in Klassenfähigkeiten gesteckt werden, Steine **nicht** in
persönliche Skills. Wer nur online steht, wächst persönlich; wer Steine sammelt,
wächst in seiner Klasse.

### Klassenstufe

Die Klassenstufe ist keine XP-Stufe: **sie zählt die im Klassenbaum gekauften
Stufen**. Wer 12 Stufen geskillt hat, ist Klassenstufe 12. Sie steigt also
ausschließlich durch ausgegebene Klassensteine.

Tiefere Knoten setzen eine Mindest-Klassenstufe voraus und zeigen bis dahin ein
Schloss:

| Reihe | Voraussetzung |
|---|---|
| Reihe 1–3 | nur die vorherige Fähigkeit |
| Reihe 4 (starke Knoten) | Klassenstufe 8 bzw. 12 |
| Abschlussknoten | Klassenstufe 18 |

Ein voll ausgebauter Baum hat je nach Klasse rund 40 Stufen.

### Erfahrung

XP gibt es unabhängig von der Klasse — auch ohne Erweckung:

| Quelle | XP |
|---|---|
| Onlinezeit | 20 pro Minute |
| Fähigkeit eingesetzt | 10 |
| je getroffenem Ziel | 8 |
| Meditation abgeschlossen | 150 |

Meditation gibt zusätzlich Meditationspunkte — eine eigene Währung, siehe unten.

Zum Start gibt es 500 XP. Das Guthaben wird beim Kauf einer Perkstufe abgezogen;
die *persönliche Stufe* im Reiter *Persönliche Skills* richtet sich nach der
insgesamt verdienten Erfahrung (`500 + Stufe × 650` je Aufstieg) und sinkt beim
Ausgeben nicht. Alles einstellbar in `MysticConfig.Progression`.

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
zwei Ausbaustufen, drei starke Knoten ab Klassenstufe 8 bzw. 12 und ein
Abschlussknoten ab Klassenstufe 18. Fähigkeiten haben 1, 3 oder 5 Stufen; jede Stufe verbessert die Werte
und wird im Detailfenster einzeln aufgelistet.

## Steine

Es gibt nur **zwei Grundsteine**, aus denen alles andere entsteht:

| Stein | Woher |
|---|---|
| **Runenstein** | Weltboss (1–4), Steinhändler (1000 $) |
| **Seelenstein** | Weltboss (1–4), Steinhändler (1000 $) |

**Binden** am Ritualpunkt, Reiter *Steine*:

```
10x Runenstein + 10x Seelenstein  ──>  1x Klassenstein
```

Der Klassenstein richtet sich nach der eigenen Klasse — ein Vampir bindet
Blutsteine, ein Magier Arkansteine — und ist die einzige Währung im Skilltree.
Rezept und Preise stehen in `MysticConfig.Stones` und `MysticConfig.Merchant`.

**Steinhändler** stehen in Vinewood, Sandy Shores, Paleto Bay und der
Innenstadt, sind auf der Karte markiert und verkaufen beide Grundsteine gegen
Bargeld. Details zum Weltboss in [`SURVIVAL.md`](SURVIVAL.md).

Alle Steine sind normale Items im Core-Inventar und werden beim Start über
`exports['moonshine-core']:RegisterItem` registriert – `moonshine-core` bleibt
unverändert.

## Persönliche Skills

Bezahlt wird mit **XP**. Die Kosten steigen je Stufe: `costBase + (Stufe−1) × costStep`.

| Perk | Wirkung pro Stufe | Max | Stufe 1 | Aufschlag |
|---|---|---|---|---|
| Vitalität | +12 max. Leben | 10 | 300 XP | +200 |
| Ausdauer | längerer Sprint | 8 | 250 XP | +150 |
| Stärke | +4 % Waffen-, +5 % Nahkampfschaden | 10 | 400 XP | +250 |
| Regeneration | +1 Leben alle 5 Sekunden | 8 | 400 XP | +250 |
| Essenz | +10 max. Essenz | 10 | 300 XP | +200 |
| Fokus | +0,4 Essenz pro Tick | 8 | 400 XP | +250 |
| Zähigkeit | +8 Weste beim Spawn | 6 | 350 XP | +250 |
| Schnelligkeit | +2 % Tempo | 5 | 600 XP | +400 |
| Meisterung | −4 % Abklingzeit | 5 | 600 XP | +400 |

Zurücksetzen geht am Ritualpunkt und erstattet die volle ausgegebene Erfahrung.

## Am Ritualpunkt

Drei Dinge passieren dort, jeweils mit eigener Abklingzeit:

| Handlung | Dauer | Abklingzeit | Ertrag |
|---|---|---|---|
| **Meditation** | 20 s | 15 Min | 1–3 Meditationspunkte + 150 XP |
| **Ritual** | 30 s | 30 Min | 10.000 $ auf die Bank |
| **Segen** | sofort | – | kostet Meditationspunkte |

### Meditationspunkte

Meditation gibt **ausschließlich Meditationspunkte** — keine Steine. Sie sind
eine eigene Währung neben Klassensteinen und XP.

Aktuell kauft man damit **Segen**: sofort wirkende Vorteile am Ritualpunkt.

| Segen | Kosten | Wirkung |
|---|---|---|
| Segen der Klarheit | 1 | Essenz sofort voll |
| Segen der Genesung | 2 | volle Heilung, reinigt Flüche |
| Segen der Eile | 2 | alle Abklingzeiten zurückgesetzt |
| Segen des Schutzes | 3 | 5 Min lang 75 Weste |
| Segen der Stärke | 4 | 5 Min lang +25 % Schaden |

Das ist ein erster Entwurf — die Liste steht komplett in
`MysticConfig.Blessings` und lässt sich frei umbauen. Weitere Ideen für
Meditationspunkte stehen in [`ROADMAP.md`](ROADMAP.md).

### Rituale

Ein Ritual bringt **vorerst nur Geld**: 10.000 $ auf die Bank, alle 30 Minuten.
Was sonst noch dabei herausspringen soll, ist bewusst offen gelassen —
Vorschläge dazu in [`ROADMAP.md`](ROADMAP.md).

`MysticConfig.Ritual` regelt Dauer, Abklingzeit, Belohnung und einen optionalen
Einsatz an Meditationspunkten (`costPoints`, standardmäßig 0).

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
| `/givexp [id] [xp]` | 3 | Erfahrung für den persönlichen Baum vergeben |
| `/givemeditation [id] [n]` | 3 | Meditationspunkte vergeben |
| `/givestein [id] [stein] [n]` | 3 | Steine vergeben |
| `/unlockall [id]` | 3 | Alle Knoten auf Maximalstufe (Test) |
| `/resetmystic [id]` | 3 | Klasse, Skills, Stufe und Perks zurücksetzen |

## Balancing anpassen

* **Klassenwerte** – `shared/races.lua`: `stats` und `essence`.
* **Baum** – `shared/skills.lua`: Position (`row`, `col`), `maxRank`,
  `requires`, `level`, `stones`, `essence`, `cooldown`, `effect`.
* **Fortschritt** – `MysticConfig.Progression` (XP für den persönlichen Baum),
  `MysticConfig.Stones` (Rezept, Startguthaben), `MysticConfig.Merchant`
  (Händlerpreise und Standorte) und `MysticConfig.Meditation`.
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
profile:GetLevel()          -- geskillte Stufen im Klassenbaum
profile:GetPersonalProgress() -- Stufe, XP in der Stufe, XP bis zur naechsten
profile:AddXp(250)          -- Erfahrung fuer den persoenlichen Baum
profile:SpendXp(300)
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
| `GetLevel(source)` | number (geskillte Stufen im Klassenbaum) |
| `GetPersonalLevel(source)` | number (Stufe aus verdienter XP) |
| `GetXp(source)` | number (XP-Guthaben) |
| `AddXp(source, n)` | boolean |
| `SpendXp(source, n)` | boolean |
| `GetModifiers(source)` | Tabelle |
| `AddEssence(source, n)` | boolean |
| `SetRace(source, race)` | boolean |

**Events (Server)**

| Event | Argumente |
|---|---|
| `mystic:server:profileLoaded` | `source, profile` |
| `mystic:server:playerAwakened` | `source, race` |
| `mystic:server:skillUpgraded` | `source, skillId, rank` |
| `mystic:server:skillUsed` | `source, skillId, targetSource, hits` |
| `mystic:server:levelUp` | `source, level` (persönliche Stufe) |
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
