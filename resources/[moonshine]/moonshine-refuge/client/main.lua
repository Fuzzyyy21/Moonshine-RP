--- Zufluchtsorte: Blips, Marker, Oberflaeche.

local MS = exports['moonshine-core']:GetCoreObject()

local offen = false
local zustand = {}        -- [placeId] = frei?
local eigener = nil       -- Id des eigenen Ortes
local blips = {}

-- Blips ------------------------------------------------------------------------

local function clearBlips()
    for _, blip in pairs(blips) do RemoveBlip(blip) end
    blips = {}
end

local function drawBlips()
    clearBlips()

    for _, place in ipairs(Refuge.Places) do
        local eigen = eigener == place.id
        local config = eigen and RefugeConfig.Blip.eigener or RefugeConfig.Blip.frei

        -- Fremde Orte bekommen keinen Blip: wo jemand anders wohnt, geht
        -- niemanden etwas an.
        local zeigen = config.enabled and (eigen or zustand[place.id] == true)

        if zeigen then
            local blip = AddBlipForCoord(place.zutritt.x, place.zutritt.y,
                place.zutritt.z)

            SetBlipSprite(blip, config.sprite)
            SetBlipColour(blip, config.colour)
            SetBlipScale(blip, config.scale)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(eigen and 'Deine Zuflucht'
                or ('%s (frei)'):format(place.label))
            EndTextCommandSetBlipName(blip)

            blips[#blips + 1] = blip
        end
    end
end

RegisterNetEvent('refuge:client:overview', function(liste, meiner)
    zustand = {}
    for _, entry in ipairs(liste or {}) do zustand[entry.id] = entry.frei end

    eigener = meiner
    drawBlips()
end)

-- Oberflaeche ---------------------------------------------------------------------

local function close()
    if not offen then return end

    offen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'refuge:close' })
    TriggerEvent('moonshine:client:nuiOpen', false)
end

RegisterNetEvent('refuge:client:open', function(payload)
    if not offen then
        offen = true
        SetNuiFocus(true, true)
        TriggerEvent('moonshine:client:nuiOpen', true)
    end

    SendNUIMessage({ action = 'refuge:open', data = payload })
end)

RegisterNetEvent('refuge:client:close', function() close() end)

RegisterNetEvent('refuge:client:stash', function(payload)
    SendNUIMessage({ action = 'refuge:stash', data = payload })
end)

-- NUI ------------------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('claim', function(data, cb)
    TriggerServerEvent('refuge:server:claim', data.id)
    cb('ok')
end)

RegisterNUICallback('release', function(_, cb)
    TriggerServerEvent('refuge:server:release')
    cb('ok')
end)

RegisterNUICallback('upgrade', function(_, cb)
    TriggerServerEvent('refuge:server:upgrade')
    cb('ok')
end)

RegisterNUICallback('rename', function(data, cb)
    TriggerServerEvent('refuge:server:rename', data.name)
    cb('ok')
end)

RegisterNUICallback('rest', function(_, cb)
    close()
    TriggerServerEvent('refuge:server:rest')
    cb('ok')
end)

RegisterNUICallback('openStash', function(_, cb)
    TriggerServerEvent('refuge:server:stash')
    cb('ok')
end)

RegisterNUICallback('put', function(data, cb)
    TriggerServerEvent('refuge:server:put', data.slot, data.count)
    cb('ok')
end)

RegisterNUICallback('take', function(data, cb)
    TriggerServerEvent('refuge:server:take', data.index, data.count)
    cb('ok')
end)

--- Das eigene Inventar fuer das Lager.
RegisterNUICallback('requestInventory', function(_, cb)
    local core = exports['moonshine-core']:GetPlayerData()
    local entries = {}

    for _, entry in ipairs(core and core.inventory or {}) do
        if entry and entry.name then
            local item = exports['moonshine-core']:GetItem(entry.name)

            entries[#entries + 1] = {
                slot  = entry.slot,
                name  = entry.name,
                label = item and item.label or entry.name,
                count = entry.count,
            }
        end
    end

    table.sort(entries, function(a, b) return a.label < b.label end)
    cb(entries)
end)

-- Marker -------------------------------------------------------------------------------

CreateThread(function()
    Wait(3000)
    TriggerServerEvent('refuge:server:request')

    while true do
        local wait = 900

        if not offen then
            local coords = GetEntityCoords(PlayerPedId())

            for _, place in ipairs(Refuge.Places) do
                local distance = #(coords - place.zutritt)

                if distance < 25.0 then
                    wait = 0

                    local eigen = eigener == place.id
                    local frei = zustand[place.id] == true

                    -- Fremde Orte bekommen keinen Marker.
                    if eigen or frei then
                        local r, g, b = 155, 107, 216
                        if frei and not eigen then r, g, b = 130, 130, 140 end

                        DrawMarker(21, place.zutritt.x, place.zutritt.y,
                            place.zutritt.z + 0.9,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.7, 0.7, 0.7,
                            r, g, b, 140, true, true, 2, false, nil, nil, false)

                        if distance <= RefugeConfig.Range then
                            MS.DrawText3D(place.zutritt + vector3(0.0, 0.0, 1.3),
                                eigen and '~b~E~s~  Deine Zuflucht'
                                or ('~b~E~s~  %s'):format(place.label), 0.42)

                            if IsControlJustReleased(0, 38) then
                                TriggerServerEvent('refuge:server:open', place.id)
                            end
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
        if offen then
            if IsControlJustReleased(0, 322) then close() end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    clearBlips()
    if offen then SetNuiFocus(false, false) end
end)
