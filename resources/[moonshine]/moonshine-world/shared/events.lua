--- Mystische Weltereignisse.
---
--- Ein Ereignis laeuft eine Weile, faerbt Himmel und Wetter, veraendert die
--- Kraefte einzelner Klassen und greift in die uebrigen Systeme ein
--- (Bossintervall, Ritualertrag, Beutechance).
---
--- Felder je Ereignis:
---   duration    Dauer in Minuten Echtzeit
---   weight      Gewicht bei der Auswahl
---   weather     erzwungenes Wetter
---   forceHour   erzwungene Uhrzeit (optional)
---   freezeTime  Zeit steht waehrend des Ereignisses still
---   timecycle   Timecycle-Effekt fuer den Client
---   tint        Farbe fuer die Anzeige
---   races       Modifikatoren je Klasse
---   global      Modifikatoren fuer alle
---   world       Eingriffe in andere Systeme

World.Events = {

    {
        id = 'blutmond', label = 'Blutmond', icon = '🌕',
        headline = 'Der Mond faerbt sich rot.',
        description = 'Die Nacht gehoert den Jaegern und den Gejagten. '
            .. 'Blut und Wut sind naeher an der Oberflaeche als sonst.',
        duration = 20, weight = 10,
        weather = 'THUNDER', forceHour = 1, freezeTime = true,
        timecycle = 'eyeinthesky', tint = '#a3232c',
        races = {
            vampir  = { damageMult = 0.20, meleeMult = 0.20, essenceRegen = 0.8,
                        lifesteal = 0.05 },
            werwolf = { damageMult = 0.20, speedMult = 0.06, healthBonus = 40 },
            jaeger  = { critChance = 0.08, critBonus = 0.15, lootChance = 0.08 },
        },
        global = { lootChance = 0.08, xpBonus = 0.25 },
        world  = { bossInterval = 0.5, stoneBonus = 1, ritualBonus = 0.5 },
    },

    {
        id = 'sonnenfinsternis', label = 'Sonnenfinsternis', icon = '🌘',
        headline = 'Die Sonne verschwindet am helllichten Tag.',
        description = 'Das Sonnenlicht verliert seine Kraft. Vampire atmen auf, '
            .. 'die Magie liegt offen wie selten.',
        duration = 12, weight = 8,
        weather = 'OVERCAST', forceHour = 13, freezeTime = true,
        timecycle = 'Mp_Bkr_Bus_Interior', tint = '#3b3550',
        races = {
            vampir = { sunImmune = true, damageMult = 0.10, essenceRegen = 0.5 },
            magier = { costMult = -0.20, cooldownMult = -0.15, essenceRegen = 0.6 },
            hexer  = { costMult = -0.15, damageMult = 0.10 },
        },
        global = { essenceRegen = 0.3 },
        world  = { sunlightDamage = 0.0, ritualBonus = 0.75 },
    },

    {
        id = 'nebelnacht', label = 'Nebelnacht', icon = '🌫',
        headline = 'Ein Nebel zieht auf, der nicht von hier ist.',
        description = 'Man sieht kaum die Hand vor Augen. Was sich darin bewegt, '
            .. 'bewegt sich ungesehen.',
        duration = 18, weight = 12,
        weather = 'FOGGY', forceHour = 3, freezeTime = false,
        timecycle = 'prologue_ending_fog', tint = '#6d7f8c',
        races = {
            nekromant = { damageMult = 0.15, essenceRegen = 0.6 },
            hexer     = { cooldownMult = -0.12, essenceRegen = 0.4 },
            vampir    = { speedMult = 0.05 },
        },
        global = { speedMult = 0.03 },
        world  = { stoneBonus = 1 },
    },

    {
        id = 'sternenfall', label = 'Sternenfall', icon = '✨',
        headline = 'Der Himmel faellt in Streifen herab.',
        description = 'Wer jetzt meditiert, hoert mehr als sonst. '
            .. 'Die Grenze zwischen den Welten ist duenn.',
        duration = 15, weight = 12,
        weather = 'EXTRASUNNY', forceHour = 23, freezeTime = true,
        timecycle = 'lightning', tint = '#d8b25f',
        races = {
            fee    = { essenceRegen = 0.8, speedMult = 0.06, regenPerTick = 0.4 },
            magier = { essenceRegen = 0.6, costMult = -0.10 },
        },
        global = { xpBonus = 0.40, meditationBonus = 0.60 },
        world  = { ritualBonus = 1.0 },
    },

    {
        id = 'aschesturm', label = 'Aschesturm', icon = '🔥',
        headline = 'Asche regnet vom Himmel und es riecht nach Schwefel.',
        description = 'Etwas brennt, das nicht brennen sollte. '
            .. 'Die Daemonen wittern Heimat.',
        duration = 14, weight = 9,
        weather = 'SMOG', forceHour = 18, freezeTime = false,
        timecycle = 'Trevor3_Grain', tint = '#c8541e',
        races = {
            daemon = { damageMult = 0.25, meleeMult = 0.20, fireImmune = true,
                       essenceRegen = 0.8 },
            hexer  = { damageMult = 0.08 },
            fee    = { damageMult = -0.10, essenceRegen = -0.3 },
        },
        global = { damageMult = -0.05 },
        world  = { bossInterval = 0.7, stoneBonus = 1 },
    },

    {
        id = 'geisterstunde', label = 'Geisterstunde', icon = '👻',
        headline = 'Es ist drei Uhr nachts. Ueberall.',
        description = 'Die Toten kommen naeher an die Lebenden heran, '
            .. 'als es ihnen zusteht.',
        duration = 10, weight = 10,
        weather = 'CLEARING', forceHour = 3, freezeTime = true,
        timecycle = 'spectator5', tint = '#8e5bbd',
        races = {
            nekromant = { damageMult = 0.30, essenceRegen = 1.0, healthBonus = 30 },
            hexer     = { damageMult = 0.15, costMult = -0.15 },
            jaeger    = { damageMult = 0.10, critChance = 0.05 },
        },
        global = { lootChance = 0.10 },
        world  = { stoneBonus = 2, bossInterval = 0.6 },
    },

    {
        id = 'nordlicht', label = 'Nordlicht', icon = '🌌',
        headline = 'Gruenes Licht steht ueber dem Horizont.',
        description = 'Ein Vorhang aus Farbe. Wer Magie spuert, spuert sie jetzt '
            .. 'ueberall.',
        duration = 20, weight = 11,
        weather = 'CLEAR', forceHour = 2, freezeTime = true,
        timecycle = 'CAMERA_secuirity_FUZZ', tint = '#5fc9a6',
        races = {
            fee    = { essenceRegen = 1.0, regenPerTick = 0.5, speedMult = 0.05 },
            magier = { essenceRegen = 1.0, costMult = -0.20, damageMult = 0.12 },
            hexer  = { essenceRegen = 0.5 },
        },
        global = { essenceRegen = 0.6, meditationBonus = 0.30 },
        world  = { ritualBonus = 0.5 },
    },

    {
        id = 'wilde_jagd', label = 'Wilde Jagd', icon = '🐺',
        headline = 'Etwas jagt heute Nacht. Und es ist nicht allein.',
        description = 'Rudel und Orden sind unterwegs. Wer klug ist, '
            .. 'schliesst sich an oder bleibt drinnen.',
        duration = 16, weight = 10,
        weather = 'RAIN', forceHour = 22, freezeTime = false,
        timecycle = 'Bikers_Dark', tint = '#7d5a33',
        races = {
            werwolf = { damageMult = 0.25, speedMult = 0.10, meleeMult = 0.20,
                        healthBonus = 35 },
            jaeger  = { damageMult = 0.20, critChance = 0.10, lootChance = 0.10 },
            vampir  = { speedMult = 0.05 },
        },
        global = { moneyBonus = 0.20 },
        world  = { bossInterval = 0.4, stoneBonus = 1 },
    },
}

World.EventById = {}
for _, event in ipairs(World.Events) do
    World.EventById[event.id] = event
end

function World.GetEvent(id)
    if type(id) ~= 'string' then return nil end
    return World.EventById[id]
end

--- Standardwerte fuer die Welt-Eingriffe.
function World.DefaultWorldEffects()
    return {
        bossInterval   = 1.0,   -- Multiplikator auf die Wartezeit
        stoneBonus     = 0,     -- zusaetzliche Steine je Boss
        ritualBonus    = 0.0,   -- Anteil mehr Ertrag am Ritualpunkt
        sunlightDamage = 1.0,   -- Multiplikator auf den Sonnenschaden
    }
end

--- Fasst Mondphase und laufendes Ereignis zu einem Satz Modifikatoren
--- fuer eine bestimmte Klasse zusammen.
---@param raceName string|nil
---@param phaseId string|nil
---@param eventId string|nil
---@return table
function World.BuildModifiers(raceName, phaseId, eventId)
    local mods = {}

    local function apply(source)
        for key, value in pairs(source or {}) do
            if type(value) == 'number' then
                mods[key] = (mods[key] or 0) + value
            elseif type(value) == 'boolean' then
                mods[key] = mods[key] or value
            end
        end
    end

    local phase = World.GetPhase(phaseId)
    if phase then
        apply(phase.global)
        if raceName then apply(phase.races[raceName]) end
    end

    local event = World.GetEvent(eventId)
    if event then
        apply(event.global)
        if raceName then apply(event.races[raceName]) end
    end

    return mods
end

--- Die Welt-Eingriffe des laufenden Ereignisses.
function World.BuildWorldEffects(eventId)
    local effects = World.DefaultWorldEffects()

    local event = World.GetEvent(eventId)
    if not event then return effects end

    for key, value in pairs(event.world or {}) do
        if key == 'bossInterval' or key == 'sunlightDamage' then
            effects[key] = value
        else
            effects[key] = (effects[key] or 0) + value
        end
    end

    return effects
end

--- Beschreibt ein Ereignis als Liste kurzer Zeilen (fuer die Anzeige).
function World.DescribeEvent(event, raceName)
    local LABELS = {
        damageMult      = '%+d %% Schaden',
        meleeMult       = '%+d %% Nahkampfschaden',
        speedMult       = '%+d %% Tempo',
        essenceRegen    = '%+.1f Essenz je Tick',
        regenPerTick    = '%+.1f Lebensregeneration',
        healthBonus     = '%+d Leben',
        costMult        = '%+d %% Essenzkosten',
        cooldownMult    = '%+d %% Abklingzeit',
        critChance      = '%+d %% kritische Trefferchance',
        critBonus       = '%+d %% kritischer Schaden',
        lifesteal       = '%+d %% Lebensentzug',
        lootChance      = '%+d %% Beutechance',
        xpBonus         = '%+d %% Erfahrung',
        moneyBonus      = '%+d %% Geld',
        meditationBonus = '%+d %% Meditationspunkte',
    }

    local PERCENT = {
        damageMult = true, meleeMult = true, speedMult = true, costMult = true,
        cooldownMult = true, critChance = true, critBonus = true, lifesteal = true,
        lootChance = true, xpBonus = true, moneyBonus = true, meditationBonus = true,
    }

    local lines = {}

    local function collect(source, scope)
        for key, value in pairs(source or {}) do
            local label = LABELS[key]

            if label and type(value) == 'number' and value ~= 0 then
                local text = PERCENT[key]
                    and label:format(math.floor(value * 100 + (value < 0 and -0.5 or 0.5)))
                    or label:format(value)

                lines[#lines + 1] = { text = text, scope = scope }
            elseif key == 'sunImmune' and value then
                lines[#lines + 1] = { text = 'Kein Schaden durch Sonnenlicht', scope = scope }
            elseif key == 'fireImmune' and value then
                lines[#lines + 1] = { text = 'Kein Schaden durch Feuer', scope = scope }
            end
        end
    end

    collect(event.global, 'alle')
    if raceName then collect(event.races[raceName], 'deine Klasse') end

    return lines
end
