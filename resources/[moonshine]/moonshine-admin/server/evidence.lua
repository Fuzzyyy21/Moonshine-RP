--- Schicht 4: die Beweiskette.
---
--- Eine einzelne Meldung im Chat sagt einem Admin wenig. Wichtig ist die
--- Vorgeschichte: derselbe Spieler, dieselbe Sache, dreimal in zehn
--- Minuten - oder eben einmal vor drei Wochen.

Admin.Evidence = {}
Admin.Evidence.Ready = false

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `ms_flags` (
    `id`         INT          NOT NULL AUTO_INCREMENT,
    `license`    VARCHAR(64)  NOT NULL,
    `name`       VARCHAR(64)  DEFAULT NULL,
    `reason`     VARCHAR(128) NOT NULL,
    `weight`     INT          NOT NULL DEFAULT 1,
    `strikes`    INT          NOT NULL DEFAULT 0,
    `details`    LONGTEXT     DEFAULT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `license` (`license`),
    KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

MySQL.ready(function()
    local ok, err = pcall(function() MySQL.query.await(SCHEMA) end)

    if not ok then
        print(('^1[Wachhund]^7 Beweistabelle fehlt: %s'):format(tostring(err)))
        return
    end

    Admin.Evidence.Ready = true
end)

--- Schreibt eine Meldung mit.
function Admin.Evidence.Add(player, reason, weight, strikes, details)
    if not AdminConfig.Guard.beweise.enabled or not Admin.Evidence.Ready then return end
    if not player then return end

    local kodiert = nil
    if type(details) == 'table' then
        local ok, text = pcall(json.encode, details)
        if ok then kodiert = text end
    end

    MySQL.insert('INSERT INTO ms_flags (license, name, reason, weight, strikes, details) '
        .. 'VALUES (?, ?, ?, ?, ?, ?)', {
        player.license,
        ('%s %s'):format(player.firstname or '', player.lastname or ''),
        tostring(reason):sub(1, 128),
        weight or 1,
        strikes or 0,
        kodiert,
    })
end

--- Die letzten Meldungen zu einer Lizenz.
function Admin.Evidence.History(license, limit)
    if not Admin.Evidence.Ready then return {} end

    return MySQL.query.await([[
        SELECT reason, weight, strikes, details, created_at
        FROM ms_flags WHERE license = ?
        ORDER BY id DESC LIMIT ?
    ]], { license, math.min(math.max(1, math.floor(tonumber(limit) or 20)), 100) }) or {}
end

--- Wie oft ein Spieler insgesamt auffiel.
function Admin.Evidence.Count(license)
    if not Admin.Evidence.Ready then return 0 end

    local row = MySQL.single.await(
        'SELECT COUNT(*) AS anzahl FROM ms_flags WHERE license = ?', { license })

    return row and tonumber(row.anzahl) or 0
end

--- Alte Zeilen aufraeumen. Ohne das waechst die Tabelle ewig.
CreateThread(function()
    while not Admin.Evidence.Ready do Wait(1000) end

    while true do
        local tage = math.max(1, AdminConfig.Guard.beweise.behalten)

        pcall(function()
            MySQL.update.await(
                'DELETE FROM ms_flags WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)',
                { tage })
        end)

        Wait(6 * 3600 * 1000)
    end
end)

-- Commands ----------------------------------------------------------------------------

RegisterCommand('verdacht', function(source, args)
    local player = source > 0 and MS.GetPlayer(source) or nil
    if source > 0 and (not player or (player.adminLevel or 0) < 2) then return end

    local target = MS.GetPlayer(tonumber(args[1]) or -1)

    if not target then
        local text = 'Verwendung: /verdacht [id]'
        if player then player:Notify(text, 'error') else print(text) end
        return
    end

    local zeilen = Admin.Evidence.History(target.license, 10)
    local gesamt = Admin.Evidence.Count(target.license)

    local kopf = ('%s: %d Meldungen insgesamt, %d Strikes gerade'):format(
        target.fullname, gesamt, Admin.GetStrikes(target.source))

    if player then
        player:Notify(kopf, 'info', 10000)

        for _, zeile in ipairs(zeilen) do
            player:Notify(('%s - %s (+%d)'):format(
                tostring(zeile.created_at):sub(1, 19), zeile.reason, zeile.weight),
                'warning', 9000)
        end

        if #zeilen == 0 then
            player:Notify('Nichts aufgefallen.', 'success', 6000)
        end
    else
        print(kopf)
        for _, zeile in ipairs(zeilen) do
            print(('  %s  %-40s +%d'):format(
                tostring(zeile.created_at):sub(1, 19), zeile.reason, zeile.weight))
        end
    end
end, false)

exports('GetFlagHistory', function(license, limit)
    return Admin.Evidence.History(license, limit)
end)
