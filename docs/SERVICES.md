# Dienstleistungen – Tankstellen, Werkstätten, Bank, Schwarzmarkt

Resource: `moonshine-services`
Zugang: überall mit `E` am jeweiligen Punkt

Diese Resource füllt die Lücken, die andere Systeme offen gelassen haben: Das
Fahrzeugsystem rechnet mit Sprit und Schäden, die Konten aus dem Core gab es
nur als Zahl. Hier sind die Orte dazu.

## Bank und Geldautomaten

Sechs Filialen (fünf Fleeca plus Pacific Standard) und 16 Geldautomaten über
die Karte verteilt.

| | Filiale | Automat |
|---|---|---|
| Einzahlen | ja | ja |
| Abheben | unbegrenzt | max. 25.000 $ |
| Überweisen | ja | nein |

Überweisungen kosten 1 % Gebühr und gehen nur an online Spieler. Auf das
Bankguthaben gibt es stündlich 0,4 % Zinsen, gedeckelt bei 20.000 $ je
Auszahlung – so lohnt sich Einzahlen, ohne dass Reiche unendlich reicher
werden.

## Tankstellen

Neun Tankstellen mit je zwei bis drei Zapfsäulen. Man stellt sich mit dem
Fahrzeug an eine Säule, drückt `E` und wählt die Menge.

* **45 $ bar** je Prozentpunkt.
* Der Balken läuft mit Animation, der Tankstand steigt schrittweise.
* War der Tank leer und das Fahrzeug damit unfahrbar, geht es danach wieder.

**Benzinkanister** (1.800 $) füllt rund 25 Prozentpunkte und lässt sich
überall benutzen – für den Fall, dass der Tank auf der Landstraße leer wird.

## Werkstätten

Vier Werkstätten: Bennys, Hafen, Sandy Shores, Paleto Bay.

Der Preis besteht aus 750 $ Grundgebühr plus 120 $ je fehlendem
Motor-Prozentpunkt und 70 $ je Karosserie-Prozentpunkt. Wer den Job
`mechanic` hat, zahlt die Hälfte. Nach der Reparatur ist alles wieder wie
neu, inklusive Lack und Dellen.

Das **Reparaturkit** aus dem Inventar stellt je 35 Prozentpunkte auf Motor und
Karosserie wieder her – genug, um weiterzukommen, nicht genug, um sich die
Werkstatt zu sparen. (Das Item existierte im Core schon, hatte aber keine
Funktion.)

## Schwarzmarkt

Ein wandernder Händler, der alle 90 Minuten an einen von sechs Orten zieht:
Mülldeponie, Hafenlager, Steinbruch, Sumpfhütte, alter Tunnel, Chumash Pier.
Blip und Händler erscheinen erst im Umkreis von 120 bzw. 60 Metern – wer ihn
finden will, muss suchen oder jemanden fragen. `/schwarzmarkt` verrät den
groben Standort und wie lange er noch bleibt.

Gehandelt wird in **Schwarzgeld**:

| Verkauft | Preis | Kauft an | Preis |
|---|---|---|---|
| Runenstein | 2.200 $ | Runenstein | 900 $ |
| Seelenstein | 2.200 $ | Seelenstein | 900 $ |
| Dietrich | 3.500 $ | | |
| Medikit | 4.000 $ | | |
| Reparaturkit | 6.500 $ | | |

Die **Waschanlage** macht aus Schwarzgeld Bargeld – 72 % kommen an, höchstens
250.000 $ je Vorgang. Damit hat das dritte Konto aus dem Core endlich einen
Zweck.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/kontostand` | – | Bar, Bank und Schwarzgeld im Chat |
| `/ueberweisen [id] [betrag]` | – | Überweisung (nur in der Filiale) |
| `/schwarzmarkt` | – | Wo der Markt steht und wie lange noch |
| `/marktumzug` | 3 | Markt sofort umziehen lassen |

## API

```lua
exports['moonshine-services']:GetRepairPrice(engine, body, discount)
exports['moonshine-services']:GrantFuel(source, plate, 50)
exports['moonshine-services']:GrantRepair(source, plate, 10)
exports['moonshine-services']:GetBlackMarket()      --> 'steinbruch' oder nil
exports['moonshine-services']:MoveBlackMarket()
```

Ereignisse: `services:server:vehicleRepaired`, `services:server:marketMoved`.

## Was hier bewusst nicht drin ist

Keine eigene Tabelle – die Resource speichert nichts. Kontostände liegen im
Core, Tankstände und Schäden in `moonshine-vehicles`. Der Schwarzmarkt-Standort
wird beim Neustart neu gewürfelt; das ist Absicht.
