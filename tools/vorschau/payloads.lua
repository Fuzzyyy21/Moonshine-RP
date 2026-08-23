-- Erzeugt echte NUI-Nutzlasten, ohne FXServer.
--
-- Nicht abgeschrieben: geladen wird der echte Client-Code einer Resource,
-- dann wird das echte Ereignis ausgeloest, und was dabei an SendNUIMessage
-- ginge, faellt hinten heraus. Der Server-Anteil - der Teil, den sonst die
-- Datenbank fuellt - steht hier als erfundener, aber vollstaendiger
-- Charakter.
--
-- Aufruf:  lua5.4 tools/vorschau/payloads.lua [zielordner]
-- Ergebnis: daten/<resource>.json, gelesen von laden.js

dofile('tools/vorschau/attrappe-client.lua')

local ZIEL = arg[1] or 'tools/vorschau/daten'

--- Kleiner JSON-Schreiber. Die Attrappe hat nur einen Platzhalter.
local function kodiere(wert, tiefe)
    tiefe = (tiefe or 0) + 1
    if tiefe > 40 then return 'null' end

    local art = type(wert)

    if art == 'nil' then return 'null' end
    if art == 'boolean' then return tostring(wert) end
    if art == 'number' then
        if wert ~= wert or wert == math.huge or wert == -math.huge then return '0' end
        return ('%.14g'):format(wert)
    end
    if art == 'string' then
        return '"' .. wert:gsub('[\\"]', '\\%0'):gsub('\n', '\\n'):gsub('\t', '\\t') .. '"'
    end

    if art ~= 'table' then return 'null' end

    if #wert > 0 then
        local teile = {}
        for _, eintrag in ipairs(wert) do
            teile[#teile + 1] = kodiere(eintrag, tiefe)
        end
        return '[' .. table.concat(teile, ',') .. ']'
    end

    local schluessel = {}
    for name in pairs(wert) do
        if type(name) == 'string' or type(name) == 'number' then
            schluessel[#schluessel + 1] = tostring(name)
        end
    end

    if #schluessel == 0 then return '{}' end
    table.sort(schluessel)

    local teile = {}
    for _, name in ipairs(schluessel) do
        local roh = wert[name] ~= nil and wert[name] or wert[tonumber(name)]
        teile[#teile + 1] = ('%s:%s'):format(kodiere(name, tiefe), kodiere(roh, tiefe))
    end

    return '{' .. table.concat(teile, ',') .. '}'
end

local function schreiben(name, nachrichten)
    local datei = assert(io.open(('%s/%s.json'):format(ZIEL, name), 'w'))
    datei:write(kodiere(nachrichten))
    datei:close()

    return #nachrichten
end

os.execute('mkdir -p ' .. ZIEL)

-- Der erfundene Charakter. Ein Vampir mit Fortschritt in beiden Baeumen,
-- damit die Oberflaechen etwas zu zeichnen haben.
local CHARAKTER = {
    firstname = 'Anna', lastname = 'Voss', charId = 12,
    job = { name = 'post', label = 'Postdienst', grade = 2, gradeLabel = 'Fahrerin' },
    accounts = { cash = 1240, bank = 48900, black = 3500 },
}

local ergebnisse = {}

--- Meldet, was eine Resource ans NUI schicken wuerde.
local function bauen(resource, ereignisse)
    local fehler = Fangen.Resource(resource)

    if #fehler > 0 then
        print(('  %-24s laedt nicht: %s'):format(resource, fehler[1]))
        return
    end

    local alle = {}

    for _, eintrag in ipairs(ereignisse) do
        local ok, err = pcall(function()
            local nachrichten = Fangen.Ausloesen(eintrag.name, table.unpack(eintrag.args or {}))
            for _, nachricht in ipairs(nachrichten) do alle[#alle + 1] = nachricht end
        end)

        if not ok then
            print(('  %-24s %s: %s'):format(resource, eintrag.name, tostring(err)))
        end
    end

    if #alle == 0 then
        print(('  %-24s schickt nichts'):format(resource))
        return
    end

    ergebnisse[resource] = alle
    print(('  %-24s %d Nachrichten'):format(resource, schreiben(resource, alle)))
end

-- ---------------------------------------------------------------- Mystik

do
    local ranks = {
        vampir_blutdurst = 3, vampir_blutsinn = 2, vampir_lebensentzug = 1,
        vampir_schattenhuelle = 1,
    }

    local personal = {
        vit_leben1 = 3, vit_regen1 = 2, vit_zaeh1 = 1, vit_verstaerkt = 1,
    }

    local profil = {
        race = 'vampir', raceLabel = 'Vampir', raceIcon = '🩸',
        raceColor = '#a3232c', essenceLabel = 'Blut',
        level = 7, maxRanks = 40,
        xp = 18400, xpTotal = 18400, personalLevel = 8,
        meditationPoints = 6, xpIntoLevel = 420, xpForNext = 1200,
        essence = 64, maxEssence = 100,
        ranks = ranks, totalRanks = 7, canSwitchClass = true,
        skillbar = { 'vampir_blutdurst', 'vampir_lebensentzug', false, false, false },
        personal = personal, skillPoints = 5, spentPoints = 7,
        modifiers = { healthBonus = 40, armorBonus = 0, damageMult = 1.0,
                      meleeMult = 1.35, speedMult = 1.08, costMult = 1.0,
                      cooldownMult = 1.0, essenceBonus = 0, essenceRegen = 0,
                      regenPerTick = 0, stamina = 0 },
        cooldowns = { vampir_lebensentzug = 12 },
        classStone = 'blutstein', classStoneLabel = 'Blutstein',
        secondsPlayed = 42000,
    }

    local steine = {}
    for name in pairs(Mystic and Mystic.Stones or {}) do steine[name] = 4 end

    bauen('moonshine-mystic', {
        { name = 'mystic:client:openRitual', args = { {
            profile = profil, stones = steine, atRitual = true,
            meditationLeft = 0, canMeditate = true,
            ritualLeft = 0, ritual = MysticConfig and MysticConfig.Ritual,
            blessings = MysticConfig and MysticConfig.Blessings,
            recipe = MysticConfig and MysticConfig.Stones.recipe,
            craftable = 2,
        } } },
    })
end

-- ------------------------------------------------------------- Fortschritt

do
    Fangen.Resource('moonshine-progress', true)

    -- Das Profil kommt aus dem echten Konstruktor, nur die Datenbankzeile
    -- ist erfunden. Damit rechnen die echten Aufbaufunktionen.
    Progress.DB.Ready = true
    Progress.DB.Load = function()
        return {
            playtime_day = Progress.DailyPeriod(), playtime_minutes = 145,
            playtime_claimed = '[]', playtime_total = 4200,
            bp_season = ProgressConfig.BattlePass.season, bp_xp = 12400,
            bp_premium = 1, bp_claimed = '[1,2,3]', cases = '{"holz":2}',
        }
    end
    Progress.DB.LoadMissions = function() return {} end
    Progress.DB.SaveMissions = function() end

    local profil = Progress.LoadProfile(1, 12)

    if profil then
        -- Der Client legt die Daten beim Empfang nur ab und schickt sie
        -- erst weiter, wenn die Oberflaeche offen ist - und das haengt an
        -- einer lokalen Variablen, die von aussen niemand setzt. Die beiden
        -- Nachrichten stehen deshalb hier. Der Inhalt kommt trotzdem aus
        -- der echten Aufbaufunktion.
        local daten = {
            { action = 'progress:open' },
            { action = 'progress:data', data = profil:GetPayload() },
        }

        ergebnisse['moonshine-progress'] = daten
        print(('  %-24s %d Nachrichten'):format('moonshine-progress',
            schreiben('moonshine-progress', daten)))
    else
        print('  moonshine-progress       kein Profil')
    end
end

-- ------------------------------------------------------------------- Kern

do
    Fangen.Resource('moonshine-core')

    -- Die Charakterauswahl ist die einzige Oberflaeche, die jeder Spieler
    -- zwingend sieht - und beim allerersten ist die Liste leer. Genau
    -- deshalb steht sie hier.
    local daten = Fangen.Ausloesen('moonshine:client:characterList', {
        characters = {
            { id = 12, slot = 1, firstname = 'Anna', lastname = 'Voss',
              dob = '1994-03-12', gender = 'w', job = 'Postdienst',
              jobGrade = 'Fahrerin', cash = 1240, bank = 48900,
              lastPlayed = '2026-08-20 21:14:00' },
            { id = 13, slot = 2, firstname = 'Ruben', lastname = 'Kast',
              dob = '1988-11-02', gender = 'm', job = 'Arbeitslos',
              jobGrade = '', cash = 90, bank = 300,
              lastPlayed = '2026-07-02 18:40:00' },
        },
        maxCharacters = Config and Config.MaxCharacters or 3,
        allowDeletion = true,
        camera = Config and Config.SelectionCamera,
        serverName = Config and Config.ServerName or 'Moonshine',
    })

    if #daten > 0 then
        ergebnisse['moonshine-core'] = daten
        print(('  %-24s %d Nachrichten'):format('moonshine-core',
            schreiben('moonshine-core', daten)))
    end
end

print(('\nFertig. %s/'):format(ZIEL))
