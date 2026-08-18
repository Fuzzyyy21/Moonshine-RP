--- Uhrzeit und Wetter beim Client nachhalten.
---
--- Der Server schickt die Zeit im Takt von WorldConfig.Time.syncInterval.
--- Dazwischen laesst der Client die Uhr selbst weiterlaufen, damit sie nicht
--- springt.

World.Now = {
    day = 0, hour = 20, minute = 0,
    weather = 'CLEAR', night = true, phase = nil,
}

local frozen = false
local lastTick = 0

--- Setzt die Uhr im Spiel.
local function applyTime()
    NetworkOverrideClockTime(World.Now.hour, World.Now.minute, 0)
end

RegisterNetEvent('world:client:time', function(payload)
    if not payload then return end

    World.Now.day    = payload.day or 0
    World.Now.hour   = payload.hour or 0
    World.Now.minute = payload.minute or 0
    World.Now.night  = payload.night == true
    World.Now.phase  = payload.phase

    if payload.weather then World.Now.weather = payload.weather end

    lastTick = GetGameTimer()
    applyTime()

    SendNUIMessage({ action = 'world:time', data = payload })
end)

RegisterNetEvent('world:client:phase', function(phase)
    World.Now.phase = phase

    if phase then
        SendNUIMessage({ action = 'world:phase', data = phase })
    end
end)

--- Wetterwechsel mit weichem Uebergang.
RegisterNetEvent('world:client:weather', function(payload)
    if not payload or not payload.weather then return end

    World.Now.weather = payload.weather

    ClearOverrideWeather()
    ClearWeatherTypePersist()

    if (payload.transition or 0) > 0 then
        SetWeatherTypeOverTime(payload.weather, payload.transition + 0.0)
        Wait(math.floor((payload.transition + 0.5) * 1000))
    end

    SetWeatherTypePersist(payload.weather)
    SetWeatherTypeNow(payload.weather)
    SetWeatherTypeNowPersist(payload.weather)

    SendNUIMessage({ action = 'world:weather', data = payload })
end)

--- Das Spiel darf die Uhr nicht selbst weiterdrehen.
CreateThread(function()
    while true do
        Wait(0)
        applyTime()
    end
end)

--- Zwischen zwei Syncs selbst weiterzaehlen.
CreateThread(function()
    while true do
        Wait(200)

        if not frozen and lastTick > 0 then
            local elapsed = GetGameTimer() - lastTick

            if elapsed >= WorldConfig.Time.minuteLength then
                local minutes = math.floor(elapsed / WorldConfig.Time.minuteLength)
                lastTick = lastTick + minutes * WorldConfig.Time.minuteLength

                World.Now.minute = World.Now.minute + minutes

                while World.Now.minute >= 60 do
                    World.Now.minute = World.Now.minute - 60
                    World.Now.hour = (World.Now.hour + 1) % 24
                end

                World.Now.night = World.IsNight(World.Now.hour)

                SendNUIMessage({ action = 'world:tick', data = {
                    hour = World.Now.hour, minute = World.Now.minute,
                    night = World.Now.night,
                } })
            end
        end
    end
end)

--- Waehrend eines Ereignisses mit `freezeTime` steht die Uhr still.
RegisterNetEvent('world:client:freeze', function(state)
    frozen = state == true
end)

--- Beim Start einmal nachfragen.
CreateThread(function()
    Wait(3000)
    TriggerServerEvent('world:server:request')
end)

--- Andere Resources duerfen die Uhrzeit abfragen.
exports('GetTime', function()
    return World.Now.hour, World.Now.minute, World.Now.day
end)

exports('IsNight', function()
    return World.Now.night
end)

exports('GetMoonPhase', function()
    return World.Now.phase and World.Now.phase.id or nil
end)
