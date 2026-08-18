# Moonshine RP – Custom FiveM Framework

Ein eigenständiges Roleplay-Framework für FiveM plus ein mystisches
Rassensystem. Kein ESX-/QBCore-Fork, keine Alt-Lasten – nur Lua,
[oxmysql](https://github.com/overextended/oxmysql) und eine klare API.

| Resource | Inhalt |
|---|---|
| `moonshine-core` | Framework: Accounts, Multicharacter, Geld, Inventar, Jobs, HUD, API |
| `moonshine-mystic` | Klassen mit Skilltree (Ränge, bezahlt mit Klassensteinen), Skillleiste, persönlicher Skillbaum (bezahlt mit XP) → [`docs/MYSTIC.md`](docs/MYSTIC.md) |
| `moonshine-death` | Bewusstlosigkeit statt Sofort-Respawn, Notruf, Wiederbelebung → [`docs/SURVIVAL.md`](docs/SURVIVAL.md) |
| `moonshine-nodes` | Steinadern in der Welt: Ritualsteine abbauen → [`docs/SURVIVAL.md`](docs/SURVIVAL.md) |
| `moonshine-shops` | Beispiel-Resource: 24/7 Läden über die Core-API |

## Features

| Bereich | Umfang |
|---|---|
| **Accounts** | Automatische Anlage per Rockstar-Lizenz, Adminlevel, Spielzeit, Ban-System mit Ablaufdatum |
| **Multicharacter** | Bis zu 3 Charaktere pro Lizenz, Erstellung/Löschung über eigenes NUI |
| **Wirtschaft** | Frei konfigurierbare Konten (Bar, Bank, Schwarzgeld), Transaktionslog, Gehaltszahlung nach Job-Rang |
| **Inventar** | Slot- und gewichtsbasiert, stapelbare Items, Drag & Drop, Geben, Bodenitems mit Verfallszeit |
| **Jobs** | Jobs mit Rängen, Gehalt und Whitelist-Flag |
| **Status** | Hunger und Durst mit Tick-Verbrauch, Schaden bei 0, Screen-Effekt |
| **HUD** | Name, Server-ID, Job, Geld, Leben, Weste, Hunger, Durst |
| **Persistenz** | Autosave, Speichern bei Disconnect, Resource-Stop und Server-Shutdown |
| **API** | Exports, Server-Callbacks, Events – für eigene Resources dokumentiert in [`docs/API.md`](docs/API.md) |
| **Admin** | Rechtesystem über Adminlevel plus Commands für Geld, Items, Jobs, Teleport, Kick, Ban |

## Voraussetzungen

* FXServer (aktuelle Recommended-Version)
* MySQL oder MariaDB
* [`oxmysql`](https://github.com/overextended/oxmysql)
* Basis-Resources: `chat`, `spawnmanager`, `sessionmanager`, `mapmanager`, `hardcap`

## Installation

1. Repository in den `resources`-Ordner deines Servers kopieren – die Ordner
   liegen bereits im Format `resources/[moonshine]/…`.
2. Datenbank anlegen und die Verbindung in der `server.cfg` setzen:

   ```cfg
   set mysql_connection_string "mysql://user:passwort@localhost/moonshine?charset=utf8mb4"
   ```

   Die Tabellen legt `moonshine-core` beim Start selbst an. Wer sie lieber manuell
   importiert, findet das Schema in [`sql/moonshine.sql`](sql/moonshine.sql).

3. Resources starten (siehe [`server.cfg.example`](server.cfg.example)):

   ```cfg
   ensure oxmysql
   ensure moonshine-core
   ensure moonshine-mystic
   ensure moonshine-death
   ensure moonshine-nodes
   ensure moonshine-shops
   ```

4. Einmal verbinden, danach dich selbst zum Owner machen:

   ```sql
   UPDATE ms_users SET admin_level = 4 WHERE license = 'license:deinelizenz';
   ```

   Die Lizenz steht nach dem ersten Join in der Tabelle `ms_users`.

## Aufbau

```
resources/[moonshine]/
├── moonshine-core/          Framework
│   ├── shared/              Config, Utils, Jobs, Items
│   ├── server/              Datenbank, Spielerobjekt, Inventar, Commands, API
│   ├── client/              Charakterauswahl, HUD, Inventar, Callbacks
│   └── nui/                 Oberfläche (Charakterauswahl, HUD, Inventar)
├── moonshine-mystic/        Klassen, Skilltree, Skillleiste, Perks
│   ├── shared/              Config, Klassen, Skills, Perks, Steine
│   ├── server/              Profile, Skills, Perks, Ritualpunkte, API
│   ├── client/              Fähigkeiten, Skillleiste, Ritual-UI, Klassenmechanik
│   └── nui/                 Oberfläche (Skillleiste, Skilltree, Perks)
├── moonshine-death/         Bewusstlosigkeit, Notruf, Wiederbelebung, Respawn
├── moonshine-nodes/         Steinadern zum Abbauen von Ritualsteinen
└── moonshine-shops/         Beispiel-Resource: 24/7 Läden auf Basis der API
sql/moonshine.sql            Schema als Referenz
docs/API.md                  API-Dokumentation des Frameworks
docs/MYSTIC.md               Dokumentation des Mystik-Systems
docs/SURVIVAL.md             Sterbesystem und Steinadern
docs/ROADMAP.md              Ideen für den weiteren Ausbau
```

## Konfiguration

Alles Wesentliche liegt in `moonshine-core/shared/config.lua`:

* `Config.MaxCharacters` – Charakterslots pro Lizenz
* `Config.DefaultSpawn` – Startpunkt neuer Charaktere
* `Config.Accounts` – Konten und Startguthaben
* `Config.Paycheck` – Intervall, Zielkonto, Arbeitslosengeld
* `Config.Inventory` – Maximalgewicht und Slots
* `Config.Status` – Hunger-/Durstverbrauch
* `Config.SaveInterval` – Autosave-Intervall in Minuten
* `Config.CommandPermissions` – benötigtes Adminlevel je Command
* `Config.Logs.webhook` – optionaler Discord-Webhook

Jobs stehen in `shared/jobs.lua`, Items in `shared/items.lua`.

## Steuerung

| Taste | Funktion |
|---|---|
| `F2` | Inventar |
| `F5` | Skillleiste aus-/einklappen |
| `F7` | HUD ein-/ausblenden |
| `NUMPAD 1–6` | Skill-Slots auslösen |
| `E` | Bodenitem aufheben / Laden öffnen / Ritualpunkt / Steinader / Notruf |
| `G` | Wiederbeleben bzw. aufgeben, wenn bewusstlos |

Die Tasten lassen sich im FiveM-Menü unter *Einstellungen → Tastenbelegung → FiveM*
frei ändern.

## Commands

| Command | Level | Beschreibung |
|---|---|---|
| `/charakter` | – | Zurück zur Charakterauswahl |
| `/inventar` | – | Inventar öffnen |
| `/id` | – | Eigene Server-ID |
| `/revive [id]` | 2 | Spieler wiederbeleben |
| `/heal [id]` | 2 | Spieler heilen |
| `/goto [id]`, `/bring [id]`, `/tp [x] [y] [z]` | 2 | Teleport |
| `/kick [id] [grund]` | 2 | Spieler kicken |
| `/setjob [id] [job] [rang]` | 3 | Job setzen |
| `/givemoney [id] [betrag] [konto]` | 3 | Geld geben |
| `/giveitem [id] [item] [menge]` | 3 | Item geben |
| `/setstatus [id] [hunger\|thirst] [wert]` | 3 | Status setzen |
| `/ban [id] [stunden] [grund]`, `/unban [license]` | 3 | Bann verwalten |
| `/setmoney [id] [betrag] [konto]` | 4 | Kontostand setzen |
| `/setadmin [id] [level]` | 4 | Adminlevel setzen |
| `/saveall` | 4 | Alle Charaktere speichern |

Mystik-Commands (`/mystik`, `/setrasse`, `/givestein`, …) stehen in
[`docs/MYSTIC.md`](docs/MYSTIC.md), das Sterbesystem und die Steinadern in
[`docs/SURVIVAL.md`](docs/SURVIVAL.md).

Adminlevel: `0` User, `1` Support, `2` Moderator, `3` Admin, `4` Owner.

## Eigene Resources anbinden

```lua
-- server.lua
local MS = exports['moonshine-core']:GetCoreObject()

RegisterCommand('bonus', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    player:AddMoney(500, 'bank', 'bonus')
    player:AddItem('bread', 2)
    player:Notify('Bonus erhalten.', 'success')
end, false)
```

Vollständige Referenz: [`docs/API.md`](docs/API.md).
`moonshine-shops` zeigt den kompletten Ablauf mit Marker, NUI und Server-Callback.

## Hinweise

* Alle Geld- und Item-Aktionen laufen serverseitig; der Client schickt nur Absichten.
* Positionen werden alle 30 Sekunden gemeldet und beim Speichern übernommen.
* Bodenitems leben nur zur Laufzeit und verfallen nach 10 Minuten.
* Skins/Kleidung sind bewusst nicht enthalten – `appearance` liegt als Spalte und
  Feld bereit, damit ein Clothing-Script direkt andocken kann.
* Was als Nächstes sinnvoll wäre, steht in [`docs/ROADMAP.md`](docs/ROADMAP.md).
