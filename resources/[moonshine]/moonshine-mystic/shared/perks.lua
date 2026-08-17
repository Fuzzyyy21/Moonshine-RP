--- Persoenliche Skills ("Perks").
--- Sie sind rassenunabhaengig und werden mit persoenlichen Punkten gekauft,
--- die es fuer Onlinezeit gibt.
---
---   maxLevel   hoechste Stufe
---   costBase   Punktekosten fuer Stufe 1
---   costStep   Aufschlag je weiterer Stufe
---   perLevel   Wirkung pro Stufe (wird mit der Stufe multipliziert)

Mystic.Perks = {
    {
        id = 'vitalitaet', label = 'Vitalitaet', icon = '❤',
        description = 'Erhoeht deine maximalen Lebenspunkte.',
        maxLevel = 10, costBase = 1, costStep = 1,
        perLevel = { healthBonus = 12 },
        format = '+%d max. Leben',
    },
    {
        id = 'ausdauer', label = 'Ausdauer', icon = '🏃',
        description = 'Du kannst deutlich laenger sprinten.',
        maxLevel = 8, costBase = 1, costStep = 1,
        perLevel = { stamina = 12 },
        format = '+%d%% Ausdauer',
    },
    {
        id = 'staerke', label = 'Staerke', icon = '💪',
        description = 'Erhoeht deinen Waffen- und Nahkampfschaden.',
        maxLevel = 10, costBase = 2, costStep = 1,
        perLevel = { damageMult = 0.04, meleeMult = 0.05 },
        format = '+%d%% Schaden',
    },
    {
        id = 'regeneration', label = 'Regeneration', icon = '💚',
        description = 'Deine Wunden schliessen sich von selbst.',
        maxLevel = 8, costBase = 2, costStep = 1,
        perLevel = { regenPerTick = 1 },
        format = '+%d Leben alle 5 Sekunden',
    },
    {
        id = 'essenz', label = 'Essenz', icon = '🔵',
        description = 'Vergroessert deinen Essenzvorrat.',
        maxLevel = 10, costBase = 1, costStep = 1,
        perLevel = { essenceBonus = 10 },
        format = '+%d max. Essenz',
    },
    {
        id = 'fokus', label = 'Fokus', icon = '🧘',
        description = 'Deine Essenz regeneriert schneller.',
        maxLevel = 8, costBase = 2, costStep = 1,
        perLevel = { essenceRegen = 0.4 },
        format = '+%.1f Essenz pro Tick',
    },
    {
        id = 'zaehigkeit', label = 'Zaehigkeit', icon = '🛡',
        description = 'Du erhaeltst beim Spawnen zusaetzliche Weste.',
        maxLevel = 6, costBase = 2, costStep = 2,
        perLevel = { armorBonus = 8 },
        format = '+%d Weste',
    },
    {
        id = 'schnelligkeit', label = 'Schnelligkeit', icon = '⚡',
        description = 'Du bewegst dich schneller zu Fuss.',
        maxLevel = 5, costBase = 3, costStep = 2,
        perLevel = { speedMult = 0.02 },
        format = '+%d%% Tempo',
    },
    {
        id = 'meisterung', label = 'Meisterung', icon = '⏱',
        description = 'Verkuerzt die Abklingzeit deiner Rassenskills.',
        maxLevel = 5, costBase = 3, costStep = 2,
        perLevel = { cooldownMult = -0.04 },
        format = '-%d%% Abklingzeit',
    },
}

Mystic.PerksById = {}
for _, perk in ipairs(Mystic.Perks) do
    Mystic.PerksById[perk.id] = perk
end

---@return table|nil
function Mystic.GetPerk(id)
    if type(id) ~= 'string' then return nil end
    return Mystic.PerksById[id]
end

--- Punktekosten fuer die naechste Stufe.
---@return number|nil nil wenn die Maximalstufe erreicht ist
function Mystic.GetPerkCost(perk, nextLevel)
    if nextLevel < 1 or nextLevel > perk.maxLevel then return nil end
    return perk.costBase + (nextLevel - 1) * perk.costStep
end

--- Rechnet die Perk-Stufen in Gesamtboni um.
---@param levels table { [perkId] = level }
---@return table Summierte Modifikatoren
function Mystic.SumPerks(levels)
    local total = {
        healthBonus = 0, stamina = 0, damageMult = 0, meleeMult = 0,
        regenPerTick = 0, essenceBonus = 0, essenceRegen = 0,
        armorBonus = 0, speedMult = 0, cooldownMult = 0,
    }

    for perkId, level in pairs(levels or {}) do
        local perk = Mystic.GetPerk(perkId)
        if perk and type(level) == 'number' and level > 0 then
            local capped = math.min(level, perk.maxLevel)
            for key, value in pairs(perk.perLevel) do
                total[key] = (total[key] or 0) + value * capped
            end
        end
    end

    return total
end
