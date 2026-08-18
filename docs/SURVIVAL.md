# Sterben, Wiederbelebung und Steinadern

Zwei Resources, die den Spielkreislauf schließen: `moonshine-death` gibt dem Tod
eine Konsequenz, `moonshine-nodes` gibt den Ritualsteinen eine Quelle in der Welt.

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

## moonshine-nodes – Steinadern

13 Fundorte in der Welt, an denen Ritualsteine abgebaut werden. Sie sind
**nicht auf der Karte** (`NodeConfig.Blips.enabled = false`) — sie sollen
gefunden und weitergegeben werden.

### Ablauf

* **Werkzeug**: ein **Runenmeißel** (450 $ im 24/7) ist Pflicht. Er zerbricht
  mit 4 % Wahrscheinlichkeit je Abbau.
* **Abbau**: `E` an der Ader, 9 Sekunden Fortschrittsbalken. Weglaufen bricht ab.
* **Vorkommen**: jede Ader hat 2–4 Ladungen, danach ist sie 10 Minuten versiegt.
* **Gleichzeitigkeit**: an einer Ader arbeitet immer nur einer.

### Adertypen

| Typ | Fundorte | Ausbeute |
|---|---|---|
| **Runenader** | Steinbruch, Mine, Bergland | vor allem Runensteine |
| **Seelenader** | Höhlen und Küste | vor allem Seelensteine |
| **Verwunschene Ader** | Wälder, Chiliad | wirft zusätzlich den **Klassenstein** des Spielers aus |
| **Verfluchte Ader** | Friedhof, Altruisten-Lager | beste Ausbeute, kostet währenddessen Leben |

Die Klassenader liest die Klasse über `moonshine-mystic` aus — ein Vampir
findet dort Blutsteine, ein Magier Arkansteine. Läuft das Mystik-System nicht,
fällt der Anteil einfach weg.

### Damit ergibt sich der Kreislauf

```
Steinader abbauen  ──>  Runensteine
        │                    │
        │                    ├── 5:1 umwandeln am Ritualpunkt ──> Klassenstein
        │                                                              │
        └── Verwunschene/Verfluchte Ader ──> Klassenstein direkt ───────┤
                                                                       v
                                                          Skilltree ausbauen
```

Dazu weiterhin: Meditation am Ritualpunkt alle 15 Minuten.

### Konfiguration

`moonshine-nodes/config.lua`: Werkzeug und Bruchchance, Abbaudauer, Respawn,
Ladungen, Adertypen mit gewichteter Lootliste und alle Koordinaten.
Die Koordinaten sind Richtwerte — einmal im Spiel gegenprüfen.

| Event (Server) | Argumente |
|---|---|
| `moonshine-nodes:server:mined` | `source, adertyp, item, menge` |
