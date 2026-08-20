--- Zufluchtsorte.
---
--- Kein Housing im ueblichen Sinn: keine Wohnung mit Kueche, kein Klingelschild.
--- Ein Zufluchtsort ist der Platz, an den eine Klasse gehoert - ein Sarg in
--- einer Gruft, eine Hoehle am Berg, ein Turm ueber der Stadt.
---
--- Er kann drei Dinge:
---   * Lagern    - ein eigenes Lager fuer Steine und alles andere
---   * Rasten    - Essenz und Leben voll, dazu ein Segen auf Zeit
---   * Zuflucht  - bewusstlos hierher aufwachen statt ins Krankenhaus

Refuge = Refuge or {}

RefugeConfig = {}

RefugeConfig.Debug = false

--- Reichweite fuer Marker und Interaktion.
RefugeConfig.Range = 2.2

--- Konto, ueber das gekauft wird.
RefugeConfig.Account = 'bank'

--- So viele Zufluchtsorte darf ein Charakter halten. Einer reicht - sonst
--- kauft der erste Spieler mit Geld die Karte leer.
RefugeConfig.MaxPerCharacter = 1

-- Lager ------------------------------------------------------------------------
RefugeConfig.Stash = {
    baseSlots  = 40,
    maxWeight  = 150000,

    -- Ausbaustufen: je Stufe mehr Plaetze, je Stufe teurer.
    ausbau = {
        { slots = 20, preis = 45000 },
        { slots = 20, preis = 90000 },
        { slots = 30, preis = 180000 },
    },
}

-- Rasten -------------------------------------------------------------------------
RefugeConfig.Rest = {
    enabled = true,

    -- Wie lange die Rast dauert (Sekunden, Bildschirm bleibt schwarz).
    duration = 18,

    -- Abklingzeit zwischen zwei Rasten (Minuten).
    cooldown = 45,

    -- Wie lange der Segen danach haelt (Minuten).
    segenDauer = 30,

    -- Segen an einem Ort, der nicht zur Klasse passt.
    segen = {
        regenPerTick = 0.4,
        essenceRegen = 0.5,
        xpBonus      = 0.10,
    },

    -- Segen am passenden Ort. Ein Vampir in einer Gruft schlaeft besser als
    -- ein Vampir in einer Jagdhuette.
    segenPassend = {
        regenPerTick = 0.9,
        essenceRegen = 1.2,
        xpBonus      = 0.25,
    },
}

-- Zuflucht statt Krankenhaus --------------------------------------------------------
RefugeConfig.Respawn = {
    enabled = true,

    -- Wer nach Hause kriecht, zahlt keine Behandlungskosten.
    kostenlos = true,

    -- Danach ist der Zufluchtsort so lange erschoepft (Minuten).
    cooldown = 20,
}

-- Arten ------------------------------------------------------------------------------
--- Wie der Zufluchtsort einer Klasse heisst - und welche Ortsart zu ihr passt.
--- `ort` verweist auf die `art` eines Platzes in shared/places.lua.
RefugeConfig.Kinds = {
    vampir    = { label = 'Sarg',        icon = '⚰',  ort = 'gruft',      ruhe = 'Du legst dich in den Sarg.' },
    nekromant = { label = 'Gruft',       icon = '💀', ort = 'gruft',      ruhe = 'Du steigst hinab zu den Toten.' },
    werwolf   = { label = 'Bau',         icon = '🐺', ort = 'hoehle',     ruhe = 'Du rollst dich im Bau zusammen.' },
    daemon    = { label = 'Schlund',     icon = '🔥', ort = 'keller',     ruhe = 'Du sinkst in die Glut.' },
    fee       = { label = 'Hain',        icon = '🧚', ort = 'hain',       ruhe = 'Du loest dich zwischen den Baeumen auf.' },
    magier    = { label = 'Turm',        icon = '🔮', ort = 'turm',       ruhe = 'Du ziehst dich in den Turm zurueck.' },
    hexer     = { label = 'Zirkelhaus',  icon = '🕯', ort = 'ruine',      ruhe = 'Du entzuendest die Kerzen.' },
    jaeger    = { label = 'Jagdhuette',  icon = '🏹', ort = 'huette',     ruhe = 'Du legst die Waffen ab.' },
}

--- Fuer alle ohne Klasse.
RefugeConfig.DefaultKind = {
    label = 'Unterschlupf', icon = '🏚', ort = nil,
    ruhe = 'Du legst dich hin.',
}

-- Blip -------------------------------------------------------------------------------
RefugeConfig.Blip = {
    -- Freie Plaetze sieht jeder.
    frei    = { enabled = true, sprite = 40, colour = 0,  scale = 0.6 },
    -- Den eigenen Ort sieht nur der Besitzer.
    eigener = { enabled = true, sprite = 40, colour = 27, scale = 0.8 },
}

-- Zugriff --------------------------------------------------------------------------------

--- Wie der Zufluchtsort dieser Klasse heisst.
---@param race string|nil
function Refuge.GetKind(race)
    return RefugeConfig.Kinds[race or ''] or RefugeConfig.DefaultKind
end

--- Passt dieser Platz zur Klasse?
---@param race string|nil
---@param art string
function Refuge.Fits(race, art)
    local kind = RefugeConfig.Kinds[race or '']
    return kind ~= nil and kind.ort == art
end

--- Wie viele Plaetze ein Lager auf dieser Ausbaustufe hat.
---@param stufe number 0 = ohne Ausbau
function Refuge.GetSlots(stufe)
    local slots = RefugeConfig.Stash.baseSlots

    for index = 1, math.min(math.floor(tonumber(stufe) or 0), #RefugeConfig.Stash.ausbau) do
        slots = slots + RefugeConfig.Stash.ausbau[index].slots
    end

    return slots
end

--- Was der naechste Ausbau kostet. nil = voll ausgebaut.
function Refuge.GetUpgradePrice(stufe)
    local naechste = math.floor(tonumber(stufe) or 0) + 1
    local eintrag = RefugeConfig.Stash.ausbau[naechste]

    return eintrag and eintrag.preis or nil
end

--- Der Segen einer Rast, je nachdem ob der Ort passt.
function Refuge.GetBlessing(race, art)
    local config = RefugeConfig.Rest

    if Refuge.Fits(race, art) then return config.segenPassend, true end
    return config.segen, false
end
