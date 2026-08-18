--- Fraktionen: Einstellungen.

Factions = Factions or {}

FactionConfig = {}

FactionConfig.Debug = false

--- Taste und Command fuer die Oberflaeche.
FactionConfig.OpenKey = 'F10'
FactionConfig.Command = 'fraktion'

-- Gruendung -------------------------------------------------------------------
FactionConfig.Create = {
    -- Kosten der Gruendung.
    price   = 500000,
    account = 'bank',
    -- Mindestlaenge von Name und Kuerzel.
    minName = 4,
    maxName = 28,
    minTag  = 2,
    maxTag  = 4,
    -- Ab welchem Adminlevel man Fraktionen ohne Kosten anlegen darf.
    adminLevel = 3,
}

-- Mitglieder ------------------------------------------------------------------
FactionConfig.Members = {
    -- Grundzahl an Plaetzen; der Skilltree kann sie erhoehen.
    baseSlots = 20,
    -- Einladungen verfallen nach dieser Zeit (Sekunden).
    inviteTimeout = 60,
}

-- Kasse -----------------------------------------------------------------------
FactionConfig.Kasse = {
    -- Konto, von dem Ein- und Auszahlungen laufen.
    account = 'bank',
    -- Hoechstbetrag je Auszahlung.
    maxWithdraw = 250000,
}

-- Tresor ----------------------------------------------------------------------
FactionConfig.Vault = {
    -- Grundplaetze; der Skilltree kann sie erhoehen.
    baseSlots = 60,
    maxWeight = 500000,
}

-- Fraktionslevel --------------------------------------------------------------
FactionConfig.Level = {
    maxLevel = 30,
    xpBase   = 2500,
    xpStep   = 1800,
    -- Skillpunkte je Stufe.
    pointsPerLevel = 1,
    -- Kosten fuer das Zuruecksetzen des Fraktionsbaums.
    resetCost = 250000,
}

-- Shop ------------------------------------------------------------------------
FactionConfig.Shop = {
    enabled = true,
    -- Wird aus der Kasse bezahlt.
    account = 'kasse',
    items = {
        { name = 'medikit',     price = 2500,  label = 'Medikit' },
        { name = 'bread',       price = 250,   label = 'Brot' },
        { name = 'water',       price = 200,   label = 'Wasser' },
        { name = 'runenstein',  price = 1200,  label = 'Runenstein' },
        { name = 'seelenstein', price = 1200,  label = 'Seelenstein' },
        { name = 'repairkit',   price = 4500,  label = 'Reparaturkit' },
    },
}

-- Garage ----------------------------------------------------------------------
FactionConfig.Garage = {
    enabled = true,
    -- Grundzahl an Fahrzeugplaetzen.
    baseSlots = 6,
    -- Kaufbare Fahrzeuge; Preis kommt aus der Kasse.
    vehicles = {
        { model = 'sultan',   label = 'Sultan',    price = 120000, minRank = 2 },
        { model = 'buffalo3', label = 'Buffalo S', price = 180000, minRank = 2 },
        { model = 'baller',   label = 'Baller',    price = 260000, minRank = 3 },
        { model = 'rumpo',    label = 'Rumpo',     price =  95000, minRank = 1 },
        { model = 'kuruma',   label = 'Kuruma',    price = 320000, minRank = 4 },
        { model = 'oracle',   label = 'Oracle',    price = 140000, minRank = 2 },
    },
    -- Ausgabepunkte der Garage.
    points = {
        { label = 'Hafen',      coords = vector3(  -60.0, -1096.0, 26.4), heading = 340.0 },
        { label = 'Sandy',      coords = vector3( 1737.0,  3306.0, 41.2), heading = 195.0 },
        { label = 'Paleto',     coords = vector3(  -50.0,  6420.0, 31.5), heading =  45.0 },
        { label = 'Vinewood',   coords = vector3(  216.0,  -810.0, 31.0), heading = 250.0 },
    },
}

-- Basis / Interaktionspunkte ---------------------------------------------------
--- Jede Fraktion bekommt beim Gruenden einen dieser Punkte zugewiesen.
FactionConfig.Bases = {
    { id = 'hafen',    label = 'Hafenlager',    coords = vector3(  -49.0, -1096.0, 26.4) },
    { id = 'sandy',    label = 'Sandy Depot',   coords = vector3( 1727.0,  3312.0, 41.2) },
    { id = 'paleto',   label = 'Paleto Halle',  coords = vector3(  -37.0,  6428.0, 31.5) },
    { id = 'vinewood', label = 'Vinewood Loft', coords = vector3(  227.0,  -805.0, 31.0) },
    { id = 'mirror',   label = 'Mirror Park',   coords = vector3( 1145.0,  -344.0, 68.0) },
    { id = 'grapes',   label = 'Grapeseed',     coords = vector3( 1701.0,  4924.0, 42.0) },
}

-- Gebiete ----------------------------------------------------------------------
FactionConfig.Territory = {
    enabled = true,
    -- Dauer einer Einnahme in Sekunden.
    captureTime = 180,
    -- So viele Mitglieder muessen im Gebiet stehen.
    minAttackers = 1,
    -- Ein eingenommenes Gebiet ist so lange geschuetzt (Minuten).
    protection = 30,
    -- Einkommen wird alle X Minuten ausgeschuettet.
    payoutInterval = 15,
    -- Gebietsfortschritt faellt ohne Angreifer so schnell zurueck (pro Sekunde).
    decay = 1.5,
    -- Sichtbarkeitsradius fuer die Gebietsanzeige.
    hudRange = 260.0,
}

-- Missionen ---------------------------------------------------------------------
FactionConfig.Missions = {
    enabled = true,
    -- So viele Fraktionsmissionen laufen gleichzeitig.
    active = 3,
    -- Zeitraum: taeglicher Reset zur gleichen Stunde wie im Fortschrittssystem.
    resetHour = 4,
}

--- Standardfarben der Fraktion.
FactionConfig.DefaultColors = {
    primary   = '#9b6bd8',
    secondary = '#1a1424',
}
