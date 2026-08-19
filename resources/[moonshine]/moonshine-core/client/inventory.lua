--- Inventar-Interface und Bodenitems.

local inventoryOpen = false
local drops = {}

local function buildInventoryPayload()
    local items = {}

    for _, entry in ipairs(MS.PlayerData.inventory or {}) do
        local item = MS.GetItem(entry.name)
        if item then
            items[#items + 1] = {
                slot        = entry.slot,
                name        = entry.name,
                label       = item.label,
                count       = entry.count,
                weight      = item.weight * entry.count,
                usable      = item.usable or false,
                description = item.description or '',
            }
        end
    end

    local weight = 0
    for _, item in ipairs(items) do weight = weight + item.weight end

    return {
        items     = items,
        weight    = weight,
        maxWeight = MS.PlayerData.maxWeight or Config.Inventory.maxWeight,
        maxSlots  = MS.PlayerData.maxSlots or Config.Inventory.maxSlots,
        money     = MS.PlayerData.accounts and MS.PlayerData.accounts.cash or 0,
    }
end

function MS.OpenInventory()
    if not MS.IsPlayerLoaded or inventoryOpen then return end
    if IsEntityDead(PlayerPedId()) then return end

    inventoryOpen = true
    SetNuiFocus(true, true)
    TriggerEvent('moonshine:client:nuiOpen', true)
    SendNUIMessage({ action = 'showInventory', data = true })
    SendNUIMessage({ action = 'setInventory', data = buildInventoryPayload() })
end

function MS.CloseInventory()
    if not inventoryOpen then return end

    inventoryOpen = false
    SetNuiFocus(false, false)
    TriggerEvent('moonshine:client:nuiOpen', false)
    SendNUIMessage({ action = 'showInventory', data = false })
end

RegisterCommand('inventar', function()
    if inventoryOpen then MS.CloseInventory() else MS.OpenInventory() end
end, false)

RegisterKeyMapping('inventar', 'Inventar oeffnen', 'keyboard', Config.Keys.inventory)

RegisterNetEvent('moonshine:client:closeInventory', function()
    MS.CloseInventory()
end)

--- Offenes Inventar aktualisieren, sobald sich die Spielerdaten aendern.
AddEventHandler('moonshine:client:dataChanged', function()
    if inventoryOpen then
        SendNUIMessage({ action = 'setInventory', data = buildInventoryPayload() })
    end
end)

-- NUI-Callbacks --------------------------------------------------------------

RegisterNUICallback('closeInventory', function(_, cb)
    MS.CloseInventory()
    cb('ok')
end)

RegisterNUICallback('useItem', function(data, cb)
    TriggerServerEvent('moonshine:server:useItem', data.slot)
    cb('ok')
end)

RegisterNUICallback('moveItem', function(data, cb)
    TriggerServerEvent('moonshine:server:moveItem', data.fromSlot, data.toSlot)
    cb('ok')
end)

RegisterNUICallback('dropItem', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('moonshine:server:dropItem', data.slot, data.count, {
        x = coords.x, y = coords.y, z = coords.z - 0.9,
    })
    cb('ok')
end)

RegisterNUICallback('giveItem', function(data, cb)
    local target, distance = GetClosestPlayer(5.0)
    if not target then
        MS.Notify('Niemand in der Naehe.', 'error')
        cb('ok')
        return
    end

    if distance > 3.0 then
        MS.Notify('Du bist zu weit entfernt.', 'error')
        cb('ok')
        return
    end

    TriggerServerEvent('moonshine:server:giveItem', GetPlayerServerId(target), data.slot, data.count)
    MS.CloseInventory()
    cb('ok')
end)

-- Bodenitems -----------------------------------------------------------------

RegisterNetEvent('moonshine:client:syncDrops', function(list)
    drops = list or {}
end)

--- Naechster Spieler in Reichweite.
---@return number|nil playerIndex, number distance
function GetClosestPlayer(maxDistance)
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closest, closestDistance = nil, maxDistance or 5.0

    for _, playerIndex in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerIndex)
        if ped ~= myPed and DoesEntityExist(ped) then
            local distance = #(myCoords - GetEntityCoords(ped))
            if distance < closestDistance then
                closest, closestDistance = playerIndex, distance
            end
        end
    end

    return closest, closestDistance
end

CreateThread(function()
    while true do
        local sleep = 1000

        if MS.IsPlayerLoaded and next(drops) then
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance = nil, 2.0

            for id, drop in pairs(drops) do
                local dropCoords = vector3(drop.coords.x, drop.coords.y, drop.coords.z)
                local distance = #(coords - dropCoords)

                if distance < 20.0 then
                    sleep = 0
                    DrawMarker(2, dropCoords.x, dropCoords.y, dropCoords.z + 0.2, 0.0, 0.0, 0.0,
                        180.0, 0.0, 0.0, 0.2, 0.2, 0.2, 235, 190, 60, 180,
                        false, false, 2, false, nil, nil, false)

                    if distance < 2.0 then
                        MS.DrawText3D(dropCoords + vector3(0.0, 0.0, 0.4),
                            ('%dx %s'):format(drop.count, drop.label))

                        if distance < nearestDistance then
                            nearest, nearestDistance = id, distance
                        end
                    end
                end
            end

            if nearest then
                MS.DrawHelpText('Druecke ~INPUT_PICKUP~ zum Aufheben')
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('moonshine:server:pickupDrop', nearest)
                end
            end
        end

        Wait(sleep)
    end
end)
