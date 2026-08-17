MS.Logger = {}

local COLORS = {
    money     = 3066993,
    item      = 15105570,
    admin     = 15158332,
    character = 3447003,
    connect   = 10181046,
}

--- Schreibt einen Log-Eintrag nach Konsole, Datenbank und optional Discord.
---@param category string z.B. 'money', 'item', 'admin'
---@param message string
---@param license string|nil
function MS.Logger.Log(category, message, license)
    if Config.Logs.console then
        MS.Utils.Print('info', '[%s] %s', category, message)
    end

    if Config.Logs.database and MS.DB.Ready then
        MySQL.insert('INSERT INTO ms_logs (category, license, message) VALUES (?, ?, ?)', {
            category, license, message,
        })
    end

    if Config.Logs.webhook and Config.Logs.webhook ~= '' then
        local payload = json.encode({
            username = 'Moonshine Logs',
            embeds = { {
                title = category:upper(),
                description = message,
                color = COLORS[category] or 9807270,
                footer = { text = license or 'system' },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            } },
        })

        PerformHttpRequest(Config.Logs.webhook, function(status)
            if status ~= 200 and status ~= 204 then
                MS.Utils.Print('warn', 'Discord Webhook antwortete mit Status %s', tostring(status))
            end
        end, 'POST', payload, { ['Content-Type'] = 'application/json' })
    end
end

--- Speichert eine Geldbewegung in ms_transactions.
function MS.Logger.Transaction(characterId, account, amount, balance, reason)
    if not MS.DB.Ready then return end

    MySQL.insert('INSERT INTO ms_transactions (character_id, account, amount, balance, reason) VALUES (?, ?, ?, ?, ?)', {
        characterId, account, amount, balance, reason or 'unbekannt',
    })
end
