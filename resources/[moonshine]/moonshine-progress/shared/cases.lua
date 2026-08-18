--- Kisten mit gewichteter Ausbeute.
---
--- Jede Kiste ist ein Item im Core-Inventar und wird in der Oberflaeche
--- geoeffnet. Die Ausbeute wuerfelt der Server.

Progress.Cases = {
    holz = {
        label = 'Holzkiste', icon = '📦', color = '#a1743c', weight = 800,
        description = 'Einfache Kiste mit bescheidenem Inhalt.',
        loot = {
            { weight = 30, label = '2.500 $',        reward = { money = 2500 } },
            { weight = 25, label = '5.000 $',        reward = { money = 5000 } },
            { weight = 20, label = '1x Runenstein',  reward = { items = { { name = 'runenstein', count = 1 } } } },
            { weight = 12, label = '2x Runenstein',  reward = { items = { { name = 'runenstein', count = 2 } } } },
            { weight = 8,  label = '1x Seelenstein', reward = { items = { { name = 'seelenstein', count = 1 } } } },
            { weight = 5,  label = '150 Pass-XP',    reward = { bpxp = 150 } },
        },
    },

    silber = {
        label = 'Silberkiste', icon = '🎁', color = '#b9c2cf', weight = 900,
        description = 'Solide Kiste mit brauchbarer Ausbeute.',
        loot = {
            { weight = 25, label = '10.000 $',       reward = { money = 10000 } },
            { weight = 20, label = '18.000 $',       reward = { money = 18000 } },
            { weight = 20, label = '3x Runenstein',  reward = { items = { { name = 'runenstein', count = 3 } } } },
            { weight = 15, label = '3x Seelenstein', reward = { items = { { name = 'seelenstein', count = 3 } } } },
            { weight = 10, label = '400 Pass-XP',    reward = { bpxp = 400 } },
            { weight = 7,  label = 'Goldkiste',      reward = { cases = { gold = 1 } } },
            { weight = 3,  label = '5x Seelenstein', reward = { items = { { name = 'seelenstein', count = 5 } } } },
        },
    },

    gold = {
        label = 'Goldkiste', icon = '🏆', color = '#e0b13c', weight = 1000,
        description = 'Wertvolle Kiste. Hier lohnt sich das Oeffnen.',
        loot = {
            { weight = 22, label = '35.000 $',        reward = { money = 35000 } },
            { weight = 20, label = '60.000 $',        reward = { money = 60000 } },
            { weight = 18, label = '6x Runenstein',   reward = { items = { { name = 'runenstein', count = 6 } } } },
            { weight = 15, label = '6x Seelenstein',  reward = { items = { { name = 'seelenstein', count = 6 } } } },
            { weight = 12, label = '900 Pass-XP',     reward = { bpxp = 900 } },
            { weight = 8,  label = '10x Runenstein',  reward = { items = { { name = 'runenstein', count = 10 } } } },
            { weight = 5,  label = 'Mystische Kiste', reward = { cases = { mystisch = 1 } } },
        },
    },

    mystisch = {
        label = 'Mystische Kiste', icon = '🔮', color = '#9b6bd8', weight = 1200,
        description = 'Selten und unberechenbar. Enthaelt das Beste, was es gibt.',
        loot = {
            { weight = 25, label = '120.000 $',        reward = { money = 120000 } },
            { weight = 20, label = '15x Runenstein',   reward = { items = { { name = 'runenstein', count = 15 } } } },
            { weight = 20, label = '15x Seelenstein',  reward = { items = { { name = 'seelenstein', count = 15 } } } },
            { weight = 15, label = '2.500 Pass-XP',    reward = { bpxp = 2500 } },
            { weight = 12, label = '200.000 $',        reward = { money = 200000 } },
            { weight = 8,  label = 'Grosses Steinpaket',
              reward = { items = { { name = 'runenstein', count = 20 }, { name = 'seelenstein', count = 20 } } } },
        },
    },
}

--- Kistendefinition oder nil.
function Progress.GetCase(name)
    if type(name) ~= 'string' then return nil end
    return Progress.Cases[name]
end

--- Reihenfolge fuer die Oberflaeche.
Progress.CaseOrder = { 'holz', 'silber', 'gold', 'mystisch' }

--- Registriert die Kisten als Items im Core (Server und Client).
---@return boolean ok
function Progress.RegisterCaseItems()
    return pcall(function()
        for name, entry in pairs(Progress.Cases) do
            exports['moonshine-core']:RegisterItem('kiste_' .. name, {
                label       = entry.label,
                weight      = entry.weight,
                stack       = true,
                usable      = true,
                description = entry.description,
            })
        end
    end)
end

--- Itemname einer Kiste.
function Progress.GetCaseItem(name)
    return 'kiste_' .. name
end
