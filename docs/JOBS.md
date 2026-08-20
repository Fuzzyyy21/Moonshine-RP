# Arbeit – Jobcenter und Aufträge

Resource: `moonshine-jobs`
Zugang: Jobcenter (`E` oder `/jobcenter`), Aufträge direkt beim Auftraggeber

Die Jobs im Core waren bisher nur Titel mit Gehalt. Hier bekommen sie einen
Ablauf: anmelden, Stationen abarbeiten, abmelden.

## Wie eine Schicht läuft

1. **Anmelden** beim Auftraggeber mit `E`. Wer ein Arbeitsfahrzeug bekommt,
   sitzt sofort drin.
2. Der Server zieht **sechs Stationen** aus dem Pool des Auftrags und setzt
   die Route auf die erste. Zufällig – außer beim Bus, der seine Linie in
   fester Reihenfolge fährt.
3. An der Station aussteigen, `E` drücken, Fortschrittsbalken abwarten. Der Lohn
   kommt sofort in bar, dazu Erfahrung für den persönlichen Skillbaum.
4. Nach der letzten Station **zurück zum Auftraggeber** und abmelden.

Der **Abschlussbonus** (35 % Aufschlag auf den Grundbonus) gibt es nur, wenn
alle sechs Stationen erledigt sind. Wer vorher abbricht, behält seinen bis
dahin verdienten Lohn, verliert aber den Bonus.

Eine Schicht ohne Fortschritt läuft nach 20 Minuten von selbst aus. Loggt
jemand mitten in der Schicht aus, wird sie beendet.

## Die sieben Aufträge

| Auftrag | Anmeldung | Fahrzeug | Je Station | Abschluss | Voraussetzung |
|---|---|---|---|---|---|
| 🚚 **Spedition** | Speditionslager | Mule | 420 $ | 900 $ | Job `trucker` |
| 🗑 **Müllabfuhr** | Mülldepot | Trashmaster | 285 $ | 600 $ | – |
| 🚕 **Taxi** | Downtown Cab Co. | Taxi | 340 $ + km | 700 $ | – |
| 📮 **Postdienst** | Postzentrale | Boxville | 240 $ | 500 $ | – |
| 🪝 **Abschleppdienst** | Abschlepphof | Flatbed | 520 $ | 1.100 $ | – |
| 🚌 **Busfahrer** | Busdepot | Bus | 190 $ | 850 $ | – |
| 🕯 **Nachtwache** | Wachhaus am Friedhof | Burrito | 780 $ | 1.800 $ | nur nachts |

Auf jede Auszahlung kommt eine Streuung von ±15 %, damit es sich nicht wie
eine Tabelle anfühlt.

### Vier Aufträge laufen anders

Sonst wäre es siebenmal dieselbe Fahrt mit anderer Farbe.

**🚕 Taxi** — statt einer Station gibt es erst einen Fahrgast. Der NPC wird
erzeugt, sobald man in seine Nähe kommt, steigt auf `E` ein und wird zum Ziel
gefahren. Zusätzlich **180 $ je Kilometer** Luftlinie zwischen Aufnahme und
Ziel; lange Fahrten lohnen sich also wirklich.

**🪝 Abschleppdienst** — was verladen wird, muss auch abgeliefert werden.
Nach *jeder* Station geht es zurück zum Hof und das Fahrzeug wird abgeladen,
erst dann kommt der nächste Einsatz. Das verdoppelt die Fahrtstrecke und ist
der Grund für den höheren Lohn.

**🚌 Busfahrer** — eine Linie fährt man der Reihe nach. Die Haltestellen
werden **nicht gewürfelt**, jede Schicht ist dieselbe Runde. Wenig je
Haltestelle, dafür der höchste Abschlussbonus im Verhältnis.

**🕯 Nachtwache** — die sechs Ritualpunkte abgehen, solange es dunkel ist.
Tagsüber steht der Auftrag im Jobcenter, lässt sich aber nicht beginnen; das
Jobcenter sagt auch, warum. Zahlt deutlich über dem Schnitt — es meldet sich
nicht jeder freiwillig, mitten in der Nacht auf den Mount Chiliad zu fahren.

> Läuft `moonshine-world` nicht mit, gilt für die Nachtwache immer „Nacht“.
> Eine fehlende Resource soll niemanden aussperren.

## Jobcenter

Ein fester Punkt in der Stadt mit Sachbearbeiterin. Drei Reiter:

* **Aufträge** – alle sieben mit Beschreibung, Konditionen, deiner Statistik und
  einem Knopf, der einen Wegpunkt setzt. Aufträge, für die die Anstellung
  fehlt, werden ausgegraut mit Hinweis angezeigt.
* **Anstellung** – hier vergibt man sich die nicht-gewhitelisteten Jobs selbst
  (Arbeitslos, Taxi, Spedition, …). Whitelist-Jobs wie Polizei, Rettungsdienst
  und Mechaniker laufen weiter über `/setjob`. Zwischen zwei Wechseln liegen
  fünf Minuten.
* **Bestenliste** – wer je Auftrag am meisten verdient hat, aus `ms_work`.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/jobcenter` | – | Jobcenter öffnen (nur vor Ort) |
| `/dienst` | – | Laufende Schicht im Chat |
| `/feierabend` | – | Schicht sofort beenden |
| `/arbeitsstatistik` | – | Eigene Zahlen je Auftrag |
| `/endshift [id]` | 2 | Fremde Schicht beenden |

## API

```lua
exports['moonshine-jobs']:IsWorking(source)
exports['moonshine-jobs']:GetShift(source)     --> job, index, total, earned
exports['moonshine-jobs']:StopShift(source)
exports['moonshine-jobs']:GetWorkStats(source)
```

Clientseitig: `IsWorking()`.

Ereignisse: `work:server:shiftStarted`, `work:server:stopCompleted`,
`work:server:shiftEnded`, `work:server:jobChanged`.

## Eigene Aufträge

Ein Eintrag in `shared/jobs.lua` reicht — Route, Marker, Fortschritt, Lohn und
Statistik laufen danach von selbst:

```lua
meinjob = {
    id = 'meinjob', label = 'Mein Auftrag', icon = '📦',
    description = 'Ein Satz, worum es geht.',
    requiresJob = nil,              -- oder ein Core-Job
    colour = '#5fc98a',

    start = { label = 'Treffpunkt', coords = vector3(0.0, 0.0, 0.0) },
    vehicle = { model = 'burrito3', spawn = vector4(0.0, 0.0, 0.0, 0.0),
                label = 'Transporter' },

    action = 'liefern', actionLabel = 'Abliefern',
    duration = 5, pay = 300, finalPay = 600,

    stops = {
        { label = 'Station 1', coords = vector3(0.0, 0.0, 0.0) },
        -- mindestens so viele wie WorkConfig.Shift.stops
    },
}
```

Danach den Eintrag in `Work.Order` aufnehmen.

Vier Felder ändern den Ablauf selbst:

| Feld | Wirkung |
|---|---|
| `passengers = true` | Vor jeder Station wird jemand aufgenommen (dazu `passengerModels` und `payPerKilometer`) |
| `fixedRoute = true` | Stationen der Reihe nach statt gewürfelt |
| `abliefern = true` | Nach jeder Station zurück zum Anmeldepunkt (dazu `ablieferLabel`) |
| `nurNachts = true` | Schicht lässt sich nur nachts beginnen |

## Tabelle

`ms_work` — je Charakter und Auftrag Schichten, Stationen und Gesamtverdienst.
Daraus speist sich auch die Bestenliste.
