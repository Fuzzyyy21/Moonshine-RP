# Klassenbedürfnisse

Resource: `moonshine-needs`
Anzeige: als Ring oder Balken in der Statusgruppe von
[`moonshine-hud`](HUD.md), in der Farbe und mit dem Zeichen des jeweiligen
Bedürfnisses. Der eigene Balken dieser Resource ist deshalb ab Werk aus
(`NeedsConfig.Hud.enabled`).

Bis hierher konnten alle acht Klassen dasselbe: kämpfen. Hunger und Durst aus
dem Core gelten für jeden gleich. Hier bekommt **jede Klasse etwas Eigenes**,
das sie am Leben hält — und jede muss es anders beschaffen.

## Was jede Klasse braucht

| Klasse | Bedürfnis | Woher |
|---|---|---|
| 🩸 Vampir | **Blutdurst** | Von Bewusstlosen trinken (40), Passanten aussaugen (22), Blutkonserve (30) |
| 🐺 Werwolf | **Hunger auf Fleisch** | Rohes Fleisch (35), ein Tier reißen (45), Weltboss (25) |
| 🪄 Magier | **Manafluss** | Meditation (45), Manakristall (40), Orte der Kraft (passiv) |
| 🜏 Hexer | **Reagenzien** | Kräuterbund (30), Natur (passiv), Meditation (25) |
| 🧚 Fee | **Naturnähe** | Natur (passiv, stark), Orte der Kraft, Kräuterbund (20) |
| 🔥 Dämon | **Seelenhunger** | Wenn jemand durch deine Hand fällt (30), Weltboss (40), Seelensplitter (35) |
| 💀 Nekromant | **Totenkraft** | Friedhöfe (passiv), Kraft aus Sterbenden ziehen (35), Totenasche (35) |
| 🏹 Jäger | **Vorräte** | Weltboss (45), Jagdvorrat (40), Kills (15) |

Keine Klasse hängt an einer einzigen Quellart — das prüft der Testlauf.

## Wie es abläuft

Der Wert fällt alle 45 Sekunden um etwa einen Punkt. Das reicht für rund eine
Stunde, bevor es unangenehm wird.

| Bereich | Ab | Wirkung |
|---|---|---|
| **gesättigt** | 85 | +0,4 Essenzregeneration, +0,2 Lebensregeneration |
| in Ordnung | 35 | nichts |
| **lässt nach** | unter 35 | −0,3 Essenzregeneration |
| **schwach** | unter 15 | −0,8 Essenz, −8 % Tempo, −10 % Schaden |
| **am Ende** | 0 | −1,5 Essenz, −15 % Tempo, −20 % Schaden, 4 Schaden je Takt |

Die Werte fließen in `Profile:GetModifiers()` des Mystik-Systems ein — sie
wirken also auf dieselbe Weise wie Skills, Mondphase und Weltereignisse. Beim
Wechsel in einen anderen Bereich werden alle Werte sofort neu gerechnet. Tempo
und Schaden können dabei nicht unter die Hälfte fallen; wer verhungert, wird
schwach, aber nicht wehrlos.

## Die Wege im Einzelnen

**Gegenstände** — sieben neue Items, jedes nur für seine Klasse brauchbar. Wer
das falsche benutzt, bekommt einen Hinweis statt einer Wirkung.

**Passanten und Tiere** (`G`) — Vampire an Menschen, Werwölfe an Tieren. Fünf
bis sieben Sekunden mit Animation, 20 Sekunden Abklingzeit.

**Bewusstlose** (`G`) — Vampire und Nekromanten. Der Server prüft über
`moonshine-death`, dass das Ziel wirklich am Boden liegt und in Reichweite ist.
Das Opfer bekommt eine Meldung.

**Zonen** — passives Auffüllen, solange man dort steht. Acht Naturgebiete,
vier Friedhöfe, Orte der Kraft. Die **Ritualpunkte zählen automatisch als Orte
der Kraft**, mit 25 Metern Zuschlag auf ihren Radius.

**Meditation, Weltbosse, Kills** — hängen an den Ereignissen, die es ohnehin
schon gibt.

## Was dafür im Core dazukam

Der Kill-Weg brauchte etwas, das es noch gar nicht gab: **wer war es?** Der
Core hat den Tod bisher ohne Verursacher gemeldet.

Jetzt ermittelt der Client `GetPedSourceOfDeath`, löst Fahrzeuge zum Fahrer auf
und schickt die Server-Id mit. Der Server glaubt das nicht blind — er prüft,
dass der Gemeldete existiert, jemand anderes ist und höchstens
`Config.MaxKillDistance` (250 m) entfernt war. Danach geht der Verursacher an
`moonshine:server:playerDeath` und weiter an
`moonshine-death:server:playerDowned`.

Davon hat auch das Protokoll etwas: Statt „X ist gestorben" steht dort jetzt
„X wurde von Y getötet".

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/beduerfnis` | – | Eigenen Balken ein-/ausblenden (ab Werk aus) |
| `/beduerfnisinfo` | – | Wert und Bereich im Chat |
| `/setbeduerfnis [id] [wert]` | 3 | Wert setzen |

## API

```lua
exports['moonshine-needs']:GetNeed(source)          --> 0 bis 100, oder nil
exports['moonshine-needs']:SetNeed(source, 100)
exports['moonshine-needs']:AddNeed(source, -20)
exports['moonshine-needs']:GetModifiers(source)     --> holt sich moonshine-mystic
```

Clientseitig: `GetNeed()` und `GetNeedData()`.

Ereignisse: `needs:server:filled` mit `source`, Quellart und Menge;
`needs:server:drainedPlayer` mit Täter, Opfer und Klasse.

## Eigene Bedürfnisse

Ein Eintrag in `shared/needs.lua` je Klasse. Neue Quellarten brauchen einen
Handler in `server/sources.lua` — die vorhandenen sieben decken das meiste ab.

Neue Zonen sind ein Eintrag unter `Needs.Zones`; `Needs.ZoneAt` und der
Fülltakt greifen sofort.

## Wo es speichert

Als Metadatum am Charakter (`classNeed`), also im Autosave des Cores. Ein
Klassenwechsel setzt den Wert auf voll zurück — das alte Bedürfnis ergibt für
die neue Klasse keinen Sinn.
