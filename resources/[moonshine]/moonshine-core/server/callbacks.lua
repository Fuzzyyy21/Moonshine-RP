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

    -- Callbacks sind Netz-Events wie alle anderen: der Client entscheidet,
    -- wann und wie oft er fragt. Ohne Begrenzung laesst sich jede Abfrage
    -- im Dauerfeuer stellen, und viele davon schlagen bis in die Datenbank
    -- durch.
    --
    -- Zwei Stufen: eine grosszuegige Gesamtgrenze ueber alle Callbacks und
    -- eine engere je Name, damit ein einzelner nicht alles blockiert.
    if not MS.RateLimit(source, 'core:callback', Config.RateLimit.callbackMax,
        Config.RateLimit.callbackWindow) then return end

    if type(name) ~= 'string' then return end

    if not MS.RateLimit(source, 'cb:' .. name, Config.RateLimit.callbackPerName,
        Config.RateLimit.callbackWindow) then return end

    local callback = MS.ServerCallbacks[name]

    if not callback then
        MS.Utils.Print('warn', 'Unbekannter Server-Callback "%s" (von %d)', tostring(name), source)

        -- Wer wiederholt nach Callbacks fragt, die es nicht gibt, sucht
        -- etwas. Das ist eine Meldung wert.
        pcall(function()
            exports['moonshine-admin']:Flag(source,
                ('Unbekannter Callback "%s"'):format(name), 1)
        end)

        TriggerClientEvent('moonshine:client:callbackResponse', source, requestId)
        return
    end

    callback(MS.Players[source], function(...)
        TriggerClientEvent('moonshine:client:callbackResponse', source, requestId, ...)
    end, ...)
end)
