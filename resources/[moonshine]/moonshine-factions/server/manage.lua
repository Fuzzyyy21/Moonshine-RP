--- Verwaltung: Wappen, Raenge, Skilltree und Kasse.

-- Wappen, Banner, Willkommensbild ----------------------------------------------

RegisterNetEvent('factions:server:setEmblem', function(emblem)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'manage') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    faction.emblem = Factions.SanitizeEmblem(emblem, faction.emblem)
    faction.dirty = true
    faction:Save()

    faction:Log('wappen', ('%s %s hat das Wappen geaendert.'):format(
        player.firstname, player.lastname))
    faction:Sync()

    player:Notify('Wappen gespeichert.', 'success')
end)

--- Name und Kuerzel aendern.
RegisterNetEvent('factions:server:rename', function(name, tag)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or player.charId ~= faction.ownerId then
        player:Notify('Nur die Fuehrung darf das.', 'error')
        return
    end

    local config = FactionConfig.Create

    name = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    tag  = tostring(tag or ''):upper():gsub('[^%w]', '')

    if #name < config.minName or #name > config.maxName then
        player:Notify(('Der Name braucht %d bis %d Zeichen.'):format(
            config.minName, config.maxName), 'error')
        return
    end

    if #tag < config.minTag or #tag > config.maxTag then
        player:Notify(('Das Kuerzel braucht %d bis %d Zeichen.'):format(
            config.minTag, config.maxTag), 'error')
        return
    end

    for _, other in pairs(Factions.List) do
        if other.id ~= faction.id then
            if other.name:lower() == name:lower() then
                player:Notify('Diesen Namen gibt es schon.', 'error')
                return
            end
            if other.tag:lower() == tag:lower() then
                player:Notify('Dieses Kuerzel gibt es schon.', 'error')
                return
            end
        end
    end

    faction:Log('name', ('Umbenannt in %s [%s].'):format(name, tag))
    faction.name, faction.tag = name, tag
    faction.dirty = true
    faction:Save()
    faction:Sync()

    player:Notify('Name gespeichert.', 'success')
end)

-- Raenge -------------------------------------------------------------------------

RegisterNetEvent('factions:server:setRanks', function(ranks)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or player.charId ~= faction.ownerId then
        player:Notify('Nur die Fuehrung darf die Raenge aendern.', 'error')
        return
    end

    local clean = Factions.SanitizeRanks(ranks, faction.ranks)
    local top = math.max(0, #clean - 1)

    faction.ranks = clean
    faction.dirty = true

    -- Mitglieder, deren Rang es nicht mehr gibt, nach unten setzen.
    for characterId, member in pairs(faction.members) do
        if member.grade > top then
            member.grade = top
            Factions.DB.SetGrade(characterId, top)
        end
    end

    -- Die Fuehrung bleibt oben.
    local owner = faction.members[faction.ownerId]
    if owner and owner.grade ~= top then
        owner.grade = top
        Factions.DB.SetGrade(faction.ownerId, top)
    end

    faction:Save()
    faction:Log('rang', 'Die Rangstruktur wurde geaendert.')
    faction:Sync()

    player:Notify('Raenge gespeichert.', 'success')
end)

-- Skilltree ------------------------------------------------------------------------

--- Baut den Fraktionsbaum fuer die Oberflaeche.
function Factions.BuildSkillPayload(faction)
    local nodes = {}
    local level = faction.level

    for _, node in ipairs(Factions.SkillTree) do
        local rank = faction.skills[node.id] or 0
        local maxed = rank >= node.maxRank

        local ok, reason = Factions.MeetsSkillRequirements(node, faction.skills, level)
        local cost = Factions.GetSkillCost(node, rank + 1)

        nodes[#nodes + 1] = {
            id          = node.id,
            label       = node.label,
            icon        = node.icon,
            row         = node.row,
            col         = node.col,
            rank        = rank,
            maxRank     = node.maxRank,
            cost        = cost,
            requires    = node.requires or {},
            minLevel    = node.minLevel,
            description = node.description,
            unlocked    = rank > 0,
            available   = ok and not maxed and faction.points >= cost,
            blocked     = not ok,
            reason      = reason,
            current     = rank > 0 and Factions.DescribeSkillRank(node, rank) or {},
            next        = not maxed and Factions.DescribeSkillRank(node, rank + 1) or {},
        }
    end

    return nodes
end

RegisterNetEvent('factions:server:upgradeSkill', function(nodeId)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'skills') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    local node = Factions.GetSkill(nodeId)
    if not node then return end

    local rank = faction.skills[node.id] or 0
    if rank >= node.maxRank then
        player:Notify('Diese Stufe ist bereits voll ausgebaut.', 'error')
        return
    end

    local ok, reason = Factions.MeetsSkillRequirements(node, faction.skills, faction.level)
    if not ok then
        player:Notify(reason, 'error')
        return
    end

    local cost = Factions.GetSkillCost(node, rank + 1)
    if faction.points < cost then
        player:Notify(('Dafuer fehlen %d Fraktionspunkte.'):format(cost - faction.points), 'error')
        return
    end

    faction.points = faction.points - cost
    faction.skills[node.id] = rank + 1
    faction.dirty = true
    faction:Save()

    faction:Log('skill', ('%s auf Stufe %d ausgebaut.'):format(node.label, rank + 1))
    faction:Notify(('%s wurde auf Stufe %d ausgebaut.'):format(node.label, rank + 1), 'success')
    faction:Sync()

    TriggerEvent('factions:server:skillUpgraded', faction.id, node.id, rank + 1)
end)

RegisterNetEvent('factions:server:resetSkills', function()
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or player.charId ~= faction.ownerId then
        player:Notify('Nur die Fuehrung darf den Baum zuruecksetzen.', 'error')
        return
    end

    local spent = Factions.GetSpentPoints(faction.skills)
    if spent <= 0 then
        player:Notify('Es ist nichts zum Zuruecksetzen da.', 'error')
        return
    end

    local cost = FactionConfig.Level.resetCost
    if not faction:RemoveKasse(cost, 'skill-reset') then
        player:Notify(('In der Kasse fehlen %s.'):format(
            MS.Utils.FormatMoney(cost - faction.kasse)), 'error')
        return
    end

    faction.skills = {}
    faction.points = faction.points + spent
    faction.dirty = true
    faction:Save()

    faction:Log('skill', ('Der Fraktionsbaum wurde zurueckgesetzt (%d Punkte frei).'):format(spent))
    faction:Notify('Der Fraktionsbaum wurde zurueckgesetzt.', 'warning')
    faction:Sync()
end)

-- Kasse -----------------------------------------------------------------------------

RegisterNetEvent('factions:server:deposit', function(amount)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    if not player:RemoveMoney(amount, FactionConfig.Kasse.account, 'fraktionskasse') then
        player:Notify('So viel hast du nicht.', 'error')
        return
    end

    faction:AddKasse(amount, ('Einzahlung von %s %s'):format(player.firstname, player.lastname))

    local member = faction.members[player.charId]
    if member then
        member.contribution = member.contribution + amount
        Factions.DB.AddContribution(player.charId, amount)
    end

    faction:Save()
    Factions.Advance(faction.id, 'deposit', amount)

    faction:Notify(('%s %s hat %s eingezahlt.'):format(
        player.firstname, player.lastname, MS.Utils.FormatMoney(amount)), 'success')
    faction:Sync()
end)

RegisterNetEvent('factions:server:withdraw', function(amount)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'kasseTake') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    if amount > FactionConfig.Kasse.maxWithdraw then
        player:Notify(('Hoechstens %s auf einmal.'):format(
            MS.Utils.FormatMoney(FactionConfig.Kasse.maxWithdraw)), 'error')
        return
    end

    -- Der Skilltree kann die Auszahlung verbilligen.
    local bonus = faction:GetModifiers().payoutBonus or 0
    local charged = math.max(1, math.floor(amount * (1 - math.min(bonus, 0.5))))

    if not faction:RemoveKasse(charged, ('Auszahlung an %s %s'):format(
        player.firstname, player.lastname)) then
        player:Notify('So viel ist nicht in der Kasse.', 'error')
        return
    end

    player:AddMoney(amount, FactionConfig.Kasse.account, 'fraktionskasse')
    faction:Save()

    faction:Notify(('%s %s hat %s entnommen.'):format(
        player.firstname, player.lastname, MS.Utils.FormatMoney(amount)), 'warning')
    faction:Sync()
end)

-- Protokoll ---------------------------------------------------------------------------

RegisterNetEvent('factions:server:requestLog', function()
    local source = source
    local faction = Factions.GetByPlayer(source)
    if not faction then return end

    TriggerClientEvent('factions:client:log', source, Factions.DB.LoadLog(faction.id, 50))
end)
