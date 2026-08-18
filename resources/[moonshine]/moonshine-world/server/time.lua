--- Serverzeit und Wetter.
---
--- Der Server ist die einzige Quelle. Die Clients halten ihre Uhr nur nach.

MS = MS or exports['moonshine-core']:GetCoreObject()

World.State = {
    day     = 0,
    hour    = WorldConfig.Time.startHour,
    minute  = WorldConfig.Time.startMinute,
    weather = 'CLEAR',
    phase   = nil,
    history = {},
}

local weatherUntil = 0
local dirty = false

--- Ganzer Zustand fuer die Clients.
function World.GetTimePayload()
    local phase = World.GetPhaseForDay(World.State.day)

    return {
        day     = World.State.day,
        hour    = World.State.hour,
        minute  = World.State.minute,
        weather = World.State.weather,
        phase   = phase and {
            id          = phase.id,
            label       = phase.label,
            icon        = phase.icon,
            description = phase.description,
            index       = phase.index,
            total       = #World.Phases,
        } or nil,
        night = World.IsNight(World.State.hour),
    }
end

function World.SyncTime(target)
    TriggerClientEvent('world:client:time', target or -1, World.GetTimePayload())
end

--- Setzt die Uhrzeit.
function World.SetTime(hour, minute, silent)
    hour = math.floor(tonumber(hour) or 0) % 24
    minute = math.floor(tonumber(minute) or 0) % 60

    World.State.hour = hour
    World.State.minute = minute
    dirty = true

    World.SyncTime()

    if not silent then
        TriggerEvent('world:server:timeChanged', hour, minute)
    end
end

--- Setzt den Tageszaehler und damit die Mondphase.
function World.SetDay(day)
    World.State.day = math.max(0, math.floor(tonumber(day) or 0))
    dirty = true

    local phase = World.GetPhaseForDay(World.State.day)
    World.SyncTime()

    TriggerEvent('world:server:phaseChanged', phase and phase.id or nil)
    return phase
end

-- Wetter -------------------------------------------------------------------------

--- Bezeichnung eines Wettertyps.
function World.GetWeatherLabel(weatherType)
    for _, entry in ipairs(WorldConfig.Weather.pool) do
        if entry.type == weatherType then return entry.label end
    end

    local EXTRA = {
        XMAS = 'Schneefall', SNOWLIGHT = 'Leichter Schnee',
        BLIZZARD = 'Schneesturm', HALLOWEEN = 'Unheimlich',
        NEUTRAL = 'Neutral',
    }

    return EXTRA[weatherType] or weatherType
end

--- Setzt das Wetter.
---@param weatherType string
---@param holdMinutes number|nil Wie lange es mindestens haelt
function World.SetWeather(weatherType, holdMinutes)
    if type(weatherType) ~= 'string' then return false end

    World.State.weather = weatherType:upper()
    dirty = true

    if holdMinutes then
        weatherUntil = os.time() + math.floor(holdMinutes * 60)
    end

    TriggerClientEvent('world:client:weather', -1, {
        weather    = World.State.weather,
        label      = World.GetWeatherLabel(World.State.weather),
        transition = WorldConfig.Weather.transition,
    })

    TriggerEvent('world:server:weatherChanged', World.State.weather)
    return true
end

--- Waehlt ein neues Wetter aus dem Pool.
local function rollWeather()
    local entry = World.PickWeighted(WorldConfig.Weather.pool)
    if not entry then return end

    local duration = math.random(WorldConfig.Weather.minDuration,
        WorldConfig.Weather.maxDuration)

    World.SetWeather(entry.type, duration)
end

-- Uhr ------------------------------------------------------------------------------

CreateThread(function()
    while not World.DB.Ready do Wait(500) end

    local row = World.DB.Load()

    World.State.day     = tonumber(row.day) or 0
    World.State.hour    = tonumber(row.hour) or WorldConfig.Time.startHour
    World.State.minute  = tonumber(row.minute) or 0
    World.State.weather = row.weather or 'CLEAR'

    local ok, history = pcall(json.decode, row.history or '[]')
    World.State.history = (ok and type(history) == 'table') and history or {}

    local phase = World.GetPhaseForDay(World.State.day)
    print(('^2[Welt]^7 Tag %d, %s Uhr, %s, %s.'):format(
        World.State.day, World.FormatTime(World.State.hour, World.State.minute),
        World.GetWeatherLabel(World.State.weather), phase and phase.label or '?'))

    World.SyncTime()

    if WorldConfig.Weather.enabled and weatherUntil == 0 then
        weatherUntil = os.time() + math.random(WorldConfig.Weather.minDuration,
            WorldConfig.Weather.maxDuration) * 60
    end

    -- Minutentakt
    while true do
        local length = WorldConfig.Time.minuteLength

        -- Nachts laeuft die Zeit optional schneller.
        local from, to = WorldConfig.Time.nightFrom, WorldConfig.Time.nightTo
        local inNightWindow = from <= to
            and (World.State.hour >= from and World.State.hour < to)
            or (World.State.hour >= from or World.State.hour < to)

        if inNightWindow then
            length = math.floor(length * WorldConfig.Time.nightMultiplier)
        end

        Wait(math.max(50, length))

        if WorldConfig.Time.enabled and not World.IsTimeFrozen() then
            World.State.minute = World.State.minute + 1

            if World.State.minute >= 60 then
                World.State.minute = 0
                World.State.hour = World.State.hour + 1

                if World.State.hour >= 24 then
                    World.State.hour = 0
                    World.State.day = World.State.day + 1

                    local newPhase = World.GetPhaseForDay(World.State.day)
                    TriggerEvent('world:server:phaseChanged', newPhase and newPhase.id or nil)

                    if newPhase then
                        TriggerClientEvent('world:client:phase', -1, {
                            id = newPhase.id, label = newPhase.label,
                            icon = newPhase.icon, description = newPhase.description,
                        })
                    end
                end
            end

            dirty = true
        end
    end
end)

--- Regelmaessiger Abgleich mit den Clients.
CreateThread(function()
    while true do
        Wait(WorldConfig.Time.syncInterval * 1000)
        World.SyncTime()
    end
end)

--- Wetterwechsel.
CreateThread(function()
    while not World.DB.Ready do Wait(500) end

    while true do
        Wait(30000)

        if WorldConfig.Weather.enabled and not World.IsWeatherLocked()
            and os.time() >= weatherUntil then
            rollWeather()
        end
    end
end)

--- Speichern.
CreateThread(function()
    while true do
        Wait(60000)

        if dirty and World.DB.Ready then
            World.DB.Save({
                day = World.State.day, hour = World.State.hour,
                minute = World.State.minute, weather = World.State.weather,
                history = World.State.history,
            })

            dirty = false
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not World.DB.Ready then return end

    World.DB.Save({
        day = World.State.day, hour = World.State.hour,
        minute = World.State.minute, weather = World.State.weather,
        history = World.State.history,
    })
end)
