# Administration – Panel und Wachhund

Resource: `moonshine-admin`
Panel: `F9` oder `/admin` (ab Adminlevel 2)

Die Commands aus dem Core gibt es weiterhin. Das Panel macht dieselben Dinge
schneller und protokolliert sie mit Namen.

## Panel

**Spieler** – Liste aller Online-Spieler mit ID, Name, Job, Klasse und
Strike-Zahl. Rechts die Detailspalte mit:

| Gruppe | Aktionen | Level |
|---|---|---|
| Bewegung | Hin, Herholen, Beobachten, Wegpunkt setzen | 2 |
| Zustand | Heilen, Wiederbeleben, Einfrieren, Auftauen | 2 |
| Geld | Geben und Setzen je Konto | 3 / 4 |
| Items | Item aus der Liste geben | 3 |
| Job | Job und Rang setzen | 3 |
| Adminlevel | Level 0–4 vergeben | 4 |
| Maßnahmen | Verwarnen, Kicken, Bannen mit Grund und Dauer | 2 / 3 |

Zwei Regeln gelten immer: Niemand kann jemanden mit höherem Adminlevel
anfassen, und niemand vergibt ein Level, das seinem eigenen entspricht oder
darüber liegt.

**Protokoll** – die letzten 60 Einträge aus `ms_logs`, filterbar nach
Kategorie. Anticheat-Meldungen sind rot abgesetzt.

**Werkzeuge** – Noclip und Unsichtbarkeit für einen selbst, Bann per Lizenz
aufheben, und eine Liste aller gerade auffälligen Spieler.

### Noclip

`W A S D` bewegen, `Q` hoch, `E` runter, `Shift` schneller, Mausrad regelt das
Grundtempo. Auch per `/noclip` erreichbar.

### Beobachten

Setzt den eigenen Charakter unsichtbar und kollisionsfrei zum Ziel und
aktiviert den Spectator-Modus. Ein zweiter Klick beendet es und teleportiert
zurück an den Ausgangspunkt.

## Wachhund

Bewusst zurückhaltend: Er meldet und sammelt **Strikes**, statt sofort zu
kicken. Ein Fehlalarm soll niemanden aus dem Spiel werfen. Admins ab Level 3
werden gar nicht geprüft.

| Prüfung | Was auffällt | Gewicht |
|---|---|---|
| **Leben** | mehr als 200 + Klassenbonus + 60 Puffer | 2 |
| **Weste** | über 105 | 2 |
| **Waffen** | Railgun, Minigun, RPG, Werfer, Raumwaffen | 3 (+ Entzug) |
| **Bewegung** | über 190 m/s im Fahrzeug bzw. 300 m Sprung zu Fuß | 1 |
| **Rate** | zu viele Aufrufe desselben Events | 2 |

Ab **6 Strikes** greift die konfigurierte Maßnahme (`log`, `kick` oder `ban`).
Strikes verfallen nach 30 Minuten wieder. Jede Meldung geht in die
Serverkonsole, nach `ms_logs` unter `anticheat` und an alle Admins ab Level 2.

Die Bewegungsprüfung läuft **serverseitig** über `GetEntityCoords` — sie lässt
sich also nicht vom Client aus abschalten. Nach einem Admin-Teleport wird die
letzte Position verworfen, damit das keinen Fehlalarm auslöst.

### Ratenbegrenzung für eigene Resources

Der wichtigste Teil für andere Skripte: jedes Netzwerkereignis, das Geld oder
Items bewegt, sollte begrenzt sein.

```lua
RegisterNetEvent('meinshop:server:kaufen', function(item, menge)
    local source = source

    -- Höchstens 10 Käufe in 5 Sekunden.
    if not exports['moonshine-admin']:RateLimit(source, 'meinshop:kaufen', 10, 5) then
        return
    end

    -- … weiter wie gewohnt
end)
```

Wird die Grenze dreimal überschritten, setzt es automatisch Strikes.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/admin` (`F9`) | 2 | Panel öffnen |
| `/noclip` | 2 | Noclip umschalten |
| `/unsichtbar` | 2 | Unsichtbarkeit umschalten |
| `/adminliste` | 2 | Welche Admins sind online |
| `/strikes [id]` | 2 | Strikes eines Spielers |
| `/clearstrikes [id]` | 3 | Strikes zurücksetzen |
| `/wachhund [an\|aus]` | 4 | Anticheat umschalten |

## API

```lua
-- Ratenbegrenzung (der wichtigste Export)
exports['moonshine-admin']:RateLimit(source, 'key', 10, 5)

-- Verdacht selbst melden
exports['moonshine-admin']:Flag(source, 'Unmoegliche Distanz', 2)

exports['moonshine-admin']:GetStrikes(source)
exports['moonshine-admin']:ClearStrikes(source)

-- Praktisch fuer eigene Ortspruefungen
exports['moonshine-admin']:IsNear(source, { x = 0, y = 0, z = 0 }, 3.0)
```

Ereignis: `admin:server:flagged` mit `source`, `reason` und der Strike-Zahl.

## Was der Wachhund nicht ist

Kein vollwertiger Anticheat. Er fängt grobe und offensichtliche Sachen ab und
liefert die Werkzeuge, damit eigene Resources sich selbst absichern. Gegen
gezielte Angriffe auf einzelne Netzwerkereignisse hilft nur, dass jede
Resource ihre eigenen Eingaben prüft — was in diesem Framework durchgehend
geschieht: Der Client schickt nur Absichten, der Server prüft Distanz, Geld,
Besitz und Rechte selbst.
