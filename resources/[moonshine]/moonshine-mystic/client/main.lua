--- Clientseitiger Zustand des Mystik-Systems.

local MS = exports['moonshine-core']:GetCoreObject()

Mystic.RegisterStones()

Mystic.Profile   = nil    -- zuletzt synchronisierte Profildaten
Mystic.Effects   = {}     -- laufende Effekte auf dem eigenen Spieler
Mystic.Buffs     = {}     -- aktive Selbst-Buffs { [skillId] = { until, ... } }

--- Aktive Modifikatoren inklusive laufender Buffs.
function Mystic.GetActiveModifiers()
    local mods = Mystic.Profile and Mystic.Profile.modifiers or {
        healthBonus = 0, armorBonus = 0, stamina = 0, damageMult = 1.0,
        meleeMult = 1.0, speedMult = 1.0, regenPerTick = 0,
    }

    local result = {
        healthBonus  = mods.healthBonus or 0,
        armorBonus   = mods.armorBonus or 0,
        stamina      = mods.stamina or 0,
        damageMult   = mods.damageMult or 1.0,
        meleeMult    = mods.meleeMult or 1.0,
        speedMult    = mods.speedMult or 1.0,
        regenPerTick = mods.regenPerTick or 0,
        noFallDamage = mods.noFallDamage or false,
        fireImmune   = mods.fireImmune or false,
        sunImmune    = mods.sunImmune or false,
    }

    local now = GetGameTimer()
    for skillId, buff in pairs(Mystic.Buffs) do
        if buff.expires <= now then
            Mystic.Buffs[skillId] = nil
        else
            result.damageMult = result.damageMult * (buff.damageMult or 1.0)
            result.meleeMult  = result.meleeMult * (buff.meleeMult or 1.0)
            result.speedMult  = result.speedMult * (buff.speedMult or 1.0)
        end
    end

    -- Flueche und Gifte verlangsamen.
    if Mystic.Effects.slow and Mystic.Effects.slow.expires > now then
        result.speedMult = result.speedMult * Mystic.Effects.slow.factor
    end

    return result
end

-- Synchronisation ------------------------------------------------------------

RegisterNetEvent('mystic:client:syncProfile', function(data)
    local previousRace = Mystic.Profile and Mystic.Profile.race
    Mystic.Profile = data

    TriggerEvent('mystic:client:profileChanged', data)
    SendNUIMessage({ action = 'mysticProfile', data = data })

    if data.race ~= previousRace then
        TriggerEvent('mystic:client:raceChanged', data.race)
    end
end)

RegisterNetEvent('mystic:client:essence', function(current, max)
    if not Mystic.Profile then return end

    Mystic.Profile.essence = current
    Mystic.Profile.maxEssence = max
    SendNUIMessage({ action = 'mysticEssence', data = { essence = current, maxEssence = max } })
end)

RegisterNetEvent('mystic:client:awakened', function(raceName)
    local race = Mystic.GetRace(raceName)
    if not race then return end

    MS.Notify(('Du bist als %s erwacht.'):format(race.label), 'success', 8000)
    AnimpostfxPlay('HeistCelebPass', 3000, false)
end)

RegisterNetEvent('mystic:client:levelUp', function(level)
    MS.Notify(('Klassenstufe %d erreicht.'):format(level), 'success', 7000)
    AnimpostfxPlay('SuccessNeutral', 2000, false)
    PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
end)

RegisterNetEvent('mystic:client:resetEffects', function()
    Mystic.Buffs = {}
    Mystic.Effects = {}
    ResetEntityAlpha(PlayerPedId())
    ClearTimecycleModifier()
    SetPedMoveRateOverride(PlayerPedId(), 1.0)
end)

-- Eingehende Wirkungen -------------------------------------------------------

--- Schaden auf den eigenen Spieler anwenden.
local function takeDamage(amount, element)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end

    local mods = Mystic.GetActiveModifiers()
    if element == 'fire' and mods.fireImmune then
        MS.Notify('Das Feuer perlt an dir ab.', 'info', 3000)
        return
    end

    -- Weste faengt einen Teil ab.
    local armor = GetPedArmour(ped)
    if armor > 0 then
        local absorbed = math.min(armor, math.floor(amount * 0.5))
        SetPedArmour(ped, armor - absorbed)
        amount = amount - absorbed
    end

    SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - math.floor(amount)))
    TriggerServerEvent('mystic:server:reportDamage', amount)

    if element == 'fire' then
        StartEntityFire(ped)
    end

    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.35)
end

--- Schaden ueber Zeit (Fluch, Gift).
local function damageOverTime(totalDuration, damagePerTick, element)
    CreateThread(function()
        local ticks = math.floor(totalDuration / 2)

        for _ = 1, ticks do
            Wait(2000)
            if IsEntityDead(PlayerPedId()) then return end
            takeDamage(damagePerTick, element)
        end
    end)
end

RegisterNetEvent('mystic:client:applyEffect', function(payload)
    if type(payload) ~= 'table' then return end

    local ped = PlayerPedId()

    if payload.type == 'damage' then
        takeDamage(payload.amount or 0, payload.element)
        if payload.ragdoll then
            SetPedToRagdoll(ped, 2500, 2500, 0, true, true, false)
        end

    elseif payload.type == 'heal' then
        local maxHealth = GetEntityMaxHealth(ped)
        SetEntityHealth(ped, math.min(maxHealth, GetEntityHealth(ped) + (payload.amount or 0)))
        AnimpostfxPlay('FocusIn', 1200, false)

    elseif payload.type == 'curse' then
        Mystic.Effects.slow = {
            factor  = payload.slow or 0.6,
            expires = GetGameTimer() + (payload.duration or 10) * 1000,
        }
        SetTimecycleModifier('spectator5')
        MS.Notify('Du bist verflucht.', 'error')

        if payload.disarm then
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        end
        if payload.damageOverTime then
            damageOverTime(payload.duration or 10, payload.damageOverTime, 'curse')
        end

        SetTimeout((payload.duration or 10) * 1000, function()
            ClearTimecycleModifier()
        end)

    elseif payload.type == 'poison' then
        Mystic.Effects.slow = {
            factor  = 0.8,
            expires = GetGameTimer() + (payload.duration or 10) * 1000,
        }
        SetTimecycleModifier('drug_wobbly')
        MS.Notify('Gift brennt in deinen Lungen.', 'error')
        damageOverTime(payload.duration or 10, payload.damagePerTick or 4, 'poison')

        SetTimeout((payload.duration or 10) * 1000, function()
            ClearTimecycleModifier()
        end)

    elseif payload.type == 'fear' then
        SetPedToRagdoll(ped, (payload.duration or 5) * 1000, (payload.duration or 5) * 1000, 0, true, true, false)
        ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 0.8)
        AnimpostfxPlay('DeathFailOut', (payload.duration or 5) * 1000, false)
        MS.Notify('Panik ergreift dich.', 'error')

    elseif payload.type == 'revive' then
        local coords = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
        SetEntityHealth(ped, payload.health or 120)
        ClearPedBloodDamage(ped)
        MS.Notify('Eine fremde Kraft holt dich zurueck.', 'success')
    end
end)

-- Regeneration ---------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(5000)

        local mods = Mystic.GetActiveModifiers()
        local ped = PlayerPedId()

        if Mystic.Profile and mods.regenPerTick > 0 and not IsEntityDead(ped) then
            local maxHealth = GetEntityMaxHealth(ped)
            local health = GetEntityHealth(ped)

            if health < maxHealth then
                SetEntityHealth(ped, math.min(maxHealth, health + math.floor(mods.regenPerTick)))
            end
        end
    end
end)

-- Start ----------------------------------------------------------------------

AddEventHandler('moonshine:client:playerLoaded', function()
    Wait(1500)
    TriggerServerEvent('mystic:server:requestProfile')
end)

CreateThread(function()
    Wait(2000)
    if MS.IsPlayerLoaded then
        TriggerServerEvent('mystic:server:requestProfile')
    end
end)
