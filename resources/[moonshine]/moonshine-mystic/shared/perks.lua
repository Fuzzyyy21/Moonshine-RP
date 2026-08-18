--- Persoenliche Skills ("Perks").
---
--- Sie sind klassenunabhaengig und werden mit ERFAHRUNG (XP) bezahlt. XP gibt
--- es fuer Onlinezeit und Aktivitaet. Der Klassenbaum benutzt keine XP, sondern
--- ausschliesslich Klassensteine.
---
---   maxLevel   hoechste Stufe
---   costBase   XP-Kosten fuer Stufe 1
---   costStep   Aufschlag je weiterer Stufe
---   perLevel   Wirkung pro Stufe (wird mit der Stufe multipliziert)

Mystic.Perks = {
    {
        id = 'vitalitaet', label = 'Vitalitaet', icon = '❤',
        description = 'Erhoeht deine maximalen Lebenspunkte.',
        maxLevel = 10, costBase = 300, costStep = 200,
        perLevel = { healthBonus = 12 },
    },
    {
        id = 'ausdauer', label = 'Ausdauer', icon = '🏃',
        description = 'Du kannst deutlich laenger sprinten.',
        maxLevel = 8, costBase = 250, costStep = 150,
        perLevel = { stamina = 12 },
    },
    {
        id = 'staerke', label = 'Staerke', icon = '💪',
        description = 'Erhoeht deinen Waffen- und Nahkampfschaden.',
        maxLevel = 10, costBase = 400, costStep = 250,
        perLevel = { damageMult = 0.04, meleeMult = 0.05 },
    },
    {
        id = 'regeneration', label = 'Regeneration', icon = '💚',
        description = 'Deine Wunden schliessen sich von selbst.',
        maxLevel = 8, costBase = 400, costStep = 250,
        perLevel = { regenPerTick = 1 },
    },
    {
        id = 'essenz', label = 'Essenz', icon = '🔵',
        description = 'Vergroessert deinen Essenzvorrat.',
        maxLevel = 10, costBase = 300, costStep = 200,
        perLevel = { essenceBonus = 10 },
    },
    {
        id = 'fokus', label = 'Fokus', icon = '🧘',
        description = 'Deine Essenz regeneriert schneller.',
        maxLevel = 8, costBase = 400, costStep = 250,
        perLevel = { essenceRegen = 0.4 },
    },
    {
        id = 'zaehigkeit', label = 'Zaehigkeit', icon = '🛡',
        description = 'Du erhaeltst beim Spawnen zusaetzliche Weste.',
        maxLevel = 6, costBase = 350, costStep = 250,
        perLevel = { armorBonus = 8 },
    },
    {
        id = 'schnelligkeit', label = 'Schnelligkeit', icon = '⚡',
        description = 'Du bewegst dich schneller zu Fuss.',
        maxLevel = 5, costBase = 600, costStep = 400,
        perLevel = { speedMult = 0.02 },
    },
    {
        id = 'meisterung', label = 'Meisterung', icon = '⏱',
        description = 'Verkuerzt die Abklingzeit deiner Klassenskills.',
        maxLevel = 5, costBase = 600, costStep = 400,
        perLevel = { cooldownMult = -0.04 },
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

--- XP-Kosten fuer die naechste Stufe.
---@return number|nil nil wenn die Maximalstufe erreicht ist
function Mystic.GetPerkCost(perk, nextLevel)
    if nextLevel < 1 or nextLevel > perk.maxLevel then return nil end
    return perk.costBase + (nextLevel - 1) * perk.costStep
end

--- Beschreibt die Wirkung einer Perkstufe.
function Mystic.DescribePerkLevel(perk, level)
    local parts = {}

    for key, value in pairs(perk.perLevel) do
        local total = value * level

        if key == 'healthBonus' then
            parts[#parts + 1] = ('+%d max. Leben'):format(total)
        elseif key == 'armorBonus' then
            parts[#parts + 1] = ('+%d Weste'):format(total)
        elseif key == 'stamina' then
            parts[#parts + 1] = ('+%d%% Ausdauer'):format(total)
        elseif key == 'damageMult' then
            parts[#parts + 1] = ('+%d%% Schaden'):format(math.floor(total * 100 + 0.5))
        elseif key == 'meleeMult' then
            parts[#parts + 1] = ('+%d%% Nahkampf'):format(math.floor(total * 100 + 0.5))
        elseif key == 'speedMult' then
            parts[#parts + 1] = ('+%d%% Tempo'):format(math.floor(total * 100 + 0.5))
        elseif key == 'regenPerTick' then
            parts[#parts + 1] = ('+%d Leben alle 5 s'):format(total)
        elseif key == 'essenceBonus' then
            parts[#parts + 1] = ('+%d max. Essenz'):format(total)
        elseif key == 'essenceRegen' then
            parts[#parts + 1] = ('+%.1f Essenz/Tick'):format(total)
        elseif key == 'cooldownMult' then
            parts[#parts + 1] = ('%d%% Abklingzeit'):format(math.floor(total * 100 - 0.5))
        end
    end

    table.sort(parts)
    return table.concat(parts, ' · ')
end

--- Rechnet die Perk-Stufen in Gesamtboni um.
---@param levels table { [perkId] = level }
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

--- Gesamte XP-Kosten aller gekauften Stufen (fuer die Erstattung).
function Mystic.GetSpentXp(perk, level)
    local total = 0
    for step = 1, level do
        total = total + (Mystic.GetPerkCost(perk, step) or 0)
    end
    return total
end
