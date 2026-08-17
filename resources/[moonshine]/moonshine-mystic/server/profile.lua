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

--- Erstellt das Profil aus einem Datenbankdatensatz.
function Mystic.CreateProfile(source, characterId, row)
    local unlockedList = decode(row.unlocked, {})
    local unlocked = {}
    for _, id in ipairs(unlockedList) do
        if Mystic.GetSkill(id) then unlocked[id] = true end
    end

    -- Leiste auf feste Laenge bringen, leere Slots sind false.
    local storedBar = decode(row.skillbar, {})
    local skillbar = {}
    for slot = 1, MysticConfig.SkillBar.slots do
        local id = storedBar[slot]
        skillbar[slot] = (type(id) == 'string' and unlocked[id]) and id or false
    end

    local self = setmetatable({
        source         = source,
        characterId    = characterId,
        race           = row.race,
        skillPoints    = row.skill_points or 0,
        personalPoints = row.personal_points or 0,
        unlocked       = unlocked,
        skillbar       = skillbar,
        perks          = decode(row.perks, {}),
        secondsPlayed  = row.seconds_played or 0,

        essence        = 0,
        cooldowns      = {},   -- [skillId] = Ablaufzeitpunkt (os.time)
        lastCast       = 0,
        lastMeditation = 0,
    }, Profile)

    self.essence = self:GetMaxEssence()
    Mystic.Profiles[source] = self
    return self
end

---@return table|nil
function Mystic.GetProfile(source)
    return Mystic.Profiles[tonumber(source)]
end

-- Werte ----------------------------------------------------------------------

--- Summiert Rassenwerte, passive Skills und Perks.
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

    -- Passive Skills
    for skillId in pairs(self.unlocked) do
        local skill = Mystic.GetSkill(skillId)
        if skill and skill.passive then
            local effect = skill.effect
            mods.healthBonus  = mods.healthBonus + (effect.healthBonus or 0)
            mods.essenceBonus = mods.essenceBonus + (effect.essenceBonus or 0)
            mods.essenceRegen = mods.essenceRegen + (effect.essenceRegen or 0)
            mods.regenPerTick = mods.regenPerTick + (effect.regenPerTick or 0)
            mods.damageMult   = mods.damageMult + (effect.damageMult or 0)
            mods.meleeMult    = mods.meleeMult + (effect.meleeMult or 0)
            mods.costMult     = mods.costMult * (effect.costMult or 1.0)
            mods.cooldownMult = mods.cooldownMult * (effect.cooldownMult or 1.0)
            mods.sunImmune    = mods.sunImmune or effect.sunImmune == true
            mods.fireImmune   = mods.fireImmune or effect.fireImmune == true
            mods.noFallDamage = mods.noFallDamage or effect.noFallDamage == true
        end
    end

    -- Perks
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

-- Skills ---------------------------------------------------------------------

function Profile:IsUnlocked(skillId)
    return self.unlocked[skillId] == true
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

    -- Skill darf nur einmal in der Leiste liegen.
    for index, id in pairs(self.skillbar) do
        if id == skillId and index ~= slot then self.skillbar[index] = false end
    end

    self.skillbar[slot] = skillId or false
    return true
end

-- Punkte ---------------------------------------------------------------------

function Profile:AddSkillPoints(amount)
    self.skillPoints = math.max(0, self.skillPoints + amount)
end

function Profile:AddPersonalPoints(amount)
    self.personalPoints = math.max(0, self.personalPoints + amount)
end

-- Synchronisation ------------------------------------------------------------

--- Daten fuer den Client (inklusive verbleibender Abklingzeiten).
function Profile:GetData()
    local cooldowns = {}
    for skillId in pairs(self.cooldowns) do
        local remaining = self:GetCooldown(skillId)
        if remaining > 0 then cooldowns[skillId] = remaining end
    end

    local unlocked = {}
    for skillId in pairs(self.unlocked) do unlocked[#unlocked + 1] = skillId end

    local race = Mystic.GetRace(self.race)

    return {
        race           = self.race,
        raceLabel      = race and race.label or nil,
        raceIcon       = race and race.icon or nil,
        raceColor      = race and race.color or nil,
        essenceLabel   = race and race.essence.label or 'Essenz',
        essence        = math.floor(self.essence),
        maxEssence     = self:GetMaxEssence(),
        skillPoints    = self.skillPoints,
        personalPoints = self.personalPoints,
        unlocked       = unlocked,
        skillbar       = self.skillbar,
        perks          = self.perks,
        modifiers      = self:GetModifiers(),
        cooldowns      = cooldowns,
        secondsPlayed  = self.secondsPlayed,
    }
end

function Profile:Sync()
    TriggerClientEvent('mystic:client:syncProfile', self.source, self:GetData())
end

function Profile:Notify(message, type)
    TriggerClientEvent('moonshine:client:notify', self.source, message, type or 'info', 5000)
end

function Profile:Save()
    if not Mystic.DB.Ready then return false end

    local unlocked = {}
    for skillId in pairs(self.unlocked) do unlocked[#unlocked + 1] = skillId end

    Mystic.DB.Save(self.characterId, {
        race           = self.race,
        skillPoints    = self.skillPoints,
        personalPoints = self.personalPoints,
        unlocked       = unlocked,
        skillbar       = self.skillbar,
        perks          = self.perks,
        secondsPlayed  = self.secondsPlayed,
    })
    return true
end
