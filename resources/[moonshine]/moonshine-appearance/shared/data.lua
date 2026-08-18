--- Bausteine des Aussehens.
---
--- Die Zahlen sind die Ids aus GTA. Die Bezeichnungen stehen hier, damit die
--- Oberflaeche nicht "Component 11" anzeigen muss.

-- Kleidungsstuecke (SetPedComponentVariation) ----------------------------------
Appearance.Components = {
    { id = 11, key = 'oberteil',    label = 'Oberteil',      icon = '👕', group = 'kleidung' },
    { id = 3,  key = 'arme',        label = 'Arme',          icon = '💪', group = 'kleidung' },
    { id = 8,  key = 'unterhemd',   label = 'Unterhemd',     icon = '🎽', group = 'kleidung' },
    { id = 4,  key = 'hose',        label = 'Hose',          icon = '👖', group = 'kleidung' },
    { id = 6,  key = 'schuhe',      label = 'Schuhe',        icon = '👟', group = 'kleidung' },
    { id = 9,  key = 'weste',       label = 'Weste',         icon = '🦺', group = 'kleidung' },
    { id = 1,  key = 'maske',       label = 'Maske',         icon = '🎭', group = 'accessoires' },
    { id = 5,  key = 'rucksack',    label = 'Rucksack',      icon = '🎒', group = 'accessoires' },
    { id = 7,  key = 'halskette',   label = 'Halskette',     icon = '📿', group = 'accessoires' },
    { id = 10, key = 'aufnaeher',   label = 'Aufnaeher',     icon = '🏷', group = 'accessoires' },
}

-- Anbauteile (SetPedPropIndex) -----------------------------------------------------
Appearance.Props = {
    { id = 0, key = 'hut',      label = 'Kopfbedeckung', icon = '🎩', group = 'accessoires' },
    { id = 1, key = 'brille',   label = 'Brille',        icon = '👓', group = 'accessoires' },
    { id = 2, key = 'ohren',    label = 'Ohrschmuck',    icon = '👂', group = 'accessoires' },
    { id = 6, key = 'uhr',      label = 'Uhr',           icon = '⌚', group = 'accessoires' },
    { id = 7, key = 'armband',  label = 'Armband',       icon = '💫', group = 'accessoires' },
}

-- Gesichtsauflagen (SetPedHeadOverlay) ------------------------------------------------
--- `colourType`: 0 Haar, 1 Augenbraue/Bart, 2 Make-up. `nil` = keine Farbe.
Appearance.Overlays = {
    { id = 2,  key = 'augenbrauen', label = 'Augenbrauen',   colourType = 1, group = 'kopf' },
    { id = 1,  key = 'bart',        label = 'Bart',          colourType = 1, group = 'kopf' },
    { id = 10, key = 'brusthaar',   label = 'Brusthaar',     colourType = 1, group = 'koerper' },
    { id = 0,  key = 'sommersprossen', label = 'Sommersprossen', colourType = nil, group = 'kopf' },
    { id = 3,  key = 'altersspuren',  label = 'Altersspuren',   colourType = nil, group = 'kopf' },
    { id = 6,  key = 'hautunreinheit',label = 'Hautunreinheiten', colourType = nil, group = 'kopf' },
    { id = 9,  key = 'flecken',     label = 'Muttermale',    colourType = nil, group = 'kopf' },
    { id = 11, key = 'koerperspuren', label = 'Koerperspuren', colourType = nil, group = 'koerper' },
    { id = 4,  key = 'makeup',      label = 'Make-up',       colourType = 2, group = 'makeup' },
    { id = 5,  key = 'rouge',       label = 'Rouge',         colourType = 2, group = 'makeup' },
    { id = 8,  key = 'lippenstift', label = 'Lippenstift',   colourType = 2, group = 'makeup' },
    { id = 7,  key = 'schaden',     label = 'Hautschaden',   colourType = nil, group = 'kopf' },
    { id = 12, key = 'glanz',       label = 'Teint',         colourType = nil, group = 'kopf' },
}

-- Gesichtszuege (SetPedFaceFeature), Werte von -1.0 bis 1.0 ---------------------------
Appearance.Features = {
    { id = 0,  label = 'Nasenbreite' },
    { id = 1,  label = 'Nasenhoehe' },
    { id = 2,  label = 'Nasenlaenge' },
    { id = 3,  label = 'Nasenruecken' },
    { id = 4,  label = 'Nasenspitze' },
    { id = 5,  label = 'Nasenversatz' },
    { id = 6,  label = 'Augenbrauenhoehe' },
    { id = 7,  label = 'Augenbrauentiefe' },
    { id = 8,  label = 'Wangenknochenhoehe' },
    { id = 9,  label = 'Wangenknochenbreite' },
    { id = 10, label = 'Wangentiefe' },
    { id = 11, label = 'Augengroesse' },
    { id = 12, label = 'Lippendicke' },
    { id = 13, label = 'Kieferbreite' },
    { id = 14, label = 'Kieferform' },
    { id = 15, label = 'Kinnhoehe' },
    { id = 16, label = 'Kinntiefe' },
    { id = 17, label = 'Kinnbreite' },
    { id = 18, label = 'Kinnform' },
    { id = 19, label = 'Halsdicke' },
}

--- Elternteile fuer die Gesichtsmischung. Die Ids sind die Standardgesichter.
Appearance.Parents = {
    male = {
        { id = 0,  label = 'Benjamin' }, { id = 1,  label = 'Daniel' },
        { id = 2,  label = 'Joshua' },   { id = 3,  label = 'Noah' },
        { id = 4,  label = 'Andrew' },   { id = 5,  label = 'Juan' },
        { id = 6,  label = 'Alex' },     { id = 7,  label = 'Isaac' },
        { id = 8,  label = 'Evan' },     { id = 9,  label = 'Ethan' },
        { id = 10, label = 'Vincent' },  { id = 11, label = 'Angel' },
        { id = 12, label = 'Diego' },    { id = 13, label = 'Adrian' },
        { id = 14, label = 'Gabriel' },  { id = 15, label = 'Michael' },
        { id = 16, label = 'Santiago' }, { id = 17, label = 'Kevin' },
        { id = 18, label = 'Louis' },    { id = 19, label = 'Samuel' },
        { id = 20, label = 'Anthony' },
    },
    female = {
        { id = 21, label = 'Hannah' },   { id = 22, label = 'Audrey' },
        { id = 23, label = 'Jasmine' },  { id = 24, label = 'Giselle' },
        { id = 25, label = 'Amelia' },   { id = 26, label = 'Isabella' },
        { id = 27, label = 'Zoe' },      { id = 28, label = 'Ava' },
        { id = 29, label = 'Camila' },   { id = 30, label = 'Violet' },
        { id = 31, label = 'Sophia' },   { id = 32, label = 'Evelyn' },
        { id = 33, label = 'Nicole' },   { id = 34, label = 'Ashley' },
        { id = 35, label = 'Gracie' },   { id = 36, label = 'Brianna' },
        { id = 37, label = 'Natalie' },  { id = 38, label = 'Olivia' },
        { id = 39, label = 'Elizabeth' },{ id = 40, label = 'Charlotte' },
        { id = 41, label = 'Emma' },
    },
}

--- Hautfarben fuer die Mischung (dieselben Ids wie die Gesichter).
Appearance.SkinTones = Appearance.Parents

--- Wie viele Haarfarben es gibt.
Appearance.HairColours = 64

--- Wie viele Augenfarben es gibt.
Appearance.EyeColours = 32

--- Leeres Aussehen als Ausgangspunkt.
---@param gender string 'm' oder 'w'
function Appearance.Default(gender)
    local female = gender == 'w'

    local overlays = {}
    for _, overlay in ipairs(Appearance.Overlays) do
        overlays[tostring(overlay.id)] = {
            index = 255, opacity = 1.0, colour = 0, secondColour = 0,
        }
    end

    -- Augenbrauen sollen von Anfang an sichtbar sein.
    overlays['2'] = { index = female and 1 or 0, opacity = 1.0, colour = 1, secondColour = 1 }

    local features = {}
    for _, feature in ipairs(Appearance.Features) do
        features[tostring(feature.id)] = 0.0
    end

    local components = {}
    for _, component in ipairs(Appearance.Components) do
        components[tostring(component.id)] = { drawable = 0, texture = 0 }
    end

    -- Startkleidung, damit niemand nackt herumsteht.
    components['11'] = { drawable = female and 5 or 15, texture = 0 }
    components['3']  = { drawable = female and 15 or 15, texture = 0 }
    components['8']  = { drawable = female and 14 or 15, texture = 0 }
    components['4']  = { drawable = female and 10 or 10, texture = 0 }
    components['6']  = { drawable = female and 5 or 7, texture = 0 }

    local props = {}
    for _, prop in ipairs(Appearance.Props) do
        props[tostring(prop.id)] = { drawable = -1, texture = 0 }
    end

    return {
        model = female and 'mp_f_freemode_01' or 'mp_m_freemode_01',
        headBlend = {
            shapeFirst = female and 21 or 0, shapeSecond = female and 21 or 0,
            shapeThird = 0,
            skinFirst = female and 21 or 0, skinSecond = female and 21 or 0,
            skinThird = 0,
            shapeMix = 0.5, skinMix = 0.5, thirdMix = 0.0,
        },
        features   = features,
        overlays   = overlays,
        hair       = { drawable = 0, texture = 0, colour = 1, highlight = 1 },
        eyeColour  = 0,
        components = components,
        props      = props,
    }
end

--- Baustein nach Schluessel.
function Appearance.GetComponent(key)
    for _, entry in ipairs(Appearance.Components) do
        if entry.key == key then return entry end
    end
    return nil
end

function Appearance.GetProp(key)
    for _, entry in ipairs(Appearance.Props) do
        if entry.key == key then return entry end
    end
    return nil
end

--- Gehoert dieses Teil zu einer Kategorie, die der Laden fuehrt?
function Appearance.InCategories(group, categories)
    for _, entry in ipairs(categories or {}) do
        if entry == group then return true end
    end
    return false
end
