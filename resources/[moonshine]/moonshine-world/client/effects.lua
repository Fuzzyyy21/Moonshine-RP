--- Sichtbare Wirkung der Weltereignisse.
---
--- Timecycle, Farbstich und Partikel. Die Kampfwerte kommen vom Server,
--- hier geht es nur um Atmosphaere.

local active = nil
local currentTimecycle = nil
local modifiers = {}
local ptfxReady = false

--- Partikel-Asset einmalig laden.
local function ensurePtfx()
    if ptfxReady then return true end

    if not HasNamedPtfxAssetLoaded('core') then
        RequestNamedPtfxAsset('core')

        local tries = 0
        while not HasNamedPtfxAssetLoaded('core') and tries < 60 do
            Wait(50)
            tries = tries + 1
        end
    end

    ptfxReady = HasNamedPtfxAssetLoaded('core')
    return ptfxReady
end

--- Setzt einen Timecycle-Effekt.
local function applyTimecycle(name, strength)
    if currentTimecycle then
        ClearTimecycleModifier()
        currentTimecycle = nil
    end

    if name then
        SetTimecycleModifier(name)
        SetTimecycleModifierStrength(strength or 0.6)
        currentTimecycle = name
    end
end

--- Ereignis beginnt oder endet.
RegisterNetEvent('world:client:event', function(payload)
    local wasActive = active ~= nil and active.id or nil

    if payload and payload.active then
        active = payload

        if wasActive ~= payload.id then
            applyTimecycle(payload.timecycle, 0.55)

            -- Kurzer Blitz beim Einsetzen.
            AnimpostfxPlay('MinigameTransitionIn', 800, false)
            PlaySoundFrontend(-1, 'Bed', 'WastedSounds', true)

            TriggerEvent('world:client:eventStarted', payload.id)
        end

        TriggerServerEvent('world:server:request')
    else
        if wasActive then
            applyTimecycle(nil)
            AnimpostfxStop('MinigameTransitionIn')
            TriggerEvent('world:client:eventEnded', wasActive)
        end

        active = nil
    end

    SendNUIMessage({ action = 'world:event', data = payload })
end)

--- Vorwarnung.
RegisterNetEvent('world:client:warning', function(payload)
    SendNUIMessage({ action = 'world:warning', data = payload })
    PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
end)

--- Die Werte aus Phase und Ereignis fuer die eigene Klasse.
RegisterNetEvent('world:client:modifiers', function(payload)
    modifiers = payload or {}
    SendNUIMessage({ action = 'world:modifiers', data = modifiers })
end)

exports('GetWorldModifiers', function()
    return modifiers
end)

exports('GetActiveEvent', function()
    return active and active.id or nil
end)

--- Partikel und Umgebungsgeraeusche je Ereignis.
CreateThread(function()
    while true do
        local wait = 1000

        if active then
            wait = 0
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            if active.id == 'aschesturm' then
                -- Ascheflocken um den Spieler herum.
                if math.random() < 0.4 and ensurePtfx() then
                    UseParticleFxAsset('core')
                    StartParticleFxNonLoopedAtCoord('ent_amb_smoke_foundry',
                        coords.x + math.random(-14, 14),
                        coords.y + math.random(-14, 14),
                        coords.z + math.random(2, 9),
                        0.0, 0.0, 0.0, 1.4, false, false, false)
                end

                wait = 220

            elseif active.id == 'sternenfall' then
                if math.random() < 0.25 and ensurePtfx() then
                    UseParticleFxAsset('core')
                    StartParticleFxNonLoopedAtCoord('exp_air_blimp2',
                        coords.x + math.random(-70, 70),
                        coords.y + math.random(-70, 70),
                        coords.z + math.random(45, 90),
                        0.0, 0.0, 0.0, 0.7, false, false, false)
                end

                wait = 900

            elseif active.id == 'blutmond' then
                -- Dunkelroter Schleier ueber der Szene.
                SetTimecycleModifierStrength(0.55 + math.sin(GetGameTimer() / 1400) * 0.12)
                wait = 250

            elseif active.id == 'geisterstunde' then
                SetTimecycleModifierStrength(0.45 + math.sin(GetGameTimer() / 900) * 0.2)
                wait = 200

            elseif active.id == 'nordlicht' then
                SetTimecycleModifierStrength(0.35 + math.sin(GetGameTimer() / 2200) * 0.18)
                wait = 300

            else
                wait = 1000
            end
        end

        Wait(wait)
    end
end)

--- Nebelnacht: Sichtweite drastisch senken.
CreateThread(function()
    while true do
        if active and active.id == 'nebelnacht' then
            SetRainLevel(0.0)
            Wait(500)
        else
            Wait(2000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    applyTimecycle(nil)
    AnimpostfxStopAll()
    ClearOverrideWeather()
    ClearWeatherTypePersist()
end)
