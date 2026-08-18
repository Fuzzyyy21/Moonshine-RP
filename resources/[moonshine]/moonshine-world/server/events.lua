--- Weltereignisse: Auswahl, Ablauf und Wirkung.

World.Active = nil        -- laufendes Ereignis
World.NextAt = 0          -- Zeitstempel des naechsten Ereignisses

--- Laeuft gerade ein Ereignis, das die Zeit anhaelt?
function World.IsTimeFrozen()
    return World.Active ~= nil and World.Active.definition.freezeTime == true
end

--- Waehrend eines Ereignisses bestimmt das Ereignis das Wetter.
function World.IsWeatherLocked()
    return World.Active ~= nil and World.Active.definition.weather ~= nil
end

--- Klasse eines Spielers, falls das Mystik-System laeuft.
local function raceOf(source)
    local race = nil
    pcall(function() race = exports['moonshine-mystic']:GetRace(source) end)

    return race
end

--- Zustand des Ereignisses fuer die Clients.
---@param raceName string|nil Klasse des Empfaengers, fuer die Wirkungsliste
function World.GetEventPayload(raceName)
    if not World.Active then
        return {
            active = false,
            nextIn = math.max(0, World.NextAt - os.time()),
        }
    end

    local definition = World.Active.definition

    return {
        active      = true,
        id          = definition.id,
        label       = definition.label,
        icon        = definition.icon,
        headline    = definition.headline,
        description = definition.description,
        tint        = definition.tint,
        timecycle   = definition.timecycle,
        freezeTime  = definition.freezeTime == true,
        remaining   = math.max(0, World.Active.endsAt - os.time()),
        duration    = definition.duration * 60,
        effects     = World.DescribeEvent(definition, raceName),
    }
end

--- Schickt den Ereigniszustand. Ohne Ziel bekommt jeder Spieler die
--- Wirkungsliste seiner eigenen Klasse.
function World.SyncEvent(target)
    if target then
        TriggerClientEvent('world:client:event', target, World.GetEventPayload(raceOf(target)))
        TriggerClientEvent('world:client:freeze', target, World.IsTimeFrozen())
        return
    end

    for _, player in pairs(MS.GetPlayers()) do
        TriggerClientEvent('world:client:event', player.source,
            World.GetEventPayload(raceOf(player.source)))
        TriggerClientEvent('world:client:freeze', player.source, World.IsTimeFrozen())
    end
end

--- Modifikatoren aus Mondphase und Ereignis fuer eine Klasse.
function World.GetModifiersFor(raceName)
    local phase = World.GetPhaseForDay(World.State.day)

    return World.BuildModifiers(raceName,
        phase and phase.id or nil,
        World.Active and World.Active.definition.id or nil)
end

--- Die Eingriffe in die uebrigen Systeme.
function World.GetWorldEffects()
    return World.BuildWorldEffects(World.Active and World.Active.definition.id or nil)
end

-- Ablauf ---------------------------------------------------------------------------

--- Kuendigt ein Ereignis an.
local function announce(definition, seconds)
    TriggerClientEvent('world:client:warning', -1, {
        label    = definition.label,
        icon     = definition.icon,
        headline = definition.headline,
        tint     = definition.tint,
        seconds  = seconds,
    })

    for _, player in pairs(MS.GetPlayers()) do
        player:Notify(('%s %s In %d Minuten.'):format(
            definition.icon, definition.headline, math.ceil(seconds / 60)),
            'info', 10000)
    end
end

--- Startet ein Ereignis.
---@param id string
---@param minutes number|nil abweichende Dauer
function World.StartEvent(id, minutes)
    local definition = World.GetEvent(id)
    if not definition then return false end

    if World.Active then World.StopEvent(true) end

    local duration = math.max(1, math.floor(tonumber(minutes) or definition.duration))

    World.Active = {
        definition = definition,
        startedAt  = os.time(),
        endsAt     = os.time() + duration * 60,
        previousWeather = World.State.weather,
    }

    -- Himmel und Uhr nach dem Ereignis richten.
    if definition.forceHour then
        World.SetTime(definition.forceHour, 0, true)
    end

    if definition.weather then
        World.SetWeather(definition.weather)
    end

    -- In der Chronik vermerken.
    table.insert(World.State.history, 1, definition.id)
    while #World.State.history > 12 do table.remove(World.State.history) end

    World.SyncEvent()
    World.SyncTime()

    for _, player in pairs(MS.GetPlayers()) do
        player:Notify(('%s %s'):format(definition.icon, definition.headline),
            'warning', 12000)
    end

    -- Alle Klassenwerte neu berechnen lassen.
    TriggerEvent('world:server:eventStarted', definition.id, duration)
    World.PushModifiers()

    print(('^2[Welt]^7 Ereignis gestartet: %s (%d Minuten).'):format(
        definition.label, duration))

    return true
end

--- Beendet das laufende Ereignis.
function World.StopEvent(quiet)
    if not World.Active then return false end

    local definition = World.Active.definition
    local previous = World.Active.previousWeather

    World.Active = nil

    if definition.weather and previous then
        World.SetWeather(previous)
    end

    World.SyncEvent()

    if not quiet then
        for _, player in pairs(MS.GetPlayers()) do
            player:Notify(('%s ist vorbei.'):format(definition.label), 'info', 8000)
        end
    end

    TriggerEvent('world:server:eventEnded', definition.id)
    World.PushModifiers()

    print(('^2[Welt]^7 Ereignis beendet: %s.'):format(definition.label))
    return true
end

--- Waehlt das naechste Ereignis. Was zuletzt lief, kommt nicht sofort wieder.
local function pickEvent()
    local blocked = {}

    for index = 1, math.min(WorldConfig.Events.noRepeat, #World.State.history) do
        blocked[World.State.history[index]] = true
    end

    local pool = {}
    for _, definition in ipairs(World.Events) do
        if not blocked[definition.id] then pool[#pool + 1] = definition end
    end

    -- Falls alles gesperrt ist, doch die volle Liste nehmen.
    if #pool == 0 then pool = World.Events end

    return World.PickWeighted(pool)
end

--- Terminiert das naechste Ereignis.
local function scheduleNext(delayMinutes)
    local minutes = delayMinutes or math.random(WorldConfig.Events.minGap,
        WorldConfig.Events.maxGap)

    World.NextAt = os.time() + minutes * 60

    if WorldConfig.Debug then
        print(('^3[Welt]^7 Naechstes Ereignis in %d Minuten.'):format(minutes))
    end
end

--- Schickt allen Spielern ihre neuen Modifikatoren.
function World.PushModifiers()
    for _, player in pairs(MS.GetPlayers()) do
        TriggerClientEvent('world:client:modifiers', player.source,
            World.GetModifiersFor(raceOf(player.source)))
    end
end

-- Zeitsteuerung ---------------------------------------------------------------------

CreateThread(function()
    while not World.DB.Ready do Wait(500) end

    scheduleNext(WorldConfig.Events.firstDelay)

    local warned = false

    while true do
        Wait(5000)

        if WorldConfig.Events.enabled then
            local now = os.time()

            if World.Active then
                warned = false

                if now >= World.Active.endsAt then
                    World.StopEvent()
                    scheduleNext()
                end
            else
                local remaining = World.NextAt - now

                if not warned and remaining <= WorldConfig.Events.warning
                    and remaining > 0 then
                    local upcoming = pickEvent()

                    if upcoming then
                        World.Upcoming = upcoming.id
                        announce(upcoming, remaining)
                        warned = true
                    end
                end

                if remaining <= 0 then
                    local definition = World.Upcoming and World.GetEvent(World.Upcoming)
                        or pickEvent()

                    World.Upcoming = nil
                    warned = false

                    if definition then World.StartEvent(definition.id) end
                end
            end
        end
    end
end)

--- Die Anzeige braucht regelmaessig frische Restzeiten.
CreateThread(function()
    while true do
        Wait(15000)
        World.SyncEvent()
    end
end)

--- Bei Klassenwechsel und Aufstieg neu rechnen.
AddEventHandler('mystic:server:playerAwakened', function(source)
    CreateThread(function()
        Wait(500)

        TriggerClientEvent('world:client:modifiers', source,
            World.GetModifiersFor(raceOf(source)))
        World.SyncEvent(source)
    end)
end)
