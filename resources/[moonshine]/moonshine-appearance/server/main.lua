--- Aussehen: Speichern, Laeden, Outfits.

MS = MS or exports['moonshine-core']:GetCoreObject()

--- Wer gerade im Editor steht: [source] = { kind, shopId, paid }
local sessions = {}

--- Wie ein Laden heisst und was er kostet.
local function findShop(id)
    for _, shop in ipairs(AppearanceConfig.Shops) do
        if shop.id == id then return shop end
    end
    return nil
end

local function findBarber(id)
    for _, barber in ipairs(AppearanceConfig.Barbers) do
        if barber.id == id then return barber end
    end
    return nil
end

--- Steht der Spieler in Reichweite?
local function near(source, coords)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end

    return #(GetEntityCoords(ped) - coords) <= AppearanceConfig.Range + 3.0
end

-- Speichern ------------------------------------------------------------------

--- Prueft und uebernimmt ein Aussehen.
local function sanitize(input, gender)
    local base = Appearance.Default(gender)
    if type(input) ~= 'table' then return base end

    local function number(value, fallback, min, max)
        local parsed = tonumber(value)
        if not parsed then return fallback end

        if min and parsed < min then parsed = min end
        if max and parsed > max then parsed = max end

        return parsed
    end

    local result = base

    -- Das Modell darf der Client nicht frei bestimmen.
    result.model = base.model

    if type(input.headBlend) == 'table' then
        local blend = input.headBlend
        result.headBlend = {
            shapeFirst  = math.floor(number(blend.shapeFirst, 0, 0, 45)),
            shapeSecond = math.floor(number(blend.shapeSecond, 0, 0, 45)),
            shapeThird  = math.floor(number(blend.shapeThird, 0, 0, 45)),
            skinFirst   = math.floor(number(blend.skinFirst, 0, 0, 45)),
            skinSecond  = math.floor(number(blend.skinSecond, 0, 0, 45)),
            skinThird   = math.floor(number(blend.skinThird, 0, 0, 45)),
            shapeMix    = number(blend.shapeMix, 0.5, 0.0, 1.0),
            skinMix     = number(blend.skinMix, 0.5, 0.0, 1.0),
            thirdMix    = number(blend.thirdMix, 0.0, 0.0, 1.0),
        }
    end

    if type(input.features) == 'table' then
        for _, feature in ipairs(Appearance.Features) do
            local key = tostring(feature.id)
            result.features[key] = number(input.features[key], 0.0, -1.0, 1.0)
        end
    end

    if type(input.overlays) == 'table' then
        for _, overlay in ipairs(Appearance.Overlays) do
            local key = tostring(overlay.id)
            local entry = input.overlays[key]

            if type(entry) == 'table' then
                result.overlays[key] = {
                    index        = math.floor(number(entry.index, 255, 0, 255)),
                    opacity      = number(entry.opacity, 1.0, 0.0, 1.0),
                    colour       = math.floor(number(entry.colour, 0, 0, 63)),
                    secondColour = math.floor(number(entry.secondColour, 0, 0, 63)),
                }
            end
        end
    end

    if type(input.hair) == 'table' then
        result.hair = {
            drawable  = math.floor(number(input.hair.drawable, 0, 0, 200)),
            texture   = math.floor(number(input.hair.texture, 0, 0, 60)),
            colour    = math.floor(number(input.hair.colour, 1, 0, Appearance.HairColours)),
            highlight = math.floor(number(input.hair.highlight, 1, 0, Appearance.HairColours)),
        }
    end

    result.eyeColour = math.floor(number(input.eyeColour, 0, 0, Appearance.EyeColours))

    if type(input.components) == 'table' then
        for _, component in ipairs(Appearance.Components) do
            local key = tostring(component.id)
            local entry = input.components[key]

            if type(entry) == 'table' then
                result.components[key] = {
                    drawable = math.floor(number(entry.drawable, 0, 0, 400)),
                    texture  = math.floor(number(entry.texture, 0, 0, 60)),
                }
            end
        end
    end

    if type(input.props) == 'table' then
        for _, prop in ipairs(Appearance.Props) do
            local key = tostring(prop.id)
            local entry = input.props[key]

            if type(entry) == 'table' then
                result.props[key] = {
                    drawable = math.floor(number(entry.drawable, -1, -1, 400)),
                    texture  = math.floor(number(entry.texture, 0, 0, 60)),
                }
            end
        end
    end

    return result
end

--- Schreibt das Aussehen in den Charakter.
local function store(source, appearance)
    local player = MS.GetPlayer(source)
    if not player then return false end

    player.appearance = sanitize(appearance, player.gender)
    player:Save()

    return true
end

RegisterNetEvent('appearance:server:save', function(appearance)
    local source = source
    if not MS.RateLimit(source, 'appearance:save', 10, 10) then return end

    local player = MS.GetPlayer(source)
    if not player then return end

    local session = sessions[source]

    -- Ausserhalb einer Sitzung darf niemand einfach speichern.
    if not session then
        player:Notify('Du bist an keinem Laden.', 'error')
        return
    end

    if not store(source, appearance) then return end

    sessions[source] = nil
    player:Notify('Aussehen gespeichert.', 'success')

    TriggerEvent('appearance:server:changed', source)
end)

--- Der Editor wird abgebrochen: nichts speichern.
RegisterNetEvent('appearance:server:cancel', function()
    sessions[source] = nil
end)

-- Editor oeffnen ---------------------------------------------------------------------

--- Zahlt die Sitzung und gibt den Editor frei.
---@param kind string 'shop' | 'barber' | 'wardrobe' | 'ersteErstellung'
local function openEditor(source, kind, id)
    local player = MS.GetPlayer(source)
    if not player then return end

    local price, categories, label = 0, nil, 'Editor'

    if kind == 'shop' then
        local shop = findShop(id)
        if not shop or not near(source, shop.coords) then return end

        label = shop.label
        categories = shop.categories

        -- Bezahlt wird beim Speichern, nicht beim Betreten - man soll
        -- ausprobieren duerfen.
        price = 0

        sessions[source] = { kind = kind, id = id, tier = shop.tier }

    elseif kind == 'barber' then
        local barber = findBarber(id)
        if not barber or not near(source, barber.coords) then return end

        price = AppearanceConfig.Prices.friseur
        label = barber.label
        categories = { 'kopf', 'makeup' }

        if not player:RemoveMoney(price, AppearanceConfig.Prices.account, 'friseur') then
            player:Notify(('Der Friseur kostet %s.'):format(
                MS.Utils.FormatMoney(price)), 'error')
            return
        end

        sessions[source] = { kind = kind, id = id, paid = true }

    elseif kind == 'wardrobe' then
        -- Umkleide: nur eigene Outfits anlegen, nichts kaufen.
        sessions[source] = { kind = kind }
        label = 'Umkleide'
        categories = { 'kleidung', 'accessoires' }

    else
        return
    end

    local outfits = {}
    for _, row in ipairs(Appearance.DB.LoadOutfits(player.charId)) do
        outfits[#outfits + 1] = { id = row.id, label = row.label }
    end

    TriggerClientEvent('appearance:client:open', source, {
        kind       = kind,
        label      = label,
        categories = categories,
        gender     = player.gender,
        appearance = player.appearance,
        outfits    = outfits,
        maxOutfits = AppearanceConfig.MaxOutfits,
        prices     = {
            kleidung    = kind == 'shop'
                and Appearance.GetPrice('kleidung', sessions[source].tier) or 0,
            accessoires = kind == 'shop'
                and Appearance.GetPrice('accessoires', sessions[source].tier) or 0,
            outfitSlot  = AppearanceConfig.Prices.outfitSlot,
        },
        balance    = player:GetMoney(AppearanceConfig.Prices.account),
        data       = {
            components = Appearance.Components,
            props      = Appearance.Props,
            overlays   = Appearance.Overlays,
            features   = Appearance.Features,
            parents    = Appearance.Parents,
            hairColours = Appearance.HairColours,
            eyeColours  = Appearance.EyeColours,
        },
    })
end

RegisterNetEvent('appearance:server:open', function(kind, id)
    local source = source
    if not MS.RateLimit(source, 'appearance:open', 8, 10) then return end
    if type(kind) ~= 'string' then return end

    openEditor(source, kind, id)
end)

--- Kaufen: der Client meldet, wie viele Teile er geaendert hat.
RegisterNetEvent('appearance:server:buy', function(appearance, changed)
    local source = source
    if not MS.RateLimit(source, 'appearance:buy', 10, 10) then return end

    local player = MS.GetPlayer(source)
    local session = sessions[source]
    if not player or not session or session.kind ~= 'shop' then return end

    local shop = findShop(session.id)
    if not shop or not near(source, shop.coords) then return end

    changed = type(changed) == 'table' and changed or {}

    local kleidung = math.max(0, math.floor(tonumber(changed.kleidung) or 0))
    local accessoires = math.max(0, math.floor(tonumber(changed.accessoires) or 0))

    -- Mehr als es Teile gibt, kann niemand geaendert haben.
    kleidung = math.min(kleidung, #Appearance.Components + 2)
    accessoires = math.min(accessoires, #Appearance.Props + #Appearance.Components)

    local total = kleidung * Appearance.GetPrice('kleidung', shop.tier)
        + accessoires * Appearance.GetPrice('accessoires', shop.tier)

    if total > 0 then
        if not player:RemoveMoney(total, AppearanceConfig.Prices.account, 'kleidung') then
            player:Notify(('Das kostet %s.'):format(MS.Utils.FormatMoney(total)), 'error')
            TriggerClientEvent('appearance:client:buyFailed', source)
            return
        end
    end

    if not store(source, appearance) then return end

    sessions[source] = nil

    player:Notify(total > 0
        and ('Gekauft fuer %s.'):format(MS.Utils.FormatMoney(total))
        or 'Aussehen gespeichert.', 'success')

    TriggerClientEvent('appearance:client:bought', source)
    TriggerEvent('appearance:server:changed', source)
end)

-- Outfits ----------------------------------------------------------------------------

RegisterNetEvent('appearance:server:saveOutfit', function(label, outfit)
    local source = source
    if not MS.RateLimit(source, 'appearance:outfit', 10, 10) then return end

    local player = MS.GetPlayer(source)
    if not player or not sessions[source] then return end

    label = tostring(label or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 32)
    if label == '' then label = 'Outfit' end

    if Appearance.DB.CountOutfits(player.charId) >= AppearanceConfig.MaxOutfits then
        player:Notify(('Mehr als %d Outfits gehen nicht.'):format(
            AppearanceConfig.MaxOutfits), 'error')
        return
    end

    local price = AppearanceConfig.Prices.outfitSlot

    if price > 0 and not player:RemoveMoney(price, AppearanceConfig.Prices.account,
        'outfit') then
        player:Notify(('Ein Outfit-Platz kostet %s.'):format(
            MS.Utils.FormatMoney(price)), 'error')
        return
    end

    -- Nur Kleidung sichern, nicht das Gesicht.
    local clean = sanitize(outfit, player.gender)

    local id = Appearance.DB.SaveOutfit(player.charId, label, {
        components = clean.components,
        props      = clean.props,
    })

    if not id then return end

    player:Notify(('Outfit "%s" gespeichert.'):format(label), 'success')

    TriggerClientEvent('appearance:client:outfits', source,
        Appearance.DB.LoadOutfits(player.charId))
end)

RegisterNetEvent('appearance:server:wearOutfit', function(outfitId)
    local source = source
    if not MS.RateLimit(source, 'appearance:wear', 15, 10) then return end

    local player = MS.GetPlayer(source)
    if not player then return end

    local row = Appearance.DB.GetOutfit(tonumber(outfitId) or -1, player.charId)
    if not row then return end

    local ok, outfit = pcall(json.decode, row.data)
    if not ok or type(outfit) ~= 'table' then return end

    -- In das gespeicherte Aussehen uebernehmen.
    local appearance = player.appearance or Appearance.Default(player.gender)

    appearance.components = outfit.components or appearance.components
    appearance.props = outfit.props or appearance.props

    player.appearance = appearance
    player:Save()

    TriggerClientEvent('appearance:client:apply', source, appearance)
    player:Notify(('Outfit "%s" angezogen.'):format(row.label), 'success')
end)

RegisterNetEvent('appearance:server:deleteOutfit', function(outfitId)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    Appearance.DB.DeleteOutfit(tonumber(outfitId) or -1, player.charId)

    TriggerClientEvent('appearance:client:outfits', source,
        Appearance.DB.LoadOutfits(player.charId))
end)

RegisterNetEvent('appearance:server:requestOutfits', function()
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    TriggerClientEvent('appearance:client:outfits', source,
        Appearance.DB.LoadOutfits(player.charId))
end)

-- Lebenszyklus ---------------------------------------------------------------------------

AddEventHandler('moonshine:server:playerLoaded', function(source, player)
    CreateThread(function()
        Wait(1500)

        -- Neue Charaktere bekommen ein Standardaussehen und den Editor.
        local fresh = type(player.appearance) ~= 'table' or not player.appearance.model

        if fresh then
            player.appearance = Appearance.Default(player.gender)
            player:Save()
        end

        TriggerClientEvent('appearance:client:apply', source, player.appearance)

        if fresh then
            Wait(2500)
            sessions[source] = { kind = 'ersteErstellung' }

            TriggerClientEvent('appearance:client:firstTime', source, {
                gender     = player.gender,
                appearance = player.appearance,
                data       = {
                    components = Appearance.Components,
                    props      = Appearance.Props,
                    overlays   = Appearance.Overlays,
                    features   = Appearance.Features,
                    parents    = Appearance.Parents,
                    hairColours = Appearance.HairColours,
                    eyeColours  = Appearance.EyeColours,
                },
            })
        end
    end)
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)

-- API ------------------------------------------------------------------------------------

exports('GetAppearanceObject', function()
    return Appearance
end)

exports('GetAppearance', function(source)
    local player = MS.GetPlayer(source)
    return player and player.appearance or nil
end)

--- Aussehen von aussen setzen (z. B. Uniform durch ein Job-Script).
exports('SetAppearance', function(source, appearance)
    if not store(source, appearance) then return false end

    local player = MS.GetPlayer(source)
    TriggerClientEvent('appearance:client:apply', source, player.appearance)

    return true
end)

--- Nur die Kleidung setzen, Gesicht bleibt.
exports('SetOutfit', function(source, outfit)
    local player = MS.GetPlayer(source)
    if not player or type(outfit) ~= 'table' then return false end

    local appearance = player.appearance or Appearance.Default(player.gender)

    if type(outfit.components) == 'table' then appearance.components = outfit.components end
    if type(outfit.props) == 'table' then appearance.props = outfit.props end

    player.appearance = sanitize(appearance, player.gender)
    player:Save()

    TriggerClientEvent('appearance:client:apply', source, player.appearance)
    return true
end)

-- Commands ----------------------------------------------------------------------------------

RegisterCommand('outfits', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local rows = Appearance.DB.LoadOutfits(player.charId)
    if #rows == 0 then
        player:Notify('Du hast keine Outfits gespeichert.', 'info')
        return
    end

    local parts = {}
    for _, row in ipairs(rows) do parts[#parts + 1] = ('%d: %s'):format(row.id, row.label) end

    player:Notify(table.concat(parts, ' · '), 'info', 12000)
end, false)

RegisterCommand('editor', function(source)
    local player = MS.GetPlayer(source)
    if not player or (player.adminLevel or 0) < 3 then return end

    sessions[source] = { kind = 'wardrobe' }

    TriggerClientEvent('appearance:client:open', source, {
        kind       = 'wardrobe',
        label      = 'Editor (Admin)',
        categories = { 'kleidung', 'accessoires', 'kopf', 'makeup', 'koerper' },
        gender     = player.gender,
        appearance = player.appearance,
        outfits    = {},
        maxOutfits = AppearanceConfig.MaxOutfits,
        prices     = { kleidung = 0, accessoires = 0, outfitSlot = 0 },
        balance    = player:GetMoney(AppearanceConfig.Prices.account),
        data       = {
            components = Appearance.Components,
            props      = Appearance.Props,
            overlays   = Appearance.Overlays,
            features   = Appearance.Features,
            parents    = Appearance.Parents,
            hairColours = Appearance.HairColours,
            eyeColours  = Appearance.EyeColours,
        },
    })
end, false)

print('^2[Aussehen]^7 Editor, Laeden und Friseure geladen.')
