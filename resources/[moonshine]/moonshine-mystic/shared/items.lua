--- Ritualsteine. Sie werden zur Laufzeit im Core registriert, damit
--- moonshine-core unveraendert bleibt.

Mystic.Stones = {
    runenstein = {
        label = 'Runenstein', weight = 150,
        description = 'Grundwaehrung jedes Rituals.',
    },
    seelenstein = {
        label = 'Seelenstein', weight = 200,
        description = 'In ihm schimmert eine gefangene Seele.',
    },
    blutstein = {
        label = 'Blutstein', weight = 220,
        description = 'Warm und feucht. Vampire spueren ihn auf Entfernung.',
    },
    mondstein = {
        label = 'Mondstein', weight = 220,
        description = 'Leuchtet nur bei Nacht. Herz jeder Wandlung.',
    },
    flammenstein = {
        label = 'Flammenstein', weight = 240,
        description = 'Glimmt von innen. Daemonisches Handwerk.',
    },
    feenstaub = {
        label = 'Feenstaub', weight = 60,
        description = 'Feiner Staub, der von selbst schwebt.',
    },
    arkanstein = {
        label = 'Arkanstein', weight = 200,
        description = 'Gebuendelte Magie in kristalliner Form.',
    },
    schattenstein = {
        label = 'Schattenstein', weight = 210,
        description = 'Verschluckt jedes Licht in seiner Naehe.',
    },
    hexenstein = {
        label = 'Hexenstein', weight = 200,
        description = 'Riecht nach Kraeutern und alten Fluechen.',
    },
    silberstein = {
        label = 'Silberstein', weight = 250,
        description = 'Gesegnetes Silber. Wesen meiden ihn.',
    },
}

--- Klassenstein: Waehrung des jeweiligen Skilltrees. Die Meditation laesst
--- ihn bei Spielern dieser Klasse haeufiger fallen.
Mystic.RaceStones = {
    vampir    = 'blutstein',
    werwolf   = 'mondstein',
    daemon    = 'flammenstein',
    fee       = 'feenstaub',
    magier    = 'arkanstein',
    hexer     = 'hexenstein',
    nekromant = 'schattenstein',
    jaeger    = 'silberstein',
}

--- Klassenstein einer Klasse, inklusive Anzeigename.
function Mystic.GetClassStone(race)
    local name = Mystic.RaceStones[race]
    if not name then return nil end

    return name, Mystic.Stones[name] and Mystic.Stones[name].label or name
end

--- Registriert alle Steine als Items im Core.
--- Muss auf Server und Client laufen (jeweils eigener Lua-State).
--- Laeuft mit Wiederholung, falls der Core noch nicht bereit ist.
function Mystic.RegisterStones()
    CreateThread(function()
        for _ = 1, 10 do
            local ok = pcall(function()
                for name, stone in pairs(Mystic.Stones) do
                    exports['moonshine-core']:RegisterItem(name, {
                        label       = stone.label,
                        weight      = stone.weight,
                        stack       = true,
                        usable      = false,
                        description = stone.description,
                    })
                end
            end)

            if ok then return end
            Wait(1000)
        end

        print('^1[Mystic]^7 Steine konnten nicht im Core registriert werden.')
    end)
end

--- Lesbare Auflistung von Steinkosten: "2x Runenstein, 1x Blutstein".
function Mystic.FormatStones(stones)
    local parts = {}

    for name, count in pairs(stones or {}) do
        local stone = Mystic.Stones[name]
        parts[#parts + 1] = ('%dx %s'):format(count, stone and stone.label or name)
    end

    table.sort(parts)
    return table.concat(parts, ', ')
end
