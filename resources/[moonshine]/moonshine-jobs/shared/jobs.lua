--- Auftragsdefinitionen.
---
--- Jeder Job hat einen Anmeldepunkt, optional ein Arbeitsfahrzeug und eine
--- Liste moeglicher Stationen. Eine Schicht zieht daraus zufaellig
--- WorkConfig.Shift.stops Stationen und arbeitet sie der Reihe nach ab.
---
---   requiresJob  Nur mit diesem Job im Core (nil = jeder darf)
---   action       Was an einer Station passiert: 'liefern', 'sammeln',
---                'absetzen', 'verladen', 'sichern'
---   pay          Grundlohn je Station
---   finalPay     Zusatz beim Abmelden
---
--- Drei Felder aendern den Ablauf selbst:
---   passengers   Vor jeder Station wird jemand aufgenommen (Taxi)
---   fixedRoute   Stationen der Reihe nach statt zufaellig (Bus)
---   abliefern    Nach jeder Station zurueck zum Anmeldepunkt (Abschlepper)
---   nurNachts    Schicht laesst sich nur nachts beginnen (Nachtwache)

Work.Definitions = {

    -- Spedition -----------------------------------------------------------
    trucker = {
        id = 'trucker', label = 'Spedition', icon = '🚚',
        description = 'Fracht vom Lager zu den Filialen. Lange Wege, ruhige Arbeit.',
        requiresJob = 'trucker',
        colour = '#d8b25f',

        start = { label = 'Speditionslager', coords = vector3(  -424.0, -2790.0, 6.0) },

        vehicle = {
            model = 'mule',
            spawn = vector4(-437.0, -2777.0, 6.0, 85.0),
            label = 'Lieferwagen',
        },

        action = 'liefern',
        actionLabel = 'Fracht abladen',
        duration = 6,
        pay = 420,
        finalPay = 900,

        stops = {
            { label = 'Supermarkt Vespucci', coords = vector3( -1223.0, -906.0, 12.3) },
            { label = 'Laden Little Seoul',  coords = vector3(  -709.0, -904.0, 19.2) },
            { label = 'Laden Innenstadt',    coords = vector3(   373.0,  325.0, 103.6) },
            { label = 'Laden Mirror Park',   coords = vector3(  1163.0, -323.0, 69.2) },
            { label = 'Laden Grove',         coords = vector3(   -47.0, -1758.0, 29.4) },
            { label = 'Laden Sandy Shores',  coords = vector3(  1961.0, 3740.0, 32.3) },
            { label = 'Laden Paleto Bay',    coords = vector3(  -160.0, 6320.0, 31.6) },
            { label = 'Laden Grapeseed',     coords = vector3(  1698.0, 4924.0, 42.1) },
            { label = 'Laden Chumash',       coords = vector3( -3242.0, 1001.0, 12.8) },
            { label = 'Laden Harmony',       coords = vector3(   547.0, 2671.0, 42.2) },
        },
    },

    -- Muellabfuhr ----------------------------------------------------------
    garbage = {
        id = 'garbage', label = 'Muellabfuhr', icon = '🗑',
        description = 'Tonnen leeren, Route abfahren. Niemand dankt es dir.',
        requiresJob = nil,
        colour = '#5fc98a',

        start = { label = 'Muelldepot', coords = vector3( -322.0, -1545.0, 31.0) },

        vehicle = {
            model = 'trash',
            spawn = vector4(-338.0, -1553.0, 25.0, 265.0),
            label = 'Muellwagen',
        },

        action = 'sammeln',
        actionLabel = 'Tonne leeren',
        duration = 5,
        pay = 285,
        finalPay = 600,

        stops = {
            { label = 'Alta Street',       coords = vector3(  -321.0,  -95.0, 57.0) },
            { label = 'Vespucci Boulevard',coords = vector3(  -900.0, -700.0, 20.0) },
            { label = 'Mirror Park',       coords = vector3(  1108.0, -400.0, 67.0) },
            { label = 'Vinewood Hills',    coords = vector3(   -50.0,  700.0, 200.0) },
            { label = 'Little Seoul',      coords = vector3(  -650.0, -880.0, 24.0) },
            { label = 'Strawberry',        coords = vector3(   180.0,-1740.0, 29.0) },
            { label = 'Rancho',            coords = vector3(   400.0,-1900.0, 27.0) },
            { label = 'La Mesa',           coords = vector3(   820.0,-1100.0, 27.0) },
            { label = 'Del Perro',         coords = vector3( -1400.0, -600.0, 30.0) },
            { label = 'Morningwood',       coords = vector3( -1250.0, -350.0, 37.0) },
        },
    },

    -- Taxi ------------------------------------------------------------------
    taxi = {
        id = 'taxi', label = 'Taxi', icon = '🚕',
        description = 'Fahrgaeste aufsammeln und ans Ziel bringen. Kurze Wege, gutes Geld.',
        requiresJob = nil,
        colour = '#e0b13c',

        start = { label = 'Downtown Cab Co.', coords = vector3(  895.0, -179.0, 74.7) },

        vehicle = {
            model = 'taxi',
            spawn = vector4(908.0, -170.0, 74.2, 235.0),
            label = 'Taxi',
        },

        -- Beim Taxi ist jede Station ein Fahrgast: einsteigen, dann Ziel.
        action = 'absetzen',
        actionLabel = 'Fahrgast absetzen',
        duration = 3,
        pay = 340,
        finalPay = 700,
        -- Zusatzlohn je Kilometer zwischen Aufnahme und Ziel.
        payPerKilometer = 180,
        passengers = true,
        passengerModels = { 'a_m_y_business_01', 'a_f_y_business_02',
                            'a_m_m_tourist_01', 'a_f_y_hipster_01',
                            'a_m_y_skater_01', 'a_f_m_bevhills_01' },

        stops = {
            { label = 'Legion Square',   coords = vector3(  195.0, -935.0, 30.7) },
            { label = 'Del Perro Pier',  coords = vector3(-1850.0, -1240.0, 13.0) },
            { label = 'Flughafen',       coords = vector3(-1037.0, -2737.0, 20.2) },
            { label = 'Vinewood Bowl',   coords = vector3(  686.0,  577.0, 130.5) },
            { label = 'Krankenhaus',     coords = vector3(  295.0, -584.0, 43.3) },
            { label = 'Casino',          coords = vector3(  925.0,   46.0, 81.1) },
            { label = 'Strand Vespucci', coords = vector3(-1223.0, -1500.0, 4.4) },
            { label = 'Maze Bank',       coords = vector3( -75.0,  -820.0, 326.2) },
            { label = 'Sandy Shores',    coords = vector3( 1961.0, 3740.0, 32.3) },
            { label = 'Paleto Bay',      coords = vector3( -160.0, 6320.0, 31.6) },
        },
    },

    -- Post -------------------------------------------------------------------
    post = {
        id = 'post', label = 'Postdienst', icon = '📮',
        description = 'Pakete austragen. Viele kurze Stopps, wenig Aufwand.',
        requiresJob = nil,
        colour = '#5fa9c9',

        start = { label = 'Postzentrale', coords = vector3(  75.0, 113.0, 81.2) },

        vehicle = {
            model = 'boxville2',
            spawn = vector4(88.0, 106.0, 80.6, 340.0),
            label = 'Postwagen',
        },

        action = 'liefern',
        actionLabel = 'Paket zustellen',
        duration = 4,
        pay = 240,
        finalPay = 500,

        stops = {
            { label = 'Hawick Avenue',   coords = vector3(  330.0, -220.0, 54.1) },
            { label = 'Alta',            coords = vector3( -280.0,  -20.0, 50.0) },
            { label = 'Rockford Hills',  coords = vector3( -770.0,  -60.0, 40.0) },
            { label = 'West Vinewood',   coords = vector3( -620.0,  240.0, 81.0) },
            { label = 'Mirror Park',     coords = vector3( 1180.0, -350.0, 69.0) },
            { label = 'Murrieta Heights',coords = vector3(  980.0, -700.0, 58.0) },
            { label = 'Strawberry',      coords = vector3(  110.0,-1900.0, 21.0) },
            { label = 'Chamberlain',     coords = vector3(  -60.0,-1440.0, 32.0) },
            { label = 'Little Seoul',    coords = vector3( -580.0, -930.0, 24.0) },
            { label = 'Vespucci',        coords = vector3(-1180.0, -1080.0, 3.0) },
        },
    },

    -- Abschleppdienst ---------------------------------------------------------
    tow = {
        id = 'tow', label = 'Abschleppdienst', icon = '🪝',
        description = 'Liegengebliebene Fahrzeuge einsammeln. Jedes einzeln '
            .. 'zurueck zum Hof - das ist die halbe Arbeit.',
        requiresJob = nil,
        colour = '#e07b39',

        start = { label = 'Abschlepphof', coords = vector3( 409.0, -1622.0, 29.3) },

        vehicle = {
            model = 'flatbed',
            spawn = vector4(398.0, -1638.0, 29.3, 230.0),
            label = 'Abschleppwagen',
        },

        action = 'verladen',
        actionLabel = 'Fahrzeug verladen',
        duration = 8,
        pay = 520,
        finalPay = 1100,

        -- Was verladen ist, muss auch abgeliefert werden.
        abliefern = true,
        ablieferLabel = 'Fahrzeug abladen',

        stops = {
            { label = 'Panne Olympic Freeway',  coords = vector3(  -600.0, -1250.0, 12.0) },
            { label = 'Panne Route 68',         coords = vector3(  1230.0,  2700.0, 38.0) },
            { label = 'Unfall Elysian Fields',  coords = vector3(   180.0, -2600.0, 6.0) },
            { label = 'Panne Great Ocean Hwy',  coords = vector3( -2100.0,  1400.0, 200.0) },
            { label = 'Falschparker Vinewood',  coords = vector3(   300.0,   200.0, 88.0) },
            { label = 'Panne Senora Freeway',   coords = vector3(  2400.0,  3100.0, 48.0) },
            { label = 'Unfall Del Perro Fwy',   coords = vector3( -1300.0,  -400.0, 36.0) },
            { label = 'Panne Paleto',           coords = vector3(  -200.0,  6400.0, 31.0) },
            { label = 'Falschparker Hafen',     coords = vector3(   850.0, -2900.0, 5.0) },
            { label = 'Panne Grapeseed',        coords = vector3(  1700.0,  4800.0, 42.0) },
        },
    },

    -- Busfahrer -----------------------------------------------------------------
    bus = {
        id = 'bus', label = 'Busfahrer', icon = '🚌',
        description = 'Die Linie durch die Stadt, Haltestelle fuer Haltestelle. '
            .. 'Immer dieselbe Runde, immer dieselbe Reihenfolge.',
        requiresJob = nil,
        colour = '#4caf7d',

        start = { label = 'Busdepot', coords = vector3( 462.0, -601.0, 28.5) },

        vehicle = {
            model = 'bus',
            spawn = vector4(451.0, -613.0, 28.4, 180.0),
            label = 'Linienbus',
        },

        action = 'absetzen',
        actionLabel = 'Haltestelle anfahren',
        duration = 5,
        pay = 190,
        finalPay = 850,

        -- Eine Linie faehrt man der Reihe nach, nicht gewuerfelt.
        fixedRoute = true,

        stops = {
            { label = 'Haltestelle Legion Square',  coords = vector3(  216.0, -871.0, 30.5) },
            { label = 'Haltestelle Alta',           coords = vector3(  -50.0, -100.0, 57.0) },
            { label = 'Haltestelle Rockford Hills', coords = vector3( -800.0, -110.0, 37.0) },
            { label = 'Haltestelle Del Perro',      coords = vector3(-1400.0, -600.0, 30.0) },
            { label = 'Haltestelle Vespucci',       coords = vector3(-1200.0,-1450.0, 4.0) },
            { label = 'Haltestelle Flughafen',      coords = vector3(-1037.0,-2737.0, 20.0) },
            { label = 'Haltestelle Strawberry',     coords = vector3(  180.0,-1740.0, 29.0) },
            { label = 'Haltestelle La Mesa',        coords = vector3(  820.0,-1100.0, 27.0) },
            { label = 'Haltestelle Mirror Park',    coords = vector3( 1108.0, -400.0, 67.0) },
            { label = 'Haltestelle Vinewood',       coords = vector3(  300.0,  200.0, 88.0) },
        },
    },

    -- Nachtwache ------------------------------------------------------------------
    nachtwache = {
        id = 'nachtwache', label = 'Nachtwache', icon = '🕯',
        description = 'Die Ritualpunkte abgehen, solange es dunkel ist. '
            .. 'Bezahlt gut - es meldet sich nicht jeder freiwillig.',
        requiresJob = nil,
        colour = '#9b6bd8',

        start = { label = 'Wachhaus am Friedhof', coords = vector3(-1680.0, -217.0, 57.0) },

        vehicle = {
            model = 'burrito3',
            spawn = vector4(-1668.0, -228.0, 56.6, 320.0),
            label = 'Wachwagen',
        },

        action = 'sichern',
        actionLabel = 'Punkt sichern',
        duration = 10,
        pay = 780,
        finalPay = 1800,

        -- Tagsueber gibt es hier nichts zu bewachen.
        nurNachts = true,

        -- Dieselben sechs Punkte wie in der Mystik. Sie stehen hier noch
        -- einmal, weil moonshine-jobs die Mystik nicht mitlaedt - die
        -- Koordinaten gehoeren beim Nachmessen zusammen geaendert.
        stops = {
            { label = 'Vinewood Friedhof',   coords = vector3(-1671.2, -230.4, 55.1) },
            { label = 'Chiliad Gipfel',      coords = vector3(  450.9, 5566.5, 781.2) },
            { label = 'Altruisten Lager',    coords = vector3(-1170.5, 4926.6, 224.3) },
            { label = 'Kirche Sandy Shores', coords = vector3( 1972.4, 3815.5, 33.4) },
            { label = 'Leuchtturm Paleto',   coords = vector3( 3430.6, 5175.7, 21.0) },
            { label = 'Steinkreis Zancudo',  coords = vector3(-2295.1, 3384.3, 31.9) },
        },
    },
}

Work.Order = { 'trucker', 'garbage', 'taxi', 'post', 'tow', 'bus', 'nachtwache' }

function Work.GetJob(id)
    if type(id) ~= 'string' then return nil end
    return Work.Definitions[id]
end

--- Alle Jobs, die ein Spieler mit diesem Core-Job annehmen darf.
function Work.GetAvailable(coreJob)
    local list = {}

    for _, id in ipairs(Work.Order) do
        local definition = Work.Definitions[id]

        if not definition.requiresJob or definition.requiresJob == coreJob then
            list[#list + 1] = definition
        end
    end

    return list
end

--- Zieht `count` Stationen.
---
--- Eine Linie faehrt man der Reihe nach - beim Bus waere eine gewuerfelte
--- Route keine Linie mehr, sondern eine Schnitzeljagd.
function Work.PickStops(definition, count)
    local pool = {}
    for index, stop in ipairs(definition.stops) do pool[index] = stop end

    if definition.fixedRoute then
        local picked = {}
        for index = 1, math.min(count, #pool) do picked[index] = pool[index] end

        return picked
    end

    for index = #pool, 2, -1 do
        local swap = math.random(index)
        pool[index], pool[swap] = pool[swap], pool[index]
    end

    local picked = {}
    for index = 1, math.min(count, #pool) do picked[index] = pool[index] end

    return picked
end
