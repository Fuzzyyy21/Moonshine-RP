--- Auftragsdefinitionen.
---
--- Jeder Job hat einen Anmeldepunkt, optional ein Arbeitsfahrzeug und eine
--- Liste moeglicher Stationen. Eine Schicht zieht daraus zufaellig
--- WorkConfig.Shift.stops Stationen und arbeitet sie der Reihe nach ab.
---
---   requiresJob  Nur mit diesem Job im Core (nil = jeder darf)
---   action       Was an einer Station passiert: 'liefern', 'sammeln',
---                'absetzen', 'reparieren'
---   pay          Grundlohn je Station
---   finalPay     Zusatz beim Abmelden

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
}

Work.Order = { 'trucker', 'garbage', 'taxi', 'post' }

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

--- Zieht `count` zufaellige Stationen, ohne Wiederholung.
function Work.PickStops(definition, count)
    local pool = {}
    for index, stop in ipairs(definition.stops) do pool[index] = stop end

    for index = #pool, 2, -1 do
        local swap = math.random(index)
        pool[index], pool[swap] = pool[swap], pool[index]
    end

    local picked = {}
    for index = 1, math.min(count, #pool) do picked[index] = pool[index] end

    return picked
end
