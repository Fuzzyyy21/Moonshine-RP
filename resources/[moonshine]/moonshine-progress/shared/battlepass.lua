--- Battle Pass: Stufen mit kostenloser und Premium-Spur.
---
--- Fuer jede Stufe kann es einen Eintrag geben. Stufen ohne eigenen Eintrag
--- bekommen die Standardbelohnung aus Progress.DefaultTierReward.

Progress.BattlePassTiers = {
    [1]  = { free = { money = 5000, items = { { name = 'runenstein', count = 1 } } },
             premium = { money = 15000, cases = { silber = 1 } } },
    [3]  = { free = { bpxp = 0, cases = { holz = 1 } },
             premium = { money = 20000, items = { { name = 'seelenstein', count = 2 } } } },
    [5]  = { free = { money = 12000 },
             premium = { cases = { gold = 1 } } },
    [8]  = { free = { items = { { name = 'seelenstein', count = 1 } } },
             premium = { money = 30000, items = { { name = 'runenstein', count = 4 } } } },
    [10] = { free = { cases = { silber = 1 } },
             premium = { cases = { gold = 1 }, money = 40000 } },
    [15] = { free = { money = 20000 },
             premium = { cases = { gold = 1 }, items = { { name = 'seelenstein', count = 4 } } } },
    [20] = { free = { cases = { silber = 1 } },
             premium = { money = 75000, cases = { mystisch = 1 } } },
    [25] = { free = { items = { { name = 'runenstein', count = 5 } } },
             premium = { cases = { gold = 2 } } },
    [30] = { free = { money = 35000 },
             premium = { cases = { mystisch = 1 }, money = 100000 } },
    [40] = { free = { cases = { gold = 1 } },
             premium = { cases = { mystisch = 1 }, items = { { name = 'seelenstein', count = 8 } } } },
    [50] = { free = { money = 100000, cases = { gold = 1 } },
             premium = { money = 250000, cases = { mystisch = 3 } } },
}

--- Standardbelohnung fuer Stufen ohne eigenen Eintrag.
Progress.DefaultTierReward = {
    free    = { money = 5000 },
    premium = { money = 12000, items = { { name = 'runenstein', count = 1 } } },
}

--- Belohnung einer Stufe.
---@return table free, table premium
function Progress.GetTierReward(level)
    local tier = Progress.BattlePassTiers[level]
    if tier then
        return tier.free or Progress.DefaultTierReward.free,
               tier.premium or Progress.DefaultTierReward.premium
    end

    return Progress.DefaultTierReward.free, Progress.DefaultTierReward.premium
end

--- Benoetigte XP fuer den Aufstieg von `level` auf `level + 1`.
function Progress.GetTierXp(level)
    local config = ProgressConfig.BattlePass
    return math.floor(config.xpBase + level * config.xpStep)
end

--- Rechnet Gesamt-XP in Stufe und Fortschritt um.
---@return number level, number into, number needed
function Progress.GetBattlePassLevel(totalXp)
    local maxLevel = ProgressConfig.BattlePass.maxLevel
    local level = 1
    local remaining = math.max(0, math.floor(totalXp or 0))

    while level < maxLevel do
        local needed = Progress.GetTierXp(level)
        if remaining < needed then break end

        remaining = remaining - needed
        level = level + 1
    end

    if level >= maxLevel then return maxLevel, 0, 0 end
    return level, remaining, Progress.GetTierXp(level)
end
