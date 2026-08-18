--- Rassenspezifische Dauermechaniken (Sonnenlicht, Mondlicht, Sicht).

local MS = exports['moonshine-core']:GetCoreObject()

local function currentRace()
    return Mystic.Profile and Mystic.Profile.race or nil
end

local function isBetween(hour, fromHour, toHour)
    if fromHour <= toHour then
        return hour >= fromHour and hour < toHour
    end
    -- Zeitraum ueber Mitternacht
    return hour >= fromHour or hour < toHour
end

-- Vampire: Sonnenlicht --------------------------------------------------------

CreateThread(function()
    local config = MysticConfig.Weaknesses.sunlight
    if not config.enabled then return end

    local warned = false

    while true do
        Wait(config.interval * 1000)

        if currentRace() == 'vampir' and MS.IsPlayerLoaded then
            local mods = Mystic.GetActiveModifiers()
            local ped = PlayerPedId()
            local hour = GetClockHours()

            local exposed = isBetween(hour, config.fromHour, config.toHour)
                and not mods.sunImmune
                and not IsPedInAnyVehicle(ped, false)
                and GetInteriorFromEntity(ped) == 0
                and not IsEntityDead(ped)

            if exposed then
                if not warned then
                    MS.Notify('Die Sonne verbrennt dich. Such dir Schatten.', 'error')
                    warned = true
                end

                SetEntityHealth(ped, math.max(1, GetEntityHealth(ped) - config.damage))
                AnimpostfxPlay('MinigameEndNeutral', 800, false)
            else
                warned = false
            end
        end
    end
end)

-- Werwoelfe: Mondlicht --------------------------------------------------------

CreateThread(function()
    local config = MysticConfig.Weaknesses.moonlight
    if not config.enabled then return end

    local buffed = false

    while true do
        Wait(10000)

        if currentRace() == 'werwolf' and MS.IsPlayerLoaded then
            local night = isBetween(GetClockHours(), config.fromHour, config.toHour)

            if night and not buffed then
                buffed = true
                Mystic.Buffs['moonlight'] = {
                    expires   = GetGameTimer() + 24 * 60 * 60 * 1000,
                    meleeMult = config.damageMult,
                }
                MS.Notify('Der Mond steht hoch. Deine Kraft waechst.', 'success', 6000)

            elseif not night and buffed then
                buffed = false
                Mystic.Buffs['moonlight'] = nil
                MS.Notify('Der Morgen daemmert, deine Kraft schwindet.', 'info')
            end
        end
    end
end)

-- Vampire und Werwoelfe sehen im Dunkeln besser ------------------------------

CreateThread(function()
    local nightVisionActive = false

    while true do
        Wait(15000)

        local race = currentRace()
        local night = GetClockHours() >= 21 or GetClockHours() < 6

        if (race == 'vampir' or race == 'werwolf') and night then
            if not nightVisionActive then
                -- Leichte Aufhellung statt vollem Nachtsichtgeraet.
                SetTimecycleModifier('cinema_MP')
                SetTimecycleModifierStrength(0.25)
                nightVisionActive = true
            end
        elseif nightVisionActive then
            -- Nur zuruecksetzen, was wir selbst gesetzt haben; Flueche und
            -- Gifte raeumen ihren Timecycle selbst auf.
            ClearTimecycleModifier()
            nightVisionActive = false
        end
    end
end)

AddEventHandler('mystic:client:raceChanged', function()
    ClearTimecycleModifier()
    Mystic.Buffs['moonlight'] = nil
end)
