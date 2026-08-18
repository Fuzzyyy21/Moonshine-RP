--- Orte: Tankstellen, Werkstaetten, Bankfilialen, Geldautomaten,
--- Schwarzmarkt-Standorte.

-- Tankstellen ------------------------------------------------------------------
--- `coords` ist der Kassenpunkt, `pumps` sind die Zapfsaeulen.
Services.FuelStations = {
    { label = 'Tankstelle Strawberry',   coords = vector3(  265.0, -1261.0, 29.3),
      pumps = { vector3( 265.9, -1261.1, 29.2), vector3( 273.0, -1257.0, 29.2),
                vector3( 269.0, -1266.0, 29.2) } },

    { label = 'Tankstelle Grove',        coords = vector3(  -70.0, -1761.0, 29.5),
      pumps = { vector3( -70.2, -1761.8, 29.4), vector3( -63.0, -1757.0, 29.4),
                vector3( -74.0, -1767.0, 29.4) } },

    { label = 'Tankstelle Little Seoul', coords = vector3( -724.0,  -935.0, 19.2),
      pumps = { vector3(-724.6, -935.1, 19.1), vector3( -718.0, -930.0, 19.1) } },

    { label = 'Tankstelle Vinewood',     coords = vector3(  620.0,  269.0, 103.1),
      pumps = { vector3( 620.8,  269.0, 103.0), vector3( 616.0,  263.0, 103.0) } },

    { label = 'Tankstelle Sandy Shores', coords = vector3( 1208.0, 2660.0, 37.9),
      pumps = { vector3(1208.9, 2660.2, 37.8), vector3(1203.0, 2655.0, 37.8) } },

    { label = 'Tankstelle Harmony',      coords = vector3(  265.0, 2606.0, 44.9),
      pumps = { vector3( 265.9, 2606.5, 44.8), vector3( 260.0, 2601.0, 44.8) } },

    { label = 'Tankstelle Paleto Bay',   coords = vector3(  179.0, 6602.0, 31.9),
      pumps = { vector3( 179.9, 6602.8, 31.8), vector3( 174.0, 6597.0, 31.8) } },

    { label = 'Tankstelle Route 68',     coords = vector3( 1039.0, 2671.0, 39.6),
      pumps = { vector3(1039.9, 2671.2, 39.5), vector3(1034.0, 2666.0, 39.5) } },

    { label = 'Tankstelle Grapeseed',    coords = vector3( 1701.0, 4929.0, 42.1),
      pumps = { vector3(1701.9, 4929.5, 42.0), vector3(1696.0, 4924.0, 42.0) } },
}

-- Werkstaetten --------------------------------------------------------------------
Services.Workshops = {
    { id = 'bennys',   label = 'Bennys Werkstatt',
      coords = vector3( -205.0, -1310.0, 31.3) },

    { id = 'hafen',    label = 'Werkstatt Hafen',
      coords = vector3(  -35.0, -1103.0, 26.4) },

    { id = 'sandy',    label = 'Werkstatt Sandy Shores',
      coords = vector3( 1175.0, 2640.0, 37.8) },

    { id = 'paleto',   label = 'Werkstatt Paleto Bay',
      coords = vector3(  110.0, 6621.0, 31.8) },
}

-- Bankfilialen ------------------------------------------------------------------------
Services.Banks = {
    { id = 'fleeca_legion',  label = 'Fleeca Legion Square',
      coords = vector3(  149.0, -1040.0, 29.4) },

    { id = 'fleeca_hawick',  label = 'Fleeca Hawick',
      coords = vector3(  313.0, -279.0, 54.2) },

    { id = 'fleeca_alta',    label = 'Fleeca Alta Street',
      coords = vector3( -351.0, -49.0, 49.0) },

    { id = 'fleeca_route68', label = 'Fleeca Route 68',
      coords = vector3( 1175.0, 2706.0, 38.1) },

    { id = 'fleeca_paleto',  label = 'Fleeca Paleto Bay',
      coords = vector3( -111.0, 6470.0, 31.6) },

    { id = 'pacific',        label = 'Pacific Standard',
      coords = vector3(  241.0, 225.0, 106.3) },
}

-- Geldautomaten ------------------------------------------------------------------
Services.Atms = {
    vector3(  147.4, -1035.8, 29.3),
    vector3(  -57.6,  -92.7,  57.8),
    vector3(  527.5, -160.6,  57.1),
    vector3( -821.6, -1081.9, 11.1),
    vector3(  289.0,  143.0,  104.2),
    vector3( -351.5,  -49.5,  49.0),
    vector3(  112.8, -776.9,  31.4),
    vector3( -660.0, -853.0,  24.5),
    vector3( 1686.8, 4815.9,  42.0),
    vector3( 1735.0, 6410.0,  35.0),
    vector3(-2072.0, -317.0,  13.3),
    vector3(  296.0, -895.0,  29.2),
    vector3( 1153.0, -326.0,  69.2),
    vector3(-1315.0, -835.0,  17.0),
    vector3( 1822.0, 3683.0,  34.3),
    vector3(-2295.0,  355.0,  174.6),
}

-- Schwarzmarkt-Standorte --------------------------------------------------------------------
--- Der Markt steht immer nur an einem davon.
Services.BlackMarkets = {
    { id = 'muelldeponie', label = 'Muelldeponie',
      coords = vector3(-322.0, -1545.0, 31.0), heading = 265.0 },

    { id = 'hafenlager',   label = 'Hafenlager',
      coords = vector3( 887.0, -3200.0, 5.9), heading = 90.0 },

    { id = 'steinbruch',   label = 'Steinbruch',
      coords = vector3(2932.0,  2790.0, 41.0), heading = 200.0 },

    { id = 'sumpf',        label = 'Sumpfhuette',
      coords = vector3(-1108.0, 4941.0, 218.0), heading = 30.0 },

    { id = 'tunnel',       label = 'Alter Tunnel',
      coords = vector3( 500.0, -616.0, 24.5), heading = 175.0 },

    { id = 'chumash',      label = 'Chumash Pier',
      coords = vector3(-3232.0, 1000.0, 12.4), heading = 120.0 },
}
