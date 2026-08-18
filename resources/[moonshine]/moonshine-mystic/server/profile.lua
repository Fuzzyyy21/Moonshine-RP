--- Mystik-Profil eines eingeloggten Spielers.

Mystic.Profiles = {}   -- [source] = Profile

local Profile = {}
Profile.__index = Profile

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end

    local ok, decoded = pcall(json.decode, value)
    if not ok or decoded == nil then return fallback end
    return decoded
end

--- Liest die gespeicherten Stufen. Alte Datensaetze speicherten nur eine
--- Liste freigeschalteter IDs; die wandern auf Stufe 1.
local function readRanks(stored)
    local decoded = decode(stored, {})
    local ranks = {}

    for key, value in pairs(decoded) do
        if type(key) == 'number' and type(value) == 'string' then
            if Mystic.GetSkill(value) then ranks[value] = 1 end
        elseif type(key) == 'string' and type(value) == 'number' then
            local skill = Mystic.GetSkill(key)
            if skill then
                ranks[key] = math.max(1, math.min(math.floor(value), skill.maxRank))
            end
        end
    end

    return ranks
end

--- Erstellt das Profil aus einem Datenbankdatensatz.
function Mystic.CreateProfile(source, characterId, row)
    local ranks = readRanks(row.unlocked)

    -- Leiste auf feste Laenge bringen, leere Slots sind false.
    local storedBar = decode(row.skillbar, {})
    local skillbar = {}
    for slot = 1, MysticConfig.SkillBar.slots do
        local id = storedBar[slot]
        local skill = type(id) == 'string' and Mystic.GetSkill(id) or nil
        skillbar[slot] = (skill and not skill.passive and (ranks[id] or 0) > 0) and id or false
    end

    local self = setmetatable({
        source         = source,
        characterId    = characterId,
        race           = row.race,

        -- XP sind ausschliesslich die Waehrung des persoenlichen Baums.
        xp             = row.xp or MysticConfig.Progression.startXp,
        xpTotal        = row.xp_total or row.xp or MysticConfig.Progression.startXp,

        -- Meditationspunkte: eigene Waehrung fuer Segen.
        meditationPoints = row.meditation or 0,

        ranks          = ranks,
        skillbar       = skillbar,
        perks          = decode(row.perks, {}),
        secondsPlayed  = row.seconds_played or 0,

        essence        = 0,
        cooldowns      = {},   -- [skillId] = Ablaufzeitpunkt (os.time)
        lastCast       = 0,
        lastMeditation = 0,
        lastRitual     = 0,
    }, Profile)

    self.essence = self:GetMaxEssence()
    Mystic.Profiles[source] = self
    return self
end

---@return table|nil
function Mystic.GetProfile(source)
    return Mystic.Profiles[tonumber(source)]
end

-- Klassenstufe ---------------------------------------------------------------

--- Die Klassenstufe zaehlt die im Klassenbaum gekauften Stufen.
--- Sie hat nichts mit Erfahrung zu tun - der Baum kostet nur Klassensteine.
---@return number
function Profile:GetLevel()
    return self:GetTotalRanks()
end

--- Wie viele Stufen der Baum der aktuellen Klasse insgesamt hergibt.
function Profile:GetMaxRanks()
    if not self.race then return 0 end

    local total = 0
    for _, skill in ipairs(Mystic.GetSkillsForRace(self.race)) do
        total = total + skill.maxRank
    end
    return total
end

-- Erfahrung (persoenlicher Baum) ---------------------------------------------

--- Persoenliche Stufe und Fortschritt aus der gesamten verdienten Erfahrung.
---@return number level, number xpIntoLevel, number xpForNext
function Profile:GetPersonalProgress()
    return Mystic.GetLevelFromXp(self.xpTotal)
end

--- Vergibt Erfahrung fuer den persoenlichen Baum.
---@return boolean levelUp
function Profile:AddXp(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end

    local before = self:GetPersonalProgress()
    self.xp = self.xp + amount
    self.xpTotal = self.xpTotal + amount
    local after = self:GetPersonalProgress()

    if after > before then
        self:Notify(('Persoenliche Stufe %d erreicht.'):format(after), 'success')
        TriggerClientEvent('mystic:client:levelUp', self.source, after)
        TriggerEvent('mystic:server:levelUp', self.source, after)
        return true
    end

    return false
end

--- Gibt XP aus (nur persoenlicher Baum).
---@return boolean
function Profile:SpendXp(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or self.xp < amount then return false end

    self.xp = self.xp - amount
    return true
end

--- Erstattet XP, ohne die Gesamterfahrung zu veraendern.
function Profile:RefundXp(amount)
    self.xp = self.xp + math.max(0, math.floor(tonumber(amount) or 0))
end

-- Meditationspunkte ----------------------------------------------------------

function Profile:AddMeditationPoints(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return end

    self.meditationPoints = math.max(0, self.meditationPoints + amount)
end

---@return boolean
function Profile:SpendMeditationPoints(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or self.meditationPoints < amount then return false end

    self.meditationPoints = self.meditationPoints - amount
    return true
end

-- Skills ---------------------------------------------------------------------

---@return number Stufe des Skills (0 = nicht gelernt)
function Profile:GetRank(skillId)
    return self.ranks[skillId] or 0
end

function Profile:IsUnlocked(skillId)
    return self:GetRank(skillId) > 0
end

--- Anzahl aller gekauften Stufen. 0 bedeutet: die Klasse ist noch frei waehlbar.
function Profile:GetTotalRanks()
    local total = 0
    for _, rank in pairs(self.ranks) do total = total + rank end
    return total
end

--- Darf der Spieler die Klasse noch wechseln?
function Profile:CanSwitchClass()
    if not MysticConfig.Awakening.lockAfterFirstSkill then return true end
    if self:GetTotalRanks() == 0 then return true end
    return MysticConfig.Awakening.allowRaceChange
end

--- Verbleibende Abklingzeit in Sekunden.
function Profile:GetCooldown(skillId)
    local expiry = self.cooldowns[skillId]
    if not expiry then return 0 end

    local remaining = expiry - os.time()
    if remaining <= 0 then
        self.cooldowns[skillId] = nil
        return 0
    end
    return remaining
end

function Profile:SetCooldown(skillId, seconds)
    self.cooldowns[skillId] = os.time() + math.max(1, math.floor(seconds))
end

--- Belegt einen Slot der Skillleiste (skillId = nil leert ihn).
function Profile:SetBarSlot(slot, skillId)
    if slot < 1 or slot > MysticConfig.SkillBar.slots then return false end

    for index, id in pairs(self.skillbar) do
        if id == skillId and index ~= slot then self.skillbar[index] = false end
    end

    self.skillbar[slot] = skillId or false
    return true
end

-- Werte ----------------------------------------------------------------------

--- Summiert Klassenwerte, passive Skills (nach Stufe) und Perks.
---@return table Modifikatoren
function Profile:GetModifiers()
    local mods = {
        healthBonus = 0, armorBonus = 0, stamina = 0,
        damageMult = 1.0, meleeMult = 1.0, speedMult = 1.0,
        regenPerTick = 0, essenceBonus = 0, essenceRegen = 0,
        costMult = 1.0, cooldownMult = 1.0,
        sunImmune = false, fireImmune = false, noFallDamage = false,
    }

    local race = Mystic.GetRace(self.race)
    if race then
        mods.healthBonus = mods.healthBonus + race.stats.healthBonus
        mods.armorBonus  = mods.armorBonus + race.stats.armorBonus
        mods.damageMult  = mods.damageMult * race.stats.damageMult
        mods.meleeMult   = mods.meleeMult * race.stats.meleeMult
        mods.speedMult   = mods.speedMult * race.stats.speedMult
    end

    for skillId, rank in pairs(self.ranks) do
        local skill = Mystic.GetSkill(skillId)

        if skill and skill.passive and rank > 0 then
            local effect = Mystic.ResolveEffect(skill, rank)

            mods.healthBonus  = mods.healthBonus + (effect.healthBonus or 0)
            mods.armorBonus   = mods.armorBonus + (effect.armorBonus or 0)
            mods.stamina      = mods.stamina + (effect.stamina or 0)
            mods.essenceBonus = mods.essenceBonus + (effect.essenceBonus or 0)
            mods.essenceRegen = mods.essenceRegen + (effect.essenceRegen or 0)
            mods.regenPerTick = mods.regenPerTick + (effect.regenPerTick or 0)
            mods.damageMult   = mods.damageMult + (effect.damageMult or 0)
            mods.meleeMult    = mods.meleeMult + (effect.meleeMult or 0)
            mods.speedMult    = mods.speedMult + (effect.speedMult or 0)
            mods.costMult     = mods.costMult * (effect.costMult or 1.0)
            mods.cooldownMult = mods.cooldownMult * (effect.cooldownMult or 1.0)
            mods.sunImmune    = mods.sunImmune or effect.sunImmune == true
            mods.fireImmune   = mods.fireImmune or effect.fireImmune == true
            mods.noFallDamage = mods.noFallDamage or effect.noFallDamage == true
        end
    end

    local perks = Mystic.SumPerks(self.perks)
    mods.healthBonus  = mods.healthBonus + perks.healthBonus
    mods.armorBonus   = mods.armorBonus + perks.armorBonus
    mods.stamina      = mods.stamina + perks.stamina
    mods.damageMult   = mods.damageMult + perks.damageMult
    mods.meleeMult    = mods.meleeMult + perks.meleeMult
    mods.speedMult    = mods.speedMult + perks.speedMult
    mods.regenPerTick = mods.regenPerTick + perks.regenPerTick
    mods.essenceBonus = mods.essenceBonus + perks.essenceBonus
    mods.essenceRegen = mods.essenceRegen + perks.essenceRegen
    mods.cooldownMult = math.max(0.4, mods.cooldownMult + perks.cooldownMult)

    return mods
end

---@return number
function Profile:GetMaxEssence()
    local race = Mystic.GetRace(self.race)
    if not race then return 0 end

    return race.essence.max + self:GetModifiers().essenceBonus
end

--- Essenzgewinn pro Tick in absoluten Punkten.
function Profile:GetEssenceRegen()
    local race = Mystic.GetRace(self.race)
    if not race then return 0 end

    local mods = self:GetModifiers()
    local base = self:GetMaxEssence() * (MysticConfig.Essence.regenPerTick / 100)
    return base * race.essence.regen + mods.essenceRegen
end

function Profile:SetEssence(value)
    self.essence = math.max(0, math.min(self:GetMaxEssence(), value))
end

--- Zieht Essenz ab, wenn genug vorhanden ist.
---@return boolean
function Profile:UseEssence(amount)
    if self.essence < amount then return false end

    self.essence = self.essence - amount
    self.lastCast = os.time()
    return true
end

-- Synchronisation ------------------------------------------------------------

--- Daten fuer den Client (inklusive verbleibender Abklingzeiten).
function Profile:GetData()
    local cooldowns = {}
    for skillId in pairs(self.cooldowns) do
        local remaining = self:GetCooldown(skillId)
        if remaining > 0 then cooldowns[skillId] = remaining end
    end

    local race = Mystic.GetRace(self.race)
    local personalLevel, xpIntoLevel, xpForNext = self:GetPersonalProgress()
    local stoneName, stoneLabel = Mystic.GetClassStone(self.race)

    return {
        race           = self.race,
        raceLabel      = race and race.label or nil,
        raceIcon       = race and race.icon or nil,
        raceColor      = race and race.color or nil,
        essenceLabel   = race and race.essence.label or 'Essenz',

        -- Klassenbaum: Stufe = gekaufte Stufen, bezahlt mit Klassensteinen
        level          = self:GetLevel(),
        maxRanks       = self:GetMaxRanks(),

        -- Persoenlicher Baum: Erfahrung
        xp             = self.xp,
        xpTotal        = self.xpTotal,
        personalLevel  = personalLevel,
        meditationPoints = self.meditationPoints,
        xpIntoLevel    = xpIntoLevel,
        xpForNext      = xpForNext,

        essence        = math.floor(self.essence),
        maxEssence     = self:GetMaxEssence(),

        ranks          = self.ranks,
        totalRanks     = self:GetTotalRanks(),
        canSwitchClass = self:CanSwitchClass(),
        skillbar       = self.skillbar,
        perks          = self.perks,
        modifiers      = self:GetModifiers(),
        cooldowns      = cooldowns,

        classStone      = stoneName,
        classStoneLabel = stoneLabel,
        secondsPlayed   = self.secondsPlayed,
    }
end

function Profile:Sync()
    TriggerClientEvent('mystic:client:syncProfile', self.source, self:GetData())
end

function Profile:Notify(message, type, duration)
    TriggerClientEvent('moonshine:client:notify', self.source, message, type or 'info', duration or 5000)
end

function Profile:Save()
    if not Mystic.DB.Ready then return false end

    Mystic.DB.Save(self.characterId, {
        race             = self.race,
        xp               = self.xp,
        xpTotal          = self.xpTotal,
        meditationPoints = self.meditationPoints,
        ranks            = self.ranks,
        skillbar      = self.skillbar,
        perks         = self.perks,
        secondsPlayed = self.secondsPlayed,
    })
    return true
end
