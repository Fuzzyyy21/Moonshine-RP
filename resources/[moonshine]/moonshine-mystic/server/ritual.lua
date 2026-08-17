--- Ritualpunkte: Erweckung, Rassenwechsel und Meditation.

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

    if MysticConfig.Awakening.onlyAtRitualPoint and not atRitualPoint(source) then
        profile:Notify('Die Erweckung gelingt nur an einem Ritualpunkt.', 'error')
        return
    end

    -- Rassenwechsel
    if profile.race then
        if not MysticConfig.Awakening.allowRaceChange then
            profile:Notify('Deine Rasse laesst sich nicht mehr aendern.', 'error')
            return
        end

        if profile.race == raceName then return end

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

        -- Rassenskills der alten Rasse verfallen, Punkte gibt es zurueck.
        local refund = 0
        for skillId in pairs(profile.unlocked) do
            local skill = Mystic.GetSkill(skillId)
            if skill then refund = refund + skill.unlock.points end
        end

        profile.unlocked = {}
        profile.skillbar = {}
        for slot = 1, MysticConfig.SkillBar.slots do profile.skillbar[slot] = false end
        profile:AddSkillPoints(refund)
    else
        profile:AddSkillPoints(MysticConfig.Points.awakeningSkillPoints)
    end

    profile.race = raceName
    profile:SetEssence(profile:GetMaxEssence())

    Mystic.DB.SetRace(profile.characterId, raceName)
    profile:Save()
    profile:Sync()

    profile:Notify(('Du bist als %s erwacht.'):format(race.label), 'success')
    TriggerClientEvent('mystic:client:awakened', source, raceName)
    TriggerEvent('mystic:server:playerAwakened', source, raceName)

    MS.Logger.Log('character', ('%s ist als %s erwacht.'):format(player.fullname, race.label), player.license)
end)

-- Meditation -----------------------------------------------------------------

--- Zieht einen gewichteten Eintrag aus der Lootliste.
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
        -- Spieler koennte inzwischen weg sein.
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
    end)
end)

--- Der Client fragt die Daten fuer die Ritual-Oberflaeche an.
RegisterNetEvent('mystic:server:requestRitualData', function()
    local source = source
    local profile = Mystic.Profiles[source]
    local player  = MS.GetPlayer(source)
    if not profile or not player then return end

    if not atRitualPoint(source) then return end

    -- Steinbestand des Spielers fuer die Kostenanzeige.
    local stones = {}
    for name in pairs(Mystic.Stones) do
        stones[name] = player:GetItemCount(name)
    end

    local meditationLeft = math.max(0, (profile.lastMeditation + MysticConfig.Meditation.cooldown) - os.time())

    TriggerClientEvent('mystic:client:openRitual', source, {
        profile        = profile:GetData(),
        stones         = stones,
        meditationLeft = meditationLeft,
        canMeditate    = MysticConfig.Meditation.enabled,
        canChangeRace  = MysticConfig.Awakening.allowRaceChange,
    })
end)
