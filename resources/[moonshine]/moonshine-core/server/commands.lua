--- Admin- und Basis-Commands.

--- Prueft die Berechtigung fuer einen Command. Die Serverkonsole (0) darf alles.
---@return boolean
function MS.HasPermission(source, commandName)
    if source == 0 then return true end

    local required = Config.CommandPermissions[commandName] or 1
    local player = MS.Players[source]
    if player then return player.adminLevel >= required end

    local session = MS.Sessions[source]
    return session ~= nil and (session.user.admin_level or 0) >= required
end

local function reply(source, message, type)
    if source == 0 then
        MS.Utils.Print('info', message)
        return
    end

    local player = MS.Players[source]
    if player then
        player:Notify(message, type or 'info')
    else
        TriggerClientEvent('moonshine:client:notify', source, message, type or 'info', 5000)
    end
end

--- Registriert einen Command inkl. Rechtepruefung und Chat-Vorschlag.
---@param name string
---@param help string
---@param params table
---@param handler fun(source: number, args: table, player: table|nil)
local function registerCommand(name, help, params, handler)
    RegisterCommand(name, function(source, args)
        if not MS.HasPermission(source, name) then
            reply(source, 'Dazu hast du keine Berechtigung.', 'error')
            return
        end
        handler(source, args, MS.Players[source])
    end, false)

    TriggerClientEvent('chat:addSuggestion', -1, '/' .. name, help, params)
end

--- Loest eine Spieler-ID auf und meldet Fehler zurueck.
local function resolveTarget(source, value)
    local targetId = tonumber(value)
    if not targetId then
        reply(source, 'Ungueltige Spieler-ID.', 'error')
        return nil
    end

    local target = MS.Players[targetId]
    if not target then
        reply(source, ('Kein geladener Spieler mit ID %d.'):format(targetId), 'error')
        return nil
    end
    return target
end

-- Wirtschaft -----------------------------------------------------------------

registerCommand('givemoney', 'Gibt einem Spieler Geld', {
    { name = 'id', help = 'Spieler-ID' },
    { name = 'betrag', help = 'Betrag' },
    { name = 'konto', help = 'cash | bank | black (optional)' },
}, function(source, args)
    local target = resolveTarget(source, args[1])
    if not target then return end

    local amount = tonumber(args[2])
    local account = args[3] or 'cash'
    if not amount or amount <= 0 or not Config.Accounts[account] then
        reply(source, 'Verwendung: /givemoney [id] [betrag] [konto]', 'error')
        return
    end

    target:AddMoney(amount, account, 'admin:givemoney')
    target:Notify(('Du hast %s erhalten.'):format(MS.Utils.FormatMoney(amount)), 'success')
    reply(source, ('%s hat %s (%s) erhalten.'):format(target.fullname, MS.Utils.FormatMoney(amount), account), 'success')
end)

registerCommand('setmoney', 'Setzt den Kontostand eines Spielers', {
    { name = 'id', help = 'Spieler-ID' },
    { name = 'betrag', help = 'Neuer Betrag' },
    { name = 'konto', help = 'cash | bank | black (optional)' },
}, function(source, args)
    local target = resolveTarget(source, args[1])
    if not target then return end

    local amount = tonumber(args[2])
    local account = args[3] or 'cash'
    if not amount or not Config.Accounts[account] then
        reply(source, 'Verwendung: /setmoney [id] [betrag] [konto]', 'error')
        return
    end

    target:SetMoney(amount, account, 'admin:setmoney')
    reply(source, ('%s hat jetzt %s auf %s.'):format(target.fullname, MS.Utils.FormatMoney(amount), account), 'success')
end)

-- Items ----------------------------------------------------------------------

registerCommand('giveitem', 'Gibt einem Spieler ein Item', {
    { name = 'id', help = 'Spieler-ID' },
    { name = 'item', help = 'Item-Name' },
    { name = 'menge', help = 'Menge (optional)' },
}, function(source, args)
    local target = resolveTarget(source, args[1])
    if not target then return end

    local itemName = args[2]
    local count = tonumber(args[3]) or 1
    if not itemName or not MS.GetItem(itemName) then
        reply(source, 'Unbekanntes Item.', 'error')
        return
    end

    if target:AddItem(itemName, count) then
        reply(source, ('%dx %s an %s gegeben.'):format(count, MS.GetItem(itemName).label, target.fullname), 'success')
    else
        reply(source, 'Der Spieler kann das Item nicht tragen.', 'error')
    end
end)

-- Jobs -----------------------------------------------------------------------

registerCommand('setjob', 'Setzt den Job eines Spielers', {
    { name = 'id', help = 'Spieler-ID' },
    { name = 'job', help = 'Job-Name' },
    { name = 'rang', help = 'Rang (optional, Standard 0)' },
}, function(source, args)
    local target = resolveTarget(source, args[1])
    if not target then return end

    local jobName = args[2]
    local grade = tonumber(args[3]) or 0

    if not jobName or not MS.GetJob(jobName) then
        reply(source, 'Unbekannter Job.', 'error')
        return
    end

    target:SetJob(jobName, grade)
    target:Notify(('Du bist jetzt %s (%s).'):format(target.job.label, target.job.gradeLabel), 'info')
    reply(source, ('%s ist jetzt %s (%s).'):format(target.fullname, target.job.label, target.job.gradeLabel), 'success')
end)

-- Status ---------------------------------------------------------------------

registerCommand('setstatus', 'Setzt Hunger oder Durst eines Spielers', {
    { name = 'id', help = 'Spieler-ID' },
    { name = 'status', help = 'hunger | thirst' },
    { name = 'wert', help = '0-100' },
}, function(source, args)
    local target = resolveTarget(source, args[1])
    if not target then return end

    local status = args[2]
    local value = tonumber(args[3])
    if (status ~= 'hunger' and status ~= 'thirst') or not value then
        reply(source, 'Verwendung: /setstatus [id] [hunger|thirst] [0-100]', 'error')
        return
    end

    target:SetStatus(status, value)
    reply(source, ('%s: %s auf %.1f gesetzt.'):format(target.fullname, status, value), 'success')
end)

-- Spielerverwaltung ----------------------------------------------------------

--- Ziel eines Commands: angegebene ID oder der Aufrufer selbst.
local function resolveTargetOrSelf(source, value)
    if value then return resolveTarget(source, value) end

    local player = MS.Players[source]
    if not player then
        reply(source, 'Gib eine Spieler-ID an.', 'error')
    end
    return player
end

registerCommand('revive', 'Belebt einen Spieler wieder', {
    { name = 'id', help = 'Spieler-ID (optional, Standard: du selbst)' },
}, function(source, args)
    local target = resolveTargetOrSelf(source, args[1])
    if not target then return end

    TriggerClientEvent('moonshine:client:revive', target.source)
    target:Notify('Du wurdest wiederbelebt.', 'success')

    -- Sterbesysteme koennen hier ihren Zustand aufraeumen.
    TriggerEvent('moonshine:server:adminRevive', target.source)
end)

registerCommand('heal', 'Heilt einen Spieler vollstaendig', {
    { name = 'id', help = 'Spieler-ID (optional)' },
}, function(source, args)
    local target = resolveTargetOrSelf(source, args[1])
    if not target then return end

    TriggerClientEvent('moonshine:client:heal', target.source, 200)
    target:SetStatus('hunger', 100.0)
    target:SetStatus('thirst', 100.0)
end)

registerCommand('goto', 'Teleportiert dich zu einem Spieler', {
    { name = 'id', help = 'Spieler-ID' },
}, function(source, args)
    local player = MS.Players[source]
    local target = resolveTarget(source, args[1])
    if not player or not target then return end

    local coords = GetEntityCoords(GetPlayerPed(target.source))
    TriggerClientEvent('moonshine:client:teleport', player.source, coords.x, coords.y, coords.z)
end)

registerCommand('bring', 'Teleportiert einen Spieler zu dir', {
    { name = 'id', help = 'Spieler-ID' },
}, function(source, args)
    local player = MS.Players[source]
    local target = resolveTarget(source, args[1])
    if not player or not target then return end

    local coords = GetEntityCoords(GetPlayerPed(player.source))
    TriggerClientEvent('moonshine:client:teleport', target.source, coords.x, coords.y, coords.z)
end)

registerCommand('tp', 'Teleportiert dich zu Koordinaten', {
    { name = 'x', help = 'X' }, { name = 'y', help = 'Y' }, { name = 'z', help = 'Z' },
}, function(source, args)
    if source == 0 then
        reply(source, '/tp ist nur im Spiel verfuegbar.', 'error')
        return
    end

    local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    if not x or not y or not z then
        reply(source, 'Verwendung: /tp [x] [y] [z]', 'error')
        return
    end
    TriggerClientEvent('moonshine:client:teleport', source, x, y, z)
end)

registerCommand('kick', 'Kickt einen Spieler', {
    { name = 'id', help = 'Spieler-ID' },
    { name = 'grund', help = 'Grund' },
}, function(source, args)
    local target = resolveTarget(source, args[1])
    if not target then return end

    local reason = table.concat(args, ' ', 2)
    if reason == '' then reason = 'Kein Grund angegeben' end

    MS.Logger.Log('admin', ('%s wurde gekickt: %s'):format(target.fullname, reason), target.license)
    target:Kick(('Du wurdest gekickt.\nGrund: %s'):format(reason))
end)

registerCommand('ban', 'Bannt einen Spieler', {
    { name = 'id', help = 'Spieler-ID' },
    { name = 'stunden', help = 'Dauer in Stunden (0 = permanent)' },
    { name = 'grund', help = 'Grund' },
}, function(source, args)
    local target = resolveTarget(source, args[1])
    if not target then return end

    local hours = tonumber(args[2])
    if not hours then
        reply(source, 'Verwendung: /ban [id] [stunden] [grund]', 'error')
        return
    end

    local reason = table.concat(args, ' ', 3)
    if reason == '' then reason = 'Kein Grund angegeben' end

    -- Ueber alle Kennungen, nicht nur die Lizenz.
    local gesetzt = MS.Bans.Ban(target.source, reason, hours,
        source > 0 and (MS.GetPlayer(source) or {}).fullname or 'Konsole')

    if gesetzt == 0 then
        local expires = hours > 0 and (os.time() + math.floor(hours * 3600)) or 0
        MS.DB.SetBan(target.license, true, reason, expires)
    end

    MS.Logger.Log('admin', ('%s wurde gebannt (%s, %d Kennungen): %s'):format(
        target.fullname, hours > 0 and (hours .. 'h') or 'permanent',
        gesetzt, reason), target.license)

    target:Kick(('Du wurdest gebannt.\nGrund: %s'):format(reason))
end)

registerCommand('unban', 'Entbannt eine Lizenz', {
    { name = 'license', help = 'license:xxxxx' },
}, function(source, args)
    local license = args[1]
    if not license or not license:find('^license:') then
        reply(source, 'Verwendung: /unban license:xxxxxxxx', 'error')
        return
    end

    local betroffen = MS.Bans.Unban(license)
    reply(source, ('Bann fuer %s aufgehoben (%d Kennungen).'):format(
        license, betroffen), 'success')
end)

registerCommand('setadmin', 'Setzt das Adminlevel eines Spielers', {
    { name = 'id', help = 'Spieler-ID' },
    { name = 'level', help = '0-4' },
}, function(source, args)
    local target = resolveTarget(source, args[1])
    if not target then return end

    local level = tonumber(args[2])
    if not level or not Config.Permissions[level] then
        reply(source, 'Level muss zwischen 0 und 4 liegen.', 'error')
        return
    end

    MS.DB.SetAdminLevel(target.license, level)
    target.adminLevel = level
    if MS.Sessions[target.source] then
        MS.Sessions[target.source].user.admin_level = level
    end
    target:Sync()

    MS.Logger.Log('admin', ('%s ist jetzt %s (Level %d)'):format(target.fullname, Config.Permissions[level], level), target.license)
    reply(source, ('%s ist jetzt %s.'):format(target.fullname, Config.Permissions[level]), 'success')
end)

-- Ohne Rechtepruefung --------------------------------------------------------

RegisterCommand('id', function(source)
    if source == 0 then return end
    reply(source, ('Deine Server-ID: %d'):format(source), 'info')
end, false)

RegisterCommand('players', function(source)
    local players = MS.GetPlayers()
    if source == 0 then
        for _, player in ipairs(players) do
            MS.Utils.Print('info', '[%d] %s - %s', player.source, player.fullname, player.job.label)
        end
        MS.Utils.Print('info', '%d Spieler online.', #players)
        return
    end
    reply(source, ('%d Spieler online.'):format(#players), 'info')
end, false)

RegisterCommand('saveall', function(source)
    if not MS.HasPermission(source, 'setadmin') then return end
    local count = MS.SaveAllPlayers()
    reply(source, ('%d Charakter(e) gespeichert.'):format(count), 'success')
end, false)
