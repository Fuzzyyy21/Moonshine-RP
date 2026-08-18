# Fahrzeuge – Autohaus, Garage, Schlüssel, Verwahrstelle

Resource: `moonshine-vehicles`
Zugang: an Garage, Autohaus oder Verwahrstelle mit `E` (oder `/garage`)

Jeder Charakter darf bis zu sechs Fahrzeuge besitzen. Sie gehören dem
Charakter, nicht dem Account – ein Zweitcharakter fängt bei null an.

## Autohäuser

| Autohaus | Was es führt |
|---|---|
| Premium Deluxe Motorsport | Kompakt, Limousinen, SUV, Sport, Muscle, Gelände |
| Larrys RV Sales | Kompakt, SUV, Gelände, Nutzfahrzeuge |
| Motorradhändler | Motorräder |

Der Katalog umfasst 42 Fahrzeuge in acht Kategorien, von der Faggio für
12.000 $ bis zum Comet für 320.000 $. Bezahlt wird von der Bank. Das gekaufte
Fahrzeug steht sofort vor dem Autohaus bereit und ist bereits auf den Käufer
zugelassen.

Verkaufen geht in der Garage: 45 % des Neupreises zurück, das Fahrzeug muss
eingeparkt sein.

## Garagen

Sechs Garagen: Innenstadt, Hafen, Sandy Shores, Paleto Bay, Vinewood und
Grapeseed.

* **Ausparken** – an der Garage `E` drücken, Fahrzeug aus der Liste wählen.
  Ein Fahrzeug lässt sich nur aus der Garage holen, in der es steht.
* **Einparken** – mit dem Fahrzeug an eine Garage fahren und `E` drücken
  (oder `/einparken`). Es zählt die Garage, an der du gerade stehst – so
  verschiebt man Fahrzeuge zwischen Standorten.

Tank, Motor- und Karosseriezustand werden gespeichert und beim Ausparken
wiederhergestellt. Wer sich ausloggt, während ein Fahrzeug draußen steht,
findet es beim nächsten Login wieder in der Garage.

## Zustand und Sprit

* Der Tank verliert etwa 1,4 Prozentpunkte je Minute bei laufendem Motor,
  über 90 km/h rund 40 % mehr.
* Unter 0,4 % geht der Motor aus.
* Getankt wird über `vehicles:server:refuel` – 45 $ bar je Prozentpunkt. Ein
  Tankstellen-Script kann das direkt aufrufen; die Preisliste steht in
  `VehicleConfig.State`.
* Alle 25 Sekunden meldet der Fahrer Tank, Motor und Karosserie an den Server.

## Schlüssel

Ohne Schlüssel springt der Motor nicht an – das gilt nur für Fahrzeuge, die
in `ms_vehicles` stehen. NPC-Verkehr, Fraktionsfahrzeuge und alles andere
bleiben frei fahrbar.

* Der Besitzer hat immer einen Schlüssel.
* **Zweitschlüssel** vergibt man in der Garage über die Server-ID oder mit
  `/schluessel [id]`, während man im Fahrzeug sitzt.
* **Einziehen** entfernt alle Zweitschlüssel auf einmal.
* Bei einem Besitzerwechsel verfallen alle Zweitschlüssel.
* `L` schließt das Fahrzeug ab oder auf, aus bis zu acht Metern.

## Verwahrstelle

Fahrzeuge können über die API dorthin gebracht werden (z. B. von einem
Polizei-Script). Auslösen kostet 5.000 $ und geht nur an der Verwahrstelle
selbst; danach steht das Fahrzeug wieder in seiner Garage.

## Übertragen

Ein eingeparktes Fahrzeug lässt sich an einen anderen online Spieler
überschreiben. Der Empfänger braucht einen freien Fahrzeugplatz, alle
Zweitschlüssel verfallen dabei.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/garage` | – | Garage oder Autohaus öffnen (nur am Punkt) |
| `/einparken` | – | Fahrzeug einparken |
| `/fahrzeuge` | – | Eigene Fahrzeuge im Chat auflisten |
| `/schluessel [id]` | – | Zweitschlüssel für das Fahrzeug geben, in dem du sitzt |
| `/schliessen` (`L`) | – | Fahrzeug ver-/entriegeln |
| `/impound [kennzeichen]` | 2 | Fahrzeug verwahren |
| `/givevehicle [id] [modell]` | 3 | Fahrzeug vergeben |

## API

```lua
local Vehicles = exports['moonshine-vehicles']:GetVehiclesObject()

exports['moonshine-vehicles']:GetOwnedVehicles(source)
exports['moonshine-vehicles']:GetVehicleByPlate('MS 04711')
exports['moonshine-vehicles']:HasKey(source, 'MS 04711')
exports['moonshine-vehicles']:ImpoundVehicle('MS 04711', 'Falschparken')
exports['moonshine-vehicles']:GiveVehicle(source, 'sultan', 'innenstadt')
```

Clientseitig: `GetFuel(plate)` und `StoreCurrentVehicle()`.

Ereignisse: `vehicles:server:bought`, `vehicles:server:sold`,
`vehicles:server:transferred`, `vehicles:server:keyGiven`,
`vehicles:server:takenOut`, `vehicles:server:storedAway`,
`vehicles:server:impounded`.

## Eigene Fahrzeuge im Katalog

Ein Eintrag in `shared/catalogue.lua` reicht:

```lua
{ model = 'meinauto', label = 'Mein Auto', category = 'sport',
  price = 250000, seats = 2, speed = 5 },
```

Damit es auch verkauft wird, muss die Kategorie in `categories` eines
Autohauses in `shared/config.lua` stehen.

## Abgrenzung zur Fraktionsgarage

Fraktionsfahrzeuge liegen in `moonshine-factions` und haben eine eigene
Garage, eigene Kennzeichen aus dem Fraktionskürzel und einen eigenen Befehl
(`/fraktionparken`). Sie tauchen nicht in der persönlichen Garage auf und
brauchen keinen Schlüssel – dort entscheidet der Rang.

## Tabelle

`ms_vehicles`. Fahrzeuge, die beim Serverstart noch als „draußen“ eingetragen
sind, werden automatisch eingeparkt – sonst wären sie nach einem Absturz
unauffindbar.
