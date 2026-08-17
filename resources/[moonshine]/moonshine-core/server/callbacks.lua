--- Server-Callbacks: der Client fragt, der Server antwortet.
---
--- Server:  MS.RegisterServerCallback('shop:kaufen', function(player, cb, item) cb(true) end)
--- Client:  MS.TriggerServerCallback('shop:kaufen', function(ok) end, 'bread')

MS.ServerCallbacks = {}

---@param name string
---@param callback fun(player: table, cb: fun(...), ...)
function MS.RegisterServerCallback(name, callback)
    MS.ServerCallbacks[name] = callback
end

RegisterNetEvent('moonshine:server:triggerCallback', function(name, requestId, ...)
    local source = source
    local callback = MS.ServerCallbacks[name]

    if not callback then
        MS.Utils.Print('warn', 'Unbekannter Server-Callback "%s" (von %d)', tostring(name), source)
        TriggerClientEvent('moonshine:client:callbackResponse', source, requestId)
        return
    end

    callback(MS.Players[source], function(...)
        TriggerClientEvent('moonshine:client:callbackResponse', source, requestId, ...)
    end, ...)
end)
