--- Spielzeit und Spielzeit-Belohnungen.
---
--- Die Zeit laeuft nur, solange ein Charakter geladen ist. Gezaehlt wird in
--- vollen Minuten; der Tageszaehler faellt zum Reset-Zeitpunkt auf 0 zurueck.

local TICK = 60000

--- Sortierte Meilensteine (aufsteigend).
local milestones = {}

CreateThread(function()
    for _, entry in ipairs(ProgressConfig.Playtime.milestones) do
        milestones[#milestones + 1] = entry
    end

    table.sort(milestones, function(a, b) return a.minutes < b.minutes end)
end)

function Progress.GetMilestones()
    return milestones
end

--- Meilenstein zu einer Minutenzahl.
local function getMilestone(minutes)
    for _, entry in ipairs(milestones) do
        if entry.minutes == minutes then return entry end
    end
    return nil
end

--- Schreibt angefangene Minuten weg (beim Ausloggen).
function Progress.FlushPlaytime(profile)
    profile.minuteCarry = 0
end

--- Zaehlt eine Minute und meldet neue Meilensteine.
local function tick(profile)
    if not ProgressConfig.Playtime.enabled then return end

    profile:CheckDay()

    profile.playtimeMinutes = profile.playtimeMinutes + 1
    profile.playtimeTotal   = profile.playtimeTotal + 1
    profile.dirty = true

    -- Missionen mit Spielzeitziel mitzaehlen.
    Progress.Advance(profile.source, 'playtime', 1)

    -- Sobald ein Meilenstein erreicht ist, einmalig Bescheid geben.
    for _, entry in ipairs(milestones) do
        if profile.playtimeMinutes == entry.minutes and not profile:IsMilestoneClaimed(entry.minutes) then
            local player = profile:Player()
            if player then
                player:Notify(('Spielzeit-Belohnung bereit: %s (%d Min.)'):format(
                    entry.label, entry.minutes), 'success', 8000)
            end

            TriggerClientEvent('progress:client:milestoneReady', profile.source, entry.minutes)
        end
    end

    if profile.playtimeMinutes % 5 == 0 then profile:Save() end
end

CreateThread(function()
    while true do
        Wait(TICK)

        for _, profile in pairs(Progress.Profiles) do
            local ok, err = pcall(tick, profile)
            if not ok then
                print(('^1[Progress]^7 Spielzeit-Tick fehlgeschlagen: %s'):format(tostring(err)))
            end
        end
    end
end)

--- Baut die Spielzeit-Anzeige.
function Progress.BuildPlaytimePayload(profile)
    local entries = {}

    for _, entry in ipairs(milestones) do
        local claimed  = profile:IsMilestoneClaimed(entry.minutes)
        local reached  = profile.playtimeMinutes >= entry.minutes

        entries[#entries + 1] = {
            minutes  = entry.minutes,
            label    = entry.label,
            claimed  = claimed,
            reached  = reached,
            reward   = Progress.DescribeReward(entry.reward),
            progress = math.min(1.0, profile.playtimeMinutes / entry.minutes),
        }
    end

    return {
        minutes = profile.playtimeMinutes,
        total   = profile.playtimeTotal,
        entries = entries,
    }
end

--- Holt eine Spielzeit-Belohnung ab.
function Progress.ClaimMilestone(source, minutes)
    local profile = Progress.GetProfile(source)
    if not profile then return false end

    minutes = math.floor(tonumber(minutes) or 0)

    local entry = getMilestone(minutes)
    if not entry then return false end

    local player = profile:Player()
    if not player then return false end

    if profile.playtimeMinutes < minutes then
        player:Notify('Diese Spielzeit hast du heute noch nicht erreicht.', 'error')
        return false
    end

    if not profile:MarkMilestoneClaimed(minutes) then
        player:Notify('Diese Belohnung hast du bereits abgeholt.', 'error')
        return false
    end

    local _, text = Progress.GiveReward(source, entry.reward, 'spielzeit')
    player:Notify(('Spielzeit-Belohnung: %s'):format(text), 'success', 8000)

    profile:Save()
    profile:Sync()

    return true
end

RegisterNetEvent('progress:server:claimMilestone', function(minutes)
    Progress.ClaimMilestone(source, minutes)
end)
