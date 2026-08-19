--- Was eine Werkstatt anschraubt.
---
--- Die Werkstaetten haben bisher nur repariert. Die Spalte `mods` in
--- ms_vehicles lag seit dem Fahrzeugsystem ungenutzt da - hier wird sie
--- endlich gefuellt.
---
--- Die Zahlen hinter den Namen sind die Modarten aus GTA. Wie viele Stufen
--- es je Fahrzeug wirklich gibt, weiss nur das Fahrzeug selbst; der Client
--- fragt das ab und schickt es mit. Der Server rechnet den Preis dann aus
--- der Stufe, nicht aus dem, was der Client behauptet.

-- Leistung -------------------------------------------------------------------
--- Stufen kosten aufsteigend: die letzte Stufe ist die teuerste.
Services.Performance = {
    { id = 'motor',     mod = 11, label = 'Motor',      icon = '⚙',
      preise = { 12000, 26000, 48000, 85000 } },
    { id = 'bremsen',   mod = 12, label = 'Bremsen',    icon = '🛑',
      preise = { 8000, 17000, 32000 } },
    { id = 'getriebe',  mod = 13, label = 'Getriebe',   icon = '🔩',
      preise = { 11000, 24000, 44000 } },
    { id = 'federung',  mod = 15, label = 'Federung',   icon = '🪛',
      preise = { 6000, 13000, 24000, 40000 } },
    { id = 'panzerung', mod = 16, label = 'Panzerung',  icon = '🛡',
      preise = { 15000, 30000, 55000, 90000, 140000 } },
}

--- Der Turbo ist ein Schalter, keine Stufe.
Services.Turbo = { id = 'turbo', mod = 18, label = 'Turbolader', icon = '💨',
                   preis = 62000 }

-- Aussehen ---------------------------------------------------------------------
--- Optische Teile. Der Preis gilt je Stufe, unabhaengig davon welche.
Services.Cosmetics = {
    { id = 'spoiler',      mod = 0,  label = 'Spoiler',           icon = '🪽', preis = 9000 },
    { id = 'frontstange',  mod = 1,  label = 'Frontstoßstange',   icon = '🚧', preis = 7500 },
    { id = 'heckstange',   mod = 2,  label = 'Heckstoßstange',    icon = '🚧', preis = 7500 },
    { id = 'schweller',    mod = 3,  label = 'Seitenschweller',   icon = '📏', preis = 6500 },
    { id = 'auspuff',      mod = 4,  label = 'Auspuff',           icon = '🔥', preis = 8000 },
    { id = 'buegel',       mod = 5,  label = 'Überrollbügel',     icon = '🧱', preis = 12000 },
    { id = 'motorhaube',   mod = 7,  label = 'Motorhaube',        icon = '🔓', preis = 8500 },
    { id = 'kotfluegel',   mod = 8,  label = 'Kotflügel',         icon = '🪟', preis = 7000 },
    { id = 'dach',         mod = 10, label = 'Dach',              icon = '🏠', preis = 6000 },
    { id = 'lenkrad',      mod = 33, label = 'Lenkrad',           icon = '🎡', preis = 4500 },
    { id = 'sitze',        mod = 32, label = 'Sitze',             icon = '💺', preis = 5500 },
    { id = 'schaltknauf',  mod = 34, label = 'Schaltknauf',       icon = '🕹', preis = 3000 },
    { id = 'hupe',         mod = 14, label = 'Hupe',              icon = '📯', preis = 2500 },
    { id = 'felgen',       mod = 23, label = 'Felgen',            icon = '🛞', preis = 14000 },
    { id = 'kennzhalter',  mod = 25, label = 'Kennzeichenhalter', icon = '🔖', preis = 1500 },
}

-- Lackierung ---------------------------------------------------------------------
--- Die Farben stehen als Name und Nummer da, damit die Oberflaeche nicht
--- "Farbe 27" anzeigen muss. Die Nummern sind die GTA-Lackfarben.
Services.Paints = {
    { id = 0,   label = 'Schwarz',        hex = '#0d0d0d' },
    { id = 1,   label = 'Grafit',         hex = '#26282a' },
    { id = 4,   label = 'Silber',         hex = '#9ba0a8' },
    { id = 11,  label = 'Chrom',          hex = '#d5dae0' },
    { id = 27,  label = 'Rot',            hex = '#c00e1a' },
    { id = 36,  label = 'Kupfer',         hex = '#9d6b3f' },
    { id = 38,  label = 'Orange',         hex = '#f78616' },
    { id = 42,  label = 'Zitrone',        hex = '#c7d40c' },
    { id = 49,  label = 'Dunkelgrün',     hex = '#132428' },
    { id = 53,  label = 'Limette',        hex = '#67b81c' },
    { id = 61,  label = 'Marineblau',     hex = '#222e46' },
    { id = 64,  label = 'Nachtblau',      hex = '#233155' },
    { id = 70,  label = 'Himmelblau',     hex = '#4c7dc4' },
    { id = 71,  label = 'Eisblau',        hex = '#7ba7d4' },
    { id = 88,  label = 'Gelb',           hex = '#ffcf20' },
    { id = 89,  label = 'Rennrot',        hex = '#c00e1a' },
    { id = 111, label = 'Reinweiß',       hex = '#ffffff' },
    { id = 132, label = 'Blutrot',        hex = '#a3232c' },
    { id = 141, label = 'Mitternacht',    hex = '#0f1219' },
    { id = 145, label = 'Violett',        hex = '#621276' },
    { id = 146, label = 'Mondviolett',    hex = '#9b6bd8' },
    { id = 150, label = 'Waldgrün',       hex = '#2d5a3d' },
}

--- Perlmuttschimmer nutzt dieselbe Farbtafel.
Services.Tints = {
    { id = 0, label = 'Keine',        preis = 0 },
    { id = 1, label = 'Leicht',       preis = 1200 },
    { id = 2, label = 'Halbdunkel',   preis = 1800 },
    { id = 3, label = 'Dunkel',       preis = 2600 },
    { id = 4, label = 'Undurchsichtig', preis = 3400 },
}

--- Neonfarben.
Services.Neon = {
    { id = 'violett', label = 'Mondviolett', r = 155, g = 107, b = 216 },
    { id = 'rot',     label = 'Blutrot',     r = 163, g = 35,  b = 44  },
    { id = 'blau',    label = 'Nachtblau',   r = 61,  g = 139, b = 212 },
    { id = 'gruen',   label = 'Giftgrün',    r = 76,  g = 175, b = 125 },
    { id = 'gelb',    label = 'Bernstein',   r = 224, g = 166, b = 66  },
    { id = 'weiss',   label = 'Kaltweiß',    r = 230, g = 236, b = 245 },
}

--- Xenonfarben. Die Nummern sind die GTA-Scheinwerferfarben.
Services.Xenon = {
    { id = -1, label = 'Standard' },
    { id = 0,  label = 'Weiß' },
    { id = 1,  label = 'Blau' },
    { id = 2,  label = 'Elektroblau' },
    { id = 3,  label = 'Minzgrün' },
    { id = 4,  label = 'Limette' },
    { id = 5,  label = 'Gelb' },
    { id = 7,  label = 'Orange' },
    { id = 8,  label = 'Rot' },
    { id = 9,  label = 'Rosa' },
    { id = 12, label = 'Violett' },
}

-- Zugriff ---------------------------------------------------------------------------

--- Leistungsteil nach Id.
function Services.GetPerformance(id)
    for _, entry in ipairs(Services.Performance) do
        if entry.id == id then return entry end
    end

    if Services.Turbo.id == id then return Services.Turbo end
    return nil
end

--- Optisches Teil nach Id.
function Services.GetCosmetic(id)
    for _, entry in ipairs(Services.Cosmetics) do
        if entry.id == id then return entry end
    end

    return nil
end

--- Irgendein Teil, egal aus welcher Liste.
function Services.GetPart(id)
    return Services.GetPerformance(id) or Services.GetCosmetic(id)
end

--- Gibt es diese Lackfarbe?
function Services.IsPaint(id)
    for _, entry in ipairs(Services.Paints) do
        if entry.id == id then return true end
    end

    return false
end

--- Fensterfolie nach Stufe.
function Services.GetTint(id)
    for _, entry in ipairs(Services.Tints) do
        if entry.id == id then return entry end
    end

    return nil
end

--- Neonfarbe nach Id.
function Services.GetNeon(id)
    for _, entry in ipairs(Services.Neon) do
        if entry.id == id then return entry end
    end

    return nil
end

--- Gibt es diese Xenonfarbe?
function Services.IsXenon(id)
    for _, entry in ipairs(Services.Xenon) do
        if entry.id == id then return true end
    end

    return false
end

-- Preise --------------------------------------------------------------------------------

--- Was eine Stufe eines Leistungsteils kostet.
---
--- Stufen sind kumulativ zu denken: wer von Stufe 1 auf 3 geht, zahlt die
--- Stufe 3, nicht die Summe. Rueckbau auf Werkszustand kostet nichts.
---@param id string
---@param stufe number 0-basiert wie in GTA, -1 heisst ab Werk
---@return number
function Services.PerformancePrice(id, stufe)
    local entry = Services.GetPerformance(id)
    if not entry then return 0 end

    stufe = math.floor(tonumber(stufe) or -1)
    if stufe < 0 then return 0 end

    -- Der Turbo hat nur an und aus.
    if entry.preis then return stufe > 0 and entry.preis or 0 end

    return entry.preise[stufe + 1] or entry.preise[#entry.preise] or 0
end

--- Was ein optisches Teil kostet. Jede Stufe kostet gleich viel.
function Services.CosmeticPrice(id, stufe)
    local entry = Services.GetCosmetic(id)
    if not entry then return 0 end

    stufe = math.floor(tonumber(stufe) or -1)
    if stufe < 0 then return 0 end

    return entry.preis
end

--- Preis eines Teils, egal aus welcher Liste.
function Services.PartPrice(id, stufe)
    if Services.GetPerformance(id) then return Services.PerformancePrice(id, stufe) end
    return Services.CosmeticPrice(id, stufe)
end
