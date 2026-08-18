--- Fraktionsgarage: Fahrzeuge kaufen, ausgeben und einparken.

--- Erzeugt ein freies Kennzeichen.
local function makePlate(faction)
    local tag = faction.tag:upper():sub(1, 3)

    for _ = 1, 40 do
        local plate = ('%s %05d'):format(tag, math.random(0, 99999))

        local taken = false
        for _, vehicle in pairs(faction.vehicles) do
            if vehicle.plate == plate then taken = true break end
        end

        if not taken then return plate end
    end

    return ('%s %d'):format(tag, os.time() % 100000)
end

--- Baut die Garagenanzeige.
function Factions.BuildGaragePayload(faction, grade)
    if not FactionConfig.Garage.enabled then return { enabled = false } end

    local discount = faction:GetModifiers().vehicleDiscount or 0
    local owned, count = {}, 0

    for _, vehicle in pairs(faction.vehicles) do
        count = count + 1

        owned[#owned + 1] = {
            id        = vehicle.id,
            model     = vehicle.model,
            label     = vehicle.label,
            plate     = vehicle.plate,
            minGrade  = vehicle.minGrade,
            stored    = vehicle.stored,
            available = vehicle.stored and (grade or 0) >= vehicle.minGrade,
        }
    end

    table.sort(owned, function(a, b) return a.label < b.label end)

    local catalogue = {}
    for _, entry in ipairs(FactionConfig.Garage.vehicles) do
        catalogue[#catalogue + 1] = {
            model    = entry.model,
            label    = entry.label,
            price    = math.max(1, math.floor(entry.price * (1 - discount))),
            base     = entry.price,
            minRank  = entry.minRank,
        }
    end

    local points = {}
    for index, point in ipairs(FactionConfig.Garage.points) do
        points[#points + 1] = {
            index  = index,
            label  = point.label,
            coords = { x = point.coords.x, y = point.coords.y, z = point.coords.z },
        }
    end

    return {
        enabled   = true,
        vehicles  = owned,
        catalogue = catalogue,
        points    = points,
        slots     = faction:GetGarageSlots(),
        used      = count,
        discount  = discount,
    }
end

-- Kaufen ---------------------------------------------------------------------------

RegisterNetEvent('factions:server:buyVehicle', function(model)
    local source = source
    local player = MS.GetPlayer(source)
    if not player or not FactionConfig.Garage.enabled then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'garageBuy') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    local definition
    for _, entry in ipairs(FactionConfig.Garage.vehicles) do
        if entry.model == model then definition = entry break end
    end

    if not definition then return end

    local count = 0
    for _ in pairs(faction.vehicles) do count = count + 1 end

    if count >= faction:GetGarageSlots() then
        player:Notify('Die Garage ist voll. Baue den Fuhrpark aus.', 'error')
        return
    end

    local discount = faction:GetModifiers().vehicleDiscount or 0
    local price = math.max(1, math.floor(definition.price * (1 - discount)))

    if not faction:RemoveKasse(price, ('Fahrzeugkauf: %s'):format(definition.label)) then
        player:Notify(('In der Kasse fehlen %s.'):format(
            MS.Utils.FormatMoney(price - faction.kasse)), 'error')
        return
    end

    local plate = makePlate(faction)
    local id = Factions.DB.AddVehicle(faction.id, definition.model, definition.label,
        plate, definition.minRank or 0)

    if not id then
        faction:AddKasse(price, 'Fahrzeugkauf fehlgeschlagen')
        return
    end

    faction.vehicles[id] = {
        id = id, model = definition.model, label = definition.label,
        plate = plate, minGrade = definition.minRank or 0, stored = true,
    }

    faction:Save()
    faction:Log('garage', ('%s %s hat %s gekauft (%s).'):format(
        player.firstname, player.lastname, definition.label, MS.Utils.FormatMoney(price)))

    faction:Notify(('%s wurde gekauft: %s'):format(definition.label, plate), 'success')
    faction:Sync()
end)

-- Ausgeben -------------------------------------------------------------------------

RegisterNetEvent('factions:server:takeVehicle', function(vehicleId, pointIndex)
    local source = source
    local player = MS.GetPlayer(source)
    if not player or not FactionConfig.Garage.enabled then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'garage') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    vehicleId = tonumber(vehicleId)
    local vehicle = vehicleId and faction.vehicles[vehicleId]
    if not vehicle or not vehicle.stored then return end

    local grade = faction:GetGrade(player.charId) or 0
    if grade < vehicle.minGrade then
        player:Notify('Fuer dieses Fahrzeug fehlt dir der Rang.', 'error')
        return
    end

    local point = FactionConfig.Garage.points[tonumber(pointIndex) or 1]
    if not point then return end

    -- Der Spieler muss beim Ausgabepunkt stehen.
    local coords = GetEntityCoords(GetPlayerPed(source))
    if #(coords - point.coords) > 30.0 then
        player:Notify('Du stehst nicht an diesem Ausgabepunkt.', 'error')
        return
    end

    vehicle.stored = false
    Factions.DB.SetVehicleStored(vehicleId, false)

    TriggerClientEvent('factions:client:spawnVehicle', source, {
        model   = vehicle.model,
        plate   = vehicle.plate,
        coords  = { x = point.coords.x, y = point.coords.y, z = point.coords.z },
        heading = point.heading or 0.0,
    })

    faction:Log('garage', ('%s %s hat %s ausgeparkt.'):format(
        player.firstname, player.lastname, vehicle.label))

    faction:Sync()
end)

--- Der Client meldet, dass das Fahrzeug wieder eingeparkt wurde.
RegisterNetEvent('factions:server:storeVehicle', function(plate)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction then return end

    plate = tostring(plate or ''):gsub('%s+$', '')

    for _, vehicle in pairs(faction.vehicles) do
        if vehicle.plate:gsub('%s+$', '') == plate then
            vehicle.stored = true
            Factions.DB.SetVehicleStored(vehicle.id, true)

            player:Notify(('%s wurde eingeparkt.'):format(vehicle.label), 'success')
            faction:Sync()
            return
        end
    end
end)

--- Fahrzeug verkaufen (halber Preis zurueck in die Kasse).
RegisterNetEvent('factions:server:sellVehicle', function(vehicleId)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'garageBuy') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    vehicleId = tonumber(vehicleId)
    local vehicle = vehicleId and faction.vehicles[vehicleId]
    if not vehicle then return end

    if not vehicle.stored then
        player:Notify('Das Fahrzeug muss eingeparkt sein.', 'error')
        return
    end

    local refund = 0
    for _, entry in ipairs(FactionConfig.Garage.vehicles) do
        if entry.model == vehicle.model then refund = math.floor(entry.price * 0.5) break end
    end

    Factions.DB.SellVehicle(vehicleId)
    faction.vehicles[vehicleId] = nil

    if refund > 0 then faction:AddKasse(refund, ('Verkauf: %s'):format(vehicle.label)) end

    faction:Save()
    faction:Log('garage', ('%s %s hat %s verkauft.'):format(
        player.firstname, player.lastname, vehicle.label))

    faction:Notify(('%s wurde verkauft (%s).'):format(
        vehicle.label, MS.Utils.FormatMoney(refund)), 'info')
    faction:Sync()
end)

--- Mindestrang eines Fahrzeugs setzen.
RegisterNetEvent('factions:server:setVehicleGrade', function(vehicleId, grade)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'manage') then return end

    vehicleId = tonumber(vehicleId)
    grade = math.floor(tonumber(grade) or 0)

    local vehicle = vehicleId and faction.vehicles[vehicleId]
    if not vehicle then return end

    grade = math.max(0, math.min(grade, Factions.TopGrade(faction.ranks)))

    vehicle.minGrade = grade
    Factions.DB.SetVehicleGrade(vehicleId, grade)

    faction:Sync()
end)
