--- Lebenszyklus, Callbacks und Commands des Fortschrittssystems.

-- Lebenszyklus ---------------------------------------------------------------

AddEventHandler('moonshine:server:playerLoaded', function(source, player)
    CreateThread(function()
        Progress.LoadProfile(source, player.charId)
    end)
end)

AddEventHandler('moonshine:server:playerDropped', function(source)
    Progress.UnloadProfile(source)
end)

AddEventHandler('moonshine:server:playerUnloaded', function(source)
    Progress.UnloadProfile(source)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for source in pairs(Progress.Profiles) do
        Progress.UnloadProfile(source)
    end
end)

--- Autosave.
CreateThread(function()
    while true do
        Wait(5 * 60000)

        for _, profile in pairs(Progress.Profiles) do
            pcall(profile.Save, profile)
        end
    end
end)

-- Anfragen aus der Oberflaeche ------------------------------------------------

RegisterNetEvent('progress:server:request', function()
    local profile = Progress.GetProfile(source)
    if profile then profile:Sync() end
end)

-- Exporte ---------------------------------------------------------------------

exports('GetProgressObject', function()
    return Progress
end)

exports('GetProfile', function(source)
    return Progress.GetProfile(source)
end)

exports('GiveReward', function(source, reward, reason)
    return Progress.GiveReward(source, reward, reason)
end)

exports('AddBattlePassXp', function(source, amount)
    return Progress.AddBattlePassXp(source, amount)
end)

exports('GiveCase', function(source, name, amount)
    return Progress.GiveCase(source, name, amount)
end)

exports('AdvanceMission', function(source, event, amount)
    return Progress.Advance(source, event, amount)
end)

exports('GetPlaytime', function(source)
    local profile = Progress.GetProfile(source)
    if not profile then return 0, 0 end

    return profile.playtimeMinutes, profile.playtimeTotal
end)

exports('IsPremium', function(source)
    local profile = Progress.GetProfile(source)
    return profile ~= nil and profile.premium
end)

-- Commands --------------------------------------------------------------------

local function permission(source, level)
    if source == 0 then return true end

    local player = MS.GetPlayer(source)
    return player ~= nil and (player.adminLevel or 0) >= level
end

RegisterCommand('spielzeit', function(source)
    local profile = Progress.GetProfile(source)
    local player = MS.GetPlayer(source)
    if not profile or not player then return end

    player:Notify(('Heute %d Minuten, insgesamt %d Stunden.'):format(
        profile.playtimeMinutes, math.floor(profile.playtimeTotal / 60)), 'info', 8000)
end, false)

RegisterCommand('givecase', function(source, args)
    if not permission(source, 3) then return end

    local target = tonumber(args[1])
    local name   = args[2]
    local amount = math.floor(tonumber(args[3]) or 1)

    if not target or not name or not Progress.GetCase(name) then
        print('Verwendung: /givecase [id] [holz|silber|gold|mystisch] [menge]')
        return
    end

    if Progress.GiveCase(target, name, amount) then
        exports['moonshine-core']:Notify(target,
            ('Du hast %dx %s erhalten.'):format(amount, Progress.GetCase(name).label), 'success')
    end
end, false)

RegisterCommand('givepassxp', function(source, args)
    if not permission(source, 3) then return end

    local target = tonumber(args[1])
    local amount = math.floor(tonumber(args[2]) or 0)
    if not target or amount <= 0 then return end

    Progress.AddBattlePassXp(target, amount)
end, false)

RegisterCommand('resetmissions', function(source, args)
    if not permission(source, 4) then return end

    local target = tonumber(args[1]) or source
    local profile = Progress.GetProfile(target)
    if not profile then return end

    for missionId, state in pairs(profile.missions) do
        state.progress = 0
        state.claimed  = false
        Progress.DB.SaveMission(profile.characterId, missionId, state.period, 0, false)
    end

    profile:Sync()
end, false)

print('^2[Progress]^7 Fortschrittssystem geladen.')
