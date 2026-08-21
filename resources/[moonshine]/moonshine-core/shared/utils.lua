--- Globales Framework-Objekt. Wird von shared/server/client gemeinsam genutzt.
MS = MS or {}

MS.Version   = '1.0.0'
MS.Resource  = GetCurrentResourceName()
MS.IsServer  = IsDuplicityVersion()
MS.Utils     = {}

local Utils = MS.Utils

--- Konsolenausgabe mit einheitlichem Prefix.
---@param level 'info'|'warn'|'error'|'debug'
function Utils.Print(level, message, ...)
    if level == 'debug' and not Config.Debug then return end

    local colors = { info = '^2', warn = '^3', error = '^1', debug = '^5' }
    local args = { ... }
    if #args > 0 then
        message = string.format(message, table.unpack(args))
    end

    print(('%s[Moonshine]^7 [%s] %s'):format(colors[level] or '^7', level:upper(), message))
end

function Utils.Debug(message, ...)
    Utils.Print('debug', message, ...)
end

--- Rundet eine Zahl auf n Nachkommastellen.
function Utils.Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

--- Begrenzt einen Wert auf [min, max].
function Utils.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function Utils.Trim(value)
    if type(value) ~= 'string' then return value end
    return (value:gsub('^%s*(.-)%s*$', '%1'))
end

--- Tiefe Kopie einer Tabelle (ohne Metatabellen).
function Utils.DeepCopy(source)
    if type(source) ~= 'table' then return source end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = Utils.DeepCopy(value)
    end
    return copy
end

function Utils.TableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

--- Formatiert einen Betrag als deutsche Waehrungsangabe: 1234567 -> "1.234.567 $".
function Utils.FormatMoney(amount)
    local formatted = tostring(math.floor(math.abs(amount)))
    while true do
        local replacements
        formatted, replacements = formatted:gsub('^(%d+)(%d%d%d)', '%1.%2')
        if replacements == 0 then break end
    end
    return ('%s%s $'):format(amount < 0 and '-' or '', formatted)
end

--- Sicheres JSON-Decode mit Fallback.
function Utils.DecodeJson(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end

    local ok, decoded = pcall(json.decode, value)
    if not ok or decoded == nil then return fallback end
    return decoded
end

--- Erzeugt eine zufaellige alphanumerische ID (z.B. fuer Item-Metadaten).
function Utils.RandomId(length)
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = {}
    for i = 1, (length or 8) do
        local index = math.random(#chars)
        result[i] = chars:sub(index, index)
    end
    return table.concat(result)
end

--- Validiert einen Charakternamen (nur Buchstaben, Bindestriche, 2-24 Zeichen).
function Utils.IsValidName(name)
    if type(name) ~= 'string' then return false end
    name = Utils.Trim(name)
    if #name < 2 or #name > 24 then return false end
    return name:match("^[%a][%a'%-%s]*$") ~= nil
end

--- Validiert ein Geburtsdatum im Format TT.MM.JJJJ.
function Utils.IsValidDate(value)
    if type(value) ~= 'string' then return false end
    local day, month, year = value:match('^(%d%d)%.(%d%d)%.(%d%d%d%d)$')
    if not day then return false end

    day, month, year = tonumber(day), tonumber(month), tonumber(year)
    if month < 1 or month > 12 then return false end
    if day < 1 or day > 31 then return false end
    if year < 1900 or year > 2010 then return false end
    return true
end

--- Ein Schritt der Ratenbegrenzung.
---
--- Die Rechnung steht hier und nicht beim Aufrufer, damit sie sich ohne
--- laufenden Server pruefen laesst: sie haengt nur an ihren Argumenten.
---
--- Ein Eimer ist { count, resetAt, warned }. Ist er abgelaufen oder gibt es
--- ihn noch nicht, faengt ein neuer an.
---@param bucket table|nil bisheriger Zustand
---@param now number Zeit in Sekunden
---@param max number erlaubte Aufrufe je Fenster
---@param windowSeconds number Fensterbreite
---@return boolean allowed, table bucket, boolean melden
function Utils.RateBucket(bucket, now, max, windowSeconds, strikes)
    if type(bucket) ~= 'table' or (bucket.resetAt or 0) <= now then
        return true, { count = 1, resetAt = now + windowSeconds, warned = 0 }, false
    end

    bucket.count = (bucket.count or 0) + 1
    if bucket.count <= max then return true, bucket, false end

    bucket.warned = (bucket.warned or 0) + 1

    -- Erst nach mehreren Ueberschreitungen ist es eine Meldung wert. Ein
    -- einzelner Ausreisser ist meist Lag, kein Angriff.
    if bucket.warned >= (strikes or 3) then
        bucket.warned = 0
        return false, bucket, true
    end

    return false, bucket, false
end
