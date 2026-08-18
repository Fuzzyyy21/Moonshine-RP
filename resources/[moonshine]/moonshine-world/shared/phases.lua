--- Mondphasen.
---
--- Der Zyklus laeuft ueber acht Ingame-Tage. Jede Phase gibt einzelnen Klassen
--- einen kleinen, dauerhaften Vorteil - klein genug, dass niemand auf eine
--- bestimmte Nacht warten muss, gross genug, dass man es merkt.
---
--- Die Werte liegen in derselben Sprache vor wie die Modifikatoren im
--- Mystik-System und werden dort aufaddiert.

World.Phases = {
    {
        id = 'neumond', label = 'Neumond', icon = '🌑',
        description = 'Kein Licht am Himmel. Was sich verbirgt, verbirgt sich gut.',
        races = {
            nekromant = { essenceRegen = 0.3, damageMult = 0.06 },
            hexer     = { essenceRegen = 0.3, costMult = -0.05 },
            werwolf   = { damageMult = -0.05 },
        },
        global = { lootChance = 0.02 },
    },
    {
        id = 'zunehmende_sichel', label = 'Zunehmende Sichel', icon = '🌒',
        description = 'Ein schmaler Streifen Licht. Die Kraefte sammeln sich.',
        races = {
            werwolf = { damageMult = 0.03 },
            fee     = { essenceRegen = 0.2 },
        },
        global = {},
    },
    {
        id = 'erstes_viertel', label = 'Erstes Viertel', icon = '🌓',
        description = 'Halb hell, halb dunkel. Ein Gleichgewicht, das nicht haelt.',
        races = {
            magier = { costMult = -0.05 },
            jaeger = { critChance = 0.03 },
        },
        global = { essenceRegen = 0.1 },
    },
    {
        id = 'zunehmender_mond', label = 'Zunehmender Mond', icon = '🌔',
        description = 'Fast voll. Wer auf den Vollmond wartet, wird unruhig.',
        races = {
            werwolf = { damageMult = 0.06, speedMult = 0.02 },
            vampir  = { meleeMult = 0.05 },
        },
        global = {},
    },
    {
        id = 'vollmond', label = 'Vollmond', icon = '🌕',
        description = 'Die Nacht gehoert den Wandlern. Alles andere sucht Deckung.',
        races = {
            werwolf = { damageMult = 0.15, meleeMult = 0.15, speedMult = 0.05,
                        healthBonus = 25, regenPerTick = 0.4 },
            vampir  = { damageMult = 0.08, meleeMult = 0.08, essenceRegen = 0.4 },
            jaeger  = { critChance = 0.05, lootChance = 0.05 },
        },
        global = { lootChance = 0.05, xpBonus = 0.10 },
    },
    {
        id = 'abnehmender_mond', label = 'Abnehmender Mond', icon = '🌖',
        description = 'Das Licht zieht sich zurueck, die Wut mit ihm.',
        races = {
            werwolf   = { damageMult = 0.04 },
            nekromant = { essenceRegen = 0.2 },
        },
        global = {},
    },
    {
        id = 'letztes_viertel', label = 'Letztes Viertel', icon = '🌗',
        description = 'Wieder Gleichgewicht - diesmal auf dem Weg nach unten.',
        races = {
            hexer = { costMult = -0.05 },
            fee   = { essenceRegen = 0.25 },
        },
        global = { essenceRegen = 0.1 },
    },
    {
        id = 'abnehmende_sichel', label = 'Abnehmende Sichel', icon = '🌘',
        description = 'Der letzte Rest Licht. Danach beginnt alles von vorn.',
        races = {
            nekromant = { damageMult = 0.05 },
            daemon    = { essenceRegen = 0.25 },
        },
        global = { meditationBonus = 0.10 },
    },
}

World.PhaseById = {}
for index, phase in ipairs(World.Phases) do
    phase.index = index
    World.PhaseById[phase.id] = phase
end

--- Phase zu einem Ingame-Tag.
---@param day number Fortlaufender Tageszaehler
function World.GetPhaseForDay(day)
    local count = #World.Phases
    local index = (math.floor(day or 0) % count) + 1

    return World.Phases[index]
end

function World.GetPhase(id)
    if type(id) ~= 'string' then return nil end
    return World.PhaseById[id]
end

--- Ist gerade Vollmond?
function World.IsFullMoon(phaseId)
    return phaseId == 'vollmond'
end
