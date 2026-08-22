--- Datenbank der Fahrzeuge.

Vehicles.DB = {}
Vehicles.DB.Ready = false

local SCHEMA = {
    [[
    CREATE TABLE IF NOT EXISTS `ms_vehicles` (
        `id`           INT          NOT NULL AUTO_INCREMENT,
        `owner_id`     INT          NOT NULL,
        `plate`        VARCHAR(12)  NOT NULL,
        `model`        VARCHAR(32)  NOT NULL,
        `label`        VARCHAR(48)  NOT NULL,
        `category`     VARCHAR(24)  NOT NULL DEFAULT 'kompakt',
        `price`        BIGINT       NOT NULL DEFAULT 0,
        `state`        VARCHAR(12)  NOT NULL DEFAULT 'garage',
        `garage`       VARCHAR(32)  DEFAULT NULL,
        `fuel`         FLOAT        NOT NULL DEFAULT 100,
        `engine`       FLOAT        NOT NULL DEFAULT 1000,
        `body`         FLOAT        NOT NULL DEFAULT 1000,
        `mods`         LONGTEXT     DEFAULT NULL,
        `keys`         LONGTEXT     DEFAULT NULL,
        `position`     LONGTEXT     DEFAULT NULL,
        `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `plate` (`plate`),
        KEY `owner_id` (`owner_id`),
        KEY `state` (`state`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],
}

MySQL.ready(function()
    local ok, err = pcall(function()
        for _, statement in ipairs(SCHEMA) do MySQL.query.await(statement) end
    end)

    if not ok then
        print(('^1[Fahrzeuge]^7 Schema konnte nicht angelegt werden: %s'):format(tostring(err)))
        return
    end

    -- Fahrzeuge, die beim letzten Stop draussen standen, kommen in die Garage
    -- zurueck - sonst sind sie nach einem Absturz unauffindbar.
    local moved = MySQL.update.await([[
        UPDATE ms_vehicles SET state = 'garage'
        WHERE state = 'draussen' AND garage IS NOT NULL
    ]])

    if moved and moved > 0 then
        print(('^3[Fahrzeuge]^7 %d Fahrzeuge nach dem Neustart eingeparkt.'):format(moved))
    end

    Vehicles.DB.Ready = true
    print('^2[Fahrzeuge]^7 Datenbank bereit.')
end)

-- Lesen -------------------------------------------------------------------------

function Vehicles.DB.LoadOwned(characterId)
    return MySQL.query.await('SELECT * FROM ms_vehicles WHERE owner_id = ?',
        { characterId }) or {}
end

function Vehicles.DB.GetByPlate(plate)
    return MySQL.single.await('SELECT * FROM ms_vehicles WHERE plate = ?', { plate })
end

function Vehicles.DB.GetById(vehicleId)
    return MySQL.single.await('SELECT * FROM ms_vehicles WHERE id = ?', { vehicleId })
end

function Vehicles.DB.CountOwned(characterId)
    local row = MySQL.single.await(
        'SELECT COUNT(*) AS total FROM ms_vehicles WHERE owner_id = ?', { characterId })

    return row and tonumber(row.total) or 0
end

function Vehicles.DB.PlateExists(plate)
    local row = MySQL.single.await('SELECT id FROM ms_vehicles WHERE plate = ?', { plate })
    return row ~= nil
end

-- Schreiben ----------------------------------------------------------------------

function Vehicles.DB.Insert(payload)
    return MySQL.insert.await([[
        INSERT INTO ms_vehicles
            (owner_id, plate, model, label, category, price, state, garage, fuel, `keys`)
        VALUES (?, ?, ?, ?, ?, ?, 'garage', ?, ?, '[]')
    ]], {
        payload.ownerId, payload.plate, payload.model, payload.label,
        payload.category, payload.price, payload.garage,
        VehicleConfig.State.startFuel,
    })
end

--- Wechselt den Zustand nur, wenn er noch der erwartete ist.
---
--- Das ist die Antwort auf ein Rennen, das ein Fahrzeug verdoppelt hat:
--- Zwischen "steht das Auto in der Garage?" und "hol es raus" liegt ein
--- Warten auf die Datenbank. Kamen zwei Anfragen gleichzeitig - zwei
--- Klicks, zwei Schluesselbesitzer -, lasen beide denselben Zustand,
--- beide sahen "garage", und beide bekamen ein Auto. Zwei Fahrzeuge mit
--- demselben Kennzeichen.
---
--- Die Datenbank kann das allein entscheiden: wer die Zeile im erwarteten
--- Zustand antrifft, aendert sie; alle anderen aendern nichts und bekommen
--- 0 zurueck.
---@return boolean Ob dieser Aufruf den Wechsel vollzogen hat
function Vehicles.DB.ClaimState(vehicleId, von, nach, garage, position)
    local betroffen = MySQL.update.await([[
        UPDATE ms_vehicles SET state = ?, garage = ?, position = ?
        WHERE id = ? AND state = ?
    ]], { nach, garage, position and json.encode(position) or nil,
          vehicleId, von }) or 0

    return betroffen > 0
end

function Vehicles.DB.SetState(vehicleId, state, garage, position)
    return MySQL.update.await([[
        UPDATE ms_vehicles SET state = ?, garage = ?, position = ? WHERE id = ?
    ]], { state, garage, position and json.encode(position) or nil, vehicleId })
end

function Vehicles.DB.SaveCondition(vehicleId, fuel, engine, body)
    return MySQL.update.await([[
        UPDATE ms_vehicles SET fuel = ?, engine = ?, body = ? WHERE id = ?
    ]], { fuel, engine, body, vehicleId })
end

function Vehicles.DB.SaveMods(vehicleId, mods)
    return MySQL.update.await('UPDATE ms_vehicles SET mods = ? WHERE id = ?',
        { json.encode(mods or {}), vehicleId })
end

function Vehicles.DB.SaveKeys(vehicleId, keys)
    return MySQL.update.await('UPDATE ms_vehicles SET `keys` = ? WHERE id = ?',
        { json.encode(keys or {}), vehicleId })
end

function Vehicles.DB.SetOwner(vehicleId, characterId)
    return MySQL.update.await(
        'UPDATE ms_vehicles SET owner_id = ?, `keys` = \'[]\' WHERE id = ?',
        { characterId, vehicleId })
end

--- Uebertraegt nur, wenn das Fahrzeug noch diesem Besitzer gehoert und in
--- der Garage steht. Sonst hat es in der Zwischenzeit jemand verkauft oder
--- selbst ueberschrieben.
---@return boolean
function Vehicles.DB.ClaimOwner(vehicleId, vonCharakter, nachCharakter)
    local betroffen = MySQL.update.await([[
        UPDATE ms_vehicles SET owner_id = ?, `keys` = '[]'
        WHERE id = ? AND owner_id = ? AND state = 'garage'
    ]], { nachCharakter, vehicleId, vonCharakter }) or 0

    return betroffen > 0
end

function Vehicles.DB.Delete(vehicleId)
    return MySQL.update.await('DELETE FROM ms_vehicles WHERE id = ?', { vehicleId })
end

--- Loescht nur, wenn das Fahrzeug noch diesem Besitzer gehoert und in der
--- Garage steht. Wer 0 zurueckbekommt, war zu spaet - und darf nicht
--- ausgezahlt werden.
---@return boolean
function Vehicles.DB.ClaimDelete(vehicleId, characterId)
    local betroffen = MySQL.update.await([[
        DELETE FROM ms_vehicles
        WHERE id = ? AND owner_id = ? AND state = 'garage'
    ]], { vehicleId, characterId }) or 0

    return betroffen > 0
end

--- Alle Fahrzeuge eines Charakters einparken (beim Ausloggen).
function Vehicles.DB.StoreAllOf(characterId)
    return MySQL.update.await([[
        UPDATE ms_vehicles SET state = 'garage'
        WHERE owner_id = ? AND state = 'draussen' AND garage IS NOT NULL
    ]], { characterId })
end
