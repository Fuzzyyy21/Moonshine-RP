--- Garagen und Verwahrstelle: Ausparken, Einparken, Ausloesen.

--- Steht der Spieler wirklich an diesem Punkt?
local function atPoint(source, kind, id)
    local coords = GetEntityCoords(GetPlayerPed(source))
    local point, foundKind = Vehicles.PointAt(coords)

    if not point or foundKind ~= kind then return nil end
    if id and point.id and point.id ~= id then return nil end

    return point
end

--- Schickt einem Spieler seine Fahrzeugliste.
function Vehicles.SyncOwned(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local list = {}
    for _, row in ipairs(Vehicles.DB.LoadOwned(player.charId)) do
        list[#list + 1] = Vehicles.Describe(row, player.charId)
    end

    table.sort(list, function(a, b) return a.label < b.label end)

    TriggerClientEvent('vehicles:client:owned', source, {
        vehicles    = list,
        maxVehicles = VehicleConfig.Ownership.maxVehicles,
        money       = player:GetMoney(VehicleConfig.Ownership.account),
        cash        = player:GetMoney('cash'),
        impoundFee  = VehicleConfig.Impound.fee,
        garages     = VehicleConfig.Garages,
    })
end

-- Ausparken -----------------------------------------------------------------------

RegisterNetEvent('vehicles:server:take', function(vehicleId)
    local source = source
    if not MS.RateLimit(source, 'vehicles:server:take', 10, 10) then return end
    local player = MS.GetPlayer(source)
    if not player then return end

    local garage = atPoint(source, 'garage')
    if not garage then
        player:Notify('Du stehst an keiner Garage.', 'error')
        return
    end

    local row = Vehicles.DB.GetById(tonumber(vehicleId) or -1)
    if not row then return end

    -- Besitzer oder Zweitschluessel.
    local allowed = Vehicles.HasKey(player.charId, row.plate)
    if not allowed then
        player:Notify('Fuer dieses Fahrzeug hast du keinen Schluessel.', 'error')
        return
    end

    if row.state == 'verwahrt' then
        player:Notify('Das Fahrzeug steht in der Verwahrstelle.', 'error')
        return
    end

    if row.state == 'draussen' then
        player:Notify('Das Fahrzeug steht bereits draussen.', 'error')
        return
    end

    -- Nur aus der Garage, in der es steht.
    if row.garage and row.garage ~= garage.id then
        local other = Vehicles.GetGarage(row.garage)
        player:Notify(('Das Fahrzeug steht in %s.'):format(
            other and other.label or row.garage), 'error')
        return
    end

    Vehicles.DB.SetState(row.id, 'draussen', row.garage, nil)

    Vehicles.Spawned[Vehicles.CleanPlate(row.plate)] = {
        id = row.id, owner = row.owner_id, source = source,
    }

    TriggerClientEvent('vehicles:client:spawn', source, {
        id     = row.id,
        model  = row.model,
        label  = row.label,
        plate  = row.plate,
        fuel   = tonumber(row.fuel) or 100,
        engine = tonumber(row.engine) or 1000,
        body   = tonumber(row.body) or 1000,
        mods   = Vehicles.GetMods(row.plate),
        spawn  = { x = garage.spawn.x, y = garage.spawn.y,
                   z = garage.spawn.z, w = garage.spawn.w },
    })

    Vehicles.SyncOwned(source)
    TriggerEvent('vehicles:server:takenOut', source, row.id)
end)

-- Einparken ------------------------------------------------------------------------

RegisterNetEvent('vehicles:server:store', function(plate, fuel, engine, body)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local garage = atPoint(source, 'garage')
    if not garage then
        player:Notify('Du stehst an keiner Garage.', 'error')
        return
    end

    plate = Vehicles.CleanPlate(plate)

    local row = Vehicles.DB.GetByPlate(plate)
    if not row then
        player:Notify('Dieses Fahrzeug gehoert niemandem.', 'error')
        return
    end

    if not Vehicles.HasKey(player.charId, plate) then
        player:Notify('Fuer dieses Fahrzeug hast du keinen Schluessel.', 'error')
        return
    end

    Vehicles.DB.SetState(row.id, 'garage', garage.id, nil)
    Vehicles.DB.SaveCondition(row.id,
        math.max(0.0, math.min(100.0, tonumber(fuel) or tonumber(row.fuel) or 100)),
        math.max(0.0, math.min(1000.0, tonumber(engine) or 1000)),
        math.max(0.0, math.min(1000.0, tonumber(body) or 1000)))

    Vehicles.Spawned[plate] = nil

    TriggerClientEvent('vehicles:client:despawn', source, plate)
    player:Notify(('%s steht jetzt in %s.'):format(row.label, garage.label), 'success')

    Vehicles.SyncOwned(source)
    TriggerEvent('vehicles:server:storedAway', source, row.id)
end)

-- Verwahrstelle ---------------------------------------------------------------------

--- Bringt ein Fahrzeug in die Verwahrstelle.
function Vehicles.Impound(vehicleId, reason)
    if not VehicleConfig.Impound.enabled then return false end

    local row = Vehicles.DB.GetById(vehicleId)
    if not row then return false end

    Vehicles.DB.SetState(row.id, 'verwahrt', row.garage, nil)
    Vehicles.Spawned[Vehicles.CleanPlate(row.plate)] = nil

    TriggerEvent('vehicles:server:impounded', row.id, reason)
    return true
end

RegisterNetEvent('vehicles:server:release', function(vehicleId)
    if not MS.RateLimit(source, 'vehicles:release', 5, 30) then return end
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    if not atPoint(source, 'impound') then
        player:Notify('Du stehst nicht an der Verwahrstelle.', 'error')
        return
    end

    local row = Vehicles.DB.GetById(tonumber(vehicleId) or -1)
    if not row or row.owner_id ~= player.charId then
        player:Notify('Das ist nicht dein Fahrzeug.', 'error')
        return
    end

    if row.state ~= 'verwahrt' then
        player:Notify('Das Fahrzeug ist nicht verwahrt.', 'error')
        return
    end

    local config = VehicleConfig.Impound

    if not player:RemoveMoney(config.fee, config.account, 'verwahrstelle') then
        player:Notify(('Die Auslösung kostet %s.'):format(
            MS.Utils.FormatMoney(config.fee)), 'error')
        return
    end

    local garage = Vehicles.GetGarage(row.garage) or VehicleConfig.Garages[1]
    Vehicles.DB.SetState(row.id, 'garage', garage and garage.id or nil, nil)

    player:Notify(('%s wurde ausgeloest und steht in %s.'):format(
        row.label, garage and garage.label or 'deiner Garage'), 'success', 9000)

    Vehicles.SyncOwned(source)
end)

--- Fahrzeuge, die beim Ausloggen draussen stehen, wandern in die Garage.
local function parkAllOf(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    Vehicles.DB.StoreAllOf(player.charId)

    for plate, entry in pairs(Vehicles.Spawned) do
        if entry.source == source then Vehicles.Spawned[plate] = nil end
    end
end

AddEventHandler('moonshine:server:playerDropped', function(source)
    if Vehicles.DB.Ready then parkAllOf(source) end
end)

AddEventHandler('moonshine:server:playerUnloaded', function(source)
    if Vehicles.DB.Ready then parkAllOf(source) end
end)
