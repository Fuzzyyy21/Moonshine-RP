--- Fraktions-Skilltree.
---
--- Bezahlt wird mit Fraktionspunkten, die es je Fraktionslevel gibt. Die
--- Wirkung gilt fuer die ganze Fraktion, nicht fuer einzelne Mitglieder.
---
---   row/col  Position im Baum
---   maxRank  Anzahl der Stufen
---   cost     Punkte je Stufe (Zahl oder Liste je Stufe)
---   effect   Wirkung; Zahlen duerfen Listen je Stufe sein

Factions.SkillTree = {

    -- Wurzel --------------------------------------------------------------
    { id = 'fundament', label = 'Fundament', icon = '🏛', row = 0, col = 2,
      maxRank = 3, cost = 1,
      description = 'Der Unterbau jeder Fraktion. Mehr Plaetze, mehr Lager.',
      effect = { memberSlots = { 3, 6, 10 }, vaultSlots = { 10, 20, 35 } } },

    -- Zweig: Wirtschaft ----------------------------------------------------
    { id = 'handel', label = 'Handelsnetz', icon = '🪙', row = 1, col = 0.5,
      maxRank = 3, cost = 1, requires = { 'fundament' },
      description = 'Bessere Preise im Fraktionsshop.',
      effect = { shopDiscount = { 0.05, 0.10, 0.18 } } },

    { id = 'zoll', label = 'Wegzoll', icon = '🛤', row = 2, col = 0,
      maxRank = 3, cost = 2, requires = { 'handel' },
      description = 'Gebiete werfen mehr ab.',
      effect = { territoryIncome = { 0.10, 0.22, 0.35 } } },

    { id = 'schatzmeister', label = 'Schatzmeister', icon = '💰', row = 2, col = 1,
      maxRank = 2, cost = 2, requires = { 'handel' },
      description = 'Missionen der Fraktion zahlen besser.',
      effect = { missionReward = { 0.15, 0.30 } } },

    { id = 'monopol', label = 'Monopol', icon = '🏦', row = 3, col = 0.5,
      maxRank = 1, cost = 4, requires = { 'zoll', 'schatzmeister' }, minLevel = 12,
      description = 'Jede Auszahlung an Mitglieder kostet die Kasse weniger.',
      effect = { payoutBonus = 0.25, territoryIncome = 0.15 } },

    -- Zweig: Macht ---------------------------------------------------------
    { id = 'drill', label = 'Drill', icon = '🎯', row = 1, col = 2,
      maxRank = 3, cost = 1, requires = { 'fundament' },
      description = 'Gebiete werden schneller eingenommen.',
      effect = { captureSpeed = { 0.12, 0.25, 0.40 } } },

    { id = 'bollwerk', label = 'Bollwerk', icon = '🧱', row = 2, col = 2,
      maxRank = 3, cost = 2, requires = { 'drill' },
      description = 'Eigene Gebiete sind laenger geschuetzt und fallen langsamer.',
      effect = { protectionBonus = { 0.20, 0.40, 0.65 }, defenceBonus = { 0.10, 0.20, 0.35 } } },

    { id = 'sturmtrupp', label = 'Sturmtrupp', icon = '⚔', row = 3, col = 2,
      maxRank = 1, cost = 4, requires = { 'bollwerk' }, minLevel = 15,
      description = 'Ein einzelnes Mitglied reicht, um ein Gebiet zu halten.',
      effect = { soloCapture = true, captureSpeed = 0.20 } },

    -- Zweig: Logistik ------------------------------------------------------
    { id = 'fuhrpark', label = 'Fuhrpark', icon = '🚚', row = 1, col = 3.5,
      maxRank = 3, cost = 1, requires = { 'fundament' },
      description = 'Mehr Plaetze in der Fraktionsgarage.',
      effect = { garageSlots = { 2, 4, 7 } } },

    { id = 'werkstatt', label = 'Werkstatt', icon = '🔧', row = 2, col = 3,
      maxRank = 2, cost = 2, requires = { 'fuhrpark' },
      description = 'Fahrzeuge kosten die Kasse weniger.',
      effect = { vehicleDiscount = { 0.10, 0.20 } } },

    { id = 'lager', label = 'Grosslager', icon = '📦', row = 2, col = 4,
      maxRank = 3, cost = 2, requires = { 'fuhrpark' },
      description = 'Deutlich mehr Platz im Tresor.',
      effect = { vaultSlots = { 25, 50, 80 } } },

    { id = 'imperium', label = 'Imperium', icon = '👑', row = 3, col = 3.5,
      maxRank = 1, cost = 5, requires = { 'werkstatt', 'lager' }, minLevel = 20,
      description = 'Die Fraktion waechst ueber sich hinaus.',
      effect = { memberSlots = 15, garageSlots = 5, vaultSlots = 60, territoryIncome = 0.20 } },
}

Factions.SkillById = {}
for _, node in ipairs(Factions.SkillTree) do
    Factions.SkillById[node.id] = node
end

function Factions.GetSkill(id)
    if type(id) ~= 'string' then return nil end
    return Factions.SkillById[id]
end

--- Waehlt den Wert einer Stufe aus einer Zahl oder einer Liste.
function Factions.PickRankValue(value, rank)
    if type(value) ~= 'table' then return value end
    if rank < 1 then return nil end

    return value[math.min(rank, #value)]
end

--- Kosten der naechsten Stufe.
function Factions.GetSkillCost(node, nextRank)
    if type(node.cost) == 'table' then
        return node.cost[math.min(nextRank, #node.cost)] or node.cost[#node.cost]
    end

    return node.cost or 1
end

--- Summe aller ausgegebenen Punkte.
function Factions.GetSpentPoints(ranks)
    local total = 0

    for id, rank in pairs(ranks or {}) do
        local node = Factions.GetSkill(id)

        if node then
            for step = 1, math.min(rank, node.maxRank) do
                total = total + Factions.GetSkillCost(node, step)
            end
        end
    end

    return total
end

--- Sind die Voraussetzungen erfuellt?
---@return boolean ok, string reason
function Factions.MeetsSkillRequirements(node, ranks, level)
    if node.minLevel and level < node.minLevel then
        return false, ('Fraktionslevel %d noetig.'):format(node.minLevel)
    end

    for _, required in ipairs(node.requires or {}) do
        if (ranks[required] or 0) < 1 then
            local parent = Factions.GetSkill(required)
            return false, ('Erst %s freischalten.'):format(parent and parent.label or required)
        end
    end

    return true, ''
end

--- Rechnet alle gekauften Stufen in Werte um.
function Factions.SumSkills(ranks)
    local result = {
        memberSlots     = 0,
        vaultSlots      = 0,
        garageSlots     = 0,
        shopDiscount    = 0,
        vehicleDiscount = 0,
        territoryIncome = 0,
        missionReward   = 0,
        captureSpeed    = 0,
        protectionBonus = 0,
        defenceBonus    = 0,
        payoutBonus     = 0,
        soloCapture     = false,
    }

    for id, rank in pairs(ranks or {}) do
        local node = Factions.GetSkill(id)

        if node and rank > 0 then
            for key, value in pairs(node.effect or {}) do
                local picked = Factions.PickRankValue(value, rank)

                if type(picked) == 'number' and type(result[key]) == 'number' then
                    result[key] = result[key] + picked
                elseif type(picked) == 'boolean' then
                    result[key] = result[key] or picked
                end
            end
        end
    end

    -- Prozentwerte deckeln, damit nichts entgleist.
    result.shopDiscount    = math.min(result.shopDiscount, 0.40)
    result.vehicleDiscount = math.min(result.vehicleDiscount, 0.40)
    result.captureSpeed    = math.min(result.captureSpeed, 0.60)

    return result
end

--- Beschreibt eine Stufe im Klartext.
function Factions.DescribeSkillRank(node, rank)
    local lines = {}

    local LABELS = {
        memberSlots     = { '%+d Mitgliederplaetze', false },
        vaultSlots      = { '%+d Tresorplaetze', false },
        garageSlots     = { '%+d Fahrzeugplaetze', false },
        shopDiscount    = { '%d %% guenstiger im Shop', true },
        vehicleDiscount = { '%d %% guenstigere Fahrzeuge', true },
        territoryIncome = { '%+d %% Gebietseinkommen', true },
        missionReward   = { '%+d %% Missionsbelohnung', true },
        captureSpeed    = { '%d %% schnellere Einnahme', true },
        protectionBonus = { '%+d %% Schutzzeit', true },
        defenceBonus    = { '%+d %% Verteidigung', true },
        payoutBonus     = { '%d %% guenstigere Auszahlungen', true },
    }

    for key, value in pairs(node.effect or {}) do
        local picked = Factions.PickRankValue(value, rank)
        local label = LABELS[key]

        if label and type(picked) == 'number' then
            lines[#lines + 1] = label[2]
                and label[1]:format(math.floor(picked * 100 + 0.5))
                or label[1]:format(picked)
        elseif key == 'soloCapture' and picked then
            lines[#lines + 1] = 'Ein Mitglied reicht zur Einnahme'
        end
    end

    table.sort(lines)
    return lines
end
