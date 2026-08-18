--- Lebenszyklus, Netz-Events, API und Commands der Fahrzeuge.

local function reply(source, ok, message)
    if message and message ~= '' then
        exports['moonshine-core']:Notify(source, message, ok and 'success' or 'error', 8000)
    end
end

-- Autohaus ---------------------------------------------------------------------

RegisterNetEvent('vehicles:server:openDealer', function(dealerId)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local dealer = Vehicles.GetDealer(dealerId)
    if not dealer then return end

    local coords = GetEntityCoords(GetPlayerPed(source))
    if #(coords - dealer.coords) > VehicleConfig.Range + 3.0 then return end

    local list = {}
    for _, entry in ipairs(Vehicles.GetForDealer(dealer)) do
        list[#list + 1] = {
            model    = entry.model,
            label    = entry.label,
            category = entry.category,
            categoryLabel = Vehicles.GetCategoryLabel(entry.category),
            price    = entry.price,
            seats    = entry.seats,
            speed    = entry.speed,
        }
    end

    TriggerClientEvent('vehicles:client:dealer', source, {
        id         = dealer.id,
        label      = dealer.label,
        vehicles   = list,
        categories = Vehicles.Categories,
        money      = player:GetMoney(VehicleConfig.Ownership.account),
        owned      = Vehicles.DB.CountOwned(player.charId),
        maxOwned   = VehicleConfig.Ownership.maxVehicles,
    })
end)

RegisterNetEvent('vehicles:server:buy', function(model, dealerId)
    local source = source
    if not MS.RateLimit(source, 'vehicles:server:buy', 4, 10) then return end
    local player = MS.GetPlayer(source)
    if not player then return end

    local dealer = Vehicles.GetDealer(dealerId)
    if not dealer then return end

    local coords = GetEntityCoords(GetPlayerPed(source))
    if #(coords - dealer.coords) > VehicleConfig.Range + 3.0 then return end

    local ok, message, vehicle = Vehicles.Buy(source, model, dealerId)
    reply(source, ok, message)

    if ok and vehicle then
        local row = Vehicles.DB.GetById(vehicle.id)

        if row then
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
                engine = 1000,
                body   = 1000,
                spawn  = { x = dealer.spawn.x, y = dealer.spawn.y,
                           z = dealer.spawn.z, w = dealer.spawn.w },
            })
        end

        TriggerClientEvent('vehicles:client:closeUi', source)
    end

    Vehicles.SyncOwned(source)
end)

RegisterNetEvent('vehicles:server:sell', function(vehicleId)
    local source = source
    if not MS.RateLimit(source, 'vehicles:server:sell', 4, 10) then return end
    if not MS.GetPlayer(source) then return end

    local ok, message = Vehicles.Sell(source, vehicleId)
    reply(source, ok, message)

    Vehicles.SyncOwned(source)
end)

RegisterNetEvent('vehicles:server:transfer', function(vehicleId, targetId)
    local source = source
    if not MS.GetPlayer(source) then return end

    local ok, message = Vehicles.Transfer(source, vehicleId, targetId)
    reply(source, ok, message)

    if ok then Vehicles.SyncOwned(source) end
end)

RegisterNetEvent('vehicles:server:request', function()
    local source = source
    if MS.GetPlayer(source) then Vehicles.SyncOwned(source) end
end)

-- Lebenszyklus -------------------------------------------------------------------

AddEventHandler('moonshine:server:playerLoaded', function(source, player)
    CreateThread(function()
        Wait(3000)
        if not Vehicles.DB.Ready then return end

        -- Was von einer alten Sitzung noch draussen steht, kommt in die Garage.
        Vehicles.DB.StoreAllOf(player.charId)
        Vehicles.SyncOwned(source)
    end)
end)

-- API ----------------------------------------------------------------------------

exports('GetVehiclesObject', function()
    return Vehicles
end)

--- Alle Fahrzeuge eines Spielers.
exports('GetOwnedVehicles', function(source)
    local player = MS.GetPlayer(source)
    if not player then return {} end

    local list = {}
    for _, row in ipairs(Vehicles.DB.LoadOwned(player.charId)) do
        list[#list + 1] = Vehicles.Describe(row, player.charId)
    end

    return list
end)

--- Gehoert dieses Kennzeichen jemandem?
exports('GetVehicleByPlate', function(plate)
    return Vehicles.DB.GetByPlate(Vehicles.CleanPlate(plate))
end)

exports('HasKey', function(source, plate)
    local player = MS.GetPlayer(source)
    if not player then return false end

    return (Vehicles.HasKey(player.charId, plate))
end)

--- Fahrzeug in die Verwahrstelle bringen (z. B. fuer die Polizei).
exports('ImpoundVehicle', function(plate, reason)
    local row = Vehicles.DB.GetByPlate(Vehicles.CleanPlate(plate))
    if not row then return false end

    return Vehicles.Impound(row.id, reason)
end)

--- Fahrzeug vergeben, ohne dass jemand dafuer bezahlt.
exports('GiveVehicle', function(source, model, garageId)
    local player = MS.GetPlayer(source)
    if not player then return nil end

    local entry = Vehicles.GetModel(model)
    if not entry then return nil end

    local plate = Vehicles.MakePlate()

    local id = Vehicles.DB.Insert({
        ownerId = player.charId, plate = plate, model = entry.model,
        label = entry.label, category = entry.category, price = entry.price,
        garage = garageId or (VehicleConfig.Garages[1] and VehicleConfig.Garages[1].id),
    })

    if id then Vehicles.SyncOwned(source) end
    return id and plate or nil
end)

-- Commands --------------------------------------------------------------------------

local function permission(source, level)
    if source == 0 then return true end

    local player = MS.GetPlayer(source)
    return player ~= nil and (player.adminLevel or 0) >= level
end

RegisterCommand('fahrzeuge', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local rows = Vehicles.DB.LoadOwned(player.charId)
    if #rows == 0 then
        player:Notify('Du besitzt kein Fahrzeug.', 'info')
        return
    end

    local parts = {}
    for _, row in ipairs(rows) do
        local STATES = { garage = 'Garage', draussen = 'draussen', verwahrt = 'verwahrt' }
        parts[#parts + 1] = ('%s (%s, %s)'):format(row.label, row.plate,
            STATES[row.state] or row.state)
    end

    player:Notify(table.concat(parts, ' · '), 'info', 12000)
end, false)

RegisterCommand('schluessel', function(source, args)
    local player = MS.GetPlayer(source)
    if not player then return end

    local targetId = tonumber(args[1])
    if not targetId then
        player:Notify('Verwendung: /schluessel [id] - gibt einen Schluessel fuer '
            .. 'das Fahrzeug, in dem du sitzt.', 'info', 9000)
        return
    end

    TriggerClientEvent('vehicles:client:giveKeyHere', source, targetId)
end, false)

RegisterCommand('givevehicle', function(source, args)
    if not permission(source, 3) then return end

    local targetId = tonumber(args[1])
    local model = args[2]
    if not targetId or not model then
        print('Verwendung: /givevehicle [id] [modell]')
        return
    end

    local plate = exports[GetCurrentResourceName()]:GiveVehicle(targetId, model)

    if plate then
        exports['moonshine-core']:Notify(targetId,
            ('Du hast ein Fahrzeug erhalten: %s'):format(plate), 'success', 9000)
    else
        print('Unbekanntes Modell.')
    end
end, false)

RegisterCommand('impound', function(source, args)
    if not permission(source, 2) then return end
    if not args[1] then return end

    local plate = table.concat(args, ' ')
    if exports[GetCurrentResourceName()]:ImpoundVehicle(plate, 'Admin') then
        print(('%s wurde verwahrt.'):format(plate))
    end
end, false)

print('^2[Fahrzeuge]^7 Fahrzeugsystem geladen.')
