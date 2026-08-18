--- Oeffentliche Server-API fuer andere Resources.
---
---   local MS = exports['moonshine-core']:GetCoreObject()
---   local player = MS.GetPlayer(source)
---
--- Alternativ direkt:
---   exports['moonshine-core']:AddMoney(source, 500, 'bank', 'shop')

exports('GetCoreObject', function()
    return MS
end)

exports('GetPlayer', function(source)
    return MS.GetPlayer(source)
end)

exports('GetPlayers', function(jobName)
    return MS.GetPlayers(jobName)
end)

exports('GetPlayerData', function(source)
    local player = MS.GetPlayer(source)
    return player and player:GetData() or nil
end)

exports('IsPlayerLoaded', function(source)
    return MS.GetPlayer(source) ~= nil
end)

exports('AddMoney', function(source, amount, account, reason)
    local player = MS.GetPlayer(source)
    return player and player:AddMoney(amount, account, reason) or false
end)

exports('RemoveMoney', function(source, amount, account, reason)
    local player = MS.GetPlayer(source)
    return player and player:RemoveMoney(amount, account, reason) or false
end)

exports('GetMoney', function(source, account)
    local player = MS.GetPlayer(source)
    return player and player:GetMoney(account) or 0
end)

exports('AddItem', function(source, name, count, metadata)
    local player = MS.GetPlayer(source)
    return player and player:AddItem(name, count, metadata) or false
end)

exports('RemoveItem', function(source, name, count, slot)
    local player = MS.GetPlayer(source)
    return player and player:RemoveItem(name, count, slot) or false
end)

exports('HasItem', function(source, name, count)
    local player = MS.GetPlayer(source)
    return player and player:HasItem(name, count) or false
end)

exports('SetJob', function(source, name, grade)
    local player = MS.GetPlayer(source)
    return player and player:SetJob(name, grade) or false
end)

exports('Notify', function(source, message, type, duration)
    local player = MS.GetPlayer(source)
    if player then
        player:Notify(message, type, duration)
    else
        TriggerClientEvent('moonshine:client:notify', source, message, type or 'info', duration or 5000)
    end
end)

exports('RegisterUsableItem', function(name, callback)
    MS.RegisterUsableItem(name, callback)
end)

exports('RegisterItem', function(name, definition)
    return MS.RegisterItem(name, definition)
end)

exports('GetItem', function(name)
    return MS.GetItem(name)
end)

exports('RegisterServerCallback', function(name, callback)
    MS.RegisterServerCallback(name, callback)
end)

exports('SavePlayer', function(source)
    local player = MS.GetPlayer(source)
    return player and player:Save() or false
end)

exports('SaveAllPlayers', function()
    return MS.SaveAllPlayers()
end)

exports('CreateDrop', function(name, count, metadata, coords)
    return MS.CreateDrop(name, count, metadata, coords)
end)
