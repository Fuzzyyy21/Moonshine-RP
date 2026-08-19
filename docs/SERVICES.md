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

## Tuning

An derselben Werkstatt, aber auf **G** statt `E`. Damit füllt sich endlich
die Spalte `mods` in `ms_vehicles`, die seit dem Fahrzeugsystem ungenutzt
dalag.

Geschraubt wird nur am eigenen Fahrzeug – oder an einem, für das man einen
Zweitschlüssel hat. Der Server fragt das bei `moonshine-vehicles` nach,
bevor er irgendetwas anbaut.

### Leistung

| Teil | Stufen | Preis |
|---|---|---|
| Motor | 4 | 12.000 → 85.000 $ |
| Getriebe | 3 | 11.000 → 44.000 $ |
| Bremsen | 3 | 8.000 → 32.000 $ |
| Federung | 4 | 6.000 → 40.000 $ |
| Panzerung | 5 | 15.000 → 140.000 $ |
| Turbolader | an/aus | 62.000 $ |

Stufen sind **nicht** kumulativ zu bezahlen: wer von Stufe 1 direkt auf 4
geht, zahlt die 85.000 $ und nicht die Summe aller Stufen. Rückbau auf
Serienzustand kostet nichts – bringt aber auch nichts zurück.

### Aussehen

15 Anbauteile (Spoiler, Stoßstangen, Schweller, Auspuff, Überrollbügel,
Motorhaube, Kotflügel, Dach, Lenkrad, Sitze, Schaltknauf, Hupe, Felgen,
Kennzeichenhalter) zu je 1.500 – 14.000 $, unabhängig von der gewählten
Variante.

Dazu Lackierung (Grund-, Zweit-, Perlmutt- und Felgenfarbe aus 22 Tönen),
Fensterfolie in fünf Stufen, Xenon-Scheinwerfer, Neonbeleuchtung und
Reifenrauch.

**Nur was das Fahrzeug hergibt.** Ein Kleinwagen hat keinen Überrollbügel;
solche Teile stehen gar nicht erst in der Liste. Der Client fragt das am
Fahrzeug selbst ab (`GetNumVehicleMods`) und schickt es mit.

### Angeschaut, dann bezahlt

Jede Auswahl sitzt sofort am echten Fahrzeug – man sieht die Felge, bevor
man sie kauft. Bezahlt wird erst beim **Einbauen**. Wer abbricht oder die
Oberfläche schließt, bekommt den alten Zustand zurück.

Bezahlt wird außerdem nur, was sich **ändert**: wer eine Stufe behält, zahlt
dafür nichts. Mechaniker bekommen 25 % Rabatt.

> Der Client schickt nur, *was* er will. **Was das kostet, rechnet der
> Server aus seinem eigenen Katalog** – sonst baut sich ein manipulierter
> Client den Motor umsonst ein.

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
| `/tuning` | – | Tuning an der Werkstatt öffnen (wie `G`) |
| `/marktumzug` | 3 | Markt sofort umziehen lassen |

## API

```lua
exports['moonshine-services']:GetRepairPrice(engine, body, discount)
exports['moonshine-services']:GrantFuel(source, plate, 50)
exports['moonshine-services']:GrantRepair(source, plate, 10)
exports['moonshine-services']:GetBlackMarket()      --> 'steinbruch' oder nil
exports['moonshine-services']:MoveBlackMarket()
```

Ereignisse: `services:server:vehicleRepaired`, `services:server:vehicleTuned`,
`services:server:marketMoved`.

Die Umbauten selbst liegen bei den Fahrzeugen:

```lua
exports['moonshine-vehicles']:GetMods(plate)          --> Tabelle
exports['moonshine-vehicles']:SetMods(plate, mods)    --> speichert und trägt auf
exports['moonshine-vehicles']:MayModify(source, plate)

-- Client
exports['moonshine-vehicles']:ApplyMods(vehicle, mods)
exports['moonshine-vehicles']:ReadMods(vehicle)
exports['moonshine-vehicles']:CountMod(vehicle, modId)
```

## Was hier bewusst nicht drin ist

Keine eigene Tabelle – die Resource speichert nichts. Kontostände liegen im
Core, Tankstände, Schäden und **Umbauten** in `moonshine-vehicles`. Der
Schwarzmarkt-Standort wird beim Neustart neu gewürfelt; das ist Absicht.

Beim Tuning fehlt bewusst der **Handel mit Umbauteilen**: kein Ausbauen und
Weiterverkaufen, kein Schwarzmarkt für Motoren. Das wäre ein eigenes System,
kein Anbau an die Werkstatt.
