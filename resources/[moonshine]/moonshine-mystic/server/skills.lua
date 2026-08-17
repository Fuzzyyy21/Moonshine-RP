--- Freischalten, Ausruesten und Einsetzen von Rassenskills.

local MS = exports['moonshine-core']:GetCoreObject()

-- Hilfsfunktionen ------------------------------------------------------------

local function coordsOf(source)
    return GetEntityCoords(GetPlayerPed(source))
end

--- Liegt der Punkt in einer Schutzzone?
local function inSafeZone(coords)
    for _, zone in ipairs(MysticConfig.Combat.safeZones) do
        if #(coords - zone.coords) < zone.radius then return zone end
    end
end

--- Alle Spieler im Umkreis, ohne den Verursacher.
---@return table Liste aus { source, profile, distance }
local function playersInRadius(coords, radius, exceptSource)
    local result = {}

    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)

        if target ~= exceptSource and MS.GetPlayer(target) then
            local distance = #(coords - coordsOf(target))
            if distance <= radius then
                result[#result + 1] = {
                    source   = target,
                    profile  = Mystic.Profiles[target],
                    distance = distance,
                }
            end
        end
    end

    return result
end

--- Darf der Verursacher dieses Ziel treffen?
local function canAffect(profile, targetSource)
    if MysticConfig.Combat.friendlyFireSameRace then return true end

    local targetProfile = Mystic.Profiles[targetSource]
    if not targetProfile or not targetProfile.race then return true end
    return targetProfile.race ~= profile.race
end

--- Schickt eine Wirkung an den Client des Ziels.
local function applyToTarget(targetSource, payload)
    TriggerClientEvent('mystic:client:applyEffect', targetSource, payload)
end

-- Freischalten ---------------------------------------------------------------

--- Prueft und bezahlt die Kosten eines Skills.
---@return boolean ok, string|nil fehlermeldung
local function payUnlock(player, profile, skill)
    if profile.skillPoints < skill.unlock.points then
        return false, ('Dir fehlen Skillpunkte (%d benoetigt).'):format(skill.unlock.points)
    end

    for item, count in pairs(skill.unlock.stones) do
        if not player:HasItem(item, count) then
            return false, ('Dir fehlen Steine: %s'):format(Mystic.FormatStones(skill.unlock.stones))
        end
    end

    for item, count in pairs(skill.unlock.stones) do
        if not player:RemoveItem(item, count) then
            return false, 'Die Steine konnten nicht entnommen werden.'
        end
    end

    profile:AddSkillPoints(-skill.unlock.points)
    return true
end

RegisterNetEvent('mystic:server:unlockSkill', function(skillId)
    local source = source
    local profile = Mystic.Profiles[source]
    local player  = MS.GetPlayer(source)
    if not profile or not player then return end

    local skill = Mystic.GetSkill(skillId)
    if not skill then return end

    if not profile.race or skill.race ~= profile.race then
        profile:Notify('Dieser Skill gehoert nicht zu deiner Rasse.', 'error')
        return
    end

    if profile:IsUnlocked(skillId) then return end

    if not Mystic.MeetsRequirements(skill, profile.unlocked) then
        profile:Notify('Du musst zuerst die vorherigen Skills freischalten.', 'error')
        return
    end

    if not Mystic.IsNearRitualPoint(coordsOf(source)) then
        profile:Notify('Skills lassen sich nur an einem Ritualpunkt einloesen.', 'error')
        return
    end

    local ok, message = payUnlock(player, profile, skill)
    if not ok then
        profile:Notify(message, 'error')
        return
    end

    profile.unlocked[skillId] = true

    -- Aktive Skills wandern automatisch in den ersten freien Slot.
    if not skill.passive then
        for slot = 1, MysticConfig.SkillBar.slots do
            if not profile.skillbar[slot] then
                profile.skillbar[slot] = skillId
                break
            end
        end
    end

    profile:Save()
    profile:Sync()
    profile:Notify(('%s freigeschaltet.'):format(skill.label), 'success')
    TriggerEvent('mystic:server:skillUnlocked', source, skillId)
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
local function applySkillEffects(profile, skill, casterCoords, targetSource)
    local effect = skill.effect
    local kind   = effect.kind
    local hits   = 0

    if kind == 'drain' then
        local targets = effect.single
            and (targetSource and { { source = targetSource, distance = #(casterCoords - coordsOf(targetSource)) } } or {})
            or playersInRadius(casterCoords, effect.radius or 6.0, profile.source)

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
            local distance = #(casterCoords - coordsOf(targetSource))
            if distance <= (effect.range or 60.0) then
                applyToTarget(targetSource, {
                    type = 'damage', amount = effect.damage, element = effect.element,
                })
                hits = 1
            end
        end

    elseif kind == 'curse' then
        if targetSource and canAffect(profile, targetSource) then
            local distance = #(casterCoords - coordsOf(targetSource))
            if distance <= (effect.range or 20.0) then
                applyToTarget(targetSource, {
                    type = 'curse', duration = effect.duration, slow = effect.slow,
                    damageOverTime = effect.damageOverTime, disarm = effect.disarm,
                })
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
        if targetSource then
            local distance = #(casterCoords - coordsOf(targetSource))
            if distance <= (effect.range or 10.0) then
                applyToTarget(targetSource, { type = 'heal', amount = effect.amount })
                hits = 1
            end
        end

    elseif kind == 'revive_target' then
        if targetSource then
            local distance = #(casterCoords - coordsOf(targetSource))
            if distance <= (effect.range or 6.0) then
                applyToTarget(targetSource, { type = 'revive', health = effect.health or 120 })
                hits = 1
            end
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

    if skill.race ~= profile.race or not profile:IsUnlocked(skillId) then
        profile:Notify('Diesen Skill beherrschst du nicht.', 'error')
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
    local essenceCost = math.floor((skill.cost or 0) * mods.costMult)

    if not profile:UseEssence(essenceCost) then
        local race = Mystic.GetRace(profile.race)
        profile:Notify(('Zu wenig %s.'):format(race and race.essence.label or 'Essenz'), 'error')
        return
    end

    profile:SetCooldown(skillId, (skill.cooldown or 10) * mods.cooldownMult)

    -- Ziel nur uebernehmen, wenn es wirklich existiert und in Reichweite ist.
    local targetSource = tonumber(targetServerId)
    if targetSource then
        if not MS.GetPlayer(targetSource)
            or #(casterCoords - coordsOf(targetSource)) > MysticConfig.Combat.maxTargetRange then
            targetSource = nil
        end
    end

    local hits = applySkillEffects(profile, skill, casterCoords, targetSource)

    -- Wirkung beim Verursacher (Animation, Buff, Sichtbarkeit, ...)
    TriggerClientEvent('mystic:client:skillUsed', source, skillId, {
        targetServerId = targetSource,
        hits = hits,
    })

    -- Umstehende sehen den Effekt.
    for _, nearby in ipairs(playersInRadius(casterCoords, 100.0, source)) do
        TriggerClientEvent('mystic:client:skillVisual', nearby.source, source, skillId)
    end

    profile:Sync()
    TriggerEvent('mystic:server:skillUsed', source, skillId, targetSource, hits)
end)

--- Der Client meldet abgelaufene Effekte oder Schaden aus Skills zurueck.
RegisterNetEvent('mystic:server:reportDamage', function(amount)
    local source = source
    local profile = Mystic.Profiles[source]
    if not profile then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    TriggerEvent('mystic:server:playerDamaged', source, amount)
end)
