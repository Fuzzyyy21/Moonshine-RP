--- Fraktionsmissionen: gemeinsame Ziele, gemeinsame Belohnung.
---
--- Anders als die persoenlichen Missionen zaehlt hier die ganze Fraktion. Die
--- Belohnung geht in Kasse und Fraktions-XP.

Factions.MissionPool = {
    { id = 'kasse',     event = 'deposit',   goal = 250000, icon = '💰',
      label = 'Kriegskasse',  description = 'Zahlt zusammen 250.000 $ in die Kasse ein.',
      reward = { kasse = 60000, xp = 900 } },

    { id = 'boss',      event = 'boss',      goal = 8,      icon = '☠',
      label = 'Jagdrudel',    description = 'Erlegt acht Weltbosse.',
      reward = { kasse = 90000, xp = 1400 } },

    { id = 'gebiet',    event = 'capture',   goal = 2,      icon = '🏴',
      label = 'Landnahme',    description = 'Nehmt zwei Gebiete ein.',
      reward = { kasse = 120000, xp = 1800 } },

    { id = 'steine',    event = 'craft',     goal = 15,     icon = '◆',
      label = 'Steinbruch',   description = 'Bindet 15 Klassensteine.',
      reward = { kasse = 70000, xp = 1100 } },

    { id = 'rituale',   event = 'ritual',    goal = 20,     icon = '🕯',
      label = 'Nachtwache',   description = 'Fuehrt 20 Rituale durch.',
      reward = { kasse = 65000, xp = 1000 } },

    { id = 'spielzeit', event = 'playtime',  goal = 1200,   icon = '⏳',
      label = 'Dauerpraesenz', description = 'Sammelt 20 Stunden Spielzeit.',
      reward = { kasse = 80000, xp = 1200 } },

    { id = 'retten',    event = 'revive',    goal = 25,     icon = '💚',
      label = 'Sanitaetsdienst', description = 'Belebt 25 Wesen wieder.',
      reward = { kasse = 55000, xp = 900 } },

    { id = 'shop',      event = 'buyStone',  goal = 60,     icon = '🪙',
      label = 'Grosseinkauf', description = 'Kauft 60 Grundsteine beim Haendler.',
      reward = { kasse = 50000, xp = 800 } },
}

Factions.MissionById = {}
for _, mission in ipairs(Factions.MissionPool) do
    Factions.MissionById[mission.id] = mission
end

--- Laufender Zeitraum (taeglich).
function Factions.MissionPeriod()
    return os.date('%Y-%m-%d', os.time() - FactionConfig.Missions.resetHour * 3600)
end

--- Auswahl je Fraktion und Zeitraum - stabil ueber Neustarts.
local function pickMissions(factionId, period)
    local pool = Factions.MissionPool
    if #pool == 0 then return {} end

    local state = factionId * 7919
    for index = 1, #period do
        state = (state * 31 + period:byte(index)) % 2147483647
    end

    local order = {}
    for index, mission in ipairs(pool) do order[index] = mission end

    for index = #order, 2, -1 do
        state = (state * 1103515245 + 12345) % 2147483648
        local swap = (state % index) + 1
        order[index], order[swap] = order[swap], order[index]
    end

    local picked = {}
    for index = 1, math.min(FactionConfig.Missions.active, #order) do
        picked[index] = order[index]
    end

    return picked
end

--- Laedt bzw. legt die Missionen einer Fraktion an.
function Factions.LoadMissions(faction)
    if not FactionConfig.Missions.enabled then return end

    local period = Factions.MissionPeriod()
    local rows = Factions.DB.LoadMissions(faction.id, period)

    local existing = {}
    for _, row in ipairs(rows) do existing[row.mission_id] = row end

    faction.missions = {}
    faction.missionPeriod = period

    for _, mission in ipairs(pickMissions(faction.id, period)) do
        local row = existing[mission.id]

        if not row then
            Factions.DB.InsertMission(faction.id, mission.id, period)
        end

        faction.missions[mission.id] = {
            id       = mission.id,
            progress = row and tonumber(row.progress) or 0,
            claimed  = row ~= nil and tonumber(row.claimed) == 1,
            period   = period,
        }
    end
end

--- Treibt eine Fraktionsmission voran.
function Factions.Advance(factionId, event, amount)
    if not FactionConfig.Missions.enabled then return end

    local faction = Factions.Get(factionId)
    if not faction then return end

    amount = math.floor(tonumber(amount) or 1)
    if amount <= 0 then return end

    local changed = false

    for missionId, state in pairs(faction.missions) do
        local mission = Factions.MissionById[missionId]

        if mission and mission.event == event and not state.claimed
            and state.progress < mission.goal then

            local before = state.progress
            state.progress = math.min(mission.goal, state.progress + amount)

            if state.progress ~= before then
                changed = true
                Factions.DB.SaveMission(faction.id, missionId, state.period,
                    state.progress, state.claimed)

                if state.progress >= mission.goal then
                    faction:Notify(('Fraktionsmission erfuellt: %s'):format(mission.label),
                        'success', 9000)
                end
            end
        end
    end

    if changed then faction:Sync() end
end

--- Fortschritt anhand eines Spielers.
function Factions.AdvanceForPlayer(source, event, amount)
    local faction = Factions.GetByPlayer(source)
    if faction then Factions.Advance(faction.id, event, amount) end
end

--- Baut die Missionsanzeige.
function Factions.BuildMissionPayload(faction)
    local entries = {}

    for missionId, state in pairs(faction.missions or {}) do
        local mission = Factions.MissionById[missionId]

        if mission then
            entries[#entries + 1] = {
                id          = missionId,
                label       = mission.label,
                description = mission.description,
                icon        = mission.icon,
                goal        = mission.goal,
                progress    = state.progress,
                claimed     = state.claimed,
                done        = state.progress >= mission.goal,
                kasse       = mission.reward.kasse,
                xp          = mission.reward.xp,
            }
        end
    end

    table.sort(entries, function(a, b) return a.label < b.label end)
    return entries
end

RegisterNetEvent('factions:server:claimMission', function(missionId)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'missions') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    local state = faction.missions[missionId]
    local mission = Factions.MissionById[missionId]
    if not state or not mission then return end

    if state.claimed then
        player:Notify('Diese Mission ist bereits abgerechnet.', 'error')
        return
    end

    if state.progress < mission.goal then
        player:Notify('Diese Mission ist noch nicht erfuellt.', 'error')
        return
    end

    state.claimed = true
    Factions.DB.SaveMission(faction.id, missionId, state.period, state.progress, true)

    local bonus = faction:GetModifiers().missionReward or 0
    local kasse = math.floor(mission.reward.kasse * (1 + bonus))

    faction:AddKasse(kasse, ('Mission: %s'):format(mission.label))
    faction:AddXp(mission.reward.xp)
    faction:Save()

    faction:Notify(('%s abgerechnet: %s fuer die Kasse.'):format(
        mission.label, MS.Utils.FormatMoney(kasse)), 'success', 9000)
    faction:Sync()
end)

-- Zeitraumwechsel ------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(60000)

        local period = Factions.MissionPeriod()

        for _, faction in pairs(Factions.List) do
            if faction.missionPeriod ~= period then
                Factions.LoadMissions(faction)
                faction:Sync()
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(60 * 60000)
        if Factions.DB.Ready then
            pcall(Factions.DB.CleanupMissions, Factions.MissionPeriod())
        end
    end
end)

-- Ereignisse aus anderen Resources ----------------------------------------------------

AddEventHandler('mystic:server:stoneCrafted', function(source, _, amount)
    Factions.AdvanceForPlayer(source, 'craft', math.floor(tonumber(amount) or 1))
end)

AddEventHandler('mystic:server:ritualPerformed', function(source)
    Factions.AdvanceForPlayer(source, 'ritual', 1)
end)

AddEventHandler('mystic:server:stoneBought', function(source, _, amount)
    Factions.AdvanceForPlayer(source, 'buyStone', math.floor(tonumber(amount) or 1))
end)

AddEventHandler('moonshine-death:server:playerRevived', function(_, medic)
    if medic then Factions.AdvanceForPlayer(medic, 'revive', 1) end
end)

AddEventHandler('boss:server:participantRewarded', function(source)
    Factions.AdvanceForPlayer(source, 'boss', 1)
end)
