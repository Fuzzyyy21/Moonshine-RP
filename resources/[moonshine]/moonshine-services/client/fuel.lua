--- Tanken: Zapfsaeulen, Fortschritt, Kanister.

local MS = exports['moonshine-core']:GetCoreObject()

local refuelling = false

--- Tankstand aus moonshine-vehicles holen. Fehlt die Resource, gibt es kein
--- Tanksystem - Bank und Schwarzmarkt laufen trotzdem weiter.
---@return number|nil
function Services.GetFuel(plate)
    local ok, value = pcall(function()
        return exports['moonshine-vehicles']:GetFuel(plate)
    end)

    return ok and value or nil
end

function Services.SetFuel(plate, value)
    return (pcall(function()
        exports['moonshine-vehicles']:SetFuel(plate, value)
    end))
end

--- Das Kanister-Item muss auch der Client kennen (Inventaranzeige).
CreateThread(function()
    local config = ServiceConfig.Fuel.canister

    for _ = 1, 20 do
        local ok = pcall(function()
            exports['moonshine-core']:RegisterItem(config.item, {
                label       = 'Benzinkanister',
                weight      = 5000,
                stack       = true,
                usable      = true,
                description = ('Fuellt etwa %d Prozent in einen Tank.'):format(config.amount),
            })
        end)

        if ok then break end
        Wait(500)
    end
end)

--- Fahrzeug, das gerade an der Zapfsaeule steht.
function Services.NozzleVehicle()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then return vehicle end

    vehicle = GetClosestVehicle(coords.x, coords.y, coords.z,
        ServiceConfig.Fuel.nozzleRange, 0, 71)

    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then return vehicle end
    return nil
end

--- Naechste Zapfsaeule.
function Services.NearestPump()
    local coords = GetEntityCoords(PlayerPedId())

    for _, station in ipairs(Services.FuelStations) do
        for _, pump in ipairs(station.pumps) do
            if #(coords - pump) <= ServiceConfig.Fuel.nozzleRange then
                return station, pump
            end
        end
    end

    return nil, nil
end

--- Der Server hat Sprit freigegeben.
RegisterNetEvent('services:client:fuelGranted', function(plate, amount)
    if refuelling then return end
    refuelling = true

    CreateThread(function()
        local ped = PlayerPedId()

        -- Animation, solange gefuellt wird.
        RequestAnimDict('timetable@gardener@filling_can')
        local tries = 0
        while not HasAnimDictLoaded('timetable@gardener@filling_can') and tries < 40 do
            Wait(50)
            tries = tries + 1
        end

        if HasAnimDictLoaded('timetable@gardener@filling_can') then
            TaskPlayAnim(ped, 'timetable@gardener@filling_can', 'gar_ig_5_filling_can',
                2.0, -2.0, -1, 49, 0, false, false, false)
        end

        local total = math.max(1, math.floor(amount))
        local steps = math.min(total, 20)
        local perStep = total / steps

        for index = 1, steps do
            Wait(math.floor(ServiceConfig.Fuel.speed * (total / steps)))

            local current = Services.GetFuel(plate)
            if current ~= nil then
                Services.SetFuel(plate, math.min(100.0, current + perStep))
            end

            SendNUIMessage({ action = 'services:fuelProgress',
                value = index / steps })
        end

        ClearPedTasks(ped)
        SendNUIMessage({ action = 'services:fuelProgress', value = 0 })

        -- Motor wieder startbar machen.
        local vehicle = Services.NozzleVehicle()
        if vehicle then SetVehicleUndriveable(vehicle, false) end

        refuelling = false
    end)
end)

--- Kanister benutzen.
RegisterNetEvent('services:client:useCanister', function(slot)
    local vehicle = Services.NozzleVehicle()

    if not vehicle then
        MS.Notify('Stell dich neben ein Fahrzeug.', 'error')
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+$', '')
    TriggerServerEvent('services:server:canisterUsed', slot, plate)
end)

--- Marker und Interaktion an den Zapfsaeulen.
CreateThread(function()
    while true do
        local wait = 800

        if ServiceConfig.Fuel.enabled then
            local coords = GetEntityCoords(PlayerPedId())

            for _, station in ipairs(Services.FuelStations) do
                if #(coords - station.coords) < 45.0 then
                    wait = 0

                    for _, pump in ipairs(station.pumps) do
                        local distance = #(coords - pump)

                        if distance < 12.0 then
                            DrawMarker(36, pump.x, pump.y, pump.z + 0.9,
                                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4,
                                216, 178, 95, 150, false, true, 2,
                                false, nil, nil, false)
                        end

                        if distance <= ServiceConfig.Fuel.nozzleRange and not refuelling then
                            MS.DrawText3D(pump + vector3(0.0, 0.0, 1.2),
                                '~b~E~s~  Tanken', 0.4)

                            if IsControlJustReleased(0, 38) then
                                Services.OpenFuel(station)
                            end
                        end
                    end
                end
            end
        end

        Wait(wait)
    end
end)

--- Oeffnet die Tankoberflaeche.
function Services.OpenFuel(station)
    local vehicle = Services.NozzleVehicle()

    if not vehicle then
        MS.Notify('Hier steht kein Fahrzeug.', 'error')
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+$', '')
    local current = Services.GetFuel(plate)

    if current == nil then
        MS.Notify('Dieses Fahrzeug hat keinen verwalteten Tank.', 'error')
        return
    end

    Services.Open('fuel', {
        label   = station.label,
        plate   = plate,
        fuel    = current or 0,
        price   = ServiceConfig.Fuel.price,
        canister = ServiceConfig.Fuel.canister,
        cash    = MS.PlayerData and MS.PlayerData.accounts
            and MS.PlayerData.accounts.cash or 0,
    })
end
