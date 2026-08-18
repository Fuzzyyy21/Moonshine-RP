--- Werkstatt: Reparatur mit Fortschritt, Reparaturkit unterwegs.

local MS = exports['moonshine-core']:GetCoreObject()

local repairing = false

--- Fahrzeug, das gerade repariert werden kann.
local function targetVehicle()
    local ped = PlayerPedId()

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then return vehicle end

    local coords = GetEntityCoords(ped)
    vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 6.0, 0, 71)

    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then return vehicle end
    return nil
end

--- Zustand in Prozent.
local function condition(vehicle)
    return math.floor(GetVehicleEngineHealth(vehicle) / 10),
           math.floor(GetVehicleBodyHealth(vehicle) / 10)
end

--- Der Server hat die Reparatur freigegeben.
RegisterNetEvent('services:client:repairGranted', function(plate, duration, partial)
    if repairing then return end

    local vehicle = targetVehicle()
    if not vehicle then
        MS.Notify('Das Fahrzeug ist nicht mehr da.', 'error')
        return
    end

    repairing = true

    CreateThread(function()
        local ped = PlayerPedId()
        local inside = GetVehiclePedIsIn(ped, false) ~= 0

        if not inside then
            RequestAnimDict('mini@repair')
            local tries = 0
            while not HasAnimDictLoaded('mini@repair') and tries < 40 do
                Wait(50)
                tries = tries + 1
            end

            if HasAnimDictLoaded('mini@repair') then
                TaskPlayAnim(ped, 'mini@repair', 'fixing_a_ped', 2.0, -2.0, -1,
                    49, 0, false, false, false)
            end

            SetVehicleDoorOpen(vehicle, 4, false, false)
        end

        local steps = 20
        for index = 1, steps do
            Wait(math.floor(duration * 1000 / steps))

            SendNUIMessage({ action = 'services:repairProgress',
                value = index / steps })

            if not DoesEntityExist(vehicle) then break end
        end

        SendNUIMessage({ action = 'services:repairProgress', value = 0 })
        ClearPedTasks(ped)

        if DoesEntityExist(vehicle) then
            if partial then
                -- Kit repariert nur teilweise.
                local config = ServiceConfig.Repair.kit

                SetVehicleEngineHealth(vehicle, math.min(1000.0,
                    GetVehicleEngineHealth(vehicle) + config.engine * 10))
                SetVehicleBodyHealth(vehicle, math.min(1000.0,
                    GetVehicleBodyHealth(vehicle) + config.body * 10))

                MS.Notify('Notdürftig repariert. Die Werkstatt macht es richtig.',
                    'success', 8000)
            else
                SetVehicleFixed(vehicle)
                SetVehicleDeformationFixed(vehicle)
                SetVehicleUndriveable(vehicle, false)
                SetVehicleDirtLevel(vehicle, 0.0)

                MS.Notify('Fahrzeug repariert.', 'success')
            end

            SetVehicleDoorShut(vehicle, 4, false)

            -- Neuen Zustand melden.
            local plateNow = GetVehicleNumberPlateText(vehicle):gsub('%s+$', '')
            local fuel = exports['moonshine-vehicles']:GetFuel(plateNow)

            if fuel then
                TriggerServerEvent('vehicles:server:report', plateNow, fuel,
                    GetVehicleEngineHealth(vehicle), GetVehicleBodyHealth(vehicle))
            end
        end

        repairing = false
    end)
end)

--- Reparaturkit benutzen.
RegisterNetEvent('services:client:useKit', function(slot)
    local vehicle = targetVehicle()

    if not vehicle then
        MS.Notify('Stell dich neben ein Fahrzeug.', 'error')
        return
    end

    local engine, body = condition(vehicle)
    if engine >= 100 and body >= 100 then
        MS.Notify('Das Fahrzeug ist in Ordnung.', 'info')
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+$', '')
    TriggerServerEvent('services:server:kitUsed', slot, plate)
end)

--- Oeffnet die Werkstatt.
function Services.OpenWorkshop(shop)
    local vehicle = targetVehicle()

    if not vehicle then
        MS.Notify('Fahr ein Fahrzeug in die Werkstatt.', 'error')
        return
    end

    local engine, body = condition(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+$', '')

    MS.TriggerServerCallback('services:repairQuote', function(quote)
        if not quote then return end

        Services.Open('repair', {
            label    = shop.label,
            plate    = plate,
            engine   = engine,
            body     = body,
            price    = quote.price,
            discount = quote.discount,
            balance  = quote.balance,
        })
    end, engine, body)
end

--- Marker an den Werkstaetten.
CreateThread(function()
    while true do
        local wait = 900

        if ServiceConfig.Repair.enabled then
            local coords = GetEntityCoords(PlayerPedId())

            for _, shop in ipairs(Services.Workshops) do
                local distance = #(coords - shop.coords)

                if distance < 30.0 then
                    wait = 0

                    DrawMarker(36, shop.coords.x, shop.coords.y, shop.coords.z + 0.8,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.9, 0.9, 0.9,
                        106, 169, 224, 150, false, true, 2, false, nil, nil, false)

                    if distance <= ServiceConfig.Range + 4.0 and not repairing then
                        MS.DrawText3D(shop.coords + vector3(0.0, 0.0, 1.2),
                            ('~b~E~s~  %s'):format(shop.label), 0.4)

                        if IsControlJustReleased(0, 38) then
                            Services.OpenWorkshop(shop)
                        end
                    end
                end
            end
        end

        Wait(wait)
    end
end)
