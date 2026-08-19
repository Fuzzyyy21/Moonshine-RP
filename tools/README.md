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

### Was er nicht kann

Er liest Code, er führt ihn nicht aus. Falsche Koordinaten, kaputte
Spielmechanik, Balancing und alles, was erst zur Laufzeit auffällt, findet nur
ein echter Testlauf — siehe [`docs/LAUNCH.md`](../docs/LAUNCH.md).

### Neue Prüfungen

Jede Prüfung ist eine Funktion, die `note(art, wo, was)` aufruft. In `main()`
eintragen, fertig.
