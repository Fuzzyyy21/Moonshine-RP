--- Steinadern: Fundorte fuer Ritualsteine.

NodeConfig = {}

-- Werkzeug -------------------------------------------------------------------
NodeConfig.Tool = {
    item     = 'runenmeissel',
    label    = 'Runenmeissel',
    required = true,
    -- Wahrscheinlichkeit, dass der Meissel beim Abbau zerbricht (0 = nie).
    breakChance = 0.04,
}

-- Abbau ----------------------------------------------------------------------
NodeConfig.Mining = {
    duration    = 9,     -- Sekunden je Versuch
    range       = 2.2,   -- Reichweite zur Ader
    respawn     = 600,   -- Sekunden bis eine erschoepfte Ader zurueckkommt
    chargesMin  = 2,     -- Abbauversuche je Ader
    chargesMax  = 4,
    -- Sichtweite fuer Marker und 3D-Text.
    drawDistance = 40.0,
}

-- Adertypen ------------------------------------------------------------------
-- loot: gewichtete Ausbeute, genau ein Eintrag faellt je Versuch.
NodeConfig.Types = {
    runenader = {
        label = 'Runenader',
        color = { 150, 130, 200 },
        loot  = {
            { item = 'runenstein',  count = 1, weight = 55 },
            { item = 'runenstein',  count = 2, weight = 30 },
            { item = 'seelenstein', count = 1, weight = 15 },
        },
    },

    seelenader = {
        label = 'Seelenader',
        color = { 120, 200, 190 },
        loot  = {
            { item = 'seelenstein', count = 1, weight = 60 },
            { item = 'runenstein',  count = 2, weight = 30 },
            { item = 'seelenstein', count = 2, weight = 10 },
        },
    },

    --- Klassenader: liefert bevorzugt den Stein der eigenen Klasse.
    klassenader = {
        label      = 'Verwunschene Ader',
        color      = { 210, 120, 80 },
        classStone = true,
        loot = {
            { item = 'runenstein',  count = 2, weight = 45 },
            { item = 'seelenstein', count = 1, weight = 25 },
        },
        -- Gewicht des Klassensteins in derselben Verlosung.
        classWeight = 30,
    },

    --- Verfluchte Ader: beste Ausbeute, kostet aber Lebensenergie.
    fluchader = {
        label      = 'Verfluchte Ader',
        color      = { 200, 60, 60 },
        classStone = true,
        classWeight = 45,
        damage     = 15,   -- Schaden je Abbauversuch
        loot = {
            { item = 'runenstein',  count = 3, weight = 35 },
            { item = 'seelenstein', count = 2, weight = 20 },
        },
    },
}

-- Fundorte -------------------------------------------------------------------
-- Koordinaten sind Richtwerte und sollten im Spiel geprueft werden.
NodeConfig.Nodes = {
    -- Bergbau und Steinbruch
    { type = 'runenader',   coords = vector3(2949.6, 2795.5, 41.2) },
    { type = 'runenader',   coords = vector3(2921.1, 2792.0, 41.0) },
    { type = 'runenader',   coords = vector3(-595.3, 2091.1, 131.3) },
    { type = 'runenader',   coords = vector3(-479.4, 1946.7, 175.9) },
    { type = 'runenader',   coords = vector3(1108.2, -2007.8, 34.6) },

    -- Hoehlen und Kueste
    { type = 'seelenader',  coords = vector3(3599.1, 3745.5, 28.7) },
    { type = 'seelenader',  coords = vector3(-3155.2, 1127.0, 20.8) },
    { type = 'seelenader',  coords = vector3(1387.4, 3608.9, 34.9) },

    -- Waelder und Berge
    { type = 'klassenader', coords = vector3(-1583.6, 4726.9, 58.5) },
    { type = 'klassenader', coords = vector3(-243.6, 6444.6, 31.5) },
    { type = 'klassenader', coords = vector3(510.7, 5604.1, 797.9) },

    -- Verfluchte Orte
    { type = 'fluchader',   coords = vector3(-1690.4, -216.3, 56.3) },
    { type = 'fluchader',   coords = vector3(-1131.9, 4936.1, 222.9) },
}

-- Anzeige --------------------------------------------------------------------
NodeConfig.Blips = {
    -- Adern sind standardmaessig nicht auf der Karte; sie muessen gefunden werden.
    enabled = false,
    sprite  = 618,
    color   = 27,
    scale   = 0.6,
}

--- Klassen mit "Wittern"-artigen Skills sehen Adern weiter (Meter).
NodeConfig.SenseDistance = 120.0
