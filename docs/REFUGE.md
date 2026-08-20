# Zufluchtsorte – `moonshine-refuge`

Kein Housing im üblichen Sinn: keine Wohnung mit Küche, kein Klingelschild,
keine Miete. Ein Zufluchtsort ist der Platz, an den eine Klasse **gehört** –
ein Sarg in einer Gruft, ein Bau in einer Höhle, ein Turm über der Bucht.

Er kann drei Dinge:

| | |
|---|---|
| **Lagern** | Ein eigenes Lager für Steine und alles andere, ausbaubar |
| **Rasten** | Leben und Essenz voll, dazu ein Segen auf Zeit |
| **Zuflucht** | Bewusstlos hierher aufwachen statt ins Krankenhaus |

## Die vierzehn Plätze

Verteilt über die Karte, in sieben Arten:

| Art | Plätze | ab |
|---|---|---|
| **Gruft** | Vinewood-Friedhof, Grabkammer Paleto | 245.000 $ |
| **Höhle** | Mount Chiliad, Felsspalt am Zancudo | 235.000 $ |
| **Turm** | über Kortz, Leuchtturm Palomino | 360.000 $ |
| **Hain** | Lichtung am Chiliad, Weidenhain am Raton | 225.000 $ |
| **Ruine** | Grand Senora, verlassenes Lager | 210.000 $ |
| **Keller** | Hafengewölbe, Heizkeller Strawberry | 195.000 $ |
| **Hütte** | Jagdhütte Paleto, Schuppen bei Grapeseed | 185.000 $ |

Ein Charakter hält **höchstens einen** Ort. Sonst kauft der erste Spieler mit
Geld die Karte leer.

Fremde Orte bekommen weder Blip noch Marker – wo jemand anders wohnt, geht
niemanden etwas an. Freie Plätze sieht jeder, den eigenen sieht nur der
Besitzer.

## Klasse und Ort

Kaufen darf jeder jeden freien Platz. Aber **jede Klasse hat eine Art, zu der
sie gehört** – und wer dort rastet, steht deutlich stärker wieder auf:

| Klasse | heißt dort | passt zu |
|---|---|---|
| Vampir | ⚰ Sarg | Gruft |
| Nekromant | 💀 Gruft | Gruft |
| Werwolf | 🐺 Bau | Höhle |
| Dämon | 🔥 Schlund | Keller |
| Fee | 🧚 Hain | Hain |
| Magier | 🔮 Turm | Turm |
| Hexer | 🕯 Zirkelhaus | Ruine |
| Jäger | 🏹 Jagdhütte | Hütte |

Wer nicht erweckt ist, bekommt einen **🏚 Unterschlupf** – der passt nirgends,
funktioniert aber überall.

## Rasten

Einmal alle **45 Minuten**. Der Bildschirm wird dunkel, ein Satz steht da
(„Du legst dich in den Sarg."), nach 18 Sekunden wird es wieder hell.

Danach: **Leben voll**, **Essenz voll**, und ein Segen für **30 Minuten**.

| | am fremden Ort | am passenden Ort |
|---|---|---|
| Lebensregeneration | +0,4 | **+0,9** |
| Essenzregeneration | +0,5 | **+1,2** |
| Erfahrung | +10 % | **+25 %** |

Der Segen läuft über `moonshine-mystic` und wird dort wie Mondphase,
Weltereignis und Ritualpunkt-Segen mitgerechnet. Läuft die Mystik nicht mit,
bleibt die Rast trotzdem sinnvoll — Leben wird auch dann wieder voll.

> Der Segen hält **kürzer** als die Abklingzeit der Rast. Sonst ließe er sich
> stapeln und wäre dauerhaft an.

## Zuflucht statt Krankenhaus

Wer bewusstlos liegt und einen Zufluchtsort hat, sieht im Sterbebildschirm
eine dritte Zeile:

```
   E  Notruf absetzen      G  Aufgeben      H  In Sarg aufwachen
```

`H` bringt einen nach Hause statt ins Krankenhaus – und **kostet keine
Behandlungsgebühr**. Danach ist der Ort **20 Minuten erschöpft**; wer in
dieser Zeit wieder umfällt, muss ins Krankenhaus wie alle anderen.

Der Server fragt selbst nach, ob es die Zuflucht wirklich gibt und ob sie
bereit ist. Der Client sagt nur, dass er dorthin will.

## Lager

40 Plätze zum Start, ausbaubar in drei Stufen:

| Ausbau | Plätze | Preis |
|---|---|---|
| — | 40 | – |
| 1 | 60 | 45.000 $ |
| 2 | 80 | 90.000 $ |
| 3 | 110 | 180.000 $ |

Dazu ein Gewichtslimit von 150 kg. Aufgebaut wie der Fraktionstresor, nur
ohne Rechte – es ist das eigene Lager, sonst niemandes.

**Aufgeben geht nur mit leerem Lager.** Was darin liegt, würde sonst
verschwinden.

## Commands

| Command | Level | Wirkung |
|---|---|---|
| `/zuflucht` | – | Wo dein Ort liegt und wie groß dein Lager ist |
| `/zuflucht_freigeben [platzId]` | 3 | Einen Platz wieder freigeben |

Geöffnet wird der Ort mit `E` am Marker.

## Schnittstelle

```lua
local zuflucht = exports['moonshine-refuge']

zuflucht:GetRefuge(source)         -- { placeId, name, stufe } oder nil
zuflucht:GetRespawnPoint(source)   -- Aufwachpunkt oder nil (auch bei Abklingzeit)
zuflucht:MarkRefugeUsed(source)    -- Abklingzeit setzen
zuflucht:GetModifiers(source)      -- laufender Rast-Segen oder nil

-- Client
zuflucht:IsResting()
```

### Ereignisse

| Ereignis | Argumente |
|---|---|
| `refuge:server:claimed` | `source, placeId` |
| `refuge:server:released` | `source, placeId` |
| `refuge:server:rested` | `source, placeId, passt` |

## Tabelle

`ms_refuges` — ein Datensatz je **Platz**, nicht je Spieler. Ein freier Platz
hat schlicht keine Zeile.

## Was hier bewusst fehlt

* **Keine Miete.** Ein Geldabfluss, der beim Ausloggen weiterläuft, nimmt
  einem den Ort weg, während man nicht da ist. Der Kaufpreis ist die Hürde,
  danach gehört er einem.
* **Keine Innenräume.** Der Zufluchtsort ist ein Punkt in der Welt, kein
  betretbares Interieur — das bräuchte MLOs, die dieses Repo nicht mitbringt.
  Die Rast blendet dafür ab, statt so zu tun.
* **Kein Zutritt für Gäste.** Wer jemanden hereinlassen will, muss es
  ausspielen. Ein Schlüsselsystem wäre ein eigenes Feature.
