--- Gebiete, die Fraktionen einnehmen und halten koennen.
---
--- Jedes Gebiet hat einen Mittelpunkt, einen Radius, ein Einkommen je
--- Ausschuettung und eine Farbe fuer die Karte. Wer es haelt, kassiert.

Factions.Territories = {
    { id = 'hafen',    label = 'Hafenviertel',   icon = '⚓',
      coords = vector3(  -180.0, -2450.0, 6.0),  radius = 130.0,
      income = 12000, xp = 220,
      description = 'Container, Kraene und alles, was nachts hier verladen wird.' },

    { id = 'vinewood', label = 'Vinewood Hills', icon = '🌟',
      coords = vector3(   -8.0,   730.0, 190.0), radius = 150.0,
      income = 15000, xp = 260,
      description = 'Villen, Partys und sehr viel Geld in sehr wenigen Haenden.' },

    { id = 'sandy',    label = 'Sandy Shores',   icon = '🏜',
      coords = vector3( 1960.0,  3740.0, 32.0),  radius = 160.0,
      income = 9000,  xp = 180,
      description = 'Staub, Meth und ein Flugfeld, das niemand kontrolliert.' },

    { id = 'paleto',   label = 'Paleto Bay',     icon = '🌲',
      coords = vector3(  -280.0,  6230.0, 31.0), radius = 150.0,
      income = 9500,  xp = 190,
      description = 'Waldrand, Saegewerk und der einzige Weg in den Norden.' },

    { id = 'grove',    label = 'Grove Street',   icon = '🏘',
      coords = vector3(  110.0, -1930.0, 21.0),  radius = 120.0,
      income = 11000, xp = 210,
      description = 'Enge Strassen, lange Geschichten, kurze Geduld.' },

    { id = 'mirror',   label = 'Mirror Park',    icon = '🎭',
      coords = vector3( 1140.0,  -670.0, 57.0),  radius = 120.0,
      income = 10500, xp = 200,
      description = 'Bars, Studios und Leute, die zu viel wissen.' },

    { id = 'raffinerie', label = 'Raffinerie',   icon = '🛢',
      coords = vector3( 2700.0,  1520.0, 24.0),  radius = 170.0,
      income = 16000, xp = 300,
      description = 'Der Ort mit dem hoechsten Einsatz und dem groessten Knall.' },

    { id = 'observatorium', label = 'Observatorium', icon = '🔭',
      coords = vector3( -430.0,  1140.0, 326.0),  radius = 110.0,
      income = 13000, xp = 240,
      description = 'Ein Ort der Kraft. Mystiker streiten sich seit jeher darum.' },
}

Factions.TerritoryById = {}
for _, entry in ipairs(Factions.Territories) do
    Factions.TerritoryById[entry.id] = entry
end

function Factions.GetTerritory(id)
    if type(id) ~= 'string' then return nil end
    return Factions.TerritoryById[id]
end

--- Gesamteinkommen einer Gebietsliste.
function Factions.TerritoryIncome(ids)
    local total = 0

    for _, id in ipairs(ids or {}) do
        local territory = Factions.GetTerritory(id)
        if territory then total = total + territory.income end
    end

    return total
end
