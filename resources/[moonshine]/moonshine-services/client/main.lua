--- Blips, Bank, Schwarzmarkt und die gemeinsame Oberflaeche.

local MS = exports['moonshine-core']:GetCoreObject()

local isOpen = false
local market = nil
local marketBlip = nil
local marketPed = nil

-- Oberflaeche -------------------------------------------------------------------

function Services.Close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'services:close' })
end

--- Oeffnet eine der Oberflaechen.
---@param mode string 'bank' | 'fuel' | 'repair' | 'market'
function Services.Open(mode, payload)
    if isOpen then return end

    isOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({ action = 'services:open', mode = mode, data = payload })
end

RegisterNetEvent('services:client:bank', function(payload)
    if isOpen then
        SendNUIMessage({ action = 'services:data', mode = 'bank', data = payload })
    else
        Services.Open('bank', payload)
    end
end)

RegisterNetEvent('services:client:blackmarket', function(payload)
    if isOpen then
        SendNUIMessage({ action = 'services:data', mode = 'market', data = payload })
    else
        Services.Open('market', payload)
    end
end)

-- NUI ------------------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    Services.Close()
    cb('ok')
end)

RegisterNUICallback('deposit', function(data, cb)
    TriggerServerEvent('services:server:deposit', data.amount)
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    TriggerServerEvent('services:server:withdraw', data.amount)
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    TriggerServerEvent('services:server:transfer', data.target, data.amount)
    cb('ok')
end)

RegisterNUICallback('refuel', function(data, cb)
    TriggerServerEvent('services:server:refuel', data.plate, data.amount)
    Services.Close()
    cb('ok')
end)

RegisterNUICallback('buyCanister', function(data, cb)
    TriggerServerEvent('services:server:buyCanister', data.count)
    cb('ok')
end)

RegisterNUICallback('repair', function(data, cb)
    TriggerServerEvent('services:server:repair', data.plate, data.engine, data.body)
    Services.Close()
    cb('ok')
end)

RegisterNUICallback('marketBuy', function(data, cb)
    TriggerServerEvent('services:server:marketBuy', data.name, data.count)
    cb('ok')
end)

RegisterNUICallback('marketSell', function(data, cb)
    TriggerServerEvent('services:server:marketSell', data.name, data.count)
    cb('ok')
end)

RegisterNUICallback('launder', function(data, cb)
    TriggerServerEvent('services:server:launder', data.amount)
    cb('ok')
end)

-- Blips ---------------------------------------------------------------------------------

CreateThread(function()
    Wait(1500)

    for _, station in ipairs(Services.FuelStations) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 361)
        SetBlipColour(blip, 46)
        SetBlipScale(blip, 0.6)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Tankstelle')
        EndTextCommandSetBlipName(blip)
    end

    for _, shop in ipairs(Services.Workshops) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, 446)
        SetBlipColour(blip, 3)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(shop.label)
        EndTextCommandSetBlipName(blip)
    end

    for _, bank in ipairs(Services.Banks) do
        local blip = AddBlipForCoord(bank.coords.x, bank.coords.y, bank.coords.z)
        SetBlipSprite(blip, 108)
        SetBlipColour(blip, 2)
        SetBlipScale(blip, 0.75)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(bank.label)
        EndTextCommandSetBlipName(blip)
    end
end)

-- Schwarzmarkt -----------------------------------------------------------------------------

RegisterNetEvent('services:client:market', function(payload)
    market = payload

    if marketBlip then
        RemoveBlip(marketBlip)
        marketBlip = nil
    end

    if marketPed and DoesEntityExist(marketPed) then
        DeletePed(marketPed)
        marketPed = nil
    end
end)

--- Der Haendler erscheint erst, wenn man nah genug ist.
CreateThread(function()
    while true do
        local wait = 2000

        if market and ServiceConfig.BlackMarket.enabled then
            local coords = GetEntityCoords(PlayerPedId())
            local target = vector3(market.coords.x, market.coords.y, market.coords.z)
            local distance = #(coords - target)

            if distance < 120.0 then
                wait = 500

                -- Blip nur in der Naehe.
                if not marketBlip then
                    marketBlip = AddBlipForCoord(target.x, target.y, target.z)
                    SetBlipSprite(marketBlip, 500)
                    SetBlipColour(marketBlip, 40)
                    SetBlipScale(marketBlip, 0.7)
                    SetBlipAsShortRange(marketBlip, true)

                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentString('Schwarzmarkt')
                    EndTextCommandSetBlipName(marketBlip)
                end

                -- Haendler erzeugen.
                if distance < 60.0 and (not marketPed or not DoesEntityExist(marketPed)) then
                    local model = joaat('g_m_m_chemwork_01')
                    RequestModel(model)

                    local tries = 0
                    while not HasModelLoaded(model) and tries < 60 do
                        Wait(50)
                        tries = tries + 1
                    end

                    if HasModelLoaded(model) then
                        marketPed = CreatePed(4, model, target.x, target.y, target.z - 1.0,
                            market.heading or 0.0, false, true)

                        SetEntityInvincible(marketPed, true)
                        SetBlockingOfNonTemporaryEvents(marketPed, true)
                        FreezeEntityPosition(marketPed, true)
                        TaskStartScenarioInPlace(marketPed, 'WORLD_HUMAN_SMOKING', 0, true)

                        SetModelAsNoLongerNeeded(model)
                    end
                end

                if distance <= ServiceConfig.Range + 3.0 and not isOpen then
                    wait = 0

                    MS.DrawText3D(target + vector3(0.0, 0.0, 1.1),
                        '~b~E~s~  Schwarzmarkt', 0.42)

                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent('services:server:openMarket')
                    end
                end
            else
                if marketBlip then
                    RemoveBlip(marketBlip)
                    marketBlip = nil
                end

                if marketPed and DoesEntityExist(marketPed) then
                    DeletePed(marketPed)
                    marketPed = nil
                end
            end
        end

        Wait(wait)
    end
end)

-- Bank und Geldautomaten ---------------------------------------------------------------------

CreateThread(function()
    while true do
        local wait = 900

        if ServiceConfig.Bank.enabled then
            local coords = GetEntityCoords(PlayerPedId())

            for _, bank in ipairs(Services.Banks) do
                local distance = #(coords - bank.coords)

                if distance < 20.0 then
                    wait = 0

                    if distance <= ServiceConfig.Range + 2.0 and not isOpen then
                        MS.DrawText3D(bank.coords + vector3(0.0, 0.0, 1.0),
                            ('~b~E~s~  %s'):format(bank.label), 0.4)

                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('services:server:openBank')
                        end
                    end
                end
            end

            for _, atm in ipairs(Services.Atms) do
                local distance = #(coords - atm)

                if distance < 12.0 then
                    wait = 0

                    if distance <= ServiceConfig.Range and not isOpen then
                        MS.DrawText3D(atm + vector3(0.0, 0.0, 0.9),
                            '~b~E~s~  Geldautomat', 0.38)

                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('services:server:openBank')
                        end
                    end
                end
            end
        end

        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        if isOpen then
            if IsControlJustReleased(0, 322) then Services.Close() end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if isOpen then SetNuiFocus(false, false) end
    if marketBlip then RemoveBlip(marketBlip) end
    if marketPed and DoesEntityExist(marketPed) then DeletePed(marketPed) end
end)
