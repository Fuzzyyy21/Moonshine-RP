--- Ritualpunkte: Erweckung, Klassenwechsel, Meditation und Steinumwandlung.

local MS = exports['moonshine-core']:GetCoreObject()

local function atRitualPoint(source)
    return Mystic.IsNearRitualPoint(GetEntityCoords(GetPlayerPed(source))) ~= nil
end

-- Erweckung ------------------------------------------------------------------

RegisterNetEvent('mystic:server:awaken', function(raceName)
    local source = source
    local profile = Mystic.Profiles[source]
    local player  = MS.GetPlayer(source)
    if not profile or not player then return end

    local race = Mystic.GetRace(raceName)
    if not race then return end
    if profile.race == raceName then return end

    if MysticConfig.Awakening.onlyAtRitualPoint and not atRitualPoint(source) then
        profile:Notify('Die Erweckung gelingt nur an einem Ritualpunkt.', 'error')
        return
    end

    local isSwitch = profile.race ~= nil

    if isSwitch then
        if not profile:CanSwitchClass() then
            profile:Notify('Mit der ersten gelernten Faehigkeit ist deine Klasse endgueltig.', 'error')
            return
        end

        -- Wechsel nach der ersten Faehigkeit kostet Steine (falls erlaubt).
        if profile:GetTotalRanks() > 0 then
            local stones = MysticConfig.Awakening.raceChangeStones

            for item, count in pairs(stones) do
                if not player:HasItem(item, count) then
                    profile:Notify(('Fuer den Wechsel brauchst du: %s'):format(Mystic.FormatStones(stones)), 'error')
                    return
                end
            end

            for item, count in pairs(stones) do
                player:RemoveItem(item, count)
            end

            -- Gelernte Stufen verfallen, die Klassensteine gibt es zurueck.
            local oldStone = Mystic.GetClassStone(profile.race)
            local refund = 0

            for skillId, rank in pairs(profile.ranks) do
                local skill = Mystic.GetSkill(skillId)
                if skill then refund = refund + Mystic.GetSpentStones(skill, rank) end
            end

            if oldStone and refund > 0 then
                player:AddItem(oldStone, refund)
            end
        end

        profile.ranks = {}
        for slot = 1, MysticConfig.SkillBar.slots do profile.skillbar[slot] = false end
    end

    profile.race = raceName
    profile:SetEssence(profile:GetMaxEssence())

    -- Startguthaben in der neuen Klassenwaehrung.
    local stoneName, stoneLabel = Mystic.GetClassStone(raceName)
    if not isSwitch and stoneName and MysticConfig.Stones.startAmount > 0 then
        player:AddItem(stoneName, MysticConfig.Stones.startAmount)
        profile:Notify(('Du erhaeltst %d %s.'):format(MysticConfig.Stones.startAmount, stoneLabel), 'success')
    end

    Mystic.DB.SetRace(profile.characterId, raceName)
    profile:Save()
    profile:Sync()

    profile:Notify(('Du bist als %s erwacht.'):format(race.label), 'success')
    TriggerClientEvent('mystic:client:awakened', source, raceName)
    TriggerEvent('mystic:server:playerAwakened', source, raceName)

    MS.Logger.Log('character', ('%s ist als %s erwacht.'):format(player.fullname, race.label), player.license)
end)

-- Steinumwandlung ------------------------------------------------------------

RegisterNetEvent('mystic:server:convertStones', function(times)
    local source = source
    local profile = Mystic.Profiles[source]
    local player  = MS.GetPlayer(source)
    if not profile or not player or not profile.race then return end

    if not atRitualPoint(source) then
        profile:Notify('Das geht nur an einem Ritualpunkt.', 'error')
        return
    end

    times = math.floor(tonumber(times) or 1)
    if times < 1 or times > 50 then times = 1 end

    local conversion = MysticConfig.Stones.conversion
    local needed = conversion.amount * times
    local stoneName, stoneLabel = Mystic.GetClassStone(profile.race)
    if not stoneName then return end

    if not player:HasItem(conversion.from, needed) then
        local fromLabel = Mystic.Stones[conversion.from] and Mystic.Stones[conversion.from].label or conversion.from
        profile:Notify(('Du brauchst %d %s.'):format(needed, fromLabel), 'error')
        return
    end

    if not player:RemoveItem(conversion.from, needed) then return end

    local gained = conversion.result * times
    player:AddItem(stoneName, gained)
    profile:Notify(('%d %s erhalten.'):format(gained, stoneLabel), 'success')

    TriggerClientEvent('mystic:client:refreshRitual', source)
end)

-- Meditation -----------------------------------------------------------------

local function rollLoot(race)
    local raceStone = race and Mystic.RaceStones[race] or nil
    local entries, total = {}, 0

    for _, entry in ipairs(MysticConfig.Meditation.loot) do
        local weight = entry.weight
        if raceStone and entry.item == raceStone then
            weight = weight * (MysticConfig.Meditation.raceBonus or 1)
        end

        total = total + weight
        entries[#entries + 1] = { item = entry.item, count = entry.count, weight = weight }
    end

    local roll = math.random() * total
    local sum = 0

    for _, entry in ipairs(entries) do
        sum = sum + entry.weight
        if roll <= sum then return entry end
    end

    return entries[1]
end

RegisterNetEvent('mystic:server:meditate', function()
    local source = source
    local profile = Mystic.Profiles[source]
    local player  = MS.GetPlayer(source)
    if not profile or not player or not MysticConfig.Meditation.enabled then return end

    if not atRitualPoint(source) then
        profile:Notify('Du musst an einem Ritualpunkt stehen.', 'error')
        return
    end

    local remaining = (profile.lastMeditation + MysticConfig.Meditation.cooldown) - os.time()
    if remaining > 0 then
        profile:Notify(('Die Steine schweigen noch %d Minuten.'):format(math.ceil(remaining / 60)), 'warning')
        return
    end

    profile.lastMeditation = os.time()
    TriggerClientEvent('mystic:client:meditationStart', source, MysticConfig.Meditation.duration)

    SetTimeout(MysticConfig.Meditation.duration * 1000, function()
        if not Mystic.Profiles[source] or not MS.GetPlayer(source) then return end
        if not atRitualPoint(source) then
            profile:Notify('Die Meditation wurde unterbrochen.', 'error')
            return
        end

        local loot = rollLoot(profile.race)
        if player:AddItem(loot.item, loot.count) then
            local stone = Mystic.Stones[loot.item]
            profile:Notify(('Die Erde gibt dir %dx %s.'):format(loot.count, stone and stone.label or loot.item), 'success')
        end

        profile:AddXp(MysticConfig.Progression.xpPerMeditation)
        profile:Sync()
    end)
end)

-- Daten fuer die Oberflaeche -------------------------------------------------

--- Baut die Nutzdaten des Skilltrees.
---@param atRitual boolean Steht der Spieler an einem Ritualpunkt?
function Mystic.BuildRitualPayload(source, atRitual)
    local profile = Mystic.Profiles[source]
    local player  = MS.GetPlayer(source)
    if not profile or not player then return nil end

    local stones = {}
    for name in pairs(Mystic.Stones) do
        stones[name] = player:GetItemCount(name)
    end

    local meditationLeft = math.max(0, (profile.lastMeditation + MysticConfig.Meditation.cooldown) - os.time())

    return {
        profile        = profile:GetData(),
        stones         = stones,
        atRitual       = atRitual,
        meditationLeft = meditationLeft,
        canMeditate    = MysticConfig.Meditation.enabled,
        conversion     = MysticConfig.Stones.conversion,
    }
end

RegisterNetEvent('mystic:server:requestRitualData', function()
    local source = source
    if not Mystic.Profiles[source] then return end

    local atRitual = atRitualPoint(source)
    local payload = Mystic.BuildRitualPayload(source, atRitual)
    if not payload then return end

    TriggerClientEvent('mystic:client:openRitual', source, payload)
end)
