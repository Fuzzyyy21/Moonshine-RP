--- API und Commands der Administration.

exports('GetAdminObject', function()
    return Admin
end)

--- Ratenbegrenzung fuer andere Resources.
---   if not MS.RateLimit(source, 'shop:buy', 10, 5) then return end
exports('RateLimit', function(source, key, max, windowSeconds)
    return Admin.RateLimit(source, tostring(key or 'default'), max, windowSeconds)
end)

--- Verdacht melden.
---
--- Die Art ist wichtiger als sie aussieht: darauf laeuft die Sperrzeit
--- gegen Dauerfeuer, und darauf zaehlt der Wachhund, ob ueberhaupt genug
--- *verschiedene* Verdachtsmomente zusammengekommen sind. Ohne Angabe
--- landet alles im selben Topf 'sonstiges' - dann bremst sich eine Resource
--- selbst aus.
exports('Flag', function(source, reason, weight, art)
    return Admin.Flag(source, tostring(reason or 'Unbekannt'), weight, nil,
        art and tostring(art) or nil)
end)

exports('GetStrikes', function(source)
    return Admin.GetStrikes(source)
end)

exports('ClearStrikes', function(source)
    return Admin.ClearStrikes(source)
end)

--- Prueft, ob ein Punkt in Reichweite liegt. Praktisch fuer eigene Resources.
exports('IsNear', function(source, coords, range)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or type(coords) ~= 'table' then return false end

    return #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z))
        <= (tonumber(range) or 3.0)
end)

-- Commands ----------------------------------------------------------------------

local function levelOf(source)
    if source == 0 then return 4 end

    local player = MS.GetPlayer(source)
    return player and (player.adminLevel or 0) or 0
end

RegisterCommand('adminliste', function(source)
    if levelOf(source) < 2 then return end

    local parts = {}
    for _, player in pairs(MS.GetPlayers()) do
        if (player.adminLevel or 0) > 0 then
            parts[#parts + 1] = ('%s (%d) Level %d'):format(
                player.fullname, player.source, player.adminLevel)
        end
    end

    local text = #parts > 0 and table.concat(parts, ' · ') or 'Kein Admin online.'

    if source == 0 then
        print(text)
    else
        MS.GetPlayer(source):Notify(text, 'info', 12000)
    end
end, false)

RegisterCommand('strikes', function(source, args)
    if levelOf(source) < 2 then return end

    local target = tonumber(args[1]) or source
    local count = Admin.GetStrikes(target)

    local text = ('Spieler %d hat %d Strikes.'):format(target, count)

    if source == 0 then print(text)
    else MS.GetPlayer(source):Notify(text, 'info', 8000) end
end, false)

RegisterCommand('clearstrikes', function(source, args)
    if levelOf(source) < 3 then return end

    local target = tonumber(args[1])
    if not target then return end

    Admin.ClearStrikes(target)

    if source > 0 then
        MS.GetPlayer(source):Notify('Strikes zurueckgesetzt.', 'success')
    end
end, false)

-- /wachhund steht in server/guard.lua: der Befehl zeigt den Stand und
-- schaltet um, und beides gehoert an die Stelle, die es weiss.

print('^2[Admin]^7 Panel und Wachhund geladen.')
