--- Aussehen auf das Ped anwenden und wieder auslesen.

Appearance.Current = nil

--- Setzt ein vollstaendiges Aussehen auf das eigene Ped.
function Appearance.Apply(data)
    if type(data) ~= 'table' then return end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    Appearance.Current = data

    -- Gesichtsmischung
    local blend = data.headBlend
    if type(blend) == 'table' then
        SetPedHeadBlendData(ped,
            blend.shapeFirst or 0, blend.shapeSecond or 0, blend.shapeThird or 0,
            blend.skinFirst or 0, blend.skinSecond or 0, blend.skinThird or 0,
            blend.shapeMix or 0.5, blend.skinMix or 0.5, blend.thirdMix or 0.0,
            false)
    end

    -- Gesichtszuege
    for _, feature in ipairs(Appearance.Features) do
        local value = (data.features or {})[tostring(feature.id)]
        SetPedFaceFeature(ped, feature.id, tonumber(value) or 0.0)
    end

    -- Auflagen
    for _, overlay in ipairs(Appearance.Overlays) do
        local entry = (data.overlays or {})[tostring(overlay.id)]

        if type(entry) == 'table' then
            SetPedHeadOverlay(ped, overlay.id,
                entry.index or 255, (entry.opacity or 1.0) + 0.0)

            if overlay.colourType then
                SetPedHeadOverlayColor(ped, overlay.id, overlay.colourType,
                    entry.colour or 0, entry.secondColour or 0)
            end
        end
    end

    -- Haare
    local hair = data.hair or {}
    SetPedComponentVariation(ped, 2, hair.drawable or 0, hair.texture or 0, 0)
    SetPedHairColor(ped, hair.colour or 0, hair.highlight or 0)

    -- Augen
    SetPedEyeColor(ped, data.eyeColour or 0)

    -- Kleidung
    for _, component in ipairs(Appearance.Components) do
        local entry = (data.components or {})[tostring(component.id)]

        if type(entry) == 'table' then
            SetPedComponentVariation(ped, component.id,
                entry.drawable or 0, entry.texture or 0, 0)
        end
    end

    -- Anbauteile
    for _, prop in ipairs(Appearance.Props) do
        local entry = (data.props or {})[tostring(prop.id)]

        if type(entry) == 'table' then
            if (entry.drawable or -1) < 0 then
                ClearPedProp(ped, prop.id)
            else
                SetPedPropIndex(ped, prop.id, entry.drawable, entry.texture or 0, true)
            end
        end
    end
end

--- Liest das aktuelle Aussehen vom Ped ab.
function Appearance.Read()
    local ped = PlayerPedId()

    local features = {}
    for _, feature in ipairs(Appearance.Features) do
        features[tostring(feature.id)] = Appearance.Current
            and (Appearance.Current.features or {})[tostring(feature.id)] or 0.0
    end

    local overlays = {}
    for _, overlay in ipairs(Appearance.Overlays) do
        local stored = Appearance.Current
            and (Appearance.Current.overlays or {})[tostring(overlay.id)] or {}

        overlays[tostring(overlay.id)] = {
            index        = GetPedHeadOverlayValue(ped, overlay.id),
            opacity      = stored.opacity or 1.0,
            colour       = stored.colour or 0,
            secondColour = stored.secondColour or 0,
        }
    end

    local components = {}
    for _, component in ipairs(Appearance.Components) do
        components[tostring(component.id)] = {
            drawable = GetPedDrawableVariation(ped, component.id),
            texture  = GetPedTextureVariation(ped, component.id),
        }
    end

    local props = {}
    for _, prop in ipairs(Appearance.Props) do
        props[tostring(prop.id)] = {
            drawable = GetPedPropIndex(ped, prop.id),
            texture  = GetPedPropTextureIndex(ped, prop.id),
        }
    end

    local base = Appearance.Current or {}

    return {
        model      = base.model,
        headBlend  = base.headBlend,
        features   = features,
        overlays   = overlays,
        hair       = {
            drawable  = GetPedDrawableVariation(ped, 2),
            texture   = GetPedTextureVariation(ped, 2),
            colour    = (base.hair or {}).colour or 0,
            highlight = (base.hair or {}).highlight or 0,
        },
        eyeColour  = base.eyeColour or 0,
        components = components,
        props      = props,
    }
end

--- Nur die Kleidung, ohne Gesicht.
function Appearance.ReadOutfit()
    local full = Appearance.Read()
    return { components = full.components, props = full.props }
end

--- Wie viele Varianten es fuer ein Teil gibt.
function Appearance.CountComponent(componentId, drawable)
    local ped = PlayerPedId()

    return GetNumberOfPedDrawableVariations(ped, componentId),
           GetNumberOfPedTextureVariations(ped, componentId, drawable or 0)
end

function Appearance.CountProp(propId, drawable)
    local ped = PlayerPedId()

    return GetNumberOfPedPropDrawableVariations(ped, propId),
           GetNumberOfPedPropTextureVariations(ped, propId, drawable or 0)
end

--- Wie viele Auflagen es gibt.
function Appearance.CountOverlay(overlayId)
    return GetNumHeadOverlayValues(overlayId)
end

-- Vom Server ---------------------------------------------------------------------

RegisterNetEvent('appearance:client:apply', function(data)
    Appearance.Apply(data)
end)

--- Nach dem Spawn anwenden - der Core setzt vorher das Standardmodell.
AddEventHandler('moonshine:client:playerSpawned', function()
    CreateThread(function()
        Wait(400)
        if Appearance.Current then Appearance.Apply(Appearance.Current) end
    end)
end)

--- Nach dem Wiederbeleben kann das Ped zurueckgesetzt sein.
AddEventHandler('death:client:revive', function()
    CreateThread(function()
        Wait(1200)
        if Appearance.Current then Appearance.Apply(Appearance.Current) end
    end)
end)

exports('GetAppearance', function()
    return Appearance.Current
end)

exports('ApplyAppearance', function(data)
    Appearance.Apply(data)
    return true
end)
