-- JSON fuer die Attrappe.
--
-- Die einfache Attrappe gab fuer json.decode immer {} zurueck. Das faellt
-- lange nicht auf und macht dann alles falsch: Raenge, Inventare, Emblem-
-- Einstellungen - alles, was in einer Datenbankspalte als JSON liegt, kam
-- leer heraus, und die Aufbaufunktionen rechneten auf Nichts.

local Json = {}

-- Kodieren ------------------------------------------------------------------

local ESCAPE = {
    ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
    ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function zeichenkette(text)
    return '"' .. text:gsub('[%c"\\]', function(zeichen)
        return ESCAPE[zeichen] or ('\\u%04x'):format(zeichen:byte())
    end) .. '"'
end

function Json.encode(wert, tiefe)
    tiefe = (tiefe or 0) + 1
    if tiefe > 60 then return 'null' end

    local art = type(wert)

    if wert == nil then return 'null' end
    if art == 'boolean' then return tostring(wert) end
    if art == 'string' then return zeichenkette(wert) end

    if art == 'number' then
        if wert ~= wert or wert == math.huge or wert == -math.huge then return '0' end
        if wert % 1 == 0 then return ('%d'):format(wert) end
        return ('%.14g'):format(wert)
    end

    if art ~= 'table' then return 'null' end

    if #wert > 0 then
        local teile = {}
        for _, eintrag in ipairs(wert) do
            teile[#teile + 1] = Json.encode(eintrag, tiefe)
        end
        return '[' .. table.concat(teile, ',') .. ']'
    end

    local schluessel = {}
    for name in pairs(wert) do
        if type(name) == 'string' or type(name) == 'number' then
            schluessel[#schluessel + 1] = name
        end
    end

    if #schluessel == 0 then return '{}' end

    table.sort(schluessel, function(a, b) return tostring(a) < tostring(b) end)

    local teile = {}
    for _, name in ipairs(schluessel) do
        teile[#teile + 1] = ('%s:%s'):format(
            zeichenkette(tostring(name)), Json.encode(wert[name], tiefe))
    end

    return '{' .. table.concat(teile, ',') .. '}'
end

-- Dekodieren ----------------------------------------------------------------

local function ueberspringen(text, pos)
    return text:find('[^ \t\r\n]', pos) or (#text + 1)
end

local wert   -- vorwaerts

local function leseZeichenkette(text, pos)
    -- pos zeigt auf das oeffnende Anfuehrungszeichen.
    local teile = {}
    local i = pos + 1

    while i <= #text do
        local zeichen = text:sub(i, i)

        if zeichen == '"' then
            return table.concat(teile), i + 1
        elseif zeichen == '\\' then
            local naechstes = text:sub(i + 1, i + 1)

            if naechstes == 'u' then
                local hex = text:sub(i + 2, i + 5)
                local nummer = tonumber(hex, 16) or 63
                teile[#teile + 1] = (nummer < 128)
                    and string.char(nummer) or utf8.char(nummer)
                i = i + 6
            else
                local ersatz = ({ n = '\n', t = '\t', r = '\r', b = '\b',
                                  f = '\f', ['"'] = '"', ['\\'] = '\\',
                                  ['/'] = '/' })[naechstes] or naechstes
                teile[#teile + 1] = ersatz
                i = i + 2
            end
        else
            teile[#teile + 1] = zeichen
            i = i + 1
        end
    end

    error('Zeichenkette ohne Ende')
end

local function leseListe(text, pos)
    local liste = {}
    local i = ueberspringen(text, pos + 1)

    if text:sub(i, i) == ']' then return liste, i + 1 end

    while true do
        local eintrag
        eintrag, i = wert(text, i)
        liste[#liste + 1] = eintrag

        i = ueberspringen(text, i)
        local zeichen = text:sub(i, i)

        if zeichen == ']' then return liste, i + 1 end
        if zeichen ~= ',' then error('Komma erwartet in Liste') end

        i = ueberspringen(text, i + 1)
    end
end

local function leseObjekt(text, pos)
    local objekt = {}
    local i = ueberspringen(text, pos + 1)

    if text:sub(i, i) == '}' then return objekt, i + 1 end

    while true do
        if text:sub(i, i) ~= '"' then error('Schluessel erwartet') end

        local name
        name, i = leseZeichenkette(text, i)

        i = ueberspringen(text, i)
        if text:sub(i, i) ~= ':' then error('Doppelpunkt erwartet') end

        local inhalt
        inhalt, i = wert(text, ueberspringen(text, i + 1))
        objekt[name] = inhalt

        i = ueberspringen(text, i)
        local zeichen = text:sub(i, i)

        if zeichen == '}' then return objekt, i + 1 end
        if zeichen ~= ',' then error('Komma erwartet in Objekt') end

        i = ueberspringen(text, i + 1)
    end
end

wert = function(text, pos)
    pos = ueberspringen(text, pos)
    local zeichen = text:sub(pos, pos)

    if zeichen == '{' then return leseObjekt(text, pos) end
    if zeichen == '[' then return leseListe(text, pos) end
    if zeichen == '"' then return leseZeichenkette(text, pos) end

    if text:sub(pos, pos + 3) == 'true'  then return true, pos + 4 end
    if text:sub(pos, pos + 4) == 'false' then return false, pos + 5 end
    if text:sub(pos, pos + 3) == 'null'  then return nil, pos + 4 end

    local zahl, ende = text:match('^(%-?%d+%.?%d*[eE]?[%+%-]?%d*)()', pos)
    if zahl then return tonumber(zahl), ende end

    error(('unerwartetes Zeichen "%s" an Stelle %d'):format(zeichen, pos))
end

--- Gibt nil zurueck, wenn der Text kein gueltiges JSON ist - so wie es die
--- Aufrufer im Framework erwarten.
function Json.decode(text)
    if type(text) ~= 'string' or text == '' then return nil end

    local ok, ergebnis = pcall(function()
        local inhalt = wert(text, 1)
        return inhalt
    end)

    if not ok then return nil end
    return ergebnis
end

return Json
