--- Marker, Blips und Oberflaeche.

local MS = exports['moonshine-core']:GetCoreObject()

local isOpen = false
local nearest, nearestKind = nil, ''
local owned = nil

-- Blips ------------------------------------------------------------------------

CreateThread(function()
    Wait(1500)

    if VehicleConfig.GarageBlip.enabled then
        for _, garage in ipairs(VehicleConfig.Garages) do
            local blip = AddBlipForCoord(garage.coords.x, garage.coords.y, garage.coords.z)
            SetBlipSprite(blip, VehicleConfig.GarageBlip.sprite)
            SetBlipColour(blip, VehicleConfig.GarageBlip.colour)
            SetBlipScale(blip, VehicleConfig.GarageBlip.scale)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(garage.label)
            EndTextCommandSetBlipName(blip)
        end
    end

    for _, dealer in ipairs(VehicleConfig.Dealers) do
        local config = dealer.blip
        if config then
            local blip = AddBlipForCoord(dealer.coords.x, dealer.coords.y, dealer.coords.z)
            SetBlipSprite(blip, config.sprite)
            SetBlipColour(blip, config.colour)
            SetBlipScale(blip, config.scale)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(dealer.label)
            EndTextCommandSetBlipName(blip)
        end
    end

    if VehicleConfig.Impound.enabled and VehicleConfig.Impound.blip then
        local config = VehicleConfig.Impound.blip
        local coords = VehicleConfig.Impound.coords

        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, config.sprite)
        SetBlipColour(blip, config.colour)
        SetBlipScale(blip, config.scale)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(VehicleConfig.Impound.label)
        EndTextCommandSetBlipName(blip)
    end
end)

-- Oberflaeche --------------------------------------------------------------------

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'vehicles:close' })
end

local function open(mode)
    if isOpen or not nearest then return end

    isOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({ action = 'vehicles:open', mode = mode,
        label = nearest.label or 'Garage' })

    if mode == 'dealer' then
        TriggerServerEvent('vehicles:server:openDealer', nearest.id)
    else
        TriggerServerEvent('vehicles:server:request')
    end
end

RegisterNetEvent('vehicles:client:owned', function(payload)
    owned = payload
    SendNUIMessage({ action = 'vehicles:owned', data = payload })
end)

RegisterNetEvent('vehicles:client:dealer', function(payload)
    SendNUIMessage({ action = 'vehicles:dealer', data = payload })
end)

RegisterNetEvent('vehicles:client:closeUi', function()
    close()
end)

-- NUI ---------------------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('take', function(data, cb)
    TriggerServerEvent('vehicles:server:take', data.id)
    close()
    cb('ok')
end)

RegisterNUICallback('buy', function(data, cb)
    TriggerServerEvent('vehicles:server:buy', data.model, nearest and nearest.id or nil)
    cb('ok')
end)

RegisterNUICallback('sell', function(data, cb)
    TriggerServerEvent('vehicles:server:sell', data.id)
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    TriggerServerEvent('vehicles:server:transfer', data.id, data.target)
    cb('ok')
end)

RegisterNUICallback('giveKey', function(data, cb)
    TriggerServerEvent('vehicles:server:giveKey', data.id, data.target)
    cb('ok')
end)

RegisterNUICallback('clearKeys', function(data, cb)
    TriggerServerEvent('vehicles:server:clearKeys', data.id)
    cb('ok')
end)

RegisterNUICallback('release', function(data, cb)
    TriggerServerEvent('vehicles:server:release', data.id)
    cb('ok')
end)

RegisterNUICallback('store', function(_, cb)
    close()
    Vehicles.StoreCurrent()
    cb('ok')
end)

-- Marker und Naehe ------------------------------------------------------------------

CreateThread(function()
    while true do
        local wait = 700
        local coords = GetEntityCoords(PlayerPedId())
        local found, kind = nil, ''

        local function check(point, pointKind, colour)
            local distance = #(coords - point.coords)

            if distance < 25.0 then
                wait = 0

                DrawMarker(36, point.coords.x, point.coords.y, point.coords.z + 0.6,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.9, 0.9, 0.9,
                    colour[1], colour[2], colour[3], 150, false, true, 2,
                    false, nil, nil, false)

                if distance <= VehicleConfig.Range then
                    found, kind = point, pointKind
                end
            end
        end

        for _, garage in ipairs(VehicleConfig.Garages) do
            check(garage, 'garage', { 95, 201, 138 })
        end

        for _, dealer in ipairs(VehicleConfig.Dealers) do
            check(dealer, 'dealer', { 216, 178, 95 })
        end

        if VehicleConfig.Impound.enabled then
            check(VehicleConfig.Impound, 'impound', { 217, 83, 79 })
        end

        nearest, nearestKind = found, kind

        if found and not isOpen then
            local ped = PlayerPedId()
            local inVehicle = GetVehiclePedIsIn(ped, false) ~= 0

            local text
            if kind == 'dealer' then
                text = ('~b~E~s~  %s'):format(found.label)
            elseif kind == 'impound' then
                text = '~b~E~s~  Verwahrstelle'
            elseif inVehicle then
                text = ('~b~E~s~  Einparken  ~s~/  ~b~G~s~  %s'):format(found.label)
            else
                text = ('~b~E~s~  %s'):format(found.label)
            end

            MS.DrawText3D(found.coords + vector3(0.0, 0.0, 1.0), text, 0.42)

            if IsControlJustReleased(0, 38) then
                if kind == 'garage' and inVehicle then
                    Vehicles.StoreCurrent()
                else
                    open(kind)
                end
            elseif kind == 'garage' and inVehicle and IsControlJustReleased(0, 47) then
                open('garage')
            end
        end

        Wait(wait)
    end
end)

RegisterCommand(VehicleConfig.Command, function()
    if isOpen then
        close()
    elseif nearest then
        open(nearestKind)
    else
        MS.Notify('Du stehst an keiner Garage und keinem Autohaus.', 'error')
    end
end, false)

RegisterCommand('einparken', function()
    Vehicles.StoreCurrent()
end, false)

CreateThread(function()
    while true do
        if isOpen then
            if IsControlJustReleased(0, 322) then close() end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
end)
