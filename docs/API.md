# Moonshine API

Alle Beispiele setzen `moonshine-core` als `dependency` in der `fxmanifest.lua`
der eigenen Resource voraus.

```lua
dependency 'moonshine-core'
```

## Zugriff auf das Framework

```lua
-- server.lua oder client.lua
local MS = exports['moonshine-core']:GetCoreObject()
```

Alternativ lassen sich einzelne Funktionen direkt als Export aufrufen, ohne das
gesamte Objekt zu holen:

```lua
exports['moonshine-core']:AddMoney(source, 500, 'bank', 'shop')
```

---

## Server

### Spieler holen

```lua
local player  = MS.GetPlayer(source)              -- Spielerobjekt oder nil
local byChar  = MS.GetPlayerByCharId(12)
local byLic   = MS.GetPlayerByLicense('license:…')
local alle    = MS.GetPlayers()                   -- Liste aller geladenen Spieler
local cops    = MS.GetPlayers('police')           -- nach Job gefiltert
```

### Spielerobjekt

| Feld | Typ | Beschreibung |
|---|---|---|
| `source` | number | Server-ID |
| `license` | string | Rockstar-Lizenz |
| `charId` | number | ID in `ms_characters` |
| `firstname`, `lastname`, `fullname` | string | Name |
| `dob`, `gender` | string | Geburtsdatum, `m`/`w` |
| `job` | table | `{ name, label, grade, gradeLabel, salary, whitelisted }` |
| `accounts` | table | `{ cash, bank, black }` |
| `inventory` | table | Liste aus `{ slot, name, count, metadata }` |
| `metadata` | table | frei nutzbar, enthält u.a. `hunger`, `thirst` |
| `adminLevel` | number | 0–4 |

**Methoden**

```lua
player:GetData()                       -- Client-taugliche Kopie ohne Funktionen
player:Save()                          -- sofort in die Datenbank schreiben
player:Sync()                          -- Daten an den Client schicken
player:Notify('Text', 'success', 5000) -- info | success | warning | error
player:Kick('Grund')
player:HasPermission(3)

-- Job
player:SetJob('police', 2)

-- Geld
player:GetMoney('bank')
player:CanAfford(250, 'cash')
player:AddMoney(500, 'bank', 'grund')
player:RemoveMoney(250, 'cash', 'grund')   -- false wenn zu wenig Guthaben
player:SetMoney(1000, 'cash', 'grund')

-- Inventar
player:AddItem('bread', 2, { qualitaet = 90 })
player:RemoveItem('bread', 1)              -- optional: (name, count, slot)
player:HasItem('lockpick', 1)
player:GetItemCount('water')
player:GetSlot(3)
player:CanCarryItem('repairkit', 1)
player:GetInventoryWeight()
player:ClearInventory()

-- Metadaten und Status
player:SetMetadata('handynummer', '0151-1234')
player:GetMetadata('handynummer')
player:GetStatus('hunger')
player:SetStatus('thirst', 100.0)
player:AddStatus('hunger', -10.0)

-- Position
player:SetPosition(x, y, z, heading)
```

### Benutzbare Items

```lua
MS.RegisterUsableItem('lockpick', function(player, slot, entry)
    if player:RemoveItem('lockpick', 1, slot) then
        player:TriggerEvent('meinescript:client:lockpickStarten')
    end
end)
```

### Server-Callbacks

```lua
-- Server
MS.RegisterServerCallback('werkstatt:reparieren', function(player, cb, netId)
    if not player:HasItem('repairkit', 1) then
        cb(false, 'Kein Reparaturkit dabei.')
        return
    end

    player:RemoveItem('repairkit', 1)
    cb(true, 'Fahrzeug repariert.')
end)

-- Client
MS.TriggerServerCallback('werkstatt:reparieren', function(ok, message)
    MS.Notify(message, ok and 'success' or 'error')
end, VehToNet(vehicle))
```

### Events (Server)

| Event | Argumente |
|---|---|
| `moonshine:server:databaseReady` | – |
| `moonshine:server:playerLoaded` | `source, player` |
| `moonshine:server:playerDropped` | `source, player, reason` |
| `moonshine:server:playerUnloaded` | `source, player` |
| `moonshine:server:playerDeath` | `source, player` |
| `moonshine:server:jobChanged` | `source, job, previousJob` |
| `moonshine:server:moneyChanged` | `source, account, balance, delta, reason` |
| `moonshine:server:itemAdded` | `source, name, count` |
| `moonshine:server:itemRemoved` | `source, name, count` |

```lua
AddEventHandler('moonshine:server:playerLoaded', function(source, player)
    print(player.fullname .. ' ist im Spiel.')
end)
```

### Logging

```lua
MS.Logger.Log('admin', 'Nachricht für Konsole, Datenbank und Discord', player.license)
```

---

## Client

```lua
local MS = exports['moonshine-core']:GetCoreObject()

MS.PlayerData        -- aktuelle Spielerdaten (identisch zu player:GetData())
MS.IsPlayerLoaded    -- boolean

MS.Notify('Text', 'info', 4000)
MS.DrawText3D(coords, 'Text', 0.35)
MS.DrawHelpText('Drücke ~INPUT_CONTEXT~')
MS.OpenInventory()
MS.TriggerServerCallback(name, callback, ...)
```

### Events (Client)

| Event | Argumente |
|---|---|
| `moonshine:client:playerLoaded` | `data` |
| `moonshine:client:playerUnloaded` | – |
| `moonshine:client:dataChanged` | `data` |
| `moonshine:client:jobChanged` | `job, previousJob` |
| `moonshine:client:moneyChanged` | `account, balance, delta` |
| `moonshine:client:metadataChanged` | `key, value` |
| `moonshine:client:statusChanged` | `name, value` |
| `moonshine:client:playerDied` | – |

```lua
AddEventHandler('moonshine:client:jobChanged', function(job)
    if job.name == 'police' then
        -- Polizei-Features aktivieren
    end
end)
```

---

## Items und Jobs erweitern

**Item** in `moonshine-core/shared/items.lua`:

```lua
donut = {
    label = 'Donut', weight = 150, stack = true, usable = true, closeUi = true,
    description = 'Frisch aus dem Coffeeshop.',
},
```

**Job** in `moonshine-core/shared/jobs.lua`:

```lua
reporter = {
    label = 'Weazel News',
    whitelisted = true,
    grades = {
        [0] = { label = 'Praktikant', salary = 600 },
        [1] = { label = 'Reporter',   salary = 1100 },
    },
},
```

Nach beiden Änderungen reicht ein `restart moonshine-core`.

---

## Direkte Exports

**Server**

| Export | Rückgabe |
|---|---|
| `GetCoreObject()` | Framework-Objekt |
| `GetPlayer(source)` | Spielerobjekt |
| `GetPlayerData(source)` | Datentabelle |
| `GetPlayers(jobName?)` | Liste |
| `IsPlayerLoaded(source)` | boolean |
| `AddMoney(source, amount, account?, reason?)` | boolean |
| `RemoveMoney(source, amount, account?, reason?)` | boolean |
| `GetMoney(source, account?)` | number |
| `AddItem(source, name, count?, metadata?)` | boolean |
| `RemoveItem(source, name, count?, slot?)` | boolean |
| `HasItem(source, name, count?)` | boolean |
| `SetJob(source, name, grade?)` | boolean |
| `Notify(source, message, type?, duration?)` | – |
| `RegisterUsableItem(name, cb)` | – |
| `RegisterServerCallback(name, cb)` | – |
| `SavePlayer(source)` / `SaveAllPlayers()` | boolean / number |

**Client**

| Export | Rückgabe |
|---|---|
| `GetCoreObject()` | Framework-Objekt |
| `GetPlayerData()` | Datentabelle |
| `IsPlayerLoaded()` | boolean |
| `GetJob()` | Job-Tabelle |
| `GetMoney(account?)` | number |
| `HasItem(name, count?)` | boolean |
| `Notify(message, type?, duration?)` | – |
| `TriggerServerCallback(name, cb, ...)` | – |
| `OpenInventory()` | – |
| `DrawText3D(coords, text, scale?)` | – |
