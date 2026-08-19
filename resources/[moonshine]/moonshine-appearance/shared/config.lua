--- Aussehen: Editor, Laeden, Friseure.

Appearance = Appearance or {}

AppearanceConfig = {}

AppearanceConfig.Debug = false

--- Reichweite fuer Marker und Interaktion.
AppearanceConfig.Range = 2.2

--- Kamera im Editor.
AppearanceConfig.Camera = {
    -- Abstand und Hoehe je Ansicht.
    views = {
        kopf   = { offset = 0.62,  height = 0.68, fov = 26.0 },
        koerper= { offset = 1.55,  height = 0.25, fov = 42.0 },
        beine  = { offset = 1.35,  height = -0.55, fov = 40.0 },
        ganz   = { offset = 2.60,  height = 0.10, fov = 50.0 },
    },
    default = 'ganz',
}

-- Kleidungslaeden ------------------------------------------------------------------
--- `categories` bestimmt, was hier gekauft werden darf.
AppearanceConfig.Shops = {
    {
        id = 'binco_innenstadt', label = 'Binco', tier = 'guenstig',
        coords = vector3(  75.0, -1392.0, 29.4),
        categories = { 'kleidung', 'accessoires' },
        blip = { sprite = 73, colour = 47, scale = 0.7 },
    },
    {
        id = 'binco_hafen', label = 'Binco Hafen', tier = 'guenstig',
        coords = vector3(  -822.0, -1073.0, 11.3),
        categories = { 'kleidung', 'accessoires' },
        blip = { sprite = 73, colour = 47, scale = 0.7 },
    },
    {
        id = 'suburban', label = 'Suburban', tier = 'mittel',
        coords = vector3(  127.0,  -224.0, 54.6),
        categories = { 'kleidung', 'accessoires' },
        blip = { sprite = 73, colour = 47, scale = 0.7 },
    },
    {
        id = 'ponsonbys', label = 'Ponsonbys', tier = 'teuer',
        coords = vector3( -709.0,  -152.0, 37.4),
        categories = { 'kleidung', 'accessoires' },
        blip = { sprite = 73, colour = 5, scale = 0.7 },
    },
    {
        id = 'sandy', label = 'Kleidung Sandy Shores', tier = 'guenstig',
        coords = vector3( 1696.0,  4823.0, 42.1),
        categories = { 'kleidung', 'accessoires' },
        blip = { sprite = 73, colour = 47, scale = 0.7 },
    },
    {
        id = 'paleto', label = 'Kleidung Paleto Bay', tier = 'guenstig',
        coords = vector3(  -822.0,  6497.0, 28.7),
        categories = { 'kleidung', 'accessoires' },
        blip = { sprite = 73, colour = 47, scale = 0.7 },
    },
}

-- Friseure ---------------------------------------------------------------------------
AppearanceConfig.Barbers = {
    { id = 'hairhaven',  label = 'Hair on Haven',
      coords = vector3( -814.0, -183.0, 37.6) },
    { id = 'herrfriseur',label = 'Herr Friseur',
      coords = vector3( -278.0,  6228.0, 31.7) },
    { id = 'beachcombover', label = 'Beach Combover',
      coords = vector3( -1282.0, -1117.0, 7.0) },
    { id = 'baypointe', label = 'Bay Pointe',
      coords = vector3( 1931.0,  3729.0, 32.9) },
    { id = 'oscoy',     label = "O'Sheas",
      coords = vector3( 136.0,  -1708.0, 29.3) },
}

AppearanceConfig.BarberBlip = {
    enabled = true, sprite = 71, colour = 25, scale = 0.65, label = 'Friseur',
}

-- Taetowierer ---------------------------------------------------------------------------
AppearanceConfig.TattooShops = {
    { id = 'blackbird',  label = 'Blackbird Ink',
      coords = vector3( 1322.6, -1651.9, 52.3) },
    { id = 'hafenstich', label = 'Hafenstich',
      coords = vector3( -1153.1, -1425.4, 4.9) },
    { id = 'vespucci',   label = 'Nadel und Faden',
      coords = vector3( -293.0, 6200.2, 31.5) },
    { id = 'sandynadel', label = 'Sandy Nadel',
      coords = vector3( 1864.5, 3747.7, 33.0) },
    { id = 'elysian',    label = 'Elysian Ink',
      coords = vector3( 322.1, 180.5, 103.6) },
}

AppearanceConfig.TattooBlip = {
    enabled = true, sprite = 75, colour = 1, scale = 0.65, label = 'Tätowierer',
}

-- Preise --------------------------------------------------------------------------------
AppearanceConfig.Prices = {
    account = 'bank',

    -- Je Kategorie und Ladenstufe.
    kleidung = { guenstig = 250, mittel = 900, teuer = 3500 },
    accessoires = { guenstig = 150, mittel = 600, teuer = 2200 },

    -- Friseur: einmal zahlen, so oft aendern wie man will.
    friseur = 1200,

    -- Der Editor beim ersten Charakter ist umsonst.
    ersteErstellung = 0,

    -- Outfit speichern.
    outfitSlot = 500,

    -- Taetowierung, je nach Groesse der Zone.
    tattoo = { klein = 2500, mittel = 6000, gross = 12000 },

    -- Aufschlag fuer ein Klassenmal.
    tattooMal = 3.0,

    -- Wegmachen kostet mehr als stechen - Laser statt Nadel.
    tattooEntfernen = 1.6,
}

--- So viele Outfits darf ein Charakter speichern.
AppearanceConfig.MaxOutfits = 10

--- Umkleide-Punkte, an denen man kostenlos Outfits wechselt.
AppearanceConfig.Wardrobes = {
    { label = 'Umkleide Innenstadt', coords = vector3(  215.0, -805.0, 30.8) },
    { label = 'Umkleide Hafen',      coords = vector3(  -60.0, -1090.0, 26.4) },
    { label = 'Umkleide Sandy',      coords = vector3( 1740.0, 3320.0, 41.2) },
    { label = 'Umkleide Paleto',     coords = vector3(  110.0, 6618.0, 31.8) },
}

--- Preis fuer eine Kategorie in einem Laden.
function Appearance.GetPrice(category, tier)
    local table_ = AppearanceConfig.Prices[category]
    if type(table_) ~= 'table' then return 0 end

    return table_[tier or 'guenstig'] or table_.guenstig or 0
end
