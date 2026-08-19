--- Das Taetowierstudio: Vorschau, Auswahl, Kamera.

local MS = exports['moonshine-core']:GetCoreObject()

local offen = false
local vorschau = nil        -- Motiv, das gerade probeweise am Ped klebt.

--- Traegt die eigene Liste plus optional ein Motiv zur Ansicht auf.
local function zeichnen(extra)
    local data = Appearance.Current
    if not data then return end

    local ped = PlayerPedId()
    ClearPedDecorations(ped)

    local gender = IsPedMale(ped) and 'm' or 'w'

    local liste = {}
    for _, id in ipairs(data.tattoos or {}) do liste[#liste + 1] = id end
    if extra and not Appearance.HasTattoo(liste, extra) then
        liste[#liste + 1] = extra
    end

    for _, id in ipairs(liste) do
        local entry = Appearance.GetTattoo(id)
        local overlay = Appearance.TattooOverlay(entry, gender)

        if entry and overlay then
            AddPedDecorationFromHashes(ped,
                GetHashKey(entry.collection), GetHashKey(overlay))
        end
    end
end

--- Welche Kameraansicht zu einer Zone passt.
local ANSICHT = {
    kopf = 'kopf', brust = 'koerper', bauch = 'koerper', ruecken = 'koerper',
    armLinks = 'koerper', armRechts = 'koerper',
    beinLinks = 'beine', beinRechts = 'beine',
}

local function schliessen()
    if not offen then return end

    offen = false
    vorschau = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'tattoo:close' })

    Appearance.StopEditor(false)
    zeichnen(nil)

    TriggerServerEvent('appearance:server:closeTattoo')
end

RegisterNetEvent('appearance:client:openTattoo', function(payload)
    if not offen then
        offen = true
        Appearance.StartEditor()
    end

    vorschau = nil
    zeichnen(nil)

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'tattoo:open', data = payload })
end)

-- NUI ------------------------------------------------------------------------------

RegisterNUICallback('tattooPreview', function(data, cb)
    vorschau = data.id
    zeichnen(vorschau)

    local entry = Appearance.GetTattoo(data.id)
    if entry then Appearance.SetView(ANSICHT[entry.zone] or 'ganz') end

    cb('ok')
end)

RegisterNUICallback('tattooZone', function(data, cb)
    Appearance.SetView(ANSICHT[data.zone] or 'ganz')
    cb('ok')
end)

RegisterNUICallback('tattooBuy', function(data, cb)
    TriggerServerEvent('appearance:server:buyTattoo', data.id)
    cb('ok')
end)

RegisterNUICallback('tattooRemove', function(data, cb)
    TriggerServerEvent('appearance:server:removeTattoo', data.id)
    cb('ok')
end)

RegisterNUICallback('tattooClose', function(_, cb)
    schliessen()
    cb('ok')
end)

-- Blips und Marker ----------------------------------------------------------------------

CreateThread(function()
    Wait(2200)

    if not AppearanceConfig.TattooBlip.enabled then return end

    for _, shop in ipairs(AppearanceConfig.TattooShops) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, AppearanceConfig.TattooBlip.sprite)
        SetBlipColour(blip, AppearanceConfig.TattooBlip.colour)
        SetBlipScale(blip, AppearanceConfig.TattooBlip.scale)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(shop.label)
        EndTextCommandSetBlipName(blip)
    end
end)

CreateThread(function()
    while true do
        local wait = 900

        if not offen then
            local coords = GetEntityCoords(PlayerPedId())

            for _, shop in ipairs(AppearanceConfig.TattooShops) do
                local distance = #(coords - shop.coords)

                if distance < 20.0 then
                    wait = 0

                    DrawMarker(36, shop.coords.x, shop.coords.y, shop.coords.z + 0.8,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.8,
                        200, 60, 60, 150, false, true, 2, false, nil, nil, false)

                    if distance <= AppearanceConfig.Range then
                        MS.DrawText3D(shop.coords + vector3(0.0, 0.0, 1.1),
                            ('~b~E~s~  %s'):format(shop.label), 0.4)

                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('appearance:server:openTattoo', shop.id)
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
            if IsControlJustReleased(0, 322) then schliessen() end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if offen then SetNuiFocus(false, false) end
end)
