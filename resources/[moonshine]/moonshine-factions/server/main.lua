--- Lebenszyklus, Commands und API der Fraktionen.

-- Start ------------------------------------------------------------------------

CreateThread(function()
    while not Factions.DB.Ready do Wait(500) end

    Factions.LoadAll()
    Factions.LoadTerritories()

    for _, faction in pairs(Factions.List) do
        Factions.LoadMissions(faction)
    end

    Factions.BroadcastTerritories()
end)

-- Spieler ----------------------------------------------------------------------

AddEventHandler('moonshine:server:playerLoaded', function(source, player)
    Factions.Online[player.charId] = source

    CreateThread(function()
        Wait(2000)

        local faction = Factions.GetByCharacter(player.charId)
        if not faction then
            TriggerClientEvent('factions:client:sync', source, false)
            return
        end

        Factions.SendWelcome(source, faction)
        faction:Sync(source)
        faction:Sync()
    end)

    TriggerClientEvent('factions:client:territories', source, Factions.GetTerritoryOverview())
end)

local function unload(source)
    local player = MS.GetPlayer(source)
    if player then Factions.Online[player.charId] = nil end

    for characterId, stored in pairs(Factions.Online) do
        if stored == source then Factions.Online[characterId] = nil end
    end
end

AddEventHandler('moonshine:server:playerDropped', function(source)
    unload(source)
end)

AddEventHandler('moonshine:server:playerUnloaded', function(source)
    unload(source)
end)

-- Anfragen aus der Oberflaeche ----------------------------------------------------

RegisterNetEvent('factions:server:request', function()
    local source = source
    local faction = Factions.GetByPlayer(source)

    if faction then
        faction:Sync(source)
    else
        TriggerClientEvent('factions:client:sync', source, false)
    end
end)

--- Fraktion gruenden.
RegisterNetEvent('factions:server:create', function(name, tag)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    if Factions.GetByCharacter(player.charId) then
        player:Notify('Du bist bereits in einer Fraktion.', 'error')
        return
    end

    local config = FactionConfig.Create
    local free = (player.adminLevel or 0) >= config.adminLevel

    if not free and player:GetMoney(config.account) < config.price then
        player:Notify(('Die Gruendung kostet %s.'):format(
            MS.Utils.FormatMoney(config.price)), 'error')
        return
    end

    local fullname = ('%s %s'):format(player.firstname, player.lastname)
    local faction, err = Factions.Create(name, tag, player.charId, fullname)

    if not faction then
        player:Notify(err, 'error')
        return
    end

    if not free then
        player:RemoveMoney(config.price, config.account, 'fraktionsgruendung')
    end

    Factions.LoadMissions(faction)

    player:Notify(('%s [%s] wurde gegruendet.'):format(faction.name, faction.tag), 'success', 9000)
    Factions.SendWelcome(source, faction)
    faction:Sync(source)

    MS.Logger.Log('character', ('%s hat die Fraktion %s gegruendet.'):format(
        fullname, faction.name), player.license)
end)

--- Uebersicht aller Fraktionen (auch fuer Spieler ohne Fraktion).
RegisterNetEvent('factions:server:requestList', function()
    local source = source
    local list = {}

    for _, faction in pairs(Factions.List) do
        local info = faction:GetPublicInfo()
        info.territories = #Factions.GetTerritoriesOf(faction.id)
        list[#list + 1] = info
    end

    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return a.name < b.name
    end)

    TriggerClientEvent('factions:client:list', source, list)
end)

-- Spielzeit fuer Fraktionsmissionen -------------------------------------------------

CreateThread(function()
    while true do
        Wait(60000)

        for _, faction in pairs(Factions.List) do
            local online = #faction:OnlineSources()
            if online > 0 then Factions.Advance(faction.id, 'playtime', online) end
        end
    end
end)

-- Autosave ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(5 * 60000)

        for _, faction in pairs(Factions.List) do
            pcall(faction.Save, faction)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, faction in pairs(Factions.List) do
        pcall(faction.Save, faction, true)
    end
end)

-- API ----------------------------------------------------------------------------------

exports('GetFactionsObject', function()
    return Factions
end)

exports('GetFaction', function(source)
    local faction = Factions.GetByPlayer(source)
    return faction and faction:GetPublicInfo() or nil
end)

exports('GetFactionId', function(source)
    local faction = Factions.GetByPlayer(source)
    return faction and faction.id or nil
end)

exports('GetGrade', function(source)
    local player = MS.GetPlayer(source)
    local faction = player and Factions.GetByCharacter(player.charId)
    if not faction then return nil end

    return faction:GetGrade(player.charId)
end)

exports('HasPermission', function(source, permission)
    local faction = Factions.GetByPlayer(source)
    return faction ~= nil and faction:PlayerCan(source, permission)
end)

exports('AddKasse', function(factionId, amount, reason)
    local faction = Factions.Get(factionId)
    if not faction then return false end

    local ok = faction:AddKasse(amount, reason)
    faction:Save()
    faction:Sync()

    return ok
end)

exports('AddFactionXp', function(factionId, amount)
    local faction = Factions.Get(factionId)
    if not faction then return false end

    faction:AddXp(amount)
    faction:Save()
    faction:Sync()

    return true
end)

exports('GetTerritoryOwner', function(territoryId)
    local state = Factions.TerritoryState[territoryId]
    return state and state.factionId or nil
end)

exports('AdvanceFactionMission', function(factionId, event, amount)
    return Factions.Advance(factionId, event, amount)
end)

-- Commands ---------------------------------------------------------------------------------

local function permission(source, level)
    if source == 0 then return true end

    local player = MS.GetPlayer(source)
    return player ~= nil and (player.adminLevel or 0) >= level
end

RegisterCommand('fraktioninfo', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction then
        player:Notify('Du bist in keiner Fraktion.', 'info')
        return
    end

    local rank = Factions.GetRank(faction.ranks, faction:GetGrade(player.charId) or 0)
    player:Notify(('%s [%s] - %s - Level %d - Kasse %s'):format(
        faction.name, faction.tag, rank.label, faction.level,
        MS.Utils.FormatMoney(faction.kasse)), 'info', 9000)
end, false)

RegisterCommand('fraktionannehmen', function(source)
    Factions.AcceptInvite(source)
end, false)

RegisterCommand('createfaction', function(source, args)
    if not permission(source, 3) then return end

    local name = args[1]
    local tag  = args[2]
    local targetId = tonumber(args[3]) or source

    local target = MS.GetPlayer(targetId)
    if not name or not tag or not target then
        print('Verwendung: /createfaction [name] [tag] [id]')
        return
    end

    local fullname = ('%s %s'):format(target.firstname, target.lastname)
    local faction, err = Factions.Create(name:gsub('_', ' '), tag, target.charId, fullname)

    if not faction then
        if source > 0 then MS.GetPlayer(source):Notify(err, 'error') else print(err) end
        return
    end

    Factions.LoadMissions(faction)
    Factions.SendWelcome(targetId, faction)
    faction:Sync()
end, false)

RegisterCommand('deletefaction', function(source, args)
    if not permission(source, 4) then return end

    local faction = Factions.GetByName(table.concat(args, ' '))
    if not faction then return end

    local sources = faction:OnlineSources()

    Factions.ReleaseTerritories(faction.id)
    Factions.DB.Delete(faction.id)
    Factions.List[faction.id] = nil

    for _, target in ipairs(sources) do
        TriggerClientEvent('factions:client:sync', target, false)
    end

    print(('Fraktion %s geloescht.'):format(faction.name))
end, false)

RegisterCommand('factionkasse', function(source, args)
    if not permission(source, 3) then return end

    local faction = Factions.GetByName(args[1])
    local amount = math.floor(tonumber(args[2]) or 0)
    if not faction or amount == 0 then return end

    if amount > 0 then
        faction:AddKasse(amount, 'Admin')
    else
        faction:RemoveKasse(-amount, 'Admin')
    end

    faction:Save()
    faction:Sync()
end, false)

RegisterCommand('setterritory', function(source, args)
    if not permission(source, 3) then return end

    local territory = Factions.GetTerritory(args[1])
    local faction = args[2] and Factions.GetByName(args[2])
    if not territory then return end

    local state = Factions.TerritoryState[territory.id]
    if not state then return end

    state.factionId = faction and faction.id or nil
    state.since = os.time()
    state.protectedUntil = 0
    state.progress = 0.0
    state.captureBy = nil

    Factions.DB.SaveTerritory(territory.id, state.factionId, state.since, 0)
    Factions.BroadcastTerritories()

    if faction then faction:Sync() end
end, false)

print('^2[Fraktionen]^7 Fraktionssystem geladen.')
