# Moonshine Mystik – Rassen, Skilltree und Perks

`moonshine-mystic` baut auf `moonshine-core` auf und macht aus dem Server ein
mystisches Rollenspiel: Wesen mit eigenen Kräften, ein Skilltree, der an
Ritualpunkten mit Steinen eingelöst wird, und persönliche Werte, die man sich
über Onlinezeit erspielt.

## Ablauf für Spieler

1. **Erwecken** – Am Ritualpunkt `E` drücken, Reiter *Erweckung*, Rasse wählen.
   Standardmäßig ist die Wahl endgültig (`MysticConfig.Awakening.allowRaceChange`).
2. **Steine sammeln** – Am Ritualpunkt meditieren (Reiter *Steine*). Alle 15
   Minuten fällt ein Stein; Steine der eigenen Rasse fallen häufiger.
3. **Skills einlösen** – Reiter *Skilltree*: Skill anklicken, Kosten prüfen,
   *Einlösen*. Kostet Skillpunkte **und** Steine, und geht nur am Ritualpunkt.
4. **Leiste belegen** – Reiter *Skillleiste* oder direkt im Skill-Detail.
   `F5` klappt die Leiste im Spiel aus, `NUMPAD 1–6` lösen die Slots aus.
5. **Persönliche Skills** – Reiter *Persönliche Skills*: Leben, Ausdauer,
   Schaden, Regeneration und mehr, bezahlt aus persönlichen Punkten.

`/mystik` öffnet dieselbe Oberfläche überall – nur ohne Einlösen.

## Rassen

| Rasse | Ressource | Stärken | Besonderheit |
|---|---|---|---|
| 🩸 Vampir | Blut | Nahkampf, Tempo, Lebensentzug | Nimmt tagsüber Schaden, bis *Kind der Nacht* freigeschaltet ist |
| 🐺 Werwolf | Wut | Höchster Nahkampfschaden, viel Leben | Nachts stärker, kann sich verwandeln |
| 🔥 Dämon | Höllenfeuer | Flächenschaden, Weste | Setzt Ziele in Brand |
| 🧚 Fee | Feenstaub | Heilung, Sprünge, Tempo | Wenig Leben, kein Fallschaden |
| 🪄 Magier | Mana | Größter Vorrat, Teleport, Schild | Zeitdehnung |
| 🜏 Hexer | Hexenkraft | Flüche, Gift, Entwaffnen | Schwächt statt zu töten |
| 💀 Nekromant | Seelen | Lebensentzug auf Distanz | Belebt Gefallene wieder |
| 🏹 Jäger | Fokus | Höchster Schusswaffenschaden | Startet mit voller Weste |

Jede Rasse hat fünf Skills über vier Stufen – vier aktive und einen passiven
Abschluss. Die Werte stehen in `shared/races.lua` und `shared/skills.lua`.

## Steine

| Stein | Verwendung |
|---|---|
| Runenstein | Grundkosten aller Stufen |
| Seelenstein | Stufe 2 und 4, Rassenwechsel |
| Blutstein / Mondstein / Flammenstein / Feenstaub / Arkanstein / Schattenstein / Silberstein | rassenspezifisch ab Stufe 2 |

Steine sind normale Items im Core-Inventar. Sie werden beim Start über
`exports['moonshine-core']:RegisterItem` registriert – `moonshine-core` selbst
bleibt unverändert.

## Punkte

| Punkteart | Quelle | Verwendung |
|---|---|---|
| Skillpunkte | alle 30 Minuten Onlinezeit, +2 beim Erwecken | Rassenskills im Skilltree |
| Persönliche Punkte | alle 15 Minuten Onlinezeit, 3 zum Start | Perks (Leben, Ausdauer, Schaden, …) |

Intervalle stehen in `MysticConfig.Points`.

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

Zurücksetzen geht am Ritualpunkt – alle Punkte werden erstattet.

## Ritualpunkte

Sechs Standorte in `MysticConfig.RitualPoints` (Vinewood Friedhof, Mount
Chiliad, Altruisten-Lager, Kirche Sandy Shores, Leuchtturm Paleto, Steinkreis
bei Zancudo). Koordinaten sind Richtwerte – vor dem Livegang einmal im Spiel
prüfen und anpassen. Jeder Punkt bekommt einen Blip und einen Bodenmarker.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/mystik` | – | Übersicht öffnen |
| `/skillleiste` | – | Leiste aus-/einklappen (F5) |
| `/setrasse [id] [rasse]` | 3 | Rasse setzen |
| `/givepunkte [id] [skill\|perk] [n]` | 3 | Punkte vergeben |
| `/givestein [id] [stein] [n]` | 3 | Steine vergeben |
| `/unlockall [id]` | 3 | Alle Skills der Rasse freischalten (Test) |
| `/resetmystic [id]` | 3 | Rasse, Skills und Perks zurücksetzen |

## Balancing anpassen

* **Rassenwerte** – `shared/races.lua`: `stats` (Leben, Schaden, Tempo, Weste)
  und `essence` (Vorrat, Regeneration).
* **Skills** – `shared/skills.lua`: `cooldown`, `cost`, `effect` und die
  Freischaltkosten über die Hilfsfunktion `cost(tier, rassenstein, anzahl)`.
* **Perks** – `shared/perks.lua`: `maxLevel`, `costBase`, `costStep`, `perLevel`.
* **Tempo des Fortschritts** – `MysticConfig.Points` und
  `MysticConfig.Meditation`.
* **Schutzzonen** – `MysticConfig.Combat.safeZones`, dort wirken keine Skills.

Nach Änderungen an Shared-Dateien reicht `restart moonshine-mystic`.

## Wirkungsarten für eigene Skills

`effect.kind` bestimmt, was ein Skill tut. Vorhanden sind:

| kind | Parameter | Wirkung |
|---|---|---|
| `drain` | `radius` oder `range`+`single`, `damage`, `heal` | Schaden im Umkreis oder am Ziel, heilt den Wirker |
| `aoe_damage` | `radius`, `damage`, `fire`, `ragdoll` | Flächenschaden |
| `projectile` | `damage`, `element`, `range` | Geschoss auf das anvisierte Ziel |
| `curse` | `range`, `duration`, `slow`, `damageOverTime`, `disarm` | Verlangsamt, entwaffnet, Schaden über Zeit |
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
| `passive` | `healthBonus`, `essenceBonus`, `essenceRegen`, `regenPerTick`, `damageMult`, `meleeMult`, `costMult`, `cooldownMult`, `sunImmune`, `fireImmune`, `noFallDamage` | Dauerhafte Boni |

Ein neuer Skill braucht nur einen Eintrag in `shared/skills.lua`, solange er
eine dieser Arten nutzt. Für etwas Neues kommt der serverseitige Teil nach
`server/skills.lua` (`applySkillEffects`) und die Darstellung nach
`client/abilities.lua`.

## API

```lua
-- Server
local Mystic = exports['moonshine-mystic']:GetMysticObject()

local profile = Mystic.GetProfile(source)
profile.race                      -- 'vampir', 'werwolf', ...
profile:IsUnlocked('vampir_blutdurst')
profile:GetModifiers()            -- summierte Boni
profile:AddSkillPoints(2)
profile:Sync()
```

| Export (Server) | Rückgabe |
|---|---|
| `GetMysticObject()` | Mystik-Objekt |
| `GetProfile(source)` | Profil |
| `GetRace(source)` | Rassenname |
| `IsRace(source, race)` | boolean |
| `HasSkill(source, skillId)` | boolean |
| `GetModifiers(source)` | Tabelle |
| `AddSkillPoints(source, n)` / `AddPersonalPoints(source, n)` | boolean |
| `AddEssence(source, n)` | boolean |
| `SetRace(source, race)` | boolean |

**Events (Server)**

| Event | Argumente |
|---|---|
| `mystic:server:profileLoaded` | `source, profile` |
| `mystic:server:playerAwakened` | `source, race` |
| `mystic:server:skillUnlocked` | `source, skillId` |
| `mystic:server:skillUsed` | `source, skillId, targetSource, hits` |
| `mystic:server:perkUpgraded` | `source, perkId, level` |

**Events (Client)**

| Event | Argumente |
|---|---|
| `mystic:client:profileChanged` | `data` |
| `mystic:client:raceChanged` | `race` |
| `mystic:client:transformEnded` | – |

Beispiel: Ein Türsystem, das nur Vampire durchlässt.

```lua
if exports['moonshine-mystic']:IsRace(source, 'vampir') then
    -- Tür öffnen
end
```

## Bekannte Grenzen

* Der Gestaltwandel tauscht das Spielermodell. Ein Kleidungsscript sollte auf
  `mystic:client:transformEnded` hören und das Outfit neu setzen.
* Schaden an anderen Spielern wird beim Ziel angewendet (üblich in FiveM); der
  Server prüft vorher Rasse, Freischaltung, Essenz, Abklingzeit und Distanz.
* Es gibt noch kein Fraktions- oder Clansystem, keine Quests und keine
  Rassen-Blutlinien – dafür ist die API vorbereitet.
