--- Adminpanel: Spielerliste, Aktionen, Protokoll.

--- Level eines Spielers.
local function levelOf(source)
    if source == 0 then return 4 end

    local player = MS.GetPlayer(source)
    return player and (player.adminLevel or 0) or 0
end

--- Darf dieser Spieler die Aktion?
local function may(source, action)
    return Admin.Can(levelOf(source), action)
end

--- Kurzform eines Spielers fuer die Liste.
local function describe(player)
    local ped = GetPlayerPed(player.source)
    local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0, 0, 0)

    local race = nil
    pcall(function() race = exports['moonshine-mystic']:GetRace(player.source) end)

    local faction = nil
    pcall(function()
        local info = exports['moonshine-factions']:GetFaction(player.source)
        faction = info and ('%s [%s]'):format(info.name, info.tag) or nil
    end)

    return {
        source     = player.source,
        name       = ('%s %s'):format(player.firstname, player.lastname),
        charId     = player.charId,
        job        = player.job.label,
        jobGrade   = player.job.gradeLabel,
        adminLevel = player.adminLevel or 0,
        cash       = player:GetMoney('cash'),
        bank       = player:GetMoney('bank'),
        black      = player:GetMoney('black'),
        health     = ped ~= 0 and GetEntityHealth(ped) or 0,
        armour     = ped ~= 0 and GetPedArmour(ped) or 0,
        coords     = { x = coords.x, y = coords.y, z = coords.z },
        race       = race,
        faction    = faction,
        strikes    = Admin.GetStrikes(player.source),
        ping       = GetPlayerPing(player.source),
    }
end

--- Zustand des Panels.
function Admin.Payload(source)
    local level = levelOf(source)

    local players = {}
    for _, player in pairs(MS.GetPlayers()) do
        players[#players + 1] = describe(player)
    end

    table.sort(players, function(a, b) return a.source < b.source end)

    local permissions = {}
    for action in pairs(AdminConfig.Actions) do
        permissions[action] = Admin.Can(level, action)
    end

    -- Jobs und Items fuer die Auswahlfelder.
    local jobs = {}
    for name, job in pairs(MS.Jobs) do
        jobs[#jobs + 1] = { name = name, label = job.label }
    end
    table.sort(jobs, function(a, b) return a.label < b.label end)

    local items = {}
    for name, item in pairs(MS.Items) do
        items[#items + 1] = { name = name, label = item.label }
    end
    table.sort(items, function(a, b) return a.label < b.label end)

    return {
        level       = level,
        permissions = permissions,
        players     = players,
        jobs        = jobs,
        items       = items,
        accounts    = { 'cash', 'bank', 'black' },
        server      = {
            players = #players,
            uptime  = math.floor(GetGameTimer() / 60000),
            name    = GetConvar('sv_hostname', 'Moonshine RP'),
        },
    }
end

function Admin.Sync(source)
    if levelOf(source) < AdminConfig.PanelLevel then return end

    TriggerClientEvent('admin:client:data', source, Admin.Payload(source))
end

RegisterNetEvent('admin:server:open', function()
    local source = source
    if levelOf(source) < AdminConfig.PanelLevel then return end

    TriggerClientEvent('admin:client:open', source, Admin.Payload(source))
end)

RegisterNetEvent('admin:server:refresh', function()
    Admin.Sync(source)
end)

-- Aktionen ---------------------------------------------------------------------

--- Fuehrt eine Aktion aus.
---@return boolean ok, string message
--- @rennen Unbedenklich: das Warten (SetBan) und die Wertbewegung
--- (giveitem) liegen in zwei Zweigen derselben if/elseif-Kette. Es kann nie
--- beides im selben Aufruf laufen.
function Admin.Perform(source, action, targetId, value, extra)
    if not may(source, action) then return false, 'Dafuer fehlt dir das Recht.' end

    local admin = MS.GetPlayer(source)
    local target = MS.GetPlayer(tonumber(targetId) or -1)

    if not target then return false, 'Dieser Spieler ist nicht online.' end

    -- Niemand greift jemanden mit hoeherem Level an.
    if (target.adminLevel or 0) > levelOf(source) then
        return false, 'Dieser Spieler steht ueber dir.'
    end

    local adminName = admin and ('%s %s'):format(admin.firstname, admin.lastname)
        or 'Konsole'
    local targetName = ('%s %s'):format(target.firstname, target.lastname)

    local function log(text)
        MS.Logger.Log('admin', ('%s: %s'):format(adminName, text),
            admin and admin.license or nil)
    end

    if action == 'tpTo' then
        local coords = GetEntityCoords(GetPlayerPed(target.source))
        TriggerClientEvent('admin:client:teleport', source,
            { x = coords.x, y = coords.y, z = coords.z })
        TriggerEvent('admin:server:teleported', source)

        log(('teleportiert zu %s'):format(targetName))
        return true, ('Zu %s teleportiert.'):format(targetName)

    elseif action == 'tpHere' then
        local coords = GetEntityCoords(GetPlayerPed(source))
        TriggerClientEvent('admin:client:teleport', target.source,
            { x = coords.x, y = coords.y, z = coords.z })
        TriggerEvent('admin:server:teleported', target.source)

        target:Notify('Du wurdest teleportiert.', 'info')
        log(('holt %s her'):format(targetName))
        return true, ('%s hergeholt.'):format(targetName)

    elseif action == 'heal' then
        TriggerClientEvent('admin:client:heal', target.source)
        log(('heilt %s'):format(targetName))
        return true, ('%s geheilt.'):format(targetName)

    elseif action == 'revive' then
        local revived = false
        pcall(function()
            revived = exports['moonshine-death']:RevivePlayer(target.source, 200)
        end)

        if not revived then TriggerClientEvent('admin:client:heal', target.source) end

        log(('belebt %s wieder'):format(targetName))
        return true, ('%s wiederbelebt.'):format(targetName)

    elseif action == 'freeze' then
        TriggerClientEvent('admin:client:freeze', target.source, value == true)
        log(('%s %s'):format(value and 'friert' or 'taut', targetName))
        return true, value and ('%s eingefroren.'):format(targetName)
            or ('%s aufgetaut.'):format(targetName)

    elseif action == 'warn' then
        target:Notify(('Verwarnung: %s'):format(tostring(value or 'Bitte Regeln lesen.')),
            'error', 15000)
        log(('verwarnt %s: %s'):format(targetName, tostring(value)))
        return true, ('%s verwarnt.'):format(targetName)

    elseif action == 'kick' then
        log(('kickt %s: %s'):format(targetName, tostring(value)))
        DropPlayer(target.source, ('Gekickt: %s'):format(tostring(value or 'Kein Grund')))
        return true, ('%s gekickt.'):format(targetName)

    elseif action == 'ban' then
        local hours = math.max(0, math.floor(tonumber(extra) or 24))
        local expires = hours > 0 and (os.time() + hours * 3600) or nil

        MS.DB.SetBan(target.license, true, tostring(value or 'Kein Grund'), expires)

        log(('bannt %s fuer %s: %s'):format(targetName,
            hours > 0 and (hours .. ' Stunden') or 'immer', tostring(value)))

        DropPlayer(target.source, ('Gebannt: %s'):format(tostring(value or 'Kein Grund')))
        return true, ('%s gebannt.'):format(targetName)

    elseif action == 'setjob' then
        local grade = math.floor(tonumber(extra) or 0)
        if not MS.GetJob(value) then return false, 'Unbekannter Job.' end

        target:SetJob(value, grade)
        target:Notify(('Dein Job wurde geaendert: %s'):format(
            (MS.GetJob(value) or {}).label or value), 'info', 8000)

        log(('setzt Job von %s auf %s (%d)'):format(targetName, tostring(value), grade))
        return true, ('Job von %s gesetzt.'):format(targetName)

    elseif action == 'givemoney' then
        local amount = math.floor(tonumber(value) or 0)
        local account = tostring(extra or 'cash')

        if amount == 0 then return false, 'Betrag fehlt.' end

        if amount > 0 then
            target:AddMoney(amount, account, 'admin')
        else
            target:RemoveMoney(-amount, account, 'admin')
        end

        log(('gibt %s %s auf %s'):format(targetName,
            MS.Utils.FormatMoney(amount), account))
        return true, ('%s angepasst.'):format(targetName)

    elseif action == 'setmoney' then
        local amount = math.floor(tonumber(value) or 0)
        local account = tostring(extra or 'cash')

        target:SetMoney(amount, account, 'admin')
        log(('setzt %s von %s auf %s'):format(account, targetName,
            MS.Utils.FormatMoney(amount)))
        return true, ('Konto von %s gesetzt.'):format(targetName)

    elseif action == 'giveitem' then
        local count = math.max(1, math.floor(tonumber(extra) or 1))
        if not MS.GetItem(value) then return false, 'Unbekanntes Item.' end

        if not target:AddItem(value, count) then
            return false, 'Das passt nicht ins Inventar.'
        end

        log(('gibt %s %dx %s'):format(targetName, count, tostring(value)))
        return true, ('%dx an %s gegeben.'):format(count, targetName)

    elseif action == 'setadmin' then
        local level = math.max(0, math.min(4, math.floor(tonumber(value) or 0)))

        if level >= levelOf(source) and source ~= 0 then
            return false, 'So hoch darfst du nicht setzen.'
        end

        target.adminLevel = level
        MS.DB.SetAdminLevel(target.license, level)
        target:Sync()

        log(('setzt Adminlevel von %s auf %d'):format(targetName, level))
        return true, ('Adminlevel von %s auf %d.'):format(targetName, level)

    elseif action == 'setrace' then
        local ok = false
        pcall(function()
            ok = exports['moonshine-mystic']:SetRace(target.source, value)
        end)

        if not ok then return false, 'Klasse konnte nicht gesetzt werden.' end

        log(('setzt Klasse von %s auf %s'):format(targetName, tostring(value)))
        return true, ('Klasse von %s gesetzt.'):format(targetName)

    elseif action == 'spectate' then
        local coords = GetEntityCoords(GetPlayerPed(target.source))

        TriggerClientEvent('admin:client:spectate', source, target.source,
            { x = coords.x, y = coords.y, z = coords.z }, targetName)

        return true, ''
    end

    return false, 'Unbekannte Aktion.'
end

RegisterNetEvent('admin:server:action', function(action, targetId, value, extra)
    local source = source
    if levelOf(source) < AdminConfig.PanelLevel then return end
    if type(action) ~= 'string' then return end

    if not Admin.RateLimit(source, 'admin:action', 30, 10) then return end

    local ok, message = Admin.Perform(source, action, targetId, value, extra)

    if message and message ~= '' then
        exports['moonshine-core']:Notify(source, message,
            ok and 'success' or 'error', 8000)
    end

    Admin.Sync(source)
end)

--- Protokoll fuer das Panel.
MS.RegisterServerCallback('admin:log', function(player, cb, kind)
    if not player or (player.adminLevel or 0) < AdminConfig.PanelLevel then
        return cb({})
    end

    local rows

    if kind and kind ~= 'alle' then
        rows = MySQL.query.await([[
            SELECT category AS kind, message, license, created_at FROM ms_logs
            WHERE category = ? ORDER BY id DESC LIMIT ?
        ]], { kind, AdminConfig.LogLimit })
    else
        rows = MySQL.query.await([[
            SELECT category AS kind, message, license, created_at FROM ms_logs
            ORDER BY id DESC LIMIT ?
        ]], { AdminConfig.LogLimit })
    end

    cb(rows or {})
end)

--- Bann aufheben.
RegisterNetEvent('admin:server:unban', function(license)
    local source = source
    if not may(source, 'unban') then return end

    if type(license) ~= 'string' or license == '' then return end

    MS.DB.SetBan(license, false, nil, nil)

    exports['moonshine-core']:Notify(source, 'Bann aufgehoben.', 'success')

    local admin = MS.GetPlayer(source)
    MS.Logger.Log('admin', ('%s hebt den Bann von %s auf.'):format(
        admin and admin.fullname or 'Konsole', license),
        admin and admin.license or nil)
end)
