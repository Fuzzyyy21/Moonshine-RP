--- Der Taetowierer: stechen, entfernen, bezahlen.
---
--- Taetowierungen laufen bewusst nicht ueber den Editor. Was Geld gekostet
--- hat, darf nicht in einem eingesendeten Aussehen stehen - sonst taetowiert
--- sich ein manipulierter Client umsonst. Der Server fuehrt die Liste, der
--- Client bekommt sie nur zu sehen.

--- Wer gerade beim Taetowierer steht: [source] = shopId
local atShop = {}

local function findTattooShop(id)
    for _, shop in ipairs(AppearanceConfig.TattooShops) do
        if shop.id == id then return shop end
    end

    return nil
end

--- Steht der Spieler bei diesem Studio?
local function atTattooShop(source)
    local shop = findTattooShop(atShop[source])
    if not shop then return nil end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end

    if #(GetEntityCoords(ped) - shop.coords) > AppearanceConfig.Range + 3.0 then
        return nil
    end

    return shop
end

--- Klasse des Spielers, falls moonshine-mystic laeuft.
local function raceOf(source)
    local race = nil
    pcall(function() race = exports['moonshine-mystic']:GetRace(source) end)

    return race
end

--- Die Liste fuer die Oberflaeche: was es gibt, was er traegt, was es kostet.
local function payload(source, player, shop)
    local race = raceOf(source)
    local getragen = Appearance.SanitizeTattoos((player.appearance or {}).tattoos)

    local motive = {}

    for _, entry in ipairs(Appearance.Tattoos) do
        -- Fremde Klassenmale tauchen gar nicht erst auf. Wer nicht erweckt
        -- ist, sieht ueberhaupt keines.
        --
        -- Was schon auf der Haut ist, steht aber immer in der Liste: nach
        -- einem Klassenwechsel muss das alte Mal wieder wegzubekommen sein.
        local getragenesMal = entry.race and Appearance.HasTattoo(getragen, entry.id)

        if not entry.race or entry.race == race or getragenesMal then
            motive[#motive + 1] = {
                id       = entry.id,
                label    = entry.label,
                zone     = entry.zone,
                mal      = entry.race ~= nil,
                preis    = Appearance.TattooPrice(entry.id),
                getragen = Appearance.HasTattoo(getragen, entry.id),
            }
        end
    end

    return {
        label   = shop.label,
        zonen   = Appearance.TattooZones,
        motive  = motive,
        getragen = getragen,
        balance = player:GetMoney(AppearanceConfig.Prices.account),
        entfernen = AppearanceConfig.Prices.tattooEntfernen,
        gender  = player.gender,
    }
end

--- Schreibt die Liste zurueck und laesst sie am Ped erscheinen.
local function apply(source, player, tattoos)
    local appearance = player.appearance or Appearance.Default(player.gender)

    appearance.tattoos = Appearance.SanitizeTattoos(tattoos)
    player.appearance = appearance
    player:Save()

    TriggerClientEvent('appearance:client:apply', source, appearance)
    TriggerEvent('appearance:server:changed', source)
end

-- Studio oeffnen -----------------------------------------------------------------------

RegisterNetEvent('appearance:server:openTattoo', function(shopId)
    local source = source
    if not MS.RateLimit(source, 'appearance:tattooOpen', 8, 10) then return end

    local player = MS.GetPlayer(source)
    local shop = findTattooShop(shopId)
    if not player or not shop then return end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - shop.coords) > AppearanceConfig.Range + 3.0 then return end

    atShop[source] = shopId

    TriggerClientEvent('appearance:client:openTattoo', source, payload(source, player, shop))
end)

RegisterNetEvent('appearance:server:closeTattoo', function()
    atShop[source] = nil
end)

-- Stechen -------------------------------------------------------------------------------

RegisterNetEvent('appearance:server:buyTattoo', function(id)
    local source = source
    if not MS.RateLimit(source, 'appearance:tattooBuy', 15, 20) then return end

    local player = MS.GetPlayer(source)
    local shop = atTattooShop(source)

    if not player or not shop then
        if player then player:Notify('Du stehst nicht beim Taetowierer.', 'error') end
        return
    end

    local entry = Appearance.GetTattoo(id)
    if not entry then return end

    -- Klassenmale nur fuer die eigene Klasse.
    if entry.race and entry.race ~= raceOf(source) then
        player:Notify('Dieses Mal gehoert nicht zu deiner Klasse.', 'error')
        return
    end

    local getragen = Appearance.SanitizeTattoos((player.appearance or {}).tattoos)

    if Appearance.HasTattoo(getragen, id) then
        player:Notify('Das traegst du bereits.', 'info')
        return
    end

    local preis = Appearance.TattooPrice(id)

    if preis > 0 and not player:RemoveMoney(preis,
        AppearanceConfig.Prices.account, 'taetowierung') then

        player:Notify(('Das kostet %s.'):format(MS.Utils.FormatMoney(preis)), 'error')
        return
    end

    getragen[#getragen + 1] = id
    apply(source, player, getragen)

    player:Notify(('"%s" gestochen fuer %s.'):format(
        entry.label, MS.Utils.FormatMoney(preis)), 'success', 8000)

    TriggerClientEvent('appearance:client:openTattoo', source,
        payload(source, player, shop))

    TriggerEvent('appearance:server:tattooed', source, id)
end)

-- Entfernen -------------------------------------------------------------------------------

RegisterNetEvent('appearance:server:removeTattoo', function(id)
    local source = source
    if not MS.RateLimit(source, 'appearance:tattooRemove', 15, 20) then return end

    local player = MS.GetPlayer(source)
    local shop = atTattooShop(source)
    if not player or not shop then return end

    local entry = Appearance.GetTattoo(id)
    if not entry then return end

    local getragen = Appearance.SanitizeTattoos((player.appearance or {}).tattoos)

    if not Appearance.HasTattoo(getragen, id) then return end

    local preis = math.floor(Appearance.TattooPrice(id)
        * (AppearanceConfig.Prices.tattooEntfernen or 1))

    if preis > 0 and not player:RemoveMoney(preis,
        AppearanceConfig.Prices.account, 'tattooentfernung') then

        player:Notify(('Wegmachen kostet %s.'):format(
            MS.Utils.FormatMoney(preis)), 'error')
        return
    end

    local rest = {}
    for _, vorhanden in ipairs(getragen) do
        if vorhanden ~= id then rest[#rest + 1] = vorhanden end
    end

    apply(source, player, rest)

    player:Notify(('"%s" entfernt fuer %s.'):format(
        entry.label, MS.Utils.FormatMoney(preis)), 'success', 8000)

    TriggerClientEvent('appearance:client:openTattoo', source,
        payload(source, player, shop))
end)

AddEventHandler('playerDropped', function()
    atShop[source] = nil
end)

-- Schnittstelle ------------------------------------------------------------------------------

exports('GetTattoos', function(source)
    local player = MS.GetPlayer(source)
    if not player then return {} end

    return Appearance.SanitizeTattoos((player.appearance or {}).tattoos)
end)

--- Setzt ein Motiv ohne Bezahlung (fuer Belohnungen und Adminwerkzeuge).
exports('GiveTattoo', function(source, id)
    local player = MS.GetPlayer(source)
    if not player or not Appearance.GetTattoo(id) then return false end

    local getragen = Appearance.SanitizeTattoos((player.appearance or {}).tattoos)
    if Appearance.HasTattoo(getragen, id) then return true end

    getragen[#getragen + 1] = id
    apply(source, player, getragen)

    return true
end)

exports('ClearTattoos', function(source)
    local player = MS.GetPlayer(source)
    if not player then return false end

    apply(source, player, {})
    return true
end)

-- Commands -------------------------------------------------------------------------------------

RegisterCommand('tattoos', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local getragen = Appearance.SanitizeTattoos((player.appearance or {}).tattoos)

    if #getragen == 0 then
        player:Notify('Du traegst keine Taetowierungen.', 'info')
        return
    end

    local teile = {}
    for _, id in ipairs(getragen) do
        local entry = Appearance.GetTattoo(id)
        teile[#teile + 1] = entry and entry.label or id
    end

    player:Notify(table.concat(teile, ' · '), 'info', 12000)
end, false)

RegisterCommand('gibtattoo', function(source, args)
    local player = source > 0 and MS.GetPlayer(source) or nil
    if source > 0 and (not player or (player.adminLevel or 0) < 3) then return end

    local target = MS.GetPlayer(tonumber(args[1]) or -1)
    local entry = Appearance.GetTattoo(args[2] or '')

    if not target or not entry then
        print('Verwendung: /gibtattoo [id] [motiv]')
        return
    end

    local getragen = Appearance.SanitizeTattoos((target.appearance or {}).tattoos)

    if not Appearance.HasTattoo(getragen, entry.id) then
        getragen[#getragen + 1] = entry.id
        apply(target.source, target, getragen)
    end

    target:Notify(('"%s" wurde dir gestochen.'):format(entry.label), 'success')
end, false)
