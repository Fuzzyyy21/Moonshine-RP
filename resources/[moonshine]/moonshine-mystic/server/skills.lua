--- Skillstufen kaufen, Leiste belegen und Skills einsetzen.

local MS = exports['moonshine-core']:GetCoreObject()

-- Hilfsfunktionen ------------------------------------------------------------

local function coordsOf(source)
    return GetEntityCoords(GetPlayerPed(source))
end

local function inSafeZone(coords)
    for _, zone in ipairs(MysticConfig.Combat.safeZones) do
        if #(coords - zone.coords) < zone.radius then return zone end
    end
end

--- Alle Spieler im Umkreis, ohne den Verursacher.
local function playersInRadius(coords, radius, exceptSource)
    local result = {}

    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)

        if target ~= exceptSource and MS.GetPlayer(target) then
            local distance = #(coords - coordsOf(target))
            if distance <= radius then
                result[#result + 1] = { source = target, distance = distance }
            end
        end
    end

    return result
end

local function canAffect(profile, targetSource)
    if MysticConfig.Combat.friendlyFireSameRace then return true end

    local targetProfile = Mystic.Profiles[targetSource]
    if not targetProfile or not targetProfile.race then return true end
    return targetProfile.race ~= profile.race
end

local function applyToTarget(targetSource, payload)
    TriggerClientEvent('mystic:client:applyEffect', targetSource, payload)
end

-- Stufen kaufen --------------------------------------------------------------

RegisterNetEvent('mystic:server:upgradeSkill', function(skillId)
    local source = source
    local profile = Mystic.Profiles[source]
    local player  = MS.GetPlayer(source)
    if not profile or not player then return end

    local skill = Mystic.GetSkill(skillId)
    if not skill then return end

    if not profile.race or skill.race ~= profile.race then
        profile:Notify('Dieser Skill gehoert nicht zu deiner Klasse.', 'error')
        return
    end

    if not Mystic.IsNearRitualPoint(coordsOf(source)) then
        profile:Notify('Skillen geht nur an einem Ritualpunkt.', 'error')
        return
    end

    local currentRank = profile:GetRank(skillId)
    local nextRank = currentRank + 1

    if nextRank > skill.maxRank then
        profile:Notify(('%s ist bereits auf Maximalstufe.'):format(skill.label), 'warning')
        return
    end

    if not Mystic.MeetsRequirements(skill, profile.ranks) then
        profile:Notify('Du musst zuerst die vorherigen Faehigkeiten lernen.', 'error')
        return
    end

    local level = profile:GetLevel()
    if level < (skill.level or 1) then
        profile:Notify(('Dafuer brauchst du Klassenstufe %d (aktuell %d).'):format(skill.level, level), 'error')
        return
    end

    local stoneName, stoneLabel = Mystic.GetClassStone(profile.race)
    local price = Mystic.GetRankCost(skill, nextRank)

    if not stoneName or not price then return end

    if not player:HasItem(stoneName, price) then
        profile:Notify(('Dir fehlen %d %s.'):format(price - player:GetItemCount(stoneName), stoneLabel), 'error')
        return
    end

    if not player:RemoveItem(stoneName, price) then
        profile:Notify('Die Steine konnten nicht entnommen werden.', 'error')
        return
    end

    profile.ranks[skillId] = nextRank

    -- Erste Stufe eines aktiven Skills wandert in den ersten freien Slot.
    if currentRank == 0 and not skill.passive then
        for slot = 1, MysticConfig.SkillBar.slots do
            if not profile.skillbar[slot] then
                profile.skillbar[slot] = skillId
                break
            end
        end
    end

    profile:AddXp(MysticConfig.Progression.xpPerUnlock)
    profile:Save()
    profile:Sync()
    profile:Notify(('%s auf Stufe %d.'):format(skill.label, nextRank), 'success')
    TriggerEvent('mystic:server:skillUpgraded', source, skillId, nextRank)
end)

RegisterNetEvent('mystic:server:setBarSlot', function(slot, skillId)
    local source = source
    local profile = Mystic.Profiles[source]
    if not profile then return end

    slot = tonumber(slot)
    if not slot then return end

    if skillId ~= nil then
        local skill = Mystic.GetSkill(skillId)
        if not skill or skill.passive or not profile:IsUnlocked(skillId) then return end
    end

    if profile:SetBarSlot(slot, skillId) then
        profile:Sync()
    end
end)

-- Einsetzen ------------------------------------------------------------------

--- Wendet die Wirkung eines Skills auf andere Spieler an.
---@param effect table bereits auf die Stufe aufgeloester Effekt
local function applySkillEffects(profile, effect, casterCoords, targetSource)
    local kind = effect.kind
    local hits = 0

    if kind == 'drain' then
        local targets = {}

        if effect.single then
            if targetSource then
                targets[1] = { source = targetSource, distance = #(casterCoords - coordsOf(targetSource)) }
            end
        else
            targets = playersInRadius(casterCoords, effect.radius or 6.0, profile.source)
        end

        local healed = 0
        for _, target in ipairs(targets) do
            if target.distance <= (effect.range or effect.radius or 6.0) and canAffect(profile, target.source) then
                applyToTarget(target.source, { type = 'damage', amount = effect.damage, element = 'drain' })
                healed = healed + (effect.heal or 0)
                hits = hits + 1
            end
        end

        if healed > 0 then
            applyToTarget(profile.source, { type = 'heal', amount = math.min(healed, (effect.heal or 0) * 3) })
        end

    elseif kind == 'aoe_damage' then
        for _, target in ipairs(playersInRadius(casterCoords, effect.radius, profile.source)) do
            if canAffect(profile, target.source) then
                applyToTarget(target.source, {
                    type = 'damage', amount = effect.damage,
                    element = effect.fire and 'fire' or 'physical',
                    ragdoll = effect.ragdoll,
                })
                hits = hits + 1
            end
        end

    elseif kind == 'projectile' then
        if targetSource and canAffect(profile, targetSource) then
            if #(casterCoords - coordsOf(targetSource)) <= (effect.range or 60.0) then
                applyToTarget(targetSource, { type = 'damage', amount = effect.damage, element = effect.element })
                hits = 1
            end
        end

    elseif kind == 'curse' then
        local payload = {
            type = 'curse', duration = effect.duration, slow = effect.slow,
            damageOverTime = effect.damageOverTime, disarm = effect.disarm,
        }

        if effect.radius then
            -- Flaechenfluch trifft alle im Umkreis.
            for _, target in ipairs(playersInRadius(casterCoords, effect.radius, profile.source)) do
                if canAffect(profile, target.source) then
                    applyToTarget(target.source, payload)
                    hits = hits + 1
                end
            end
        elseif targetSource and canAffect(profile, targetSource) then
            if #(casterCoords - coordsOf(targetSource)) <= (effect.range or 20.0) then
                applyToTarget(targetSource, payload)
                hits = 1
            end
        end

    elseif kind == 'poison' then
        for _, target in ipairs(playersInRadius(casterCoords, effect.radius, profile.source)) do
            if canAffect(profile, target.source) then
                applyToTarget(target.source, {
                    type = 'poison', duration = effect.duration, damagePerTick = effect.damagePerTick,
                })
                hits = hits + 1
            end
        end

    elseif kind == 'fear' then
        for _, target in ipairs(playersInRadius(casterCoords, effect.radius, profile.source)) do
            if canAffect(profile, target.source) then
                applyToTarget(target.source, { type = 'fear', duration = effect.duration })
                hits = hits + 1
            end
        end

    elseif kind == 'heal_target' then
        if targetSource and #(casterCoords - coordsOf(targetSource)) <= (effect.range or 10.0) then
            applyToTarget(targetSource, { type = 'heal', amount = effect.amount })
            hits = 1
        end

    elseif kind == 'revive_target' then
        if targetSource and #(casterCoords - coordsOf(targetSource)) <= (effect.range or 6.0) then
            applyToTarget(targetSource, { type = 'revive', health = effect.health or 120 })
            hits = 1
        end
    end

    return hits
end

RegisterNetEvent('mystic:server:useSkill', function(skillId, targetServerId)
    local source = source
    local profile = Mystic.Profiles[source]
    if not profile or not profile.race then return end

    local skill = Mystic.GetSkill(skillId)
    if not skill or skill.passive then return end

    local rank = profile:GetRank(skillId)
    if skill.race ~= profile.race or rank < 1 then
        profile:Notify('Diese Faehigkeit beherrschst du nicht.', 'error')
        return
    end

    local remaining = profile:GetCooldown(skillId)
    if remaining > 0 then
        if MysticConfig.Notifications.showCooldownHints then
            profile:Notify(('%s ist noch %d Sekunden nicht bereit.'):format(skill.label, remaining), 'warning')
        end
        return
    end

    local casterCoords = coordsOf(source)
    local zone = inSafeZone(casterCoords)
    if zone then
        profile:Notify(('Hier wirken keine Kraefte (%s).'):format(zone.label or 'Schutzzone'), 'error')
        return
    end

    local mods = profile:GetModifiers()
    local essenceCost = math.floor(Mystic.GetEssenceCost(skill, rank) * mods.costMult)

    if not profile:UseEssence(essenceCost) then
        local race = Mystic.GetRace(profile.race)
        profile:Notify(('Zu wenig %s.'):format(race and race.essence.label or 'Essenz'), 'error')
        return
    end

    profile:SetCooldown(skillId, Mystic.GetCooldown(skill, rank) * mods.cooldownMult)

    local targetSource = tonumber(targetServerId)
    if targetSource then
        if not MS.GetPlayer(targetSource)
            or #(casterCoords - coordsOf(targetSource)) > MysticConfig.Combat.maxTargetRange then
            targetSource = nil
        end
    end

    local effect = Mystic.ResolveEffect(skill, rank)
    local hits = applySkillEffects(profile, effect, casterCoords, targetSource)

    -- Wirkung beim Verursacher: der Client bekommt die aufgeloesten Werte mit.
    TriggerClientEvent('mystic:client:skillUsed', source, skillId, {
        rank = rank,
        effect = effect,
        targetServerId = targetSource,
        hits = hits,
    })

    for _, nearby in ipairs(playersInRadius(casterCoords, 100.0, source)) do
        TriggerClientEvent('mystic:client:skillVisual', nearby.source, source, skillId, effect)
    end

    profile:AddXp(MysticConfig.Progression.xpPerSkillCast + hits * MysticConfig.Progression.xpPerSkillHit)
    profile:Sync()
    TriggerEvent('mystic:server:skillUsed', source, skillId, targetSource, hits)
end)

RegisterNetEvent('mystic:server:reportDamage', function(amount)
    local source = source
    local profile = Mystic.Profiles[source]
    if not profile then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    TriggerEvent('mystic:server:playerDamaged', source, amount)
end)
