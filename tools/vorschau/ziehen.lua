-- Zieht Elementliste, Auswahl und Standardeinstellung aus der echten
-- Config, damit die Bilder nicht von einer Handabschrift leben.
dofile('tools/attrappe.lua')
dofile('resources/[moonshine]/moonshine-hud/shared/config.lua')

--- Kleiner JSON-Schreiber. Die Attrappe hat nur einen Platzhalter.
local function kodiere(wert)
    local art = type(wert)

    if art == 'nil' then return 'null' end
    if art == 'boolean' then return tostring(wert) end
    if art == 'number' then
        return ('%.14g'):format(wert)
    end
    if art == 'string' then
        return '"' .. wert:gsub('[\\"]', '\\%0'):gsub('\n', '\\n') .. '"'
    end

    if art ~= 'table' then return 'null' end

    -- Liste oder Objekt?
    if #wert > 0 then
        local teile = {}
        for _, eintrag in ipairs(wert) do teile[#teile + 1] = kodiere(eintrag) end
        return '[' .. table.concat(teile, ',') .. ']'
    end

    local schluessel = {}
    for name in pairs(wert) do schluessel[#schluessel + 1] = name end
    table.sort(schluessel)

    local teile = {}
    for _, name in ipairs(schluessel) do
        teile[#teile + 1] = ('"%s":%s'):format(name, kodiere(wert[name]))
    end

    return '{' .. table.concat(teile, ',') .. '}'
end

local ZIEL = arg[1] or 'tools/vorschau/daten'

local function schreibe(pfad, wert)
    local datei = io.open(pfad, 'w')
    datei:write(kodiere(wert))
    datei:close()
end

schreibe(ZIEL .. '/elemente.json', HudConfig.Elements)
schreibe(ZIEL .. '/auswahl.json', HudConfig.Choices)
schreibe(ZIEL .. '/standard.json', Hud.DefaultSettings())
print('gezogen')
