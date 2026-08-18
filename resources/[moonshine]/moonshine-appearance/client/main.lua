--- Laeden, Friseure, Umkleiden und die Oberflaeche.

local MS = exports['moonshine-core']:GetCoreObject()

local isOpen = false
local mode = 'shop'
local shopId = nil

-- Oberflaeche -------------------------------------------------------------------

local function close(restore)
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'appearance:close' })

    Appearance.StopEditor(restore == true)
end

RegisterNetEvent('appearance:client:open', function(payload)
    if isOpen then return end

    isOpen = true
    mode = payload.kind or 'shop'
    shopId = payload.id

    Appearance.Apply(payload.appearance)
    Appearance.StartEditor()

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'appearance:open', data = payload })
end)

--- Der allererste Charakter kommt ohne Laden in den Editor.
RegisterNetEvent('appearance:client:firstTime', function(payload)
    if isOpen then return end

    isOpen = true
    mode = 'ersteErstellung'

    Appearance.Apply(payload.appearance)
    Appearance.StartEditor()

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'appearance:open', data = {
        kind       = 'ersteErstellung',
        label      = 'Wer bist du?',
        categories = { 'kopf', 'makeup', 'koerper', 'kleidung', 'accessoires' },
        gender     = payload.gender,
        appearance = payload.appearance,
        outfits    = {},
        maxOutfits = 0,
        prices     = { kleidung = 0, accessoires = 0, outfitSlot = 0 },
        balance    = 0,
        data       = payload.data,
    } })
end)

RegisterNetEvent('appearance:client:outfits', function(rows)
    SendNUIMessage({ action = 'appearance:outfits', data = rows or {} })
end)

RegisterNetEvent('appearance:client:bought', function()
    close(false)
end)

RegisterNetEvent('appearance:client:buyFailed', function()
    SendNUIMessage({ action = 'appearance:buyFailed' })
end)

-- NUI ------------------------------------------------------------------------------

--- Setzt ein einzelnes Teil und meldet die Anzahl der Varianten zurueck.
RegisterNUICallback('setComponent', function(data, cb)
    local ped = PlayerPedId()
    local id = tonumber(data.id) or 0

    SetPedComponentVariation(ped, id, tonumber(data.drawable) or 0,
        tonumber(data.texture) or 0, 0)

    local drawables, textures = Appearance.CountComponent(id, tonumber(data.drawable) or 0)
    cb({ drawables = drawables, textures = textures })
end)

RegisterNUICallback('setProp', function(data, cb)
    local ped = PlayerPedId()
    local id = tonumber(data.id) or 0
    local drawable = tonumber(data.drawable) or -1

    if drawable < 0 then
        ClearPedProp(ped, id)
    else
        SetPedPropIndex(ped, id, drawable, tonumber(data.texture) or 0, true)
    end

    local drawables, textures = Appearance.CountProp(id, math.max(0, drawable))
    cb({ drawables = drawables, textures = textures })
end)

RegisterNUICallback('setOverlay', function(data, cb)
    local ped = PlayerPedId()
    local id = tonumber(data.id) or 0

    SetPedHeadOverlay(ped, id, tonumber(data.index) or 255,
        (tonumber(data.opacity) or 1.0) + 0.0)

    if data.colourType then
        SetPedHeadOverlayColor(ped, id, tonumber(data.colourType) or 0,
            tonumber(data.colour) or 0, tonumber(data.secondColour) or 0)
    end

    cb({ count = Appearance.CountOverlay(id) })
end)

RegisterNUICallback('setFeature', function(data, cb)
    SetPedFaceFeature(PlayerPedId(), tonumber(data.id) or 0,
        (tonumber(data.value) or 0.0) + 0.0)
    cb('ok')
end)

RegisterNUICallback('setHair', function(data, cb)
    local ped = PlayerPedId()

    SetPedComponentVariation(ped, 2, tonumber(data.drawable) or 0,
        tonumber(data.texture) or 0, 0)
    SetPedHairColor(ped, tonumber(data.colour) or 0, tonumber(data.highlight) or 0)

    local drawables = GetNumberOfPedDrawableVariations(ped, 2)
    cb({ drawables = drawables })
end)

RegisterNUICallback('setEyes', function(data, cb)
    SetPedEyeColor(PlayerPedId(), tonumber(data.value) or 0)
    cb('ok')
end)

RegisterNUICallback('setBlend', function(data, cb)
    local blend = data.blend or {}

    SetPedHeadBlendData(PlayerPedId(),
        tonumber(blend.shapeFirst) or 0, tonumber(blend.shapeSecond) or 0,
        tonumber(blend.shapeThird) or 0,
        tonumber(blend.skinFirst) or 0, tonumber(blend.skinSecond) or 0,
        tonumber(blend.skinThird) or 0,
        (tonumber(blend.shapeMix) or 0.5) + 0.0,
        (tonumber(blend.skinMix) or 0.5) + 0.0,
        (tonumber(blend.thirdMix) or 0.0) + 0.0,
        false)

    -- Die Mischung setzt Haare und Auflagen zurueck.
    if Appearance.Current then Appearance.Apply(Appearance.Current) end

    cb('ok')
end)

RegisterNUICallback('view', function(data, cb)
    Appearance.SetView(data.view or 'ganz')
    cb('ok')
end)

--- Zwischenstand merken, damit ein Kameraschwenk nichts verliert.
RegisterNUICallback('sync', function(_, cb)
    Appearance.Current = Appearance.Read()
    cb('ok')
end)

RegisterNUICallback('save', function(data, cb)
    Appearance.Current = Appearance.Read()

    if mode == 'shop' then
        TriggerServerEvent('appearance:server:buy', Appearance.Current, data.changed)
    else
        TriggerServerEvent('appearance:server:save', Appearance.Current)
        close(false)
    end

    cb('ok')
end)

RegisterNUICallback('cancel', function(_, cb)
    TriggerServerEvent('appearance:server:cancel')
    close(true)
    cb('ok')
end)

RegisterNUICallback('saveOutfit', function(data, cb)
    TriggerServerEvent('appearance:server:saveOutfit', data.label,
        Appearance.ReadOutfit())
    cb('ok')
end)

RegisterNUICallback('wearOutfit', function(data, cb)
    TriggerServerEvent('appearance:server:wearOutfit', data.id)
    cb('ok')
end)

RegisterNUICallback('deleteOutfit', function(data, cb)
    TriggerServerEvent('appearance:server:deleteOutfit', data.id)
    cb('ok')
end)

-- Blips ------------------------------------------------------------------------------

CreateThread(function()
    Wait(2000)

    for _, shop in ipairs(AppearanceConfig.Shops) do
        if shop.blip then
            local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
            SetBlipSprite(blip, shop.blip.sprite)
            SetBlipColour(blip, shop.blip.colour)
            SetBlipScale(blip, shop.blip.scale)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(shop.label)
            EndTextCommandSetBlipName(blip)
        end
    end

    if AppearanceConfig.BarberBlip.enabled then
        for _, barber in ipairs(AppearanceConfig.Barbers) do
            local blip = AddBlipForCoord(barber.coords.x, barber.coords.y, barber.coords.z)
            SetBlipSprite(blip, AppearanceConfig.BarberBlip.sprite)
            SetBlipColour(blip, AppearanceConfig.BarberBlip.colour)
            SetBlipScale(blip, AppearanceConfig.BarberBlip.scale)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(barber.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- Marker und Interaktion ------------------------------------------------------------------

CreateThread(function()
    while true do
        local wait = 900

        if not isOpen then
            local coords = GetEntityCoords(PlayerPedId())

            local function point(entry, kind, colour, text)
                local distance = #(coords - entry.coords)
                if distance >= 20.0 then return end

                wait = 0

                DrawMarker(36, entry.coords.x, entry.coords.y, entry.coords.z + 0.8,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.8,
                    colour[1], colour[2], colour[3], 150, false, true, 2,
                    false, nil, nil, false)

                if distance <= AppearanceConfig.Range then
                    MS.DrawText3D(entry.coords + vector3(0.0, 0.0, 1.1), text, 0.4)

                    if IsControlJustReleased(0, 38) then
                        if kind == 'wardrobe' then
                            TriggerServerEvent('appearance:server:open', 'wardrobe')
                        else
                            TriggerServerEvent('appearance:server:open', kind, entry.id)
                        end
                    end
                end
            end

            for _, shop in ipairs(AppearanceConfig.Shops) do
                point(shop, 'shop', { 155, 107, 216 },
                    ('~b~E~s~  %s'):format(shop.label))
            end

            for _, barber in ipairs(AppearanceConfig.Barbers) do
                point(barber, 'barber', { 216, 95, 178 },
                    ('~b~E~s~  %s'):format(barber.label))
            end

            for _, wardrobe in ipairs(AppearanceConfig.Wardrobes) do
                point(wardrobe, 'wardrobe', { 95, 201, 138 },
                    '~b~E~s~  Umkleide')
            end
        end

        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        if isOpen then
            -- ESC bricht ab und stellt das alte Aussehen wieder her.
            if IsControlJustReleased(0, 322) then
                TriggerServerEvent('appearance:server:cancel')
                close(true)
            end

            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if isOpen then SetNuiFocus(false, false) end
    Appearance.StopEditor(false)
end)
