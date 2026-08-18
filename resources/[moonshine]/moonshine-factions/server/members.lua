--- Mitgliederverwaltung: einladen, aufnehmen, befoerdern, rauswerfen.

local invites = {}   -- [source] = { factionId, expires, by }

--- Name eines Spielers.
local function nameOf(player)
    return ('%s %s'):format(player.firstname or '?', player.lastname or '')
end

-- Einladen ---------------------------------------------------------------------

RegisterNetEvent('factions:server:invite', function(targetId)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'invite') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    targetId = tonumber(targetId)
    local target = targetId and MS.GetPlayer(targetId)

    if not target then
        player:Notify('Dieser Spieler ist nicht online.', 'error')
        return
    end

    if Factions.GetByCharacter(target.charId) then
        player:Notify('Der Spieler ist bereits in einer Fraktion.', 'error')
        return
    end

    if faction:CountMembers() >= faction:GetMemberSlots() then
        player:Notify('Die Fraktion ist voll.', 'error')
        return
    end

    invites[targetId] = {
        factionId = faction.id,
        expires   = os.time() + FactionConfig.Members.inviteTimeout,
        by        = nameOf(player),
    }

    player:Notify(('Einladung an %s verschickt.'):format(nameOf(target)), 'success')
    target:Notify(('%s laedt dich zu %s ein. /fraktion annehmen'):format(
        nameOf(player), faction.name), 'info', 12000)

    TriggerClientEvent('factions:client:invite', targetId, {
        faction = faction:GetPublicInfo(),
        by      = nameOf(player),
        seconds = FactionConfig.Members.inviteTimeout,
    })
end)

local function acceptInvite(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local invite = invites[source]
    if not invite or invite.expires < os.time() then
        invites[source] = nil
        player:Notify('Du hast keine offene Einladung.', 'error')
        return
    end

    invites[source] = nil

    local faction = Factions.Get(invite.factionId)
    if not faction then return end

    if Factions.GetByCharacter(player.charId) then
        player:Notify('Du bist bereits in einer Fraktion.', 'error')
        return
    end

    if faction:CountMembers() >= faction:GetMemberSlots() then
        player:Notify('Die Fraktion ist inzwischen voll.', 'error')
        return
    end

    faction:AddMember(player.charId, nameOf(player), 0)
    faction:Log('mitglied', ('%s ist beigetreten.'):format(nameOf(player)))
    faction:Notify(('%s ist der Fraktion beigetreten.'):format(nameOf(player)), 'success')

    Factions.SendWelcome(source, faction)
    faction:Sync()

    TriggerEvent('factions:server:memberJoined', faction.id, player.charId)
end

RegisterNetEvent('factions:server:acceptInvite', function()
    acceptInvite(source)
end)

RegisterNetEvent('factions:server:declineInvite', function()
    invites[source] = nil
end)

--- Willkommensbild zeigen.
function Factions.SendWelcome(source, faction)
    TriggerClientEvent('factions:client:welcome', source, {
        name    = faction.name,
        tag     = faction.tag,
        emblem  = faction.emblem,
        level   = faction.level,
        members = faction:CountMembers(),
    })
end

-- Rauswerfen und verlassen -------------------------------------------------------

RegisterNetEvent('factions:server:kick', function(characterId)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'kick') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    characterId = tonumber(characterId)
    local member = characterId and faction.members[characterId]
    if not member then return end

    if characterId == faction.ownerId then
        player:Notify('Die Fuehrung kann nicht rausgeworfen werden.', 'error')
        return
    end

    local ownGrade = faction:GetGrade(player.charId) or 0
    if member.grade >= ownGrade then
        player:Notify('Du kannst niemanden mit deinem Rang oder darueber rauswerfen.', 'error')
        return
    end

    faction:RemoveMember(characterId)
    faction:Log('mitglied', ('%s wurde von %s entfernt.'):format(member.name, nameOf(player)))
    faction:Notify(('%s wurde aus der Fraktion entfernt.'):format(member.name), 'warning')

    local target = Factions.GetSourceOf(characterId)
    if target then
        exports['moonshine-core']:Notify(target, 'Du wurdest aus der Fraktion entfernt.', 'error', 9000)
        TriggerClientEvent('factions:client:sync', target, false)
    end

    faction:Sync()
    TriggerEvent('factions:server:memberLeft', faction.id, characterId)
end)

RegisterNetEvent('factions:server:leave', function()
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction then return end

    if player.charId == faction.ownerId then
        player:Notify('Uebergib erst die Fuehrung oder loese die Fraktion auf.', 'error')
        return
    end

    local name = nameOf(player)
    faction:RemoveMember(player.charId)
    faction:Log('mitglied', ('%s hat die Fraktion verlassen.'):format(name))
    faction:Notify(('%s hat die Fraktion verlassen.'):format(name), 'warning')

    player:Notify('Du hast die Fraktion verlassen.', 'info')
    TriggerClientEvent('factions:client:sync', source, false)

    faction:Sync()
    TriggerEvent('factions:server:memberLeft', faction.id, player.charId)
end)

-- Raenge vergeben -------------------------------------------------------------------

RegisterNetEvent('factions:server:setGrade', function(characterId, grade)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'promote') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    characterId = tonumber(characterId)
    grade = math.floor(tonumber(grade) or 0)

    local member = characterId and faction.members[characterId]
    if not member then return end

    local top = Factions.TopGrade(faction.ranks)
    if grade < 0 or grade > top then return end

    local ownGrade = faction:GetGrade(player.charId) or 0
    local isOwner  = player.charId == faction.ownerId

    if not isOwner then
        if member.grade >= ownGrade then
            player:Notify('Du kannst niemanden ab deinem Rang aendern.', 'error')
            return
        end

        if grade >= ownGrade then
            player:Notify('So hoch darfst du nicht befoerdern.', 'error')
            return
        end
    end

    if characterId == faction.ownerId then
        player:Notify('Der Rang der Fuehrung ist fest.', 'error')
        return
    end

    member.grade = grade
    Factions.DB.SetGrade(characterId, grade)

    local rank = Factions.GetRank(faction.ranks, grade)
    faction:Log('rang', ('%s ist jetzt %s.'):format(member.name, rank.label))
    faction:Notify(('%s ist jetzt %s.'):format(member.name, rank.label), 'info')

    faction:Sync()
end)

--- Fuehrung uebergeben.
RegisterNetEvent('factions:server:transferOwner', function(characterId)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or player.charId ~= faction.ownerId then
        player:Notify('Nur die Fuehrung darf das.', 'error')
        return
    end

    characterId = tonumber(characterId)
    local member = characterId and faction.members[characterId]
    if not member or characterId == faction.ownerId then return end

    local top = Factions.TopGrade(faction.ranks)

    faction.ownerId = characterId
    faction.dirty = true

    member.grade = top
    Factions.DB.SetGrade(characterId, top)

    local old = faction.members[player.charId]
    if old then
        old.grade = math.max(0, top - 1)
        Factions.DB.SetGrade(player.charId, old.grade)
    end

    faction:Save()
    faction:Log('rang', ('%s fuehrt die Fraktion jetzt.'):format(member.name))
    faction:Notify(('%s fuehrt die Fraktion jetzt.'):format(member.name), 'success', 9000)

    faction:Sync()
end)

-- Aufloesen ---------------------------------------------------------------------------

RegisterNetEvent('factions:server:disband', function(confirmation)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or player.charId ~= faction.ownerId then
        player:Notify('Nur die Fuehrung darf das.', 'error')
        return
    end

    if tostring(confirmation) ~= faction.name then
        player:Notify('Tippe den Fraktionsnamen zur Bestaetigung.', 'error')
        return
    end

    local sources = faction:OnlineSources()

    Factions.ReleaseTerritories(faction.id)
    Factions.DB.Delete(faction.id)
    Factions.List[faction.id] = nil

    for _, target in ipairs(sources) do
        exports['moonshine-core']:Notify(target, 'Die Fraktion wurde aufgeloest.', 'error', 9000)
        TriggerClientEvent('factions:client:sync', target, false)
    end

    TriggerEvent('factions:server:disbanded', faction.id)
end)

-- Abgelaufene Einladungen aufraeumen ---------------------------------------------------

CreateThread(function()
    while true do
        Wait(15000)

        local now = os.time()
        for source, invite in pairs(invites) do
            if invite.expires < now then invites[source] = nil end
        end
    end
end)

AddEventHandler('playerDropped', function()
    invites[source] = nil
end)

Factions.AcceptInvite = acceptInvite
