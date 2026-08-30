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
    Fangen.Nachrichten = {}
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

-- --------------------------------------------------------------- Auktion

do
    Fangen.Resource('moonshine-auction', true)

    -- Zwei laufende Auktionen, damit die Liste etwas zu zeichnen hat.
    local jetzt = os.time()
    Auction.List = {
        [1] = { id = 1, sellerId = 99, sellerName = 'Ruben Kast',
                item = 'blutstein', label = 'Blutstein', count = 3,
                category = 'mystik', startPrice = 2500, buyout = 9000,
                bid = 4200, bidderId = 12, bidderName = 'Anna Voss',
                endsAt = jetzt + 3600, metadata = nil },
        [2] = { id = 2, sellerId = 12, sellerName = 'Anna Voss',
                item = 'verband', label = 'Verband', count = 10,
                category = 'medizin', startPrice = 400, buyout = 0,
                bid = 0, bidderId = nil, bidderName = nil,
                endsAt = jetzt + 7200, metadata = nil },
    }

    local daten = {
        { action = 'auction:open', house = 'Auktionshaus Vinewood' },
        { action = 'auction:data', data = Auction.BuildPayload(1) },
        { action = 'auction:mail', data = {
            { id = 1, kind = 'money', amount = 4200, label = nil,
              reason = 'Ueberboten: 3x Blutstein' },
            { id = 2, kind = 'item', item = 'verband', label = 'Verband',
              count = 5, reason = 'Auktion ohne Gebot beendet' },
        } },
    }

    ergebnisse['moonshine-auction'] = daten
    print(('  %-24s %d Nachrichten'):format('moonshine-auction',
        schreiben('moonshine-auction', daten)))
end

-- ----------------------------------------------------------- Ritualkrieg

do
    Fangen.Resource('moonshine-ritualwar', true)

    local ok, uebersicht = pcall(RitualWar.Overview)

    if ok and uebersicht then
        local daten = { { action = 'ritualwar:open', data = uebersicht } }
        ergebnisse['moonshine-ritualwar'] = daten
        print(('  %-24s %d Nachrichten'):format('moonshine-ritualwar',
            schreiben('moonshine-ritualwar', daten)))
    else
        print(('  %-24s Overview bricht ab: %s')
            :format('moonshine-ritualwar', tostring(uebersicht)))
    end
end

-- ---------------------------------------------------------- Verwaltung

do
    Fangen.Resource('moonshine-admin', true)

    local ok, nutzlast = pcall(Admin.Payload, 1)

    if ok and nutzlast then
        local daten = {
            { action = 'admin:open' },
            { action = 'admin:data', data = nutzlast },
        }
        ergebnisse['moonshine-admin'] = daten
        print(('  %-24s %d Nachrichten'):format('moonshine-admin',
            schreiben('moonshine-admin', daten)))
    else
        print(('  %-24s Payload bricht ab: %s')
            :format('moonshine-admin', tostring(nutzlast)))
    end
end

-- ------------------------------------------------------------ Fahrzeuge

do
    Fangen.Resource('moonshine-vehicles', true)

    Vehicles.DB.LoadOwned = function()
        return {
            { id = 1, owner_id = 12, plate = 'MS 12 ANN', model = 'sultan',
              label = 'Sultan', category = 'sport', price = 68000,
              state = 'garage', garage = 'zentral', fuel = 74.0,
              engine = 910.0, body = 860.0, mods = '{}', keys = '[]' },
            { id = 2, owner_id = 12, plate = 'MS 44 RUB', model = 'faggio',
              label = 'Faggio', category = 'motorrad', price = 4200,
              state = 'draussen', garage = 'zentral', fuel = 22.0,
              engine = 640.0, body = 410.0, mods = '{}', keys = '[]' },
        }
    end

    -- Die Server-Funktion aufrufen genuegt: TriggerClientEvent stellt in
    -- dieser Attrappe direkt an den Client-Handler zu.
    Fangen.Nachrichten = {}
    Vehicles.SyncOwned(1)

    local daten = { { action = 'vehicles:open', mode = 'garage' } }
    for _, nachricht in ipairs(Fangen.Nachrichten) do
        daten[#daten + 1] = nachricht
    end

    ergebnisse['moonshine-vehicles'] = daten
    print(('  %-24s %d Nachrichten'):format('moonshine-vehicles',
        schreiben('moonshine-vehicles', daten)))
end

-- ------------------------------------------------------- Dienstleistungen

do
    Fangen.Resource('moonshine-services', true)

    local daten = {}
    local bank = Services.BankPayload and Services.BankPayload(1, 'bank')

    if bank then
        daten[#daten + 1] = { action = 'services:open', mode = 'bank', data = bank }
    end

    if #daten > 0 then
        ergebnisse['moonshine-services'] = daten
        print(('  %-24s %d Nachrichten'):format('moonshine-services',
            schreiben('moonshine-services', daten)))
    else
        print('  moonshine-services       keine Nutzlast')
    end
end

-- ------------------------------------------------------------- Arbeit

do
    Fangen.Resource('moonshine-jobs', true)

    local ok, nutzlast = pcall(Work.CenterPayload, 1)

    if ok and nutzlast then
        local daten = { { action = 'work:open', data = nutzlast } }
        ergebnisse['moonshine-jobs'] = daten
        print(('  %-24s %d Nachrichten'):format('moonshine-jobs',
            schreiben('moonshine-jobs', daten)))
    else
        print(('  %-24s CenterPayload: %s'):format('moonshine-jobs',
            tostring(nutzlast)))
    end
end

-- ------------------------------------------------------ Zufluchtsorte

do
    Fangen.Resource('moonshine-refuge', true)

    -- Ein Ort, der Anna gehoert, mit etwas im Lager.
    local ort = Refuge.Places and Refuge.Places[1]

    if ort then
        Refuge.Owned = Refuge.Owned or {}
        Refuge.Owned[ort.id] = {
            characterId = 12, name = 'Annas Unterschlupf', stufe = 2,
            stash = {
                { name = 'verband', label = 'Verband', count = 6, metadata = nil },
                { name = 'blutstein', label = 'Blutstein', count = 2, metadata = nil },
            },
            lastRest = 0, lastRefuge = 0,
        }

        Refuge.AtPlace = function() return true end

        Fangen.Nachrichten = {}
        Refuge.Open(1, ort.id)

        local daten = {}
        for _, nachricht in ipairs(Fangen.Nachrichten) do
            daten[#daten + 1] = nachricht
        end

        -- Das Lager als eigene Nachricht.
        Fangen.Nachrichten = {}
        pcall(function()
            TriggerClientEvent('refuge:client:stash', 1,
                Refuge.BuildStash(Refuge.Owned[ort.id]))
        end)
        for _, nachricht in ipairs(Fangen.Nachrichten) do
            daten[#daten + 1] = nachricht
        end

        if #daten > 0 then
            ergebnisse['moonshine-refuge'] = daten
            print(('  %-24s %d Nachrichten'):format('moonshine-refuge',
                schreiben('moonshine-refuge', daten)))
        else
            print('  moonshine-refuge         keine Nutzlast')
        end
    end
end

-- ---------------------------------------------------------------- Welt

do
    Fangen.Nachrichten = {}
    Fangen.Resource('moonshine-world', true)

    -- world:setup steht in einem Thread hinter einem Wait. Die Attrappe
    -- laesst Threads nur bis zum ersten Wait laufen, also faellt die
    -- Nachricht dort nicht heraus - hier steht sie mit denselben Werten
    -- aus der echten Config.
    local daten = {
        { action = 'world:setup', data = {
            showClock = WorldConfig.Hud.showClock,
            showMoon  = WorldConfig.Hud.showMoon,
            visible   = WorldConfig.Hud.enabled,
        } },
    }

    daten[#daten + 1] = { action = 'world:visible', value = true }
    daten[#daten + 1] = { action = 'world:time', data = {
        stunde = 21, minute = 14, nacht = true,
    } }
    daten[#daten + 1] = { action = 'world:phase', data = {
        id = 'blutmond', label = 'Blutmond', icon = '🌕',
        beschreibung = 'Der Mond steht rot. Vampire sind stark.',
    } }
    daten[#daten + 1] = { action = 'world:event', data = {
        id = 'nebel', label = 'Dichter Nebel', icon = '🌫️',
        beschreibung = 'Die Sicht ist schlecht.', endetIn = 900,
    } }

    ergebnisse['moonshine-world'] = daten
    print(('  %-24s %d Nachrichten'):format('moonshine-world',
        schreiben('moonshine-world', daten)))
end

-- --------------------------------------------------------------- Tod

do
    Fangen.Resource('moonshine-death', true)

    local daten = {
        { action = 'death', data = {
            text = 'Du liegst am Boden.',
            respawnAfter = 300, cost = 2500,
            refuge = 'Annas Unterschlupf',
        } },
        { action = 'deathUpdate', data = { seconds = 148, canRespawn = false } },
    }

    ergebnisse['moonshine-death'] = daten
    print(('  %-24s %d Nachrichten'):format('moonshine-death',
        schreiben('moonshine-death', daten)))
end

-- -------------------------------------------------------------- Laden

do
    Fangen.Resource('moonshine-shops', true)

    local daten = { { action = 'shop:open', data = {
        label = 'Kiosk Vinewood', money = 1240,
        items = {
            { name = 'wasser', label = 'Wasser', price = 12, weight = 500 },
            { name = 'brot',   label = 'Brot',   price = 18, weight = 400 },
            { name = 'verband', label = 'Verband', price = 90, weight = 200 },
        },
    } } }

    -- Der Name der Aktion muss zu dem passen, was das NUI erwartet.
    local html = io.open('resources/[moonshine]/moonshine-shops/nui/app.js', 'r')
    if html then
        local text = html:read('a')
        html:close()

        local aktion = text:match("action === '([^']+)'")
        if aktion then daten[1].action = aktion end
    end

    ergebnisse['moonshine-shops'] = daten
    print(('  %-24s %d Nachrichten'):format('moonshine-shops',
        schreiben('moonshine-shops', daten)))
end

-- ---------------------------------------------------------- Fraktionen

do
    Fangen.Nachrichten = {}
    Fangen.Resource('moonshine-factions', true)

    -- Faction.New ist lokal; der Weg fuehrt ueber Factions.Create, das
    -- ohne Datenbank nicht durchkommt. Also die Zeile direkt durch den
    -- Ladeweg schicken, den der Server beim Start ohnehin geht.
    local ok, fraktion = pcall(function()
        Factions.DB = Factions.DB or {}
        Factions.DB.Ready = true
        Factions.DB.LoadAll = function()
            return { {
                id = 1, name = 'Zirkel des Blutmonds', tag = 'ZDB',
                owner_id = 12, base = 'vinewood', emblem = 'null',
                ranks = 'null', skills = '{}', level = 4, xp = 3200,
                points = 6, kasse = 184000, vault = '[]',
            } }
        end
        Factions.DB.LoadMembers = function()
            return { { character_id = 12, name = 'Anna Voss', grade = 4,
                       contribution = 24000 },
                     { character_id = 99, name = 'Ruben Kast', grade = 2,
                       contribution = 8100 } }
        end
        Factions.DB.LoadVehicles = function() return {} end

        Factions.LoadAll()
        return Factions.Get(1)
    end)

    if ok and fraktion then
        -- Der Client legt die Daten beim Empfang nur ab und reicht sie erst
        -- weiter, wenn die Oberflaeche offen ist - das haengt an einer
        -- lokalen Variablen. Die beiden Nachrichten stehen deshalb hier;
        -- der Inhalt kommt aus der echten Aufbaufunktion.
        local daten = {
            { action = 'factions:open' },
            { action = 'factions:data', data = fraktion:GetPayload(1) },
        }

        ergebnisse['moonshine-factions'] = daten
        print(('  %-24s %d Nachrichten'):format('moonshine-factions',
            schreiben('moonshine-factions', daten)))
    else
        print(('  %-24s keine Fraktion: %s'):format('moonshine-factions',
            tostring(fraktion)))
    end
end

-- ------------------------------------------------------------- Aussehen

do
    Fangen.Nachrichten = {}
    Fangen.Resource('moonshine-appearance', true)

    Fangen.Spieler.appearance = {}
    Fangen.Spieler.gender = 'w'

    Appearance.DB = Appearance.DB or {}
    Appearance.DB.LoadOutfits = function()
        return { { id = 1, label = 'Arbeitskleidung' },
                 { id = 2, label = 'Ausgehen' } }
    end

    local daten = {}

    local ok, err = pcall(function()
        TriggerClientEvent('appearance:client:open', 1, {
            kind = 'shop', label = 'Bekleidung Vinewood',
            categories = { 'kleidung', 'accessoires' },
            -- Bewusst der Zustand eines frischen Charakters: in der
            -- Datenbank steht appearance = {}. Appearance.Of macht daraus
            -- ein vollstaendiges Aussehen - genau das war der Fehler.
            gender = 'w', appearance = Appearance.Of(Fangen.Spieler),
            outfits = { { id = 1, label = 'Arbeitskleidung' } },
            maxOutfits = AppearanceConfig.MaxOutfits,
            prices = { kleidung = 120, accessoires = 90, outfitSlot = 500 },
            balance = 48900,
            data = {
                components  = Appearance.Components,
                props       = Appearance.Props,
                overlays    = Appearance.Overlays,
                features    = Appearance.Features,
                parents     = Appearance.Parents,
                hairColours = Appearance.HairColours,
                eyeColours  = Appearance.EyeColours,
            },
        })
    end)

    for _, nachricht in ipairs(Fangen.Nachrichten) do
        daten[#daten + 1] = nachricht
    end

    if #daten > 0 then
        ergebnisse['moonshine-appearance'] = daten
        print(('  %-24s %d Nachrichten'):format('moonshine-appearance',
            schreiben('moonshine-appearance', daten)))
    else
        print(('  %-24s nichts: %s'):format('moonshine-appearance', tostring(err)))
    end
end

print(('\nFertig. %s/'):format(ZIEL))
