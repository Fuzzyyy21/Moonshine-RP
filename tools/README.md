# Werkzeuge

## `pruefen.py`

Prüft das Framework, ohne dass ein FXServer laufen muss.

```bash
python3 tools/pruefen.py              # alles
python3 tools/pruefen.py --nur-syntax # nur Lua und JavaScript
```

Rückgabewert 0 wenn sauber, 1 bei Funden. Läuft bei jedem Push über
[`.github/workflows/pruefen.yml`](../.github/workflows/pruefen.yml).

| Prüfung | Was sie findet |
|---|---|
| **Syntax** | Jede `.lua` durch `luac`, jede `.js` durch `node --check`. CfxLua-Hash-Literale (`` `prop_name` ``) werden vorher ersetzt, sonst stolpert `luac` darüber. |
| **Manifeste** | Dateien im Ordner, die im `fxmanifest` fehlen — und Einträge im Manifest ohne Datei. |
| **Exporte** | Jeder `exports['x']:y()`-Aufruf hat drüben ein `exports('y')`. Erkennt auch, wenn der Export nur auf der anderen Seite existiert. |
| **Netz-Events** | Jedes `TriggerServerEvent` hat serverseitig ein `RegisterNetEvent` und umgekehrt. |
| **Callbacks** | Jedes `TriggerServerCallback` hat ein `RegisterServerCallback`. |
| **NUI** | Jeder `post()`/`ask()`-Name im `app.js` hat ein `RegisterNUICallback`. Resources, die ihre Callbacks in einer Schleife anlegen, werden übersprungen. |
| **Seiten** | Reine Client-Natives in Serverdateien und umgekehrt. |
| **Commands** | Kein Command-Name doppelt über Resources hinweg — sonst gewinnt je nach Ladereihenfolge ein anderer. |
| **Abhängigkeiten** | Ungeschützte Exporte auf eine Resource, die nicht als `dependency` im Manifest steht. Ein `pcall` in den drei Zeilen davor gilt als abgesichert. |
| **Schema** | `sql/moonshine.sql` gegen das, was die Resources tatsächlich anlegen — fehlende Tabellen, verwaiste Tabellen, abweichende Spalten. Das Schema steht zwangsläufig doppelt da, also driftet es sonst. |
| **Aufrufe** | `Mystic.Foo()`, `Work.Bar()` und so weiter, die nirgends definiert sind — getrennt nach Server- und Client-Seite, weil dort verschiedene Dateien laufen. |
| **Config** | Zugriffe auf `MysticConfig.Foo`, `WorkConfig.Bar` und so weiter, die keine Config je setzt. |
| **Namensraum** | Globals aus einer anderen Resource, die gar nicht mitgeladen wird. In FiveM hat jede Resource ihren eigenen Lua-Zustand — `MysticConfig` ist anderswo schlicht `nil`, solange die Datei nicht per `'@moonshine-mystic/shared/config.lua'` im Manifest steht. Genau so lief `moonshine-needs` eine Weile ins Leere. |

### Was er nicht kann

Er liest Code, er führt ihn nicht aus. Falsche Koordinaten, kaputte
Spielmechanik, Balancing und alles, was erst zur Laufzeit auffällt, findet nur
ein echter Testlauf — siehe [`docs/LAUNCH.md`](../docs/LAUNCH.md).

### Neue Prüfungen

Jede Prüfung ist eine Funktion, die `note(art, wo, was)` aufruft. In `main()`
eintragen, fertig.

## `testen.lua`

Führt die reine Rechenlogik der `shared`-Dateien mit echtem Lua aus — ohne
FXServer.

```bash
lua5.4 tools/testen.lua
```

Rückgabewert 0 wenn alles besteht, 1 bei Fehlschlägen. Läuft ebenfalls bei
jedem Push.

`attrappe.lua` stellt die FiveM-Globals bereit, die beim *Laden* gebraucht
werden — `vector3`, `CreateThread`, `exports`, `json` und so weiter. Sie
enthält bewusst keine Spiellogik.

### Was geprüft wird

Rund 1.900 Zusicherungen, unter anderem:

* **Mystik** — jede Klasse vollständig, jede Voraussetzung im Skilltree zeigt
  auf einen existierenden Knoten, jede Rangstufe kostet etwas, die erste
  Fähigkeit kostet genau fünf Steine, `PickRankValue` verhält sich an den
  Rändern richtig, der volle persönliche Baum bleibt in den Grenzen.
* **Fortschritt** — die Battle-Pass-Kurve gegen von Hand gerechnete Werte,
  Missions-Ids eindeutig, jede Kiste hat Lose mit positivem Gewicht,
  Spielzeit-Meilensteine aufsteigend.
* **Fraktionen** — der oberste Rang hat alle Rechte, `SanitizeRanks` und
  `SanitizeEmblem` fangen Müll ab, die Kappungen im Skilltree greifen
  wirklich, Gebiets-Ids eindeutig.
* **Welt** — acht Mondphasen, der Zyklus schließt sich, jedes Ereignis nennt
  nur Klassen, die es gibt, Phase und Ereignis addieren sich korrekt.
* **Arbeit** — jeder Auftrag hat genug Stationen für eine Schicht, die
  Auswahl zieht ohne Wiederholung, der Lohn bleibt in seiner Streuung.
* **Fahrzeuge, Dienste, Auktion, Aussehen** — eindeutige Modelle, jede
  Händlerkategorie existiert, der Reparaturpreis steigt monoton mit dem
  Schaden, niemand startet nackt.

### Warum das nicht selbstverständlich ist

Ein Test, der immer besteht, ist wertlos. Jede Prüfgruppe wurde gegen
absichtlich eingebauten Schaden gehalten — verbogene Kurven, entfernte
Kappungen, ins Leere zeigende Voraussetzungen, zu wenige Stationen. Drei
Tests fielen dabei durch und wurden ersetzt:

* Die Battle-Pass-Prüfung verglich dieselbe Funktion mit sich selbst und
  hätte jede Änderung der Kurve durchgewunken. Jetzt stehen von Hand
  gerechnete Sollwerte da.
* Die Bonus-Prüfungen der Fraktionen waren reine Obergrenzen, die der echte
  Baum nie erreicht. Jetzt stehen exakte Sollwerte da, und die Kappungen
  werden über einen eingeschleusten Testknoten geprüft.
* Eine Kappungsprüfung schlug nur durch Fließkomma-Zufall an.


## `vorschau/`

Rendert ein NUI ohne laufenden FXServer und schießt Bilder davon — die
echte `index.html` samt `style.css` und `app.js`, gefüttert mit den
Nachrichten des Client-Codes.

```bash
lua5.4 tools/vorschau/ziehen.lua    # Config -> daten/*.json
node tools/vorschau/hud.js          # Bilder -> tools/vorschau/bilder/
```

Bei der Anzeige hat das auf Anhieb drei Layout-Fehler gezeigt, die im Code
nicht zu sehen waren: acht Ringe brachen als 5+3 um, vier Auswahlknöpfe als
3+1, und der Gang stand halb außerhalb des Tachorings.

Einzelheiten in [`vorschau/README.md`](vorschau/README.md).
