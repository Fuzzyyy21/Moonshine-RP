--- Ausfuehrung und Darstellung der Rassenskills.

local MS = exports['moonshine-core']:GetCoreObject()

local revealUntil = 0
local revealRadius = 0.0
local transformState = nil

--- Waehrend einer Verwandlung duerfen die Standardwerte nicht ueberschrieben
--- werden (siehe client/perks.lua).
function Mystic.IsTransformed()
    return transformState ~= nil
end

-- Zielerfassung ---------------------------------------------------------------

--- Spieler, auf den gerade gezielt wird, sonst der naechste im Sichtfeld.
---@return number|nil Server-ID
function Mystic.GetAimedTarget(maxDistance)
    maxDistance = maxDistance or MysticConfig.Combat.maxTargetRange

    local playerId = PlayerId()
    local myPed = PlayerPedId()

    -- 1. Freies Zielen
    local entity = GetEntityPlayerIsFreeAimingAt(playerId)
    if entity and DoesEntityExist(entity) and IsEntityAPed(entity) and IsPedAPlayer(entity) then
        local target = NetworkGetPlayerIndexFromPed(entity)
        if target ~= -1 and target ~= playerId then
            return GetPlayerServerId(target)
        end
    end

    -- 2. Naechster Spieler im vorderen Sichtfeld
    local myCoords = GetEntityCoords(myPed)
    local forward = GetEntityForwardVector(myPed)
    local best, bestScore = nil, -1.0

    for _, index in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(index)

        if ped ~= myPed and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            local distance = #(myCoords - coords)

            if distance <= maxDistance then
                local direction = (coords - myCoords) / distance
                local dot = forward.x * direction.x + forward.y * direction.y + forward.z * direction.z

                -- Nur was halbwegs vor uns liegt.
                if dot > 0.6 and dot > bestScore then
                    best, bestScore = index, dot
                end
            end
        end
    end

    return best and GetPlayerServerId(best) or nil
end

--- Loest einen Skill aus (wird von der Skillleiste aufgerufen).
function Mystic.UseSkill(skillId)
    local skill = Mystic.GetSkill(skillId)
    if not skill or skill.passive then return end
    if not Mystic.Profile or not Mystic.Profile.race then return end

    if IsEntityDead(PlayerPedId()) then
        MS.Notify('Nicht im Tod.', 'error')
        return
    end

    local effect = skill.effect
    local needsTarget = effect.kind == 'projectile' or effect.kind == 'curse'
        or effect.kind == 'heal_target' or effect.kind == 'revive_target'
        or (effect.kind == 'drain' and effect.single)

    local targetServerId = needsTarget
        and Mystic.GetAimedTarget(effect.range or MysticConfig.Combat.maxTargetRange)
        or nil

    if needsTarget and not targetServerId then
        MS.Notify('Kein Ziel im Visier.', 'error')
        return
    end

    TriggerServerEvent('mystic:server:useSkill', skillId, targetServerId)
end

-- Darstellung ----------------------------------------------------------------

local function playCastAnimation(dict, anim, duration)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end

    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration or 1200, 48, 0.0, false, false, false)
    end
end

--- Zeichnet kurz eine Flugbahn und laesst sie am Ziel aufschlagen.
local function drawProjectile(fromCoords, toCoords, element)
    CreateThread(function()
        local color = element == 'fire' and { 235, 110, 40 } or { 110, 160, 245 }
        local steps = 14

        for step = 1, steps do
            local progress = step / steps
            local point = fromCoords + (toCoords - fromCoords) * progress

            DrawLine(point.x, point.y, point.z,
                     toCoords.x, toCoords.y, toCoords.z,
                     color[1], color[2], color[3], 200)
            Wait(20)
        end

        AddExplosion(toCoords.x, toCoords.y, toCoords.z,
            element == 'fire' and 4 or 30, 0.0, true, false, 0.6)
    end)
end

local function startTransform(effect)
    local ped = PlayerPedId()
    local model = joaat(effect.model)

    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(model) then return end

    transformState = {
        previousModel = GetEntityModel(ped),
        health = GetEntityHealth(ped),
        expires = GetGameTimer() + effect.duration * 1000,
    }

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    local newPed = PlayerPedId()
    SetEntityMaxHealth(newPed, 200 + (effect.healthBonus or 0))
    SetEntityHealth(newPed, 200 + (effect.healthBonus or 0))
    SetPedMoveRateOverride(newPed, effect.speedMult or 1.0)

    MS.Notify('Deine Gestalt wandelt sich.', 'warning', 4000)

    SetTimeout(effect.duration * 1000, function()
        local previous = transformState and transformState.previousModel
        transformState = nil
        if not previous then return end

        RequestModel(previous)
        local wait = GetGameTimer() + 8000
        while not HasModelLoaded(previous) and GetGameTimer() < wait do Wait(10) end

        if HasModelLoaded(previous) then
            SetPlayerModel(PlayerId(), previous)
            SetPedDefaultComponentVariation(PlayerPedId())
            SetModelAsNoLongerNeeded(previous)
        end

        MS.Notify('Du kehrst in deine Gestalt zurueck.', 'info')
        -- Kleidungsscripts koennen hier ihr Outfit wiederherstellen.
        TriggerEvent('mystic:client:transformEnded')
    end)
end

--- Wirkung beim Verursacher.
RegisterNetEvent('mystic:client:skillUsed', function(skillId, info)
    local skill = Mystic.GetSkill(skillId)
    if not skill then return end

    local effect = skill.effect
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    if effect.kind == 'heal_self' then
        playCastAnimation('mp_suicide', 'pill', 1200)
        local maxHealth = GetEntityMaxHealth(ped)
        SetEntityHealth(ped, math.min(maxHealth, GetEntityHealth(ped) + effect.amount))
        AnimpostfxPlay('FocusIn', 1200, false)

        if effect.cleanse then
            Mystic.Effects.slow = nil
            ClearTimecycleModifier()
            ClearPedBloodDamage(ped)
        end
        if effect.buff then
            Mystic.Buffs[skillId] = {
                expires    = GetGameTimer() + effect.buff.duration * 1000,
                speedMult  = effect.buff.speedMult,
                damageMult = effect.buff.damageMult,
            }
        end

    elseif effect.kind == 'self_buff' then
        Mystic.Buffs[skillId] = {
            expires    = GetGameTimer() + effect.duration * 1000,
            damageMult = effect.damageMult,
            meleeMult  = effect.meleeMult,
            speedMult  = effect.speedMult,
        }

        if effect.armor then
            SetPedArmour(ped, math.max(GetPedArmour(ped), effect.armor))
        end
        if effect.timeScale then
            SetTimeScale(effect.timeScale)
            SetTimeout(effect.duration * 1000, function() SetTimeScale(1.0) end)
        end

        AnimpostfxPlay('FocusIn', 1200, false)
        MS.Notify(('%s aktiv (%d Sekunden).'):format(skill.label, effect.duration), 'success')

    elseif effect.kind == 'shield' then
        SetPedArmour(ped, math.max(GetPedArmour(ped), effect.armor))
        AnimpostfxPlay('HeistLocate', 1500, false)
        playCastAnimation('random@mugging3', 'handsup_standing_base', 900)

    elseif effect.kind == 'blink' then
        local destination = GetOffsetFromEntityInWorldCoords(ped, 0.0, effect.distance, 0.0)
        local found, groundZ = GetGroundZFor_3dCoord(destination.x, destination.y, destination.z + 5.0, false)

        AddExplosion(coords.x, coords.y, coords.z, 30, 0.0, true, false, 0.3)
        SetEntityCoordsNoOffset(ped, destination.x, destination.y,
            found and (groundZ + 1.0) or destination.z, false, false, false)
        AddExplosion(destination.x, destination.y, destination.z, 30, 0.0, true, false, 0.3)

    elseif effect.kind == 'leap' then
        local forward = GetEntityForwardVector(ped)
        SetEntityVelocity(ped,
            forward.x * (effect.force * 0.6),
            forward.y * (effect.force * 0.6),
            effect.force)

    elseif effect.kind == 'stealth' then
        SetEntityAlpha(ped, effect.alpha or 40, false)
        Mystic.Buffs[skillId] = {
            expires   = GetGameTimer() + effect.duration * 1000,
            speedMult = effect.speedMult,
        }
        MS.Notify(('%s aktiv.'):format(skill.label), 'success')

        SetTimeout(effect.duration * 1000, function()
            ResetEntityAlpha(PlayerPedId())
        end)

    elseif effect.kind == 'nightvision' then
        SetNightvision(true)
        SetTimeout(effect.duration * 1000, function() SetNightvision(false) end)

    elseif effect.kind == 'reveal' then
        revealUntil = GetGameTimer() + effect.duration * 1000
        revealRadius = effect.radius
        MS.Notify('Du spuerst die Wesen um dich herum.', 'info')

    elseif effect.kind == 'transform' then
        startTransform(effect)

    elseif effect.kind == 'projectile' then
        playCastAnimation('anim@mp_player_intcelebrationmale@thumbs_up', 'thumbs_up', 900)

        local target = info and info.targetServerId
        local targetPed = target and GetPlayerPed(GetPlayerFromServerId(target))
        local targetCoords = targetPed and DoesEntityExist(targetPed)
            and GetEntityCoords(targetPed)
            or GetOffsetFromEntityInWorldCoords(ped, 0.0, effect.range or 30.0, 0.0)

        drawProjectile(coords + vector3(0.0, 0.0, 0.6), targetCoords, effect.element)

    elseif effect.kind == 'aoe_damage' then
        playCastAnimation('melee@large_wpn@streamed_core', 'ground_attack_on_spot', 1200)
        AddExplosion(coords.x, coords.y, coords.z, effect.fire and 4 or 30, 0.0, true, false, 1.0)

        if effect.fire then
            StartScriptFire(coords.x, coords.y, coords.z, 25, true)
        end

    elseif effect.kind == 'poison' then
        playCastAnimation('anim@heists@narcotics@funding@gang_idle', 'gang_chatting_idle01', 1200)
        AddExplosion(coords.x, coords.y, coords.z, 22, 0.0, true, false, 0.4)

    elseif effect.kind == 'fear' or effect.kind == 'curse' then
        playCastAnimation('random@mugging3', 'handsup_standing_base', 1000)

    elseif effect.kind == 'drain' then
        playCastAnimation('random@mugging3', 'handsup_standing_base', 1000)
        AnimpostfxPlay('DrugsMichaelAliensFightIn', 1200, false)
    end

    if info and info.hits and info.hits > 0 then
        MS.Notify(('%s trifft %d Ziel(e).'):format(skill.label, info.hits), 'success', 3000)
    end
end)

--- Wirkung, die umstehende Spieler sehen.
RegisterNetEvent('mystic:client:skillVisual', function(casterServerId, skillId)
    local skill = Mystic.GetSkill(skillId)
    if not skill then return end

    local casterPed = GetPlayerPed(GetPlayerFromServerId(casterServerId))
    if not casterPed or not DoesEntityExist(casterPed) then return end

    local coords = GetEntityCoords(casterPed)
    if #(GetEntityCoords(PlayerPedId()) - coords) > 90.0 then return end

    local effect = skill.effect

    if effect.kind == 'aoe_damage' then
        AddExplosion(coords.x, coords.y, coords.z, effect.fire and 4 or 30, 0.0, true, false, 1.0)
    elseif effect.kind == 'blink' then
        AddExplosion(coords.x, coords.y, coords.z, 30, 0.0, true, false, 0.3)
    elseif effect.kind == 'poison' then
        AddExplosion(coords.x, coords.y, coords.z, 22, 0.0, true, false, 0.4)
    end
end)

-- Wesensblick / Wittern -------------------------------------------------------

CreateThread(function()
    while true do
        local sleep = 500

        if revealUntil > GetGameTimer() then
            sleep = 0
            local myCoords = GetEntityCoords(PlayerPedId())

            for _, index in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(index)

                if ped ~= PlayerPedId() and DoesEntityExist(ped) then
                    local coords = GetEntityCoords(ped)
                    if #(myCoords - coords) <= revealRadius then
                        DrawMarker(21, coords.x, coords.y, coords.z + 1.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            0.5, 0.5, 0.5, 190, 60, 60, 140, true, true, 2, false, nil, nil, false)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('mystic:client:resetEffects', function()
    revealUntil = 0
    SetNightvision(false)
    SetTimeScale(1.0)
end)
