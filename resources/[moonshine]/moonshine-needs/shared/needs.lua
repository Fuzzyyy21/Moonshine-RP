--- Was jede Klasse braucht und wie sie drankommt.
---
--- `sources` beschreibt die Wege, den Wert zu fuellen:
---
---   item      Gegenstand benutzen
---   npc       an einem Passanten in der Naehe
---   downed    an einem bewusstlosen Spieler
---   zone      passiv an bestimmten Orten
---   meditate  beim Meditieren am Ritualpunkt
---   boss      beim Erlegen eines Weltbosses
---   kill      wenn jemand durch die eigene Hand faellt

Needs.Definitions = {

    vampir = {
        id = 'blut', label = 'Blutdurst', icon = '🩸', colour = '#a3232c',
        description = 'Ohne fremdes Blut wirst du schwach und dann wahnsinnig.',
        decayPerTick = 1.2,
        sources = {
            { kind = 'downed', label = 'Von einem Bewusstlosen trinken',
              amount = 40, duration = 6 },
            { kind = 'npc',    label = 'Einen Passanten aussaugen',
              amount = 22, duration = 5 },
            { kind = 'item',   item = 'blutkonserve', amount = 30 },
        },
    },

    werwolf = {
        id = 'fleisch', label = 'Hunger auf Fleisch', icon = '🥩', colour = '#8c4a2f',
        description = 'Das Tier in dir frisst roh oder gar nicht.',
        decayPerTick = 1.0,
        sources = {
            { kind = 'item', item = 'rohes_fleisch', amount = 35 },
            { kind = 'npc',  label = 'Ein Tier reissen', amount = 45,
              duration = 7, animals = true },
            { kind = 'boss', amount = 25 },
        },
    },

    magier = {
        id = 'mana', label = 'Manafluss', icon = '🔷', colour = '#3d8bd4',
        description = 'Magie zehrt. Ohne Nachschub versiegt die Quelle.',
        decayPerTick = 0.9,
        sources = {
            { kind = 'meditate', amount = 45 },
            { kind = 'item',     item = 'manakristall', amount = 40 },
            { kind = 'zone',     zone = 'kraftort', amount = 2.5 },
        },
    },

    hexer = {
        id = 'reagenzien', label = 'Reagenzien', icon = '🧪', colour = '#7d4a9e',
        description = 'Ohne Zutaten bleibt jeder Zauber ein Wunsch.',
        decayPerTick = 0.8,
        sources = {
            { kind = 'item',     item = 'kraeuter', amount = 30 },
            { kind = 'zone',     zone = 'natur', amount = 1.6 },
            { kind = 'meditate', amount = 25 },
        },
    },

    fee = {
        id = 'naturnaehe', label = 'Naturnaehe', icon = '🌿', colour = '#4caf7d',
        description = 'Zu lange in der Stadt und dein Licht erlischt.',
        decayPerTick = 1.4,
        sources = {
            { kind = 'zone', zone = 'natur',    amount = 3.5 },
            { kind = 'zone', zone = 'kraftort', amount = 2.0 },
            { kind = 'item', item = 'kraeuter', amount = 20 },
        },
    },

    daemon = {
        id = 'seelen', label = 'Seelenhunger', icon = '👹', colour = '#c8541e',
        description = 'Du naehrst dich von dem, was andere verlieren.',
        decayPerTick = 0.9,
        sources = {
            { kind = 'kill', amount = 30 },
            { kind = 'boss', amount = 40 },
            { kind = 'item', item = 'seelensplitter', amount = 35 },
        },
    },

    nekromant = {
        id = 'totenkraft', label = 'Totenkraft', icon = '⚰', colour = '#8e5bbd',
        description = 'Die Toten geben dir Kraft. Nur musst du bei ihnen sein.',
        decayPerTick = 1.0,
        sources = {
            { kind = 'zone',   zone = 'friedhof', amount = 3.0 },
            { kind = 'downed', label = 'Kraft aus einem Sterbenden ziehen',
              amount = 35, duration = 6 },
            { kind = 'item',   item = 'totenasche', amount = 35 },
        },
    },

    jaeger = {
        id = 'vorraete', label = 'Vorraete', icon = '🎯', colour = '#b5853a',
        description = 'Kein Jaeger ohne Ausruestung. Und die geht zur Neige.',
        decayPerTick = 0.7,
        sources = {
            { kind = 'boss', amount = 45 },
            { kind = 'item', item = 'jagdvorrat', amount = 40 },
            { kind = 'kill', amount = 15 },
        },
    },
}

--- Zonenarten und wo sie liegen.
Needs.Zones = {
    natur = {
        label = 'Natur', icon = '🌲',
        orte = {
            { label = 'Nationalpark',     coords = vector3( -1600.0, 4500.0, 60.0),  radius = 700.0 },
            { label = 'Chiliad-Suedhang', coords = vector3(   400.0, 5600.0, 550.0), radius = 600.0 },
            { label = 'Grosser Zuckerhut',coords = vector3( -1000.0, 4400.0, 220.0), radius = 500.0 },
            { label = 'Vinewood-Huegel',  coords = vector3(   500.0, 1500.0, 300.0), radius = 450.0 },
            { label = 'Raton Canyon',     coords = vector3( -1400.0, 4200.0, 60.0),  radius = 400.0 },
            { label = 'Legion Square',    coords = vector3(   200.0, -930.0, 30.0),  radius = 60.0 },
            { label = 'Vespucci-Park',    coords = vector3( -1250.0, -1300.0, 5.0),  radius = 120.0 },
            { label = 'Mirror-Park-See',  coords = vector3(  1100.0, -700.0, 57.0),  radius = 150.0 },
        },
    },

    kraftort = {
        label = 'Ort der Kraft', icon = '✦',
        -- Die Ritualpunkte selbst sind Kraftorte. Wird beim Start ergaenzt.
        orte = {
            { label = 'Observatorium', coords = vector3(-430.0, 1140.0, 326.0), radius = 90.0 },
        },
    },

    friedhof = {
        label = 'Friedhof', icon = '🪦',
        orte = {
            { label = 'Vinewood-Friedhof', coords = vector3(-1660.0, -260.0, 52.0), radius = 120.0 },
            { label = 'Little-Seoul-Kapelle', coords = vector3(-320.0, -1050.0, 30.0), radius = 70.0 },
            { label = 'Sandy-Shores-Friedhof', coords = vector3(1780.0, 3230.0, 42.0), radius = 90.0 },
            { label = 'Paleto-Friedhof', coords = vector3(-320.0, 6300.0, 31.0), radius = 80.0 },
        },
    },
}

--- Gegenstaende, die ein Beduerfnis fuellen.
Needs.Items = {
    blutkonserve   = { label = 'Blutkonserve',  weight = 400,
                       description = 'Kalt, aber es haelt dich aufrecht.' },
    rohes_fleisch  = { label = 'Rohes Fleisch', weight = 900,
                       description = 'Blutig. Genau richtig.' },
    manakristall   = { label = 'Manakristall',  weight = 300,
                       description = 'Summt leise, wenn man ihn haelt.' },
    kraeuter       = { label = 'Kraeuterbund',  weight = 200,
                       description = 'Frisch gepflueckt, noch feucht.' },
    seelensplitter = { label = 'Seelensplitter',weight = 150,
                       description = 'Etwas darin will heraus.' },
    totenasche     = { label = 'Totenasche',    weight = 250,
                       description = 'Von einem Scheiterhaufen, der lange brannte.' },
    jagdvorrat     = { label = 'Jagdvorrat',    weight = 1200,
                       description = 'Munition, Fallen, Verbandszeug.' },
}

--- Beduerfnis einer Klasse.
function Needs.Get(race)
    if type(race) ~= 'string' then return nil end
    return Needs.Definitions[race]
end

--- Alle Quellen einer bestimmten Art fuer diese Klasse.
function Needs.GetSources(race, kind)
    local definition = Needs.Get(race)
    if not definition then return {} end

    local out = {}
    for _, source in ipairs(definition.sources) do
        if not kind or source.kind == kind then out[#out + 1] = source end
    end

    return out
end

--- Erste Quelle einer Art, oder nil.
function Needs.GetSource(race, kind)
    return Needs.GetSources(race, kind)[1]
end

--- Welches Item fuellt welches Beduerfnis?
---@return string|nil race
function Needs.RaceForItem(itemName)
    for race, definition in pairs(Needs.Definitions) do
        for _, source in ipairs(definition.sources) do
            if source.kind == 'item' and source.item == itemName then return race end
        end
    end

    return nil
end

--- In welcher Zone liegt dieser Punkt?
---@return string|nil art, table|nil ort
function Needs.ZoneAt(coords)
    for art, zone in pairs(Needs.Zones) do
        for _, ort in ipairs(zone.orte) do
            if #(coords - ort.coords) <= ort.radius then return art, ort end
        end
    end

    return nil, nil
end

--- Fuellt eine Zone dieser Klasse? Liefert die Menge je Tick.
function Needs.ZoneAmount(race, art)
    for _, source in ipairs(Needs.GetSources(race, 'zone')) do
        if source.zone == art then return source.amount end
    end

    return 0
end
