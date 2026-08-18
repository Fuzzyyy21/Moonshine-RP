# Moonshine RP – Custom FiveM Framework

Ein eigenständiges Roleplay-Framework für FiveM plus ein mystisches
Rassensystem. Kein ESX-/QBCore-Fork, keine Alt-Lasten – nur Lua,
[oxmysql](https://github.com/overextended/oxmysql) und eine klare API.

| Resource | Inhalt |
|---|---|
| `moonshine-core` | Framework: Accounts, Multicharacter, Geld, Inventar, Jobs, HUD, API |
| `moonshine-world` | Serverzeit, Wetter, Mondphasen und mystische Weltereignisse → [`docs/WORLD.md`](docs/WORLD.md) |
| `moonshine-mystic` | Klassen-Skilltree (Klassensteine) und persönlicher Skillbaum mit 6 Kategorien (Fähigkeitspunkte), Skillleiste, Ritualpunkte → [`docs/MYSTIC.md`](docs/MYSTIC.md) |
| `moonshine-death` | Bewusstlosigkeit statt Sofort-Respawn, Notruf, Wiederbelebung → [`docs/SURVIVAL.md`](docs/SURVIVAL.md) |
| `moonshine-boss` | Weltbosse alle 45 Minuten, lassen Runen- und Seelensteine fallen → [`docs/SURVIVAL.md`](docs/SURVIVAL.md) |
| `moonshine-progress` | Spielzeit-Belohnungen, Daily/Weekly Missionen, Battle Pass, Kisten → [`docs/PROGRESS.md`](docs/PROGRESS.md) |
| `moonshine-factions` | Fraktionen mit Wappen, Rängen, Skilltree, Kasse, Tresor, Shop, Garage und Gebieten → [`docs/FACTIONS.md`](docs/FACTIONS.md) |
| `moonshine-auction` | Auktionshaus mit Geboten, Sofortkauf und Abholfach → [`docs/AUCTION.md`](docs/AUCTION.md) |
| `moonshine-vehicles` | Autohäuser, eigene Fahrzeuge, Garagen, Schlüssel und Verwahrstelle → [`docs/VEHICLES.md`](docs/VEHICLES.md) |
| `moonshine-services` | Tankstellen, Werkstätten, Bank, Geldautomaten und Schwarzmarkt → [`docs/SERVICES.md`](docs/SERVICES.md) |
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
| **Welt** | Serverzeit mit 48-Minuten-Tag, Wetterzyklus, acht Mondphasen und acht Weltereignissen, die Klassenkräfte, Bossintervall und Ritualertrag verschieben |
| **Fortschritt** | Spielzeit-Meilensteine, drei tägliche und drei wöchentliche Missionen, Battle Pass über 50 Stufen, vier Kistenarten |
| **Fraktionen** | Wappen-Baukasten, bis zu acht Ränge mit 13 Rechten, eigener Skilltree, Kasse, Tresor, Shop, Garage, acht Gebiete mit Einnahme und Einkommen |
| **Auktionshaus** | Gebote mit Anti-Sniping, Sofortkauf, Hausgebühr, Abholfach für Offline-Spieler |
| **Fahrzeuge** | 42 Fahrzeuge in drei Autohäusern, sechs Garagen, Tank- und Schadenspersistenz, Schlüsselsystem und Verwahrstelle |
| **Dienste** | 9 Tankstellen, 4 Werkstätten, 6 Bankfilialen, 16 Geldautomaten, wandernder Schwarzmarkt mit Geldwäsche |
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
   ensure moonshine-world
   ensure moonshine-mystic
   ensure moonshine-death
   ensure moonshine-boss
   ensure moonshine-progress
   ensure moonshine-factions
   ensure moonshine-auction
   ensure moonshine-vehicles
   ensure moonshine-services
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
├── moonshine-world/         Zeit, Wetter, Mondphasen, Weltereignisse
│   ├── shared/              Config, Mondphasen, Ereignisse
│   ├── server/              Uhr, Wetter, Ereignissteuerung, API
│   ├── client/              Uhr nachhalten, Effekte, Widget
│   └── nui/                 Widget, Ankündigung, Einblendung
├── moonshine-mystic/        Klassen, Skilltree, Skillleiste, Perks
│   ├── shared/              Config, Klassen, Skills, persoenlicher Baum, Steine
│   ├── server/              Profile, Skills, persoenlicher Baum, Ritualpunkte, API
│   ├── client/              Fähigkeiten, Skillleiste, Ritual-UI, Klassenmechanik
│   └── nui/                 Oberfläche (Skillleiste, beide Skilltrees, Händler)
├── moonshine-death/         Bewusstlosigkeit, Notruf, Wiederbelebung, Respawn
├── moonshine-boss/          Weltbosse als Quelle fuer Runen- und Seelensteine
├── moonshine-progress/      Spielzeit, Missionen, Battle Pass, Kisten
│   ├── shared/              Config, Missionen, Battle Pass, Kisten
│   ├── server/              Profil, Belohnungen, Spielzeit, Missionen, Pass, Kisten
│   ├── client/              Oberfläche und Meldungen
│   └── nui/                 Oberfläche (vier Reiter, Kistenanimation)
├── moonshine-factions/      Fraktionen, Ränge, Gebiete, Kasse, Tresor, Garage
│   ├── shared/              Config, Wappen, Ränge, Skilltree, Gebiete
│   ├── server/              Fraktionsobjekt, Mitglieder, Verwaltung, Tresor,
│   │                        Shop, Garage, Missionen, Gebiete
│   ├── client/              Oberfläche, Gebietskarte, Garage
│   └── nui/                 Oberfläche (zehn Reiter, SVG-Wappen, Karte)
├── moonshine-auction/       Auktionshaus mit Abholfach
├── moonshine-vehicles/      Autohäuser, Garagen, Schlüssel, Verwahrstelle
├── moonshine-services/      Tankstellen, Werkstätten, Bank, Schwarzmarkt
└── moonshine-shops/         Beispiel-Resource: 24/7 Läden auf Basis der API
sql/moonshine.sql            Schema als Referenz
docs/API.md                  API-Dokumentation des Frameworks
docs/WORLD.md                Zeit, Wetter, Mondphasen, Weltereignisse
docs/MYSTIC.md               Dokumentation des Mystik-Systems
docs/SURVIVAL.md             Sterbesystem und Weltbosse
docs/PROGRESS.md             Spielzeit, Missionen, Battle Pass, Kisten
docs/FACTIONS.md             Fraktionssystem
docs/AUCTION.md              Auktionshaus
docs/VEHICLES.md             Fahrzeuge, Garagen und Schlüssel
docs/SERVICES.md             Tankstellen, Werkstätten, Bank, Schwarzmarkt
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
| `F6` | Fortschritt (Spielzeit, Missionen, Battle Pass, Kisten) |
| `F7` | HUD ein-/ausblenden |
| `F10` | Fraktion |
| `L` | Fahrzeug ver-/entriegeln |
| `NUMPAD 1–6` | Skill-Slots auslösen |
| `E` | Aufheben / Laden / Ritualpunkt / Auktionator / Garage / Tanken / Bank / Notruf |
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

Die Commands der übrigen Systeme stehen in den jeweiligen Dokumenten:
[Welt](docs/WORLD.md), [Mystik](docs/MYSTIC.md),
[Sterbesystem und Weltbosse](docs/SURVIVAL.md),
[Fortschritt](docs/PROGRESS.md), [Fraktionen](docs/FACTIONS.md),
[Auktionshaus](docs/AUCTION.md), [Fahrzeuge](docs/VEHICLES.md) und
[Dienstleistungen](docs/SERVICES.md).

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
