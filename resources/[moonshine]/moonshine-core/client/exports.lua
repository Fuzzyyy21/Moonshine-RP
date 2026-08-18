--- Oeffentliche Client-API fuer andere Resources.
---
---   local MS = exports['moonshine-core']:GetCoreObject()
---   if MS.IsPlayerLoaded then ... end

exports('GetCoreObject', function()
    return MS
end)

exports('GetPlayerData', function()
    return MS.PlayerData
end)

exports('IsPlayerLoaded', function()
    return MS.IsPlayerLoaded
end)

exports('GetJob', function()
    return MS.PlayerData.job
end)

exports('GetMoney', function(account)
    local accounts = MS.PlayerData.accounts or {}
    return accounts[account or 'cash'] or 0
end)

exports('HasItem', function(name, count)
    local total = 0
    for _, entry in ipairs(MS.PlayerData.inventory or {}) do
        if entry.name == name then total = total + entry.count end
    end
    return total >= (count or 1)
end)

exports('Notify', function(message, type, duration)
    MS.Notify(message, type, duration)
end)

exports('RegisterItem', function(name, definition)
    return MS.RegisterItem(name, definition)
end)

exports('GetItem', function(name)
    return MS.GetItem(name)
end)

exports('TriggerServerCallback', function(name, callback, ...)
    MS.TriggerServerCallback(name, callback, ...)
end)

exports('OpenInventory', function()
    MS.OpenInventory()
end)

exports('DrawText3D', function(coords, text, scale)
    MS.DrawText3D(coords, text, scale)
end)
