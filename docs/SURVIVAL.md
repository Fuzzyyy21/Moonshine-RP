# Sterben, Wiederbelebung und Steinadern

Zwei Resources, die den Spielkreislauf schließen: `moonshine-death` gibt dem Tod
eine Konsequenz, `moonshine-boss` gibt den Ritualsteinen eine Quelle in der Welt.

---

## moonshine-death – Bewusstlosigkeit statt Tod

Wer stirbt, respawnt nicht sofort, sondern geht **zu Boden**: Animation am
Boden, keine Steuerung, kein Klassenskill, ein Bildschirm mit Countdown.

### Ablauf

1. **Bewusstlos** – 5 Minuten Ausbluten (`DeathConfig.BleedoutTime`).
2. **Notruf** (`E`) – benachrichtigt alle EMS-Mitarbeiter und alle Spieler der
   Heilerklassen (Fee, Nekromant) mit blinkendem Blip auf der Karte.
3. **Wiederbelebung** – ein Helfer geht ran und drückt `G`. Das dauert
   8 Sekunden, verbraucht ein **Medikit** und braucht den Job `ambulance`.
   Alternativ heilen die Klassenskills *Wiedergeburt* (Fee) und
   *Wiedererweckung* (Nekromant) — sie räumen den Zustand direkt auf.
4. **Aufgeben** (`G`) – ab 2 Minuten erlaubt. Kostet 750 $ Behandlungskosten und
   spawnt im nächstgelegenen Krankenhaus.
5. **In die Zuflucht** (`H`) – nur wer einen Zufluchtsort hat
   (→ [`REFUGE.md`](REFUGE.md)). Kostet **nichts**, dafür ist der Ort danach
   20 Minuten erschöpft. Die Zeile taucht im Sterbebildschirm nur auf, wenn
   es wirklich einen gibt.
5. **Schwäche** – 2 Minuten lang maximal 140 Leben und langsameres Tempo.

### Gegen Combat-Log

Die Bewusstlosigkeit wird in den Charakter-Metadaten gespeichert. Wer im
bewusstlosen Zustand disconnected, liegt beim nächsten Einloggen wieder am
Boden — mit weitergelaufener Uhr (`DeathConfig.DisableCombatLog`).

### Konfiguration

Alles in `moonshine-death/config.lua`: Zeiten, Krankenhäuser, Kosten,
Wiederbelebungs-Jobs und -Item, Schwäche, Tasten.

### API

```lua
-- Server
exports['moonshine-death']:IsPlayerDowned(source)      --> boolean
exports['moonshine-death']:RevivePlayer(source, health) --> boolean

-- Client
exports['moonshine-death']:IsDowned()                  --> boolean
```

| Event (Server) | Argumente |
|---|---|
| `moonshine-death:server:playerDowned` | `source` |
| `moonshine-death:server:playerRevived` | `source` |
| `moonshine-death:server:playerRespawned` | `source, bezahlteKosten` |

---

## moonshine-boss – Weltbosse

Alle 45 Minuten erscheint an einem von sechs abgelegenen Orten ein Weltboss.
Er wird serverweit angekündigt und auf der Karte markiert.

### Ablauf

* Drei Bosse zur Auswahl: **Uralter Blutfürst** (3500 Leben), **Bestie der
  Wildnis** (2800) und **Schattenwandler** (4200, 300 Weste).
* Der Boss greift den nächstgelegenen Spieler an, flieht nie und lässt sich
  nicht umwerfen. Über ihm läuft ein Lebensbalken, solange man in der Nähe ist.
* Wer mindestens **3 Treffer** landet und beim Tod im Umkreis von 80 Metern
  steht, bekommt seinen Anteil.
* Nach 25 Minuten zieht er sich zurück, falls ihn niemand erlegt.

### Beute

Jeder Teilnehmer würfelt **getrennt für beide Steinarten**:

| Stein | Menge |
|---|---|
| Runenstein | 1–4 |
| Seelenstein | 1–4 |

Wer die meisten Treffer gelandet hat, bekommt zusätzlich 2 Seelensteine.

### Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/bossspawn` | 3 | Boss sofort erscheinen lassen |
| `/bossweg` | 3 | Laufenden Boss entfernen |
| `/bossinfo` | 3 | Status und Teilnehmerzahl |

### Konfiguration

`moonshine-boss/config.lua`: Intervall, Lebensdauer, Spawnpunkte, Bosse mit
Modell, Leben, Waffe und Treffsicherheit, Beutemenge und Teilnahmebedingungen.

| Event (Server) | Argumente |
|---|---|
| `moonshine-boss:server:spawned` | `name, ort` |
| `moonshine-boss:server:defeated` | `name, anzahlBelohnter` |
| `moonshine-boss:server:despawned` | `grund` |

---

## Die Steinwirtschaft im Überblick

Es gibt nur **zwei Grundsteine**: Runenstein und Seelenstein.

```
Weltboss (1-4 je Sorte)  ─┐
Steinhändler (1000 $/St.) ─┴──>  Runensteine + Seelensteine
                                         │
                                         │  10 + 10 am Ritualpunkt
                                         v
                                  1 Klassenstein  (erster Skill: 5 Stück)
                                         │
                                         v
                                  Skilltree ausbauen

Ritual (alle 30 Min)   ──> 10.000 $  ──> beim Händler wieder Steine
Meditation (alle 15 Min) ──> Meditationspunkte ──> Segen
```

**Steinhändler** stehen an vier Orten (Vinewood, Sandy Shores, Paleto Bay,
Innenstadt), sind auf der Karte markiert und verkaufen beide Grundsteine für
je 1000 $ Bargeld. Konfiguration in `moonshine-mystic/shared/config.lua`
unter `MysticConfig.Merchant`.

**Binden** (Craften) geht nur am Ritualpunkt, Reiter *Steine*: 10 Runensteine
plus 10 Seelensteine ergeben einen Klassenstein der eigenen Klasse. Das Rezept
steht in `MysticConfig.Stones.recipe`.
