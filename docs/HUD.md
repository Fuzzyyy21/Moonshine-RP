# Anzeige – `moonshine-hud`

Vorher lag die Anzeige verstreut: eine Karte im Core, eine Uhr in der Welt,
dazu die Skillleiste der Mystik. Drei Widgets in drei Ecken, kein
gemeinsames Aussehen, und abschalten ließ sich nichts davon einzeln.

Hier läuft alles zusammen – und jeder Spieler stellt sich ein, was er sehen
will.

## Was zu sehen ist

```
   ┌──────────────────────────────────────────────────────────┐
   │        🌙 21:14   Vinewood Blvd / Bezirk   N   ✦ Blutmond │  Kopfzeile
   │                                                          │
   │                                                          │
   │                                                    ╭───╮ │
   │  ┌────────────────────┐                            │ 87│ │  Fahrzeug
   │  │ Anna Voss     #12  │                            ╰───╯ │
   │  │ Postdienst · Fahrer│                            ⛽ ▓▓░ │
   │  │ 💵 1.240  🏦 8.900 │                            🔒 💡  │
   │  └────────────────────┘                                  │
   │  ❤️ 🛡️ 🍗 💧 🌀 🩸        ← Statusgruppe                  │
   └──────────────────────────────────────────────────────────┘
```

| Bereich | Inhalt |
|---|---|
| **Kopfzeile** | Uhrzeit, Mondphase, Straße und Bezirk, Kompass, laufendes Weltereignis |
| **Karte** | Name, Server-ID, Job und Rang, Fraktion, Bargeld, Bank, Schwarzgeld |
| **Statusgruppe** | Leben, Weste, Hunger, Durst, Ausdauer, Sauerstoff |
| **Klassenband** | Blut, Mana, Höllenfeuer … mit Namen und Zahlen |
| **Fahrzeug** | Tacho, Drehzahlring, Gang, Tank, Motorzustand, Gurt, Licht, Blinker, Tempomat |

Kontoänderungen blitzen kurz auf: grün nach oben, rot nach unten.

## Das Klassenband

Blut, Mana, Höllenfeuer und Feenstaub sind auf diesem Server keine
Nebenwerte – sie sind der Kern. Deshalb stehen sie nicht als namenloser
Ring zwischen Hunger und Durst, sondern in einem eigenen Band mit Namen,
Zahlen und der Farbe der Klasse:

```
   ┌────────────────────────────────┐
   │ 🩸  Blut              64 / 100  │
   │     ▓▓▓▓▓▓▓▓▓▓▓░░░░░░           │
   │     Vampir · Stufe 7            │
   └────────────────────────────────┘
```

Einzeln abschaltbar sind dabei: die Essenz selbst, der Name der Klasse, die
Zahlen (sonst steht dort der Prozentwert) und die Klassenstufe (ab Werk
aus). Das Band hängt standardmäßig an der Statusgruppe, lässt sich aber auch
frei an einen Rand setzen – unten mittig, unten rechts oder oben rechts.

Es taucht nur auf, wenn `moonshine-mystic` läuft und der Charakter erweckt
ist; sonst fehlt genau dieses Band und sonst nichts.

## Einstellen

`/hudmenu` öffnet das Menü. Alles darin gilt nur für den einen Spieler und
bleibt auf seinem Rechner gespeichert – es braucht dafür keinen Serverweg
und keine Datenbank.

### Aussehen

| Einstellung | Auswahl |
|---|---|
| **Anzeige an** | ganz aus, ohne alles einzeln abzuschalten |
| **Darstellung** | sechs Varianten, siehe unten |
| **Ecke** | unten links · unten rechts · oben links · oben rechts |
| **Klassenband** | an der Statusgruppe · unten mittig · unten rechts · oben rechts |
| **Farbe** | Mondviolett, Bernstein, Waldgrün, Nachtblau, Blutrot, Aschgrau |
| **Größe** | 70 % bis 140 % |
| **Deckkraft** | 30 % bis 100 % |
| **Tempo** | km/h oder mph |
| **Volle Balken ausblenden** | zeigt nur, was gerade nicht in Ordnung ist |
| **Gurtwarnung** | Ton beim Fahren ohne Gurt |

Am Regler sieht man die Änderung sofort; festgeschrieben wird sie beim
Loslassen.

### Die sechs Darstellungen

| | |
|---|---|
| **Ringe** | Kreise mit Symbol, vier je Reihe. Die Vorgabe. |
| **Balken** | Waagerechte Balken mit Symbol davor – kompakt und gut ablesbar. |
| **Segmente** | Zehn Kästchen je Wert. Man zählt statt zu schätzen. |
| **Bögen** | Bögen ineinander mit schmaler Legende daneben. Nimmt wenig Höhe. |
| **Zahlen** | Nur die Werte, keine Balken. Für alle, denen Balken zu unruhig sind. |
| **Minimal** | Dünne Balken ohne Karte und ohne Symbole. Das Wenigste. |

Bei den Bögen werden höchstens sechs Werte gezeichnet – mehr wären nicht
mehr auseinanderzuhalten.

### Elemente

Jedes der 31 Elemente lässt sich einzeln abschalten, gruppiert nach
Spieler, Zustand, Klasse, Welt und Fahrzeug. Wer nur Leben und Tacho will, schaltet
den Rest aus und behält eine Anzeige aus zwei Dingen.

**Volle Balken ausblenden** ist die zweite Stufe davon: Leben, Hunger, Durst
und der Rest verschwinden, solange sie über ihrer Schwelle liegen, und
tauchen von selbst wieder auf, wenn es knapp wird. Die Schwellen stehen in
`HudConfig.Schwellen`.

## Der Gurt

Der Gurt steht in dieser Resource, weil die Anzeige sonst etwas zeigen
würde, das es gar nicht gibt. Ein Gurtsymbol ohne Gurt ist Dekoration.

* **B** oder `/gurt` schnallt an und ab.
* Angeschnallt fliegt niemand durch die Scheibe.
* Ohne Gurt und mit über 90 km/h auf einen harten Aufprall folgt genau das:
  Ragdoll, Schaden, Landung vor dem Fahrzeug.
* Über 40 km/h ohne Gurt piept es, solange die Gurtwarnung an ist.
* Aussteigen löst den Gurt.

Der **Tempomat** (`/tempomat`) hält das aktuelle Tempo, solange man fährt.

## Commands und Tasten

| Command | Taste | Wirkung |
|---|---|---|
| `/hud` | `F7` | Anzeige ganz ein-/ausblenden |
| `/hudmenu` | frei belegbar | Einstellungen öffnen |
| `/gurt` | `B` | Gurt an-/ablegen |
| `/tempomat` | frei belegbar | Tempomat |

Alle Tasten lassen sich im Spiel unter *Einstellungen → Tastenbelegung →
FiveM* umlegen; die Vorgaben stehen in `HudConfig.Keys`.

## Wenn eine Oberfläche offen ist

Die Anzeige tritt zurück, sobald ein Menü aufgeht oder das Pausenmenü offen
ist. Dafür gibt es das Ereignis `moonshine:client:nuiOpen`:

```lua
-- Beim Öffnen einer eigenen Oberflaeche
TriggerEvent('moonshine:client:nuiOpen', true)

-- Beim Schliessen
TriggerEvent('moonshine:client:nuiOpen', false)
```

`moonshine-core` feuert es für Inventar und Charakterauswahl, das
Einstellungsmenü für sich selbst. Wer eine eigene Resource mit NUI baut,
sollte es ebenfalls tun.

Bewusst **nicht** abgefragt wird `IsNuiFocused()`: das wäre bequemer, träfe
aber auch die Chateingabe – und dabei soll die Anzeige stehen bleiben.

## Schnittstelle

```lua
local hud = exports['moonshine-hud']

hud:GetSettings()               -- die ganze Einstellung als Tabelle
hud:IsVisible()                 -- ist die Anzeige an?
hud:SetVisible(true)            -- ein- oder ausschalten
hud:ToggleElement('tacho')      -- ein Element schalten (nil = umschalten)
hud:IsBuckled()                 -- ist der Spieler angeschnallt?
```

### Ereignisse

| Ereignis | Argumente |
|---|---|
| `hud:client:settingsChanged` | die neue Einstellung |
| `hud:client:belt` | `angeschnallt`, `istFahrer` |

## Woher die Werte kommen

Jede fremde Resource wird über `pcall` gefragt. Läuft eine nicht, fehlt
genau ihr Wert und sonst nichts – die Anzeige darf nicht davon abhängen,
dass der ganze Server geladen ist.

| Wert | Quelle |
|---|---|
| Name, Job, Geld, Hunger, Durst | `moonshine-core` |
| Essenz, Klasse, Klassenfarbe | `moonshine-mystic` (`GetProfileData`) |
| Uhrzeit, Mondphase, Ereignis | `moonshine-world` (Ereignisse, nicht abgefragt) |
| Fraktion | `moonshine-factions` (`GetFactionData`) |
| Tankstand | `moonshine-vehicles` (`GetFuel`), sonst der Wert des Spiels |
| Leben, Weste, Ausdauer, Sauerstoff, Ort, Richtung | direkt aus dem Spiel |

Die Uhrzeit kommt aus der Spielzeit selbst, nicht aus einer Abfrage:
`moonshine-world` setzt sie ohnehin über `NetworkOverrideClockTime`, und so
läuft sie flüssig weiter, auch zwischen zwei Serversynchronisationen.

## Takt

| | |
|---|---|
| Statuswerte | alle 250 ms |
| Fahrzeugwerte | alle 90 ms, aber nur im Fahrzeug |
| Weltdaten | gar nicht – sie kommen als Ereignis, wenn sie sich ändern |

Beides steht in `HudConfig.Tick` und `HudConfig.VehicleTick`.

## Was dafür abgeschaltet wurde

Damit nichts doppelt dasteht, sind die alten Einzelwidgets ab Werk aus:

| Was | Wo | Wieder einschalten |
|---|---|---|
| HUD-Karte des Core | war `moonshine-core/client/hud.lua` | entfernt, ersetzt |
| Uhr-Widget der Welt | `WorldConfig.Hud.enabled` | auf `true` setzen |

Die Skillleiste der Mystik (`F5`) bleibt, wo sie ist – sie ist eine
Bedienoberfläche, keine Anzeige.

## Wo nichts gespeichert wird

Die Einstellungen liegen im KVP-Speicher des Spielers
(`moonshine:hud:einstellungen`), nicht in der Datenbank. Wie jemand seine
Anzeige haben will, ist eine Sache seines Rechners und nicht seines
Charakters. Es gibt daher **keine Tabelle** zu dieser Resource.

Was aus dem Speicher kommt, läuft trotzdem durch `Hud.Sanitize`: eine von
Hand verbogene Datei darf die Anzeige nicht zerlegen.
