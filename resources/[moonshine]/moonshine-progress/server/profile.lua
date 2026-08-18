--- Fortschrittsprofil je Spieler.
---
--- Haelt Spielzeit, Missionen, Battle Pass und Kistenbestand im Speicher und
--- schreibt sie regelmaessig in die Datenbank.

MS = MS or exports['moonshine-core']:GetCoreObject()

Progress.Profiles = {}

local Profile = {}
Profile.__index = Profile

-- Zeitraeume -----------------------------------------------------------------

--- Zeitstempel, um den Reset-Zeitpunkt verschoben.
local function shifted(time)
    return (time or os.time()) - (ProgressConfig.Missions.resetHour * 3600)
end

--- Schluessel des laufenden Tages, z. B. "2026-08-18".
function Progress.DailyPeriod(time)
    return os.date('%Y-%m-%d', shifted(time))
end

--- Schluessel der laufenden Woche, z. B. "2026-W33".
function Progress.WeeklyPeriod(time)
    return os.date('%Y-W%V', shifted(time))
end

--- Beide Schluessel auf einmal.
function Progress.Periods(time)
    local moment = time or os.time()
    return Progress.DailyPeriod(moment), Progress.WeeklyPeriod(moment)
end

-- Hilfen ---------------------------------------------------------------------

local function decode(raw, fallback)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return fallback end

    local ok, value = pcall(json.decode, raw)
    if not ok or type(value) ~= 'table' then return fallback end

    return value
end

local function contains(list, value)
    for _, entry in ipairs(list) do
        if entry == value then return true end
    end
    return false
end

-- Profil ---------------------------------------------------------------------

function Profile.New(source, characterId, row)
    local self = setmetatable({}, Profile)

    self.source      = source
    self.characterId = characterId

    self.playtimeDay     = row.playtime_day
    self.playtimeMinutes = tonumber(row.playtime_minutes) or 0
    self.playtimeClaimed = decode(row.playtime_claimed, {})
    self.playtimeTotal   = tonumber(row.playtime_total) or 0

    self.season    = tonumber(row.bp_season) or ProgressConfig.BattlePass.season
    self.bpXp      = tonumber(row.bp_xp) or 0
    self.premium   = tonumber(row.bp_premium) == 1
    self.bpClaimed = decode(row.bp_claimed, {})

    self.cases    = decode(row.cases, {})
    self.missions = {}

    self.dirty       = false
    self.minuteCarry = 0

    -- Neue Saison: Fortschritt und Premium zuruecksetzen.
    if self.season ~= ProgressConfig.BattlePass.season then
        self.season    = ProgressConfig.BattlePass.season
        self.bpXp      = 0
        self.premium   = false
        self.bpClaimed = {}
        self.dirty     = true
    end

    -- Neuer Tag: Spielzeit und abgeholte Meilensteine zuruecksetzen.
    local today = Progress.DailyPeriod()
    if self.playtimeDay ~= today then
        self.playtimeDay     = today
        self.playtimeMinutes = 0
        self.playtimeClaimed = {}
        self.dirty           = true
    end

    return self
end

function Profile:Player()
    return MS.GetPlayer(self.source)
end

--- Setzt den Tageszaehler zurueck, wenn der Tag gewechselt hat.
function Profile:CheckDay()
    local today = Progress.DailyPeriod()
    if self.playtimeDay == today then return false end

    self.playtimeDay     = today
    self.playtimeMinutes = 0
    self.playtimeClaimed = {}
    self.dirty           = true

    return true
end

-- Kisten ---------------------------------------------------------------------

function Profile:GetCaseCount(name)
    return math.floor(tonumber(self.cases[name]) or 0)
end

function Profile:AddCase(name, amount)
    if not Progress.GetCase(name) then return false end

    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then return false end

    self.cases[name] = self:GetCaseCount(name) + amount
    self.dirty = true

    return true
end

function Profile:RemoveCase(name, amount)
    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then return false end

    local have = self:GetCaseCount(name)
    if have < amount then return false end

    local left = have - amount
    self.cases[name] = left > 0 and left or nil
    self.dirty = true

    return true
end

-- Battle Pass ----------------------------------------------------------------

function Profile:AddBattlePassXp(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not ProgressConfig.BattlePass.enabled then return 0 end

    local before = Progress.GetBattlePassLevel(self.bpXp)
    self.bpXp = self.bpXp + amount
    self.dirty = true

    local after = Progress.GetBattlePassLevel(self.bpXp)
    if after > before then
        TriggerClientEvent('progress:client:battlePassLevel', self.source, after)
        TriggerEvent('progress:server:battlePassLevel', self.source, after)
    end

    return amount
end

function Profile:IsTierClaimed(level, track)
    return contains(self.bpClaimed, ('%d:%s'):format(level, track))
end

function Profile:MarkTierClaimed(level, track)
    if self:IsTierClaimed(level, track) then return false end

    self.bpClaimed[#self.bpClaimed + 1] = ('%d:%s'):format(level, track)
    self.dirty = true

    return true
end

-- Playtime -------------------------------------------------------------------

function Profile:IsMilestoneClaimed(minutes)
    return contains(self.playtimeClaimed, minutes)
end

function Profile:MarkMilestoneClaimed(minutes)
    if self:IsMilestoneClaimed(minutes) then return false end

    self.playtimeClaimed[#self.playtimeClaimed + 1] = minutes
    self.dirty = true

    return true
end

-- Missionen ------------------------------------------------------------------

function Profile:GetMissionState(missionId)
    return self.missions[missionId]
end

-- Speichern und Senden -------------------------------------------------------

function Profile:Save(force)
    if not force and not self.dirty then return false end
    if not Progress.DB.Ready then return false end

    Progress.DB.Save(self.characterId, {
        playtimeDay     = self.playtimeDay,
        playtimeMinutes = self.playtimeMinutes,
        playtimeClaimed = self.playtimeClaimed,
        playtimeTotal   = self.playtimeTotal,
        season          = self.season,
        bpXp            = self.bpXp,
        premium         = self.premium,
        bpClaimed       = self.bpClaimed,
        cases           = self.cases,
    })

    self.dirty = false
    return true
end

--- Vollstaendiger Zustand fuer die Oberflaeche.
function Profile:GetPayload()
    return {
        playtime   = Progress.BuildPlaytimePayload(self),
        missions   = Progress.BuildMissionPayload(self),
        battlepass = Progress.BuildBattlePassPayload(self),
        cases      = Progress.BuildCasePayload(self),
        config     = {
            season        = ProgressConfig.BattlePass.season,
            seasonLabel   = ProgressConfig.BattlePass.seasonLabel,
            premiumPrice  = ProgressConfig.BattlePass.premiumPrice,
            animationTime = ProgressConfig.Cases.animationTime,
        },
    }
end

function Profile:Sync()
    TriggerClientEvent('progress:client:sync', self.source, self:GetPayload())
end

-- Laden und Entladen ---------------------------------------------------------

function Progress.GetProfile(source)
    return Progress.Profiles[source]
end

function Progress.LoadProfile(source, characterId)
    if not characterId then return nil end

    -- Auf das Schema warten, falls der Spieler sehr frueh joint.
    local tries = 0
    while not Progress.DB.Ready and tries < 40 do
        Wait(250)
        tries = tries + 1
    end

    if not Progress.DB.Ready then
        print('^1[Progress]^7 Datenbank nicht bereit, Profil wird uebersprungen.')
        return nil
    end

    local row = Progress.DB.Load(characterId)
    local profile = Profile.New(source, characterId, row)

    Progress.Profiles[source] = profile
    Progress.LoadMissions(profile)

    profile:Save()
    profile:Sync()

    TriggerEvent('progress:server:profileLoaded', source, profile)
    return profile
end

function Progress.UnloadProfile(source)
    local profile = Progress.Profiles[source]
    if not profile then return end

    Progress.FlushPlaytime(profile)
    profile:Save(true)

    Progress.Profiles[source] = nil
end

Progress.ProfileClass = Profile
