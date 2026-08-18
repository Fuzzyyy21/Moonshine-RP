--- Das Fraktionsobjekt.

MS = MS or exports['moonshine-core']:GetCoreObject()

Factions.List   = {}   -- [factionId]   = Faction
Factions.Online = {}   -- [characterId] = source

local Faction = {}
Faction.__index = Faction

-- Hilfen ----------------------------------------------------------------------

local function decode(raw, fallback)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return fallback end

    local ok, value = pcall(json.decode, raw)
    if not ok or type(value) ~= 'table' then return fallback end

    return value
end

--- Quelle eines Charakters, wenn er online ist.
function Factions.GetSourceOf(characterId)
    local source = Factions.Online[characterId]
    if not source then return nil end

    local player = MS.GetPlayer(source)
    if not player or player.charId ~= characterId then
        Factions.Online[characterId] = nil
        return nil
    end

    return source
end

-- Aufbau -----------------------------------------------------------------------

function Faction.New(row)
    local self = setmetatable({}, Faction)

    self.id      = row.id
    self.name    = row.name
    self.tag     = row.tag
    self.ownerId = row.owner_id
    self.base    = row.base

    self.emblem = Factions.SanitizeEmblem(decode(row.emblem, nil), Factions.DefaultEmblem())
    self.ranks  = decode(row.ranks, nil) or Factions.CopyDefaultRanks()
    self.skills = decode(row.skills, {})

    self.level  = math.max(1, tonumber(row.level) or 1)
    self.xp     = math.max(0, tonumber(row.xp) or 0)
    self.points = math.max(0, tonumber(row.points) or 0)
    self.kasse  = math.max(0, tonumber(row.kasse) or 0)

    self.vault    = decode(row.vault, {})
    self.members  = {}
    self.vehicles = {}
    self.missions = {}

    self.dirty = false

    return self
end

function Factions.Get(factionId)
    return Factions.List[tonumber(factionId) or -1]
end

--- Fraktion eines Charakters.
function Factions.GetByCharacter(characterId)
    for _, faction in pairs(Factions.List) do
        if faction.members[characterId] then return faction end
    end

    return nil
end

--- Fraktion eines Spielers.
function Factions.GetByPlayer(source)
    local player = MS.GetPlayer(source)
    if not player then return nil end

    return Factions.GetByCharacter(player.charId)
end

function Factions.GetByName(name)
    local needle = tostring(name or ''):lower()

    for _, faction in pairs(Factions.List) do
        if faction.name:lower() == needle or faction.tag:lower() == needle then
            return faction
        end
    end

    return nil
end

-- Mitglieder ---------------------------------------------------------------------

function Faction:AddMember(characterId, name, grade)
    self.members[characterId] = {
        characterId  = characterId,
        name         = name or ('Charakter %d'):format(characterId),
        grade        = grade or 0,
        contribution = 0,
        joinedAt     = os.time(),
    }

    Factions.DB.AddMember(self.id, characterId, grade or 0)
end

function Faction:RemoveMember(characterId)
    self.members[characterId] = nil
    Factions.DB.RemoveMember(characterId)
end

function Faction:CountMembers()
    local count = 0
    for _ in pairs(self.members) do count = count + 1 end
    return count
end

function Faction:GetGrade(characterId)
    local member = self.members[characterId]
    return member and member.grade or nil
end

--- Darf dieser Charakter das?
function Faction:Can(characterId, permission)
    local grade = self:GetGrade(characterId)
    if not grade then return false end

    return Factions.RankHas(self.ranks, grade, permission)
end

--- Darf dieser Spieler das?
function Faction:PlayerCan(source, permission)
    local player = MS.GetPlayer(source)
    if not player then return false end

    return self:Can(player.charId, permission)
end

--- Alle Mitglieder, die gerade online sind.
function Faction:OnlineSources()
    local sources = {}

    for characterId in pairs(self.members) do
        local source = Factions.GetSourceOf(characterId)
        if source then sources[#sources + 1] = source end
    end

    return sources
end

function Faction:Notify(message, kind, duration)
    for _, source in ipairs(self:OnlineSources()) do
        exports['moonshine-core']:Notify(source, message, kind or 'info', duration or 6000)
    end
end

function Faction:Log(kind, text)
    Factions.DB.Log(self.id, kind, text)
end

-- Level und Skills -----------------------------------------------------------------

--- XP fuer den Aufstieg von `level` auf `level + 1`.
function Factions.LevelXp(level)
    local config = FactionConfig.Level
    return math.floor(config.xpBase + (level - 1) * config.xpStep)
end

function Faction:AddXp(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return 0 end

    self.xp = self.xp + amount
    self.dirty = true

    local config = FactionConfig.Level
    local gained = 0

    while self.level < config.maxLevel do
        local needed = Factions.LevelXp(self.level)
        if self.xp < needed then break end

        self.xp = self.xp - needed
        self.level = self.level + 1
        self.points = self.points + config.pointsPerLevel
        gained = gained + 1
    end

    if self.level >= config.maxLevel then self.xp = 0 end

    if gained > 0 then
        self:Notify(('Die Fraktion ist auf Level %d aufgestiegen.'):format(self.level), 'success', 9000)
        self:Log('level', ('Aufstieg auf Level %d.'):format(self.level))
        TriggerEvent('factions:server:levelUp', self.id, self.level)
    end

    return gained
end

--- Alle Boni aus dem Fraktionsbaum.
function Faction:GetModifiers()
    return Factions.SumSkills(self.skills)
end

function Faction:GetMemberSlots()
    return FactionConfig.Members.baseSlots + self:GetModifiers().memberSlots
end

function Faction:GetVaultSlots()
    return FactionConfig.Vault.baseSlots + self:GetModifiers().vaultSlots
end

function Faction:GetGarageSlots()
    return FactionConfig.Garage.baseSlots + self:GetModifiers().garageSlots
end

-- Kasse ------------------------------------------------------------------------------

function Faction:AddKasse(amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end

    self.kasse = self.kasse + amount
    self.dirty = true

    if reason then self:Log('kasse', ('+%s (%s)'):format(MS.Utils.FormatMoney(amount), reason)) end
    return true
end

function Faction:RemoveKasse(amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or self.kasse < amount then return false end

    self.kasse = self.kasse - amount
    self.dirty = true

    if reason then self:Log('kasse', ('-%s (%s)'):format(MS.Utils.FormatMoney(amount), reason)) end
    return true
end

-- Speichern ---------------------------------------------------------------------------

function Faction:Save(force)
    if not force and not self.dirty then return false end
    if not Factions.DB.Ready then return false end

    Factions.DB.Save(self.id, {
        name = self.name, tag = self.tag, ownerId = self.ownerId, base = self.base,
        emblem = self.emblem, ranks = self.ranks, skills = self.skills,
        level = self.level, xp = self.xp, points = self.points,
        kasse = self.kasse, vault = self.vault,
    })

    self.dirty = false
    return true
end

-- Anzeige --------------------------------------------------------------------------------

--- Kurzinfo, die auch Nichtmitglieder sehen duerfen.
function Faction:GetPublicInfo()
    return {
        id      = self.id,
        name    = self.name,
        tag     = self.tag,
        emblem  = self.emblem,
        level   = self.level,
        members = self:CountMembers(),
    }
end

--- Vollstaendiger Zustand fuer ein Mitglied.
function Faction:GetPayload(source)
    local player = MS.GetPlayer(source)
    local characterId = player and player.charId
    local grade = characterId and self:GetGrade(characterId) or 0

    local members = {}
    for _, member in pairs(self.members) do
        local rank = Factions.GetRank(self.ranks, member.grade)

        members[#members + 1] = {
            characterId  = member.characterId,
            name         = member.name,
            grade        = member.grade,
            rankLabel    = rank.label,
            rankIcon     = rank.icon,
            contribution = member.contribution,
            online       = Factions.GetSourceOf(member.characterId) ~= nil,
            owner        = member.characterId == self.ownerId,
        }
    end

    table.sort(members, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)

    local permissions = {}
    for _, entry in ipairs(Factions.Permissions) do
        permissions[entry.id] = self:Can(characterId, entry.id)
    end

    return {
        id      = self.id,
        name    = self.name,
        tag     = self.tag,
        base    = self.base,
        emblem  = self.emblem,
        ranks   = self.ranks,
        grade   = grade,
        isOwner = characterId == self.ownerId,
        permissions = permissions,

        level    = self.level,
        xp       = self.xp,
        xpNeeded = self.level >= FactionConfig.Level.maxLevel and 0 or Factions.LevelXp(self.level),
        maxLevel = FactionConfig.Level.maxLevel,
        points   = self.points,
        spent    = Factions.GetSpentPoints(self.skills),

        kasse       = self.kasse,
        maxWithdraw = FactionConfig.Kasse.maxWithdraw,

        members     = members,
        memberSlots = self:GetMemberSlots(),

        skills     = self.skills,
        skillTree  = Factions.BuildSkillPayload(self),
        modifiers  = self:GetModifiers(),

        vault      = Factions.BuildVaultPayload(self),
        shop       = Factions.BuildShopPayload(self),
        garage     = Factions.BuildGaragePayload(self, grade),
        missions   = Factions.BuildMissionPayload(self),
        territory  = Factions.BuildTerritoryPayload(self),

        options    = Factions.GetEmblemOptions(),
        rankIcons  = Factions.RankIcons,
        permissionList = Factions.Permissions,
    }
end

function Faction:Sync(target)
    if target then
        TriggerClientEvent('factions:client:sync', target, self:GetPayload(target))
        return
    end

    for _, source in ipairs(self:OnlineSources()) do
        TriggerClientEvent('factions:client:sync', source, self:GetPayload(source))
    end
end

-- Laden ----------------------------------------------------------------------------------

function Factions.LoadAll()
    local rows = Factions.DB.LoadAll()

    for _, row in ipairs(rows) do
        local faction = Faction.New(row)

        for _, member in ipairs(Factions.DB.LoadMembers(faction.id)) do
            faction.members[member.character_id] = {
                characterId  = member.character_id,
                name         = ('%s %s'):format(member.firstname or '?', member.lastname or ''),
                grade        = member.grade,
                contribution = tonumber(member.contribution) or 0,
                joinedAt     = member.joined_at,
            }
        end

        for _, vehicle in ipairs(Factions.DB.LoadVehicles(faction.id)) do
            faction.vehicles[vehicle.id] = {
                id       = vehicle.id,
                model    = vehicle.model,
                label    = vehicle.label,
                plate    = vehicle.plate,
                minGrade = vehicle.min_grade,
                stored   = tonumber(vehicle.stored) == 1,
            }
        end

        Factions.List[faction.id] = faction
    end

    print(('^2[Fraktionen]^7 %d Fraktionen geladen.'):format(#rows))
end

--- Legt eine Fraktion an.
---@return table|nil faction, string error
function Factions.Create(name, tag, ownerCharacterId, ownerName, base)
    if not Factions.DB.Ready then return nil, 'Datenbank ist nicht bereit.' end

    name = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    tag  = tostring(tag or ''):upper():gsub('[^%w]', '')

    local config = FactionConfig.Create

    if #name < config.minName or #name > config.maxName then
        return nil, ('Der Name braucht %d bis %d Zeichen.'):format(config.minName, config.maxName)
    end

    if #tag < config.minTag or #tag > config.maxTag then
        return nil, ('Das Kuerzel braucht %d bis %d Zeichen.'):format(config.minTag, config.maxTag)
    end

    for _, faction in pairs(Factions.List) do
        if faction.name:lower() == name:lower() then return nil, 'Diesen Namen gibt es schon.' end
        if faction.tag:lower() == tag:lower() then return nil, 'Dieses Kuerzel gibt es schon.' end
    end

    if Factions.GetByCharacter(ownerCharacterId) then
        return nil, 'Du bist bereits in einer Fraktion.'
    end

    -- Freie Basis suchen.
    local taken = {}
    for _, faction in pairs(Factions.List) do
        if faction.base then taken[faction.base] = true end
    end

    local chosen = base
    if not chosen or taken[chosen] then
        chosen = nil
        for _, entry in ipairs(FactionConfig.Bases) do
            if not taken[entry.id] then chosen = entry.id break end
        end
    end

    local emblem = Factions.DefaultEmblem()
    local ranks  = Factions.CopyDefaultRanks()

    local id = Factions.DB.Create(name, tag, ownerCharacterId, chosen, emblem, ranks)
    if not id then return nil, 'Die Fraktion konnte nicht angelegt werden.' end

    local faction = Faction.New({
        id = id, name = name, tag = tag, owner_id = ownerCharacterId, base = chosen,
        emblem = emblem, ranks = ranks, skills = {}, level = 1, xp = 0,
        points = FactionConfig.Level.pointsPerLevel, kasse = 0, vault = {},
    })

    faction:AddMember(ownerCharacterId, ownerName, Factions.TopGrade(ranks))
    faction:Log('gruendung', ('%s hat die Fraktion gegruendet.'):format(ownerName))

    Factions.List[id] = faction
    TriggerEvent('factions:server:created', id)

    return faction, ''
end

Factions.Class = Faction
