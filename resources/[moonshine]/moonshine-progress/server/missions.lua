--- Taegliche und woechentliche Missionen.
---
--- Jeder Charakter zieht pro Zeitraum eine feste, aber zufaellige Auswahl aus
--- den Vorlagen in shared/missions.lua. Die Auswahl haengt am Zeitraum-
--- Schluessel, damit ein Relog nicht neu wuerfelt.

--- Deterministischer Zufall aus Charakter-ID und Zeitraum.
local function seedFor(characterId, period)
    local seed = characterId * 7919

    for index = 1, #period do
        seed = (seed * 31 + period:byte(index)) % 2147483647
    end

    return seed
end

--- Waehlt `count` Vorlagen einer Art - fuer denselben Zeitraum immer dieselben.
local function pickMissions(characterId, kind, period, count)
    local pool = Progress.GetMissionPool(kind)
    if #pool == 0 then return {} end

    -- Eigener Generator, damit math.randomseed nicht global veraendert wird.
    local state = seedFor(characterId, period)
    local function nextInt(max)
        state = (state * 1103515245 + 12345) % 2147483648
        return (state % max) + 1
    end

    -- Fisher-Yates auf einer Kopie.
    local order = {}
    for index, mission in ipairs(pool) do order[index] = mission end

    for index = #order, 2, -1 do
        local swap = nextInt(index)
        order[index], order[swap] = order[swap], order[index]
    end

    local picked = {}
    for index = 1, math.min(count, #order) do
        picked[index] = order[index]
    end

    return picked
end

--- Legt die Missionen eines Profils an bzw. laedt sie.
function Progress.LoadMissions(profile)
    if not ProgressConfig.Missions.enabled then return end

    local daily, weekly = Progress.Periods()

    local selection = {}
    for _, mission in ipairs(pickMissions(profile.characterId, 'daily', daily,
        ProgressConfig.Missions.dailyCount)) do
        selection[mission.id] = { mission = mission, period = daily }
    end

    for _, mission in ipairs(pickMissions(profile.characterId, 'weekly', weekly,
        ProgressConfig.Missions.weeklyCount)) do
        selection[mission.id] = { mission = mission, period = weekly }
    end

    -- Bestehende Fortschritte einlesen.
    local rows = Progress.DB.LoadMissions(profile.characterId, daily, weekly)
    local existing = {}

    for _, row in ipairs(rows) do
        existing[row.mission_id .. '|' .. row.period] = row
    end

    profile.missions = {}

    for missionId, entry in pairs(selection) do
        local row = existing[missionId .. '|' .. entry.period]

        if not row then
            Progress.DB.InsertMission(profile.characterId, missionId, entry.mission.kind, entry.period)
        end

        profile.missions[missionId] = {
            id       = missionId,
            kind     = entry.mission.kind,
            period   = entry.period,
            progress = row and tonumber(row.progress) or 0,
            claimed  = row ~= nil and tonumber(row.claimed) == 1,
        }
    end

    profile.dailyPeriod  = daily
    profile.weeklyPeriod = weekly
end

--- Prueft, ob ein neuer Zeitraum begonnen hat, und laedt dann neu.
function Progress.RefreshMissions(profile)
    local daily, weekly = Progress.Periods()
    if profile.dailyPeriod == daily and profile.weeklyPeriod == weekly then return false end

    Progress.LoadMissions(profile)
    profile:CheckDay()
    profile:Sync()

    local player = profile:Player()
    if player then
        player:Notify('Neue Missionen stehen bereit.', 'info', 8000)
    end

    return true
end

--- Treibt alle Missionen mit passendem Ereignis voran.
---@param source number
---@param event string  Ereignisname aus shared/missions.lua
---@param amount number Fortschritt (Standard 1)
function Progress.Advance(source, event, amount)
    if not ProgressConfig.Missions.enabled then return end

    local profile = Progress.GetProfile(source)
    if not profile then return end

    amount = math.floor(tonumber(amount) or 1)
    if amount <= 0 then return end

    local player = profile:Player()
    local changed = false

    for missionId, state in pairs(profile.missions) do
        local mission = Progress.GetMission(missionId)

        if mission and mission.event == event and not state.claimed and state.progress < mission.goal then
            local before = state.progress
            state.progress = math.min(mission.goal, state.progress + amount)

            if state.progress ~= before then
                changed = true
                Progress.DB.SaveMission(profile.characterId, missionId, state.period,
                    state.progress, state.claimed)

                if state.progress >= mission.goal and player then
                    player:Notify(('Mission erfuellt: %s'):format(mission.label), 'success', 8000)
                    TriggerClientEvent('progress:client:missionDone', source, missionId)
                end
            end
        end
    end

    if changed then profile:Sync() end
end

--- Holt die Belohnung einer erfuellten Mission ab.
function Progress.ClaimMission(source, missionId)
    local profile = Progress.GetProfile(source)
    if not profile then return false end

    local state = profile.missions[missionId]
    local mission = Progress.GetMission(missionId)
    if not state or not mission then return false end

    local player = profile:Player()
    if not player then return false end

    if state.claimed then
        player:Notify('Diese Mission hast du bereits abgerechnet.', 'error')
        return false
    end

    if state.progress < mission.goal then
        player:Notify('Diese Mission ist noch nicht erfuellt.', 'error')
        return false
    end

    state.claimed = true
    Progress.DB.SaveMission(profile.characterId, missionId, state.period, state.progress, true)

    local _, text = Progress.GiveReward(source, mission.reward, 'mission')
    player:Notify(('%s: %s'):format(mission.label, text), 'success', 8000)

    profile:Save()
    profile:Sync()

    return true
end

--- Baut die Missionsanzeige.
function Progress.BuildMissionPayload(profile)
    local daily, weekly = {}, {}

    for missionId, state in pairs(profile.missions) do
        local mission = Progress.GetMission(missionId)

        if mission then
            local entry = {
                id          = missionId,
                label       = mission.label,
                description = mission.description,
                icon        = mission.icon,
                goal        = mission.goal,
                progress    = state.progress,
                claimed     = state.claimed,
                done        = state.progress >= mission.goal,
                reward      = Progress.DescribeReward(mission.reward),
            }

            if mission.kind == 'weekly' then
                weekly[#weekly + 1] = entry
            else
                daily[#daily + 1] = entry
            end
        end
    end

    local function byLabel(a, b) return a.label < b.label end
    table.sort(daily, byLabel)
    table.sort(weekly, byLabel)

    return {
        daily      = daily,
        weekly     = weekly,
        dailyReset = Progress.SecondsUntilDailyReset(),
    }
end

--- Sekunden bis zum naechsten Tagesreset.
function Progress.SecondsUntilDailyReset()
    local hour = ProgressConfig.Missions.resetHour
    local now  = os.date('*t')

    local target = os.time({
        year = now.year, month = now.month, day = now.day,
        hour = hour, min = 0, sec = 0,
    })

    if target <= os.time() then target = target + 86400 end

    return target - os.time()
end

RegisterNetEvent('progress:server:claimMission', function(missionId)
    if type(missionId) ~= 'string' then return end
    Progress.ClaimMission(source, missionId)
end)

-- Zeitraumwechsel und Aufraeumen ---------------------------------------------

CreateThread(function()
    while true do
        Wait(60000)

        for _, profile in pairs(Progress.Profiles) do
            pcall(Progress.RefreshMissions, profile)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(30 * 60000)

        if Progress.DB.Ready then
            local daily, weekly = Progress.Periods()
            pcall(Progress.DB.CleanupMissions, daily, weekly)
        end
    end
end)

-- Ereignisse aus den anderen Resources ---------------------------------------

AddEventHandler('mystic:server:meditated', function(source)
    Progress.Advance(source, 'meditate', 1)
end)

AddEventHandler('mystic:server:ritualPerformed', function(source)
    Progress.Advance(source, 'ritual', 1)
end)

AddEventHandler('mystic:server:stoneCrafted', function(source, _, amount)
    Progress.Advance(source, 'craft', math.floor(tonumber(amount) or 1))
end)

AddEventHandler('mystic:server:skillUpgraded', function(source)
    Progress.Advance(source, 'skillUpgrade', 1)
end)

AddEventHandler('mystic:server:skillUsed', function(source)
    Progress.Advance(source, 'skillUsed', 1)
end)

AddEventHandler('mystic:server:stoneBought', function(source, _, amount)
    Progress.Advance(source, 'buyStone', math.floor(tonumber(amount) or 1))
end)

AddEventHandler('moonshine-death:server:playerRevived', function(_, medic)
    if medic then Progress.Advance(medic, 'revive', 1) end
end)

AddEventHandler('boss:server:participantRewarded', function(source)
    Progress.Advance(source, 'boss', 1)
end)

--- Wer beim Start eines Weltereignisses online ist, war dabei.
AddEventHandler('world:server:eventStarted', function()
    for source in pairs(Progress.Profiles) do
        Progress.Advance(source, 'worldEvent', 1)
    end
end)
