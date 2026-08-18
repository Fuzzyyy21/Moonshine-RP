--- Steinhaendler: NPCs, die Runen- und Seelensteine verkaufen.

local MS = exports['moonshine-core']:GetCoreObject()

local spawnedPeds = {}
local merchantOpen = false

-- NPCs -----------------------------------------------------------------------

local function spawnMerchants()
    local model = joaat(MysticConfig.Merchant.model)

    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(model) then return end

    for index, entry in ipairs(MysticConfig.Merchant.peds) do
        local coords = entry.coords
        local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)

        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetPedDiesWhenInjured(ped, false)
        SetPedCanRagdoll(ped, false)
        SetPedDefaultComponentVariation(ped)

        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_SMOKING', 0, true)
        spawnedPeds[index] = ped
    end

    SetModelAsNoLongerNeeded(model)
end

local function createBlips()
    local blip = MysticConfig.Merchant.blip
    if not blip.enabled then return end

    for _, entry in ipairs(MysticConfig.Merchant.peds) do
        local handle = AddBlipForCoord(entry.coords.x, entry.coords.y, entry.coords.z)
        SetBlipSprite(handle, blip.sprite)
        SetBlipColour(handle, blip.color)
        SetBlipScale(handle, blip.scale)
        SetBlipAsShortRange(handle, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(blip.label)
        EndTextCommandSetBlipName(handle)
    end
end

CreateThread(function()
    if not MysticConfig.Merchant.enabled then return end

    createBlips()
    spawnMerchants()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then DeletePed(ped) end
    end
end)

-- Oberflaeche ----------------------------------------------------------------

RegisterNetEvent('mystic:client:openMerchant', function(payload)
    merchantOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'mysticMerchant', data = payload })
end)

RegisterNetEvent('mystic:client:merchantUpdate', function(data)
    if not merchantOpen then return end
    SendNUIMessage({ action = 'mysticMerchantUpdate', data = data })
end)

local function closeMerchant()
    if not merchantOpen then return end

    merchantOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'mysticMerchantClose' })
end

RegisterNUICallback('mysticMerchantClose', function(_, cb)
    closeMerchant()
    cb('ok')
end)

RegisterNUICallback('mysticBuyStone', function(data, cb)
    TriggerServerEvent('mystic:server:buyStone', data.item, data.amount)
    cb('ok')
end)

-- Interaktion ----------------------------------------------------------------

CreateThread(function()
    if not MysticConfig.Merchant.enabled then return end

    while true do
        local sleep = 900

        if MS.IsPlayerLoaded and not merchantOpen then
            local coords = GetEntityCoords(PlayerPedId())

            for _, entry in ipairs(MysticConfig.Merchant.peds) do
                local distance = #(coords - vector3(entry.coords.x, entry.coords.y, entry.coords.z))

                if distance < 12.0 then
                    sleep = 0

                    if distance < 2.2 then
                        MS.DrawText3D(vector3(entry.coords.x, entry.coords.y, entry.coords.z + 1.0),
                            'Steinhaendler')
                        MS.DrawHelpText('Druecke ~INPUT_CONTEXT~ um Steine zu kaufen')

                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('mystic:server:requestMerchant')
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
