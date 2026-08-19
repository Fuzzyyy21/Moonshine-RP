# Fraktionen

Resource: `moonshine-factions`
Oberfläche: `F10` oder `/fraktion`

Eine Fraktion ist eine Spielergruppe mit eigenem Wappen, eigener Rangordnung,
gemeinsamer Kasse, gemeinsamem Lager, eigenem Fuhrpark und eigenen Gebieten.

## Gründen

`/fraktion` → *Fraktion gründen*. Kostet 500.000 $ von der Bank
(`FactionConfig.Create.price`), Admins ab Level 3 gründen kostenlos. Name und
Kürzel sind serverweit eindeutig. Jede Fraktion bekommt automatisch eine freie
Basis aus `FactionConfig.Bases`.

Admins können auch `/createfaction [name] [tag] [id]` benutzen; Leerzeichen im
Namen werden als `_` geschrieben.

## Wappen, Banner und Willkommensbild

Statt Bilddateien gibt es einen Baukasten. Die Oberfläche zeichnet daraus ein
SVG, der Server speichert nur die Auswahl – es gibt also nichts hochzuladen.

* **8 Schildformen** – Wappen, Spitzschild, Rundschild, Siegel, Raute, Banner,
  Sechseck, Klaue
* **18 Symbole** – Wolf, Fledermaus, Schädel, Auge, Mond, Flamme, Blitz, Krone,
  Dolch, Kelch, Rabe, Stern, Rune, Schlange, Weltenbaum, Kristall, Zahnrad, Anker
* **8 Muster** – einfarbig, Verlauf, geteilt, schräg geteilt, Streifen,
  Strahlen, Karo, Kreuz
* **6 Motive** für Banner und Willkommensbild – Nebelwald, Blutmond, Ruinen,
  Sturm, Ascheregen, Sternenhimmel
* **Zwei Farben** aus einer Palette von zwölf

Dazu kommen ein Wahlspruch (64 Zeichen) und ein Willkommenstext (240 Zeichen).
Beides erscheint im Banner der Übersicht und im Willkommensbild, das neue
Mitglieder beim Beitritt und beim Einloggen sehen.

Die Hauptfarbe färbt außerdem die ganze Oberfläche und die Gebietsmarkierungen
auf der Karte ein.

## Ränge und Rechte

Bis zu acht Ränge, jeder mit eigenem Namen und Rang-Icon. Der oberste Rang ist
immer die Führung und hat alle Rechte – das lässt sich nicht abwählen.

| Recht | Bedeutung |
|---|---|
| `invite` | Einladen |
| `kick` | Rauswerfen |
| `promote` | Ränge vergeben |
| `vaultPut` / `vaultTake` | Tresor einlagern / entnehmen |
| `kasseTake` | Kasse abheben (Einzahlen darf jeder) |
| `shop` | Fraktionsshop nutzen |
| `garage` / `garageBuy` | Fahrzeuge ausparken / kaufen |
| `skills` | Skilltree ausbauen |
| `territory` | Gebiete einnehmen |
| `missions` | Fraktionsmissionen abrechnen |
| `manage` | Wappen und Fahrzeugränge verwalten |

Standardmäßig gibt es Anwärter, Mitglied, Veteran, Hauptmann, Rat und Führung.
Nur die Führung darf die Rangstruktur ändern und die Führung übergeben.

## Level und Skilltree

Fraktions-XP kommen aus Missionen, Gebietseinnahmen und Gebietseinkommen. Je
Level gibt es einen Fraktionspunkt, maximal Level 30.

Der Baum hat zwölf Knoten in drei Zweigen:

| Zweig | Knoten |
|---|---|
| Wirtschaft | Handelsnetz → Wegzoll, Schatzmeister → Monopol |
| Macht | Drill → Bollwerk → Sturmtrupp |
| Logistik | Fuhrpark → Werkstatt, Großlager → Imperium |

Wurzel ist *Fundament* (mehr Mitglieder- und Tresorplätze). Zurücksetzen kostet
250.000 $ aus der Kasse und gibt alle Punkte zurück; das darf nur die Führung.

## Kasse und Tresor

* **Kasse**: Einzahlen darf jeder, jede Einzahlung zählt auf den Beitrag des
  Mitglieds. Abheben braucht `kasseTake` und ist auf 250.000 $ je Vorgang
  begrenzt. *Monopol* macht Auszahlungen für die Kasse billiger.
* **Tresor**: 60 Plätze zu Beginn, bis 500 kg. Einlagern und Entnehmen sind
  getrennte Rechte, jede Bewegung steht im Protokoll.

## Shop und Garage

Beide zahlen aus der Kasse. *Handelsnetz* senkt die Shoppreise, *Werkstatt* die
Fahrzeugpreise.

Fahrzeuge bekommen ein Kennzeichen aus dem Fraktionskürzel und einen
Mindestrang. Ausgeparkt wird an einem der vier Ausgabepunkte, eingeparkt mit
`/fraktionparken`, während man im Fahrzeug am Punkt steht. Verkaufen gibt die Hälfte
des Grundpreises zurück.

## Gebiete

Acht Gebiete, je mit Einkommen und XP:

| Gebiet | Einkommen | Gebiet | Einkommen |
|---|---|---|---|
| Hafenviertel | 12.000 $ | Grove Street | 11.000 $ |
| Vinewood Hills | 15.000 $ | Mirror Park | 10.500 $ |
| Sandy Shores | 9.000 $ | Raffinerie | 16.000 $ |
| Paleto Bay | 9.500 $ | Observatorium | 13.000 $ |

**Einnahme**: Steht genau eine fremde Fraktion im Gebiet, wächst ihr Balken.
Grundzeit sind 180 Sekunden, *Drill* und *Sturmtrupp* beschleunigen das. Stehen
zwei fremde Fraktionen drin oder verteidigt der Besitzer vor Ort, ist das
Gebiet umkämpft und der Balken steht still. Ohne Angreifer fällt er zurück –
Verteidiger verdoppeln das Tempo, *Bollwerk* erhöht es weiter.

**Schutz**: Ein frisch eingenommenes Gebiet ist 30 Minuten unangreifbar,
*Bollwerk* verlängert das.

**Einkommen**: Alle 15 Minuten zahlen alle gehaltenen Gebiete in die Kasse.
*Wegzoll*, *Monopol* und *Imperium* erhöhen den Betrag.

Auf der Karte liegen Blip und Radius je Gebiet in der Farbe des Besitzers. Wer
in einem Gebiet steht, sieht links unten eine Kontrollanzeige mit Besitzer,
Fortschrittsbalken und Status. In der Oberfläche gibt es eine eigene
Gebietskarte mit allen acht Zonen.

## Ritualpunkte

Die acht Gebiete sind nicht der einzige Besitz, um den sich Fraktionen
streiten. Mit `moonshine-ritualwar` kommen die sechs Ritualpunkte dazu –
teurer zu nehmen, aber sie werfen Steine statt Geld ab und besteuern jedes
fremde Ritual. Der Fraktions-Skilltree greift dort mit denselben Knoten:
*Schürfrechte* (`territoryIncome`), *Bollwerk* (`protectionBonus`),
*Sturmtrupp* (`soloCapture`) und *Blitzeinnahme* (`captureSpeed`).

Der Ablauf steht in [`RITUALWAR.md`](RITUALWAR.md).

## Fraktionsmissionen

Drei tägliche Missionen je Fraktion, an denen alle Mitglieder mitzählen –
Kasseneinzahlungen, Weltbosse, Gebietseinnahmen, Steine, Rituale, Spielzeit,
Wiederbelebungen und Steinkäufe. Die Belohnung geht in Kasse und Fraktions-XP,
*Schatzmeister* erhöht sie. Abrechnen darf, wer `missions` hat.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/fraktion` | – | Oberfläche öffnen (auch `F10`) |
| `/fraktion annehmen` | – | Einladung annehmen |
| `/fraktioninfo` | – | Kurzinfo im Chat |
| `/fraktionparken` | – | Fraktionsfahrzeug einparken |
| `/createfaction [name] [tag] [id]` | 3 | Fraktion anlegen |
| `/factionkasse [name] [betrag]` | 3 | Kasse ändern (negativ = abziehen) |
| `/setterritory [gebiet] [fraktion]` | 3 | Gebiet zuweisen (ohne Fraktion = frei) |
| `/deletefaction [name]` | 4 | Fraktion löschen |

## API

```lua
local Factions = exports['moonshine-factions']:GetFactionsObject()

exports['moonshine-factions']:GetFaction(source)          --> Kurzinfo oder nil
exports['moonshine-factions']:GetFactionId(source)
exports['moonshine-factions']:GetGrade(source)
exports['moonshine-factions']:HasPermission(source, 'kasseTake')
exports['moonshine-factions']:AddKasse(factionId, 25000, 'grund')
exports['moonshine-factions']:AddFactionXp(factionId, 500)
exports['moonshine-factions']:GetTerritoryOwner('hafen')
exports['moonshine-factions']:AdvanceFactionMission(factionId, 'boss', 1)
```

Ereignisse: `factions:server:created`, `factions:server:memberJoined`,
`factions:server:memberLeft`, `factions:server:levelUp`,
`factions:server:skillUpgraded`, `factions:server:territoryCaptured`,
`factions:server:disbanded`.

## Tabellen

`ms_factions`, `ms_faction_members`, `ms_faction_vehicles`,
`ms_faction_territories`, `ms_faction_missions`, `ms_faction_log`.
