--- Auktionshaus: Auktionatoren, Marker und Oberflaeche.

local MS = exports['moonshine-core']:GetCoreObject()

local isOpen = false
local peds = {}
local nearest = nil

-- Auktionatoren ---------------------------------------------------------------

local function spawnPeds()
    for _, entry in ipairs(AuctionConfig.Peds) do
        local model = joaat(entry.model)
        RequestModel(model)

        local tries = 0
        while not HasModelLoaded(model) and tries < 100 do
            Wait(50)
            tries = tries + 1
        end

        if HasModelLoaded(model) then
            local ped = CreatePed(4, model, entry.coords.x, entry.coords.y,
                entry.coords.z - 1.0, entry.coords.w, false, true)

            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            FreezeEntityPosition(ped, true)
            SetPedDiesWhenInjured(ped, false)
            SetPedCanRagdoll(ped, false)
            TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)

            peds[#peds + 1] = ped
            SetModelAsNoLongerNeeded(model)
        end

        if AuctionConfig.Blip.enabled then
            local blip = AddBlipForCoord(entry.coords.x, entry.coords.y, entry.coords.z)
            SetBlipSprite(blip, AuctionConfig.Blip.sprite)
            SetBlipColour(blip, AuctionConfig.Blip.colour)
            SetBlipScale(blip, AuctionConfig.Blip.scale)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(AuctionConfig.Blip.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end

CreateThread(function()
    Wait(2000)
    spawnPeds()
end)

-- Oeffnen und Schliessen --------------------------------------------------------

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'auction:close' })
    TriggerServerEvent('auction:server:close')
end

local function open()
    if isOpen or not nearest then return end

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'auction:open', house = nearest.label })
    TriggerServerEvent('auction:server:open')
end

RegisterNetEvent('auction:client:sync', function(payload)
    SendNUIMessage({ action = 'auction:data', data = payload })
end)

RegisterNetEvent('auction:client:mail', function(entries)
    SendNUIMessage({ action = 'auction:mail', data = entries })
end)

-- NUI ----------------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('create', function(data, cb)
    TriggerServerEvent('auction:server:create', data.slot, data.count,
        data.startPrice, data.buyout, data.hours)
    cb('ok')
end)

RegisterNUICallback('bid', function(data, cb)
    TriggerServerEvent('auction:server:bid', data.id, data.amount)
    cb('ok')
end)

RegisterNUICallback('buyout', function(data, cb)
    TriggerServerEvent('auction:server:buyout', data.id)
    cb('ok')
end)

RegisterNUICallback('cancel', function(data, cb)
    TriggerServerEvent('auction:server:cancel', data.id)
    cb('ok')
end)

RegisterNUICallback('claim', function(data, cb)
    TriggerServerEvent('auction:server:claim', data.id)
    cb('ok')
end)

RegisterNUICallback('claimAll', function(_, cb)
    TriggerServerEvent('auction:server:claimAll')
    cb('ok')
end)

RegisterNUICallback('inventory', function(_, cb)
    MS.TriggerServerCallback('auction:inventory', function(entries)
        cb(entries or {})
    end)
end)

-- Naehe und Marker ------------------------------------------------------------------

CreateThread(function()
    while true do
        local wait = 800
        local coords = GetEntityCoords(PlayerPedId())
        local found = nil

        for _, entry in ipairs(AuctionConfig.Peds) do
            local point = vector3(entry.coords.x, entry.coords.y, entry.coords.z)
            local distance = #(coords - point)

            if distance < 12.0 then
                wait = 0

                if distance <= AuctionConfig.Range then
                    found = entry

                    if not isOpen then
                        MS.DrawText3D(point + vector3(0.0, 0.0, 0.9),
                            '~b~E~s~  Auktionshaus', 0.42)
                    end
                end
            end
        end

        nearest = found

        if found and not isOpen and IsControlJustReleased(0, 38) then
            open()
        end

        Wait(wait)
    end
end)

RegisterCommand(AuctionConfig.Command, function()
    if isOpen then
        close()
    elseif nearest then
        open()
    else
        exports['moonshine-core']:Notify('Du stehst an keinem Auktionshaus.', 'error')
    end
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
    for _, ped in ipairs(peds) do DeletePed(ped) end
end)
