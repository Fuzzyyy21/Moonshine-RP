--- Lebenszyklus, API und Commands der Welt.

-- Spieler ----------------------------------------------------------------------

AddEventHandler('moonshine:server:playerLoaded', function(source)
    CreateThread(function()
        Wait(1500)

        TriggerClientEvent('world:client:time', source, World.GetTimePayload())
        World.SyncEvent(source)
        TriggerClientEvent('world:client:weather', source, {
            weather    = World.State.weather,
            label      = World.GetWeatherLabel(World.State.weather),
            transition = 0.0,
        })

        Wait(2000)

        local race = nil
        pcall(function() race = exports['moonshine-mystic']:GetRace(source) end)

        TriggerClientEvent('world:client:modifiers', source, World.GetModifiersFor(race))

        -- Wer mitten in ein Ereignis hineinjoint, soll wissen, was los ist.
        if World.Active then
            local player = MS.GetPlayer(source)
            if player then
                player:Notify(('%s %s'):format(World.Active.definition.icon,
                    World.Active.definition.headline), 'warning', 10000)
            end
        end
    end)
end)

RegisterNetEvent('world:server:request', function()
    local source = source
    if not MS.GetPlayer(source) then return end

    TriggerClientEvent('world:client:time', source, World.GetTimePayload())
    World.SyncEvent(source)
end)

-- API -----------------------------------------------------------------------------

exports('GetWorldObject', function()
    return World
end)

--- Aktuelle Uhrzeit.
---@return number hour, number minute, number day
exports('GetTime', function()
    return World.State.hour, World.State.minute, World.State.day
end)

exports('SetTime', function(hour, minute)
    World.SetTime(hour, minute)
    return true
end)

exports('GetWeather', function()
    return World.State.weather
end)

exports('SetWeather', function(weatherType, holdMinutes)
    return World.SetWeather(weatherType, holdMinutes)
end)

--- Laufende Mondphase.
exports('GetMoonPhase', function()
    local phase = World.GetPhaseForDay(World.State.day)
    return phase and phase.id or nil
end)

exports('IsFullMoon', function()
    local phase = World.GetPhaseForDay(World.State.day)
    return phase ~= nil and phase.id == 'vollmond'
end)

exports('IsNight', function()
    return World.IsNight(World.State.hour)
end)

--- Laufendes Ereignis oder nil.
exports('GetActiveEvent', function()
    return World.Active and World.Active.definition.id or nil
end)

exports('IsEventActive', function(id)
    if not World.Active then return false end
    if not id then return true end

    return World.Active.definition.id == id
end)

--- Modifikatoren aus Phase und Ereignis fuer eine Klasse.
exports('GetModifiers', function(raceName)
    return World.GetModifiersFor(raceName)
end)

--- Modifikatoren fuer einen bestimmten Spieler.
exports('GetModifiersForPlayer', function(source)
    local race = nil
    pcall(function() race = exports['moonshine-mystic']:GetRace(source) end)

    return World.GetModifiersFor(race)
end)

--- Eingriffe in andere Systeme: bossInterval, stoneBonus, ritualBonus, sunlightDamage.
exports('GetWorldEffects', function()
    return World.GetWorldEffects()
end)

exports('StartEvent', function(id, minutes)
    return World.StartEvent(id, minutes)
end)

exports('StopEvent', function()
    return World.StopEvent()
end)

-- Commands ---------------------------------------------------------------------------

local function permission(source, level)
    if source == 0 then return true end

    local player = MS.GetPlayer(source)
    return player ~= nil and (player.adminLevel or 0) >= level
end

RegisterCommand('zeit', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local phase = World.GetPhaseForDay(World.State.day)

    player:Notify(('%s Uhr · Tag %d · %s %s · %s'):format(
        World.FormatTime(World.State.hour, World.State.minute),
        World.State.day,
        phase and phase.icon or '', phase and phase.label or '',
        World.GetWeatherLabel(World.State.weather)), 'info', 9000)
end, false)

RegisterCommand('ereignis', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    if World.Active then
        local remaining = math.max(0, World.Active.endsAt - os.time())
        player:Notify(('%s %s - noch %d Minuten.'):format(
            World.Active.definition.icon, World.Active.definition.label,
            math.ceil(remaining / 60)), 'info', 9000)
    else
        local minutes = math.ceil(math.max(0, World.NextAt - os.time()) / 60)
        player:Notify(('Gerade ist es ruhig. Naechstes Ereignis in etwa %d Minuten.')
            :format(minutes), 'info', 9000)
    end
end, false)

RegisterCommand('setzeit', function(source, args)
    if not permission(source, 2) then return end

    local hour = tonumber(args[1])
    local minute = tonumber(args[2]) or 0
    if not hour then return end

    World.SetTime(hour, minute)
end, false)

RegisterCommand('setwetter', function(source, args)
    if not permission(source, 2) then return end
    if not args[1] then return end

    World.SetWeather(args[1]:upper(), tonumber(args[2]))
end, false)

RegisterCommand('setmond', function(source, args)
    if not permission(source, 3) then return end

    -- Entweder eine Phasen-ID oder ein Tageszaehler.
    local phase = World.GetPhase(args[1])

    if phase then
        -- Auf den naechsten Tag mit dieser Phase springen.
        local current = World.State.day
        local target = current + ((phase.index - 1 - (current % #World.Phases)) % #World.Phases)

        World.SetDay(target)
    else
        World.SetDay(tonumber(args[1]) or 0)
    end

    local now = World.GetPhaseForDay(World.State.day)
    print(('Mondphase: %s'):format(now and now.label or '?'))
end, false)

RegisterCommand('startereignis', function(source, args)
    if not permission(source, 3) then return end

    if not args[1] then
        local names = {}
        for _, definition in ipairs(World.Events) do names[#names + 1] = definition.id end
        print(('Verwendung: /startereignis [%s] [minuten]'):format(table.concat(names, '|')))
        return
    end

    if not World.StartEvent(args[1], tonumber(args[2])) then
        print('Unbekanntes Ereignis.')
    end
end, false)

RegisterCommand('stopereignis', function(source)
    if not permission(source, 3) then return end
    World.StopEvent()
end, false)

print('^2[Welt]^7 Weltsystem geladen.')
