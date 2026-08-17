--- Admin-Commands des Mystik-Systems.
--- Die Rechtepruefung laeuft ueber das Adminlevel des Cores.

local MS = exports['moonshine-core']:GetCoreObject()

local REQUIRED_LEVEL = 3

local function hasPermission(source)
    if source == 0 then return true end

    local player = MS.GetPlayer(source)
    return player ~= nil and player.adminLevel >= REQUIRED_LEVEL
end

local function reply(source, message, type)
    if source == 0 then
        print('[Mystic] ' .. message)
        return
    end
    TriggerClientEvent('moonshine:client:notify', source, message, type or 'info', 5000)
end

local function targetProfile(source, value)
    local targetId = tonumber(value)
    if not targetId then
        reply(source, 'Ungueltige Spieler-ID.', 'error')
        return nil
    end

    local profile = Mystic.Profiles[targetId]
    if not profile then
        reply(source, 'Dieser Spieler hat kein geladenes Profil.', 'error')
        return nil
    end
    return profile
end

local function register(name, help, params, handler)
    RegisterCommand(name, function(source, args)
        if not hasPermission(source) then
            reply(source, 'Dazu hast du keine Berechtigung.', 'error')
            return
        end
        handler(source, args)
    end, false)

    TriggerClientEvent('chat:addSuggestion', -1, '/' .. name, help, params)
end

register('setrasse', 'Setzt die Rasse eines Spielers', {
    { name = 'id', help = 'Spieler-ID' },
    { name = 'rasse', help = 'vampir | werwolf | daemon | fee | magier | hexer | nekromant | jaeger' },
}, function(source, args)
    local profile = targetProfile(source, args[1])
    if not profile then return end

    local race = Mystic.GetRace(args[2])
    if not race then
        reply(source, 'Unbekannte Rasse.', 'error')
        return
    end

    profile.race = args[2]
    profile:SetEssence(profile:GetMaxEssence())
    Mystic.DB.SetRace(profile.characterId, args[2])
    profile:Save()
    profile:Sync()

    TriggerClientEvent('mystic:client:awakened', profile.source, args[2])
    profile:Notify(('Du bist nun ein %s.'):format(race.label), 'success')
    reply(source, ('Rasse gesetzt: %s'):format(race.label), 'success')
end)

register('givepunkte', 'Gibt Skill- oder persoenliche Punkte', {
    { name = 'id', help = 'Spieler-ID' },
    { name = 'art', help = 'skill | perk' },
    { name = 'anzahl', help = 'Anzahl' },
}, function(source, args)
    local profile = targetProfile(source, args[1])
    if not profile then return end

    local kind = args[2]
    local amount = tonumber(args[3])
    if not amount or (kind ~= 'skill' and kind ~= 'perk') then
        reply(source, 'Verwendung: /givepunkte [id] [skill|perk] [anzahl]', 'error')
        return
    end

    if kind == 'skill' then
        profile:AddSkillPoints(amount)
    else
        profile:AddPersonalPoints(amount)
    end

    profile:Save()
    profile:Sync()
    profile:Notify(('%d %s-Punkte erhalten.'):format(amount, kind), 'success')
    reply(source, 'Punkte vergeben.', 'success')
end)

register('givestein', 'Gibt einem Spieler Ritualsteine', {
    { name = 'id', help = 'Spieler-ID' },
    { name = 'stein', help = 'runenstein, seelenstein, blutstein, ...' },
    { name = 'anzahl', help = 'Anzahl' },
}, function(source, args)
    local targetId = tonumber(args[1])
    local player = targetId and MS.GetPlayer(targetId)
    if not player then
        reply(source, 'Spieler nicht gefunden.', 'error')
        return
    end

    local stone = args[2] and Mystic.Stones[args[2]]
    local amount = tonumber(args[3]) or 1
    if not stone then
        reply(source, 'Unbekannter Stein.', 'error')
        return
    end

    if player:AddItem(args[2], amount) then
        reply(source, ('%dx %s vergeben.'):format(amount, stone.label), 'success')
    else
        reply(source, 'Der Spieler kann die Steine nicht tragen.', 'error')
    end
end)

register('unlockall', 'Schaltet alle Skills der Rasse frei (Test)', {
    { name = 'id', help = 'Spieler-ID' },
}, function(source, args)
    local profile = targetProfile(source, args[1])
    if not profile or not profile.race then
        reply(source, 'Der Spieler hat keine Rasse.', 'error')
        return
    end

    local slot = 1
    for _, skill in ipairs(Mystic.GetSkillsForRace(profile.race)) do
        profile.unlocked[skill.id] = true

        if not skill.passive and slot <= MysticConfig.SkillBar.slots then
            profile.skillbar[slot] = skill.id
            slot = slot + 1
        end
    end

    profile:Save()
    profile:Sync()
    reply(source, 'Alle Skills freigeschaltet.', 'success')
end)

register('resetmystic', 'Setzt Rasse, Skills und Perks zurueck', {
    { name = 'id', help = 'Spieler-ID' },
}, function(source, args)
    local profile = targetProfile(source, args[1])
    if not profile then return end

    profile.race     = nil
    profile.unlocked = {}
    profile.perks    = {}
    profile.skillbar = {}
    for slot = 1, MysticConfig.SkillBar.slots do profile.skillbar[slot] = false end

    Mystic.DB.SetRace(profile.characterId, nil)
    profile:Save()
    profile:Sync()

    TriggerClientEvent('mystic:client:resetEffects', profile.source)
    reply(source, 'Profil zurueckgesetzt.', 'success')
end)

-- Fuer alle Spieler ----------------------------------------------------------

RegisterCommand('mystik', function(source)
    if source == 0 then return end

    local profile = Mystic.Profiles[source]
    if not profile then return end

    TriggerClientEvent('mystic:client:openOverview', source, profile:GetData())
end, false)
