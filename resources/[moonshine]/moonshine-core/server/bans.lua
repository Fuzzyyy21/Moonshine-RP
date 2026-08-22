--- Banne ueber alle Kennungen, nicht nur ueber die Rockstar-Lizenz.
---
--- Bisher hing ein Bann allein an `license`. Ein neuer Rockstar-Account -
--- oder ein Spoofer - und derselbe Mensch war wieder da. FiveM liefert beim
--- Verbinden mehrere Kennungen; wer gebannt wird, wird auf allen gebannt,
--- und wer mit einer davon wiederkommt, kommt nicht rein.
---
--- Das ersetzt kein HWID-Verfahren, wie es kommerzielle Anticheats
--- mitbringen. Es macht die Rueckkehr aber deutlich unbequemer: fuer einen
--- sauberen Neuanfang braucht es dann eine neue IP, ein neues Steam- und
--- ein neues Discord-Konto zugleich.

MS.Bans = {}

--- Welche Kennungen mitgenommen werden.
---
--- `ip` ist bewusst dabei, aber mit Vorsicht: hinter einer IP koennen
--- Mitbewohner sitzen. Deshalb laesst sie sich einzeln abschalten.
local ARTEN = { 'license', 'steam', 'discord', 'fivem', 'xbl', 'live', 'ip' }

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `ms_bans` (
    `id`         INT          NOT NULL AUTO_INCREMENT,
    `kind`       VARCHAR(16)  NOT NULL,
    `value`      VARCHAR(96)  NOT NULL,
    `license`    VARCHAR(64)  DEFAULT NULL,
    `name`       VARCHAR(64)  DEFAULT NULL,
    `reason`     VARCHAR(160) NOT NULL,
    `by`         VARCHAR(64)  DEFAULT NULL,
    `expires`    INT          NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `kind_value` (`kind`, `value`),
    KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

MySQL.ready(function()
    local ok, err = pcall(function() MySQL.query.await(SCHEMA) end)

    if not ok then
        MS.Utils.Print('error', 'Banntabelle fehlt: %s', tostring(err))
        return
    end

    MS.Bans.Ready = true
end)

--- Alle Kennungen eines Verbindenden, nach Art sortiert.
---@return table [art] = wert
function MS.Bans.Identifiers(source)
    local gefunden = {}

    for _, kennung in ipairs(GetPlayerIdentifiers(source) or {}) do
        local art, wert = kennung:match('^(%a+):(.+)$')

        if art and wert then
            for _, erlaubt in ipairs(ARTEN) do
                if art == erlaubt and not gefunden[art] then
                    gefunden[art] = wert
                end
            end
        end
    end

    -- Die IP steht nicht in den Identifiers, sondern am Endpunkt.
    if Config.Bans.useIp and not gefunden.ip then
        local endpunkt = GetPlayerEndpoint(source)
        if endpunkt then gefunden.ip = endpunkt:match('^([%d%.]+)') or endpunkt end
    end

    if not Config.Bans.useIp then gefunden.ip = nil end

    return gefunden
end

--- Sperrt alle Kennungen eines Spielers.
---@param source number
---@param reason string
---@param hours number|nil nil oder 0 = dauerhaft
---@param by string|nil wer den Bann gesetzt hat
---@return number wie viele Kennungen gesperrt wurden
---@param ohneIp boolean|nil IP auslassen
function MS.Bans.Ban(source, reason, hours, by, ohneIp)
    if not MS.Bans.Ready then return 0 end

    local kennungen = MS.Bans.Identifiers(source)

    -- Hinter einer IP steckt ein Anschluss, keine Person: Wohngemeinschaft,
    -- Studentenwohnheim, Mobilfunk mit wechselnder Adresse. Ein Admin darf
    -- das von Hand tun. Der Wachhund bannt nie ueber die IP.
    if ohneIp then kennungen.ip = nil end

    local player = MS.GetPlayer(source)
    local license = kennungen.license
    local expires = (hours and hours > 0) and (os.time() + hours * 3600) or 0

    local gesetzt = 0

    for art, wert in pairs(kennungen) do
        local ok = pcall(function()
            MySQL.insert.await([[
                INSERT INTO ms_bans (kind, value, license, name, reason, `by`, expires)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    reason = VALUES(reason), `by` = VALUES(`by`),
                    expires = VALUES(expires), created_at = CURRENT_TIMESTAMP
            ]], { art, wert, license,
                  player and player.fullname or GetPlayerName(source),
                  tostring(reason):sub(1, 160), by, expires })
        end)

        if ok then gesetzt = gesetzt + 1 end
    end

    -- Der alte Weg ueber ms_users bleibt bestehen: er traegt den Grund am
    -- Account und wird vom Adminpanel angezeigt.
    if license then
        pcall(function()
            MS.DB.SetBan(license, true, reason, expires > 0 and expires or nil)
        end)
    end

    MS.Utils.Print('warn', 'Bann fuer %s auf %d Kennungen: %s',
        GetPlayerName(source) or source, gesetzt, reason)

    return gesetzt
end

--- Prueft beim Verbinden alle Kennungen auf einmal.
---@return table|nil eintrag
function MS.Bans.Check(source)
    if not MS.Bans.Ready then return nil end

    local kennungen = MS.Bans.Identifiers(source)
    local werte, arten = {}, {}

    for art, wert in pairs(kennungen) do
        arten[#arten + 1] = art
        werte[#werte + 1] = wert
    end

    if #werte == 0 then return nil end

    local platzhalter = string.rep('?', #werte, ',')

    local rows = MySQL.query.await(
        ('SELECT * FROM ms_bans WHERE value IN (%s)'):format(platzhalter), werte) or {}

    local now = os.time()

    for _, row in ipairs(rows) do
        -- Nur ein Treffer, dessen Art auch passt: eine Steam-Id soll keinen
        -- Discord-Bann ausloesen, nur weil die Zeichenkette gleich waere.
        if kennungen[row.kind] == row.value then
            if row.expires == 0 or row.expires > now then
                return row
            end

            -- Abgelaufen: aufraeumen statt stehenlassen.
            pcall(function()
                MySQL.update.await('DELETE FROM ms_bans WHERE id = ?', { row.id })
            end)
        end
    end

    return nil
end

--- Hebt alle Banne zu einer Lizenz auf.
function MS.Bans.Unban(license)
    if not MS.Bans.Ready or not license then return 0 end

    local betroffen = MySQL.update.await(
        'DELETE FROM ms_bans WHERE license = ?', { license }) or 0

    pcall(function() MS.DB.SetBan(license, false, nil, nil) end)

    return betroffen
end

exports('BanPlayer', function(source, reason, hours, by)
    return MS.Bans.Ban(source, reason, hours, by)
end)

exports('UnbanLicense', function(license)
    return MS.Bans.Unban(license)
end)
