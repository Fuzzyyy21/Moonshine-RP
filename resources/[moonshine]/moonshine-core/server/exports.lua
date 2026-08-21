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

--- Ratenbegrenzung fuer Netzwerkereignisse.
---
--- Delegiert an moonshine-admin, wenn es laeuft. Fehlt die Resource, wird
--- alles durchgelassen - so bleibt jede Resource fuer sich lauffaehig.
---
---   if not MS.RateLimit(source, 'shop:kaufen', 10, 5) then return end
---
---@return boolean allowed
--- [source] = { [key] = { count, resetAt, warned } }
MS.Rates = {}

--- Prueft und zaehlt einen Aufruf.
---
--- Vorher lag das in moonshine-admin und wurde von hier per Export geholt.
--- Fiel die Resource aus oder war sie noch nicht gestartet, gab der pcall
--- still `true` zurueck - und saemtliche Begrenzungen im ganzen Framework
--- waren aus, ohne dass eine Zeile im Log stand. Jetzt rechnet der Core
--- selbst; moonshine-admin bekommt nur noch die Meldung.
---@return boolean allowed
function MS.RateLimit(source, key, max, windowSeconds)
    if not Config.RateLimit.enabled then return true end

    local player = MS.Players[source]
    if not player then return true end

    -- Admins ab dem eingestellten Level laufen ungebremst.
    if (player.adminLevel or 0) >= Config.RateLimit.exemptLevel then return true end

    key = tostring(key or 'default')
    max = max or Config.RateLimit.defaultMax
    windowSeconds = windowSeconds or Config.RateLimit.defaultWindow

    local buckets = MS.Rates[source]
    if not buckets then
        buckets = {}
        MS.Rates[source] = buckets
    end

    local allowed, bucket, melden = MS.Utils.RateBucket(
        buckets[key], os.time(), max, windowSeconds, Config.RateLimit.strikes)

    buckets[key] = bucket

    if melden then
        -- Der Wachhund darf fehlen; die Begrenzung greift trotzdem.
        pcall(function()
            exports['moonshine-admin']:Flag(source,
                ('Zu viele Aufrufe von "%s"'):format(key), 2)
        end)
    end

    return allowed
end

AddEventHandler('playerDropped', function()
    MS.Rates[source] = nil
end)

exports('RateLimit', function(source, key, max, windowSeconds)
    return MS.RateLimit(source, key, max, windowSeconds)
end)
