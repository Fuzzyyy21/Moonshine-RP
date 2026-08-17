--- Klassenstufe und Erfahrung.
--- Gespeichert wird nur die Gesamt-XP, die Stufe ergibt sich daraus.

--- Benoetigte XP fuer den Aufstieg von `level` auf `level + 1`.
---@return number
function Mystic.GetXpForLevel(level)
    local progression = MysticConfig.Progression
    return math.floor(progression.xpBase + level * progression.xpStep)
end

--- Rechnet Gesamt-XP in Stufe und Fortschritt um.
---@param totalXp number
---@return number level, number xpIntoLevel, number xpForNext
function Mystic.GetLevelFromXp(totalXp)
    local maxLevel = MysticConfig.Progression.maxLevel
    local level = 1
    local remaining = math.max(0, math.floor(totalXp or 0))

    while level < maxLevel do
        local needed = Mystic.GetXpForLevel(level)
        if remaining < needed then break end

        remaining = remaining - needed
        level = level + 1
    end

    if level >= maxLevel then
        return maxLevel, 0, 0
    end

    return level, remaining, Mystic.GetXpForLevel(level)
end

--- Gesamt-XP, die fuer eine bestimmte Stufe noetig sind.
function Mystic.GetTotalXpForLevel(target)
    local total = 0
    for level = 1, math.max(1, target) - 1 do
        total = total + Mystic.GetXpForLevel(level)
    end
    return total
end
