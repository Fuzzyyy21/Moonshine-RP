# Aussehen – Charaktereditor, Läden und Friseure

Resource: `moonshine-appearance`
Zugang: Kleidungsladen, Friseur oder Umkleide mit `E`

Bis hierher sah jeder gleich aus. Die Spalte `appearance` in `ms_characters`
lag schon bereit — jetzt wird sie gefüllt.

## Der Editor

Beim **ersten Login eines neuen Charakters** öffnet er sich automatisch. Danach
nur noch an einem der Orte unten.

Links die Gruppen, rechts die Werte, in der Mitte der Charakter im Spiel.
Vier Kameraansichten (Kopf, Oberkörper, Beine, Ganz), Drehen mit der linken
Maustaste oder den Pfeiltasten.

`ESC` bricht ab und stellt das vorherige Aussehen wieder her — probiert wird
also risikofrei.

### Was einstellbar ist

| Bereich | Umfang |
|---|---|
| **Gesicht** | Vater und Mutter aus je 21 Vorlagen, Ähnlichkeit und Hautton stufenlos, Augenfarbe, 20 Gesichtszüge von Nasenbreite bis Halsdicke |
| **Haare** | Frisur, Haarfarbe und Strähnchen aus 64 Tönen |
| **Kopf** | Augenbrauen, Bart, Sommersprossen, Altersspuren, Hautunreinheiten, Muttermale, Hautschaden, Teint — jeweils mit Deckkraft |
| **Make-up** | Make-up, Rouge, Lippenstift mit Farbe und Deckkraft |
| **Körper** | Brusthaar, Körperspuren |
| **Kleidung** | Oberteil, Arme, Unterhemd, Hose, Schuhe, Weste |
| **Accessoires** | Maske, Rucksack, Halskette, Aufnäher, Kopfbedeckung, Brille, Ohrschmuck, Uhr, Armband |

Wie viele Varianten es je Teil gibt, fragt die Oberfläche zur Laufzeit beim
Spiel ab — die Zahlen stimmen also auch, wenn du Addon-Kleidung streamst.

## Wo man hin muss

| Ort | Was geht | Kosten |
|---|---|---|
| **Kleidungsläden** (6) | Kleidung und Accessoires | je geändertem Teil |
| **Friseure** (5) | Haare, Bart, Augenbrauen, Make-up | 1.200 $ einmalig |
| **Umkleiden** (4) | Kleidung wechseln, Outfits verwalten | kostenlos |

Kleidungsläden gibt es in drei Preisstufen — Binco günstig, Suburban mittel,
Ponsonbys teuer:

| Stufe | Kleidungsstück | Accessoire |
|---|---|---|
| günstig | 250 $ | 150 $ |
| mittel | 900 $ | 600 $ |
| teuer | 3.500 $ | 2.200 $ |

Gezahlt wird erst beim Übernehmen, und nur für Teile, die man tatsächlich
geändert hat. Der Warenkorb steht die ganze Zeit links unten.

Beim Friseur zahlt man einmal beim Betreten und darf dann so lange
herumprobieren, wie man will.

## Outfits

Bis zu zehn gespeicherte Zusammenstellungen je Charakter, 500 $ je Platz. Ein
Outfit merkt sich nur die Kleidung, nicht das Gesicht — man kann es also auch
nach einem Friseurbesuch noch anziehen.

In der Umkleide kostet das Wechseln nichts.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/outfits` | – | Eigene Outfits im Chat |
| `/editor` | 3 | Editor überall öffnen, ohne Kosten |

## API

```lua
-- Server
exports['moonshine-appearance']:GetAppearance(source)
exports['moonshine-appearance']:SetAppearance(source, appearance)

-- Nur die Kleidung setzen, Gesicht bleibt (z. B. Dienstuniform)
exports['moonshine-appearance']:SetOutfit(source, {
    components = { ['11'] = { drawable = 55, texture = 0 } },
    props      = { ['0']  = { drawable = 12, texture = 0 } },
})

-- Client
exports['moonshine-appearance']:GetAppearance()
exports['moonshine-appearance']:ApplyAppearance(data)
exports['moonshine-appearance']:IsEditing()
```

Ereignis: `appearance:server:changed` mit der `source`.

## Aufbau der Daten

```lua
appearance = {
    model     = 'mp_m_freemode_01',
    headBlend = { shapeFirst, shapeSecond, shapeThird,
                  skinFirst, skinSecond, skinThird,
                  shapeMix, skinMix, thirdMix },
    features  = { ['0'] = 0.0, … },              -- 20 Gesichtszüge, -1 bis 1
    overlays  = { ['2'] = { index, opacity, colour, secondColour }, … },
    hair      = { drawable, texture, colour, highlight },
    eyeColour = 0,
    components = { ['11'] = { drawable, texture }, … },
    props      = { ['0']  = { drawable, texture }, … },  -- drawable -1 = nichts
}
```

Der Server prüft jeden Wert beim Speichern gegen seine Grenzen und setzt das
Modell selbst — der Client kann sich also weder ein fremdes Ped noch ungültige
Indizes zuweisen.

## Zusammenspiel

* Der Core spawnt weiter mit dem Standardmodell und feuert danach
  `moonshine:client:playerSpawned`. Erst dann legt sich das Aussehen darüber.
* Nach einer Wiederbelebung wird es erneut angewandt — das Ped kann dabei
  zurückgesetzt werden.
* Der **Gestaltwandel** aus `moonshine-mystic` tauscht das Modell vorübergehend.
  Nach `mystic:client:transformEnded` das Aussehen erneut anwenden, wenn du
  eigene Verwandlungen baust.

## Tabelle

`ms_outfits`. Das Aussehen selbst liegt in `ms_characters.appearance` — dort,
wo es von Anfang an vorgesehen war.
