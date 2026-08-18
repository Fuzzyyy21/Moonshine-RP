--- Fraktionsgarage: Ausgabepunkte, Ausparken und Einparken.

local spawning = false

--- Fahrzeug erzeugen.
RegisterNetEvent('factions:client:spawnVehicle', function(payload)
    if spawning then return end
    spawning = true

    local model = joaat(payload.model)
    RequestModel(model)

    local tries = 0
    while not HasModelLoaded(model) and tries < 100 do
        Wait(50)
        tries = tries + 1
    end

    if not HasModelLoaded(model) then
        exports['moonshine-core']:Notify('Das Fahrzeug konnte nicht geladen werden.', 'error')
        spawning = false
        return
    end

    local coords = vector3(payload.coords.x, payload.coords.y, payload.coords.z)
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z,
        payload.heading or 0.0, true, false)

    SetVehicleNumberPlateText(vehicle, payload.plate)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)

    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    SetModelAsNoLongerNeeded(model)

    spawning = false
end)

--- Einparken: am Ausgabepunkt mit dem Fraktionsfahrzeug.
local function storeNearby()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        exports['moonshine-core']:Notify('Du sitzt in keinem Fahrzeug.', 'error')
        return
    end

    local coords = GetEntityCoords(ped)
    local near = false

    for _, point in ipairs(FactionConfig.Garage.points) do
        if #(coords - point.coords) < 25.0 then near = true break end
    end

    if not near then
        exports['moonshine-core']:Notify('Du bist an keinem Ausgabepunkt.', 'error')
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerServerEvent('factions:server:storeVehicle', plate)

    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
end

RegisterCommand('einparken', function() storeNearby() end, false)

--- Marker an den Ausgabepunkten.
CreateThread(function()
    while true do
        local wait = 1000
        local coords = GetEntityCoords(PlayerPedId())

        for _, point in ipairs(FactionConfig.Garage.points) do
            local distance = #(coords - point.coords)

            if distance < 30.0 then
                wait = 0

                DrawMarker(36, point.coords.x, point.coords.y, point.coords.z + 0.6,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.8,
                    155, 107, 216, 140, false, true, 2, false, nil, nil, false)

                if distance < 3.0 then
                    exports['moonshine-core']:DrawText3D(
                        vector3(point.coords.x, point.coords.y, point.coords.z + 1.0),
                        ('Fraktionsgarage ~p~%s~s~  [~b~F10~s~]  /einparken'):format(point.label), 0.4)
                end
            end
        end

        Wait(wait)
    end
end)
