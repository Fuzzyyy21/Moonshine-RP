--- Beispiel fuer die Nutzung der Framework-API auf dem Client.

local MS = exports['moonshine-core']:GetCoreObject()

local shopOpen = false

local function createBlips()
    if not ShopConfig.Blip.enabled then return end

    for _, coords in ipairs(ShopConfig.Locations) do
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, ShopConfig.Blip.sprite)
        SetBlipColour(blip, ShopConfig.Blip.color)
        SetBlipScale(blip, ShopConfig.Blip.scale)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(ShopConfig.Blip.label)
        EndTextCommandSetBlipName(blip)
    end
end

local function buildCatalog()
    local catalog = {}

    for _, entry in ipairs(ShopConfig.Items) do
        local item = MS.GetItem(entry.name)
        if item then
            catalog[#catalog + 1] = {
                name  = entry.name,
                label = item.label,
                price = entry.price,
                description = item.description or '',
            }
        end
    end

    return catalog
end

local function openShop()
    if shopOpen then return end

    shopOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openShop',
        data = {
            items = buildCatalog(),
            money = exports['moonshine-core']:GetMoney(ShopConfig.Account),
        },
    })
end

local function closeShop()
    if not shopOpen then return end

    shopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeShop' })
end

RegisterNUICallback('close', function(_, cb)
    closeShop()
    cb('ok')
end)

RegisterNUICallback('buy', function(data, cb)
    MS.TriggerServerCallback('moonshine-shops:buy', function(success, message, balance)
        MS.Notify(message, success and 'success' or 'error')

        if balance and shopOpen then
            SendNUIMessage({ action = 'updateMoney', data = balance })
        end
    end, data.name, data.count)

    cb('ok')
end)

CreateThread(function()
    createBlips()

    while true do
        local sleep = 800

        if exports['moonshine-core']:IsPlayerLoaded() then
            local coords = GetEntityCoords(PlayerPedId())

            for _, shop in ipairs(ShopConfig.Locations) do
                local distance = #(coords - shop)

                if distance < 15.0 then
                    sleep = 0
                    DrawMarker(2, shop.x, shop.y, shop.z + 0.6, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0,
                        0.25, 0.25, 0.25, 224, 166, 66, 180, false, false, 2, false, nil, nil, false)

                    if distance < 1.6 and not shopOpen then
                        MS.DrawHelpText('Druecke ~INPUT_CONTEXT~ um den Laden zu oeffnen')
                        if IsControlJustReleased(0, 38) then
                            openShop()
                        end
                    elseif distance > 3.0 and shopOpen then
                        closeShop()
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
