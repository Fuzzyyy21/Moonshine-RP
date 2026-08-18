--- Fahrzeugschluessel.
---
--- Der Besitzer hat immer einen Schluessel. Weitere Schluessel gibt er an
--- andere Charaktere weiter; sie gelten, bis er sie wieder einzieht. Beim
--- Besitzerwechsel verfallen alle Zweitschluessel.

local function decode(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return {} end

    local ok, value = pcall(json.decode, raw)
    return (ok and type(value) == 'table') and value or {}
end

local function contains(list, value)
    for _, entry in ipairs(list) do
        if entry == value then return true end
    end
    return false
end

--- Darf dieser Charakter das Fahrzeug fahren?
function Vehicles.HasKey(characterId, plate)
    local row = Vehicles.DB.GetByPlate(Vehicles.CleanPlate(plate))
    if not row then return false, nil end

    if row.owner_id == characterId then return true, row end

    return contains(decode(row.keys), characterId), row
end

--- Gibt einem Spieler einen Zweitschluessel.
function Vehicles.GiveKey(source, vehicleId, targetId)
    local player = MS.GetPlayer(source)
    if not player then return false, '' end

    local target = MS.GetPlayer(tonumber(targetId) or -1)
    if not target then return false, 'Dieser Spieler ist nicht online.' end

    if target.charId == player.charId then return false, 'Den hast du schon.' end

    local row = Vehicles.DB.GetById(tonumber(vehicleId) or -1)
    if not row or row.owner_id ~= player.charId then
        return false, 'Das ist nicht dein Fahrzeug.'
    end

    local keys = decode(row.keys)
    if contains(keys, target.charId) then
        return false, ('%s hat bereits einen Schluessel.'):format(target.firstname)
    end

    keys[#keys + 1] = target.charId
    Vehicles.DB.SaveKeys(row.id, keys)

    target:Notify(('Du hast einen Schluessel fuer %s (%s) bekommen.'):format(
        row.label, row.plate), 'success', 9000)

    TriggerEvent('vehicles:server:keyGiven', row.id, player.charId, target.charId)

    return true, ('%s hat jetzt einen Schluessel.'):format(target.firstname)
end

--- Zieht alle Zweitschluessel ein.
function Vehicles.ClearKeys(source, vehicleId)
    local player = MS.GetPlayer(source)
    if not player then return false, '' end

    local row = Vehicles.DB.GetById(tonumber(vehicleId) or -1)
    if not row or row.owner_id ~= player.charId then
        return false, 'Das ist nicht dein Fahrzeug.'
    end

    local count = #decode(row.keys)
    if count == 0 then return false, 'Es gibt keine Zweitschluessel.' end

    Vehicles.DB.SaveKeys(row.id, {})

    return true, ('%d Zweitschluessel eingezogen.'):format(count)
end

-- Netz-Events ---------------------------------------------------------------------

RegisterNetEvent('vehicles:server:giveKey', function(vehicleId, targetId)
    local source = source
    local ok, message = Vehicles.GiveKey(source, vehicleId, targetId)

    exports['moonshine-core']:Notify(source, message, ok and 'success' or 'error', 7000)

    if ok then
        Vehicles.SyncOwned(source)
        TriggerClientEvent('vehicles:client:forgetKeys', tonumber(targetId))
    end
end)

--- Schluessel fuer das Fahrzeug, vor dem der Spieler gerade steht.
RegisterNetEvent('vehicles:server:giveKeyByPlate', function(plate, targetId)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local row = Vehicles.DB.GetByPlate(Vehicles.CleanPlate(plate))
    if not row then
        player:Notify('Dieses Fahrzeug gehoert niemandem.', 'error')
        return
    end

    local ok, message = Vehicles.GiveKey(source, row.id, targetId)
    player:Notify(message, ok and 'success' or 'error', 7000)

    if ok then
        Vehicles.SyncOwned(source)
        TriggerClientEvent('vehicles:client:forgetKeys', tonumber(targetId))
    end
end)

RegisterNetEvent('vehicles:server:clearKeys', function(vehicleId)
    local source = source
    local ok, message = Vehicles.ClearKeys(source, vehicleId)

    exports['moonshine-core']:Notify(source, message, ok and 'success' or 'error', 7000)

    if ok then
        Vehicles.SyncOwned(source)
        -- Alle muessen ihre Schluesselpruefung verwerfen.
        TriggerClientEvent('vehicles:client:forgetKeys', -1)
    end
end)

--- Der Client fragt, ob er ein Fahrzeug starten darf.
MS.RegisterServerCallback('vehicles:hasKey', function(player, cb, plate)
    if not player then return cb(false) end

    plate = Vehicles.CleanPlate(plate)

    -- Was nicht in ms_vehicles steht, gehoert niemandem (NPC-Verkehr,
    -- Fraktionsfahrzeuge, Mietwagen) und bleibt frei fahrbar.
    local row = Vehicles.DB.GetByPlate(plate)
    if not row then return cb(true) end

    cb(Vehicles.HasKey(player.charId, plate))
end)
