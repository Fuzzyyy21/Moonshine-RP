--- Verbindungsaufbau, Sessions, Autosave.

MS.Sessions = {}  -- [source] = { license = string, user = table }

--- Liefert die Rockstar-Lizenz eines Spielers.
function MS.GetLicense(source)
    local license = GetPlayerIdentifierByType(source, 'license')
    if not license then return nil end
    return license
end

function MS.GetDiscordId(source)
    local discord = GetPlayerIdentifierByType(source, 'discord')
    return discord and discord:gsub('discord:', '') or nil
end

-- Verbindungsaufbau ----------------------------------------------------------

AddEventHandler('playerConnecting', function(playerName, _, deferrals)
    local source = source
    deferrals.defer()
    Wait(0)

    deferrals.update(('Willkommen bei %s, %s. Verbindung wird geprueft...'):format(Config.ServerName, playerName))

    local license = MS.GetLicense(source)
    if not license then
        deferrals.done('Deine Rockstar-Lizenz konnte nicht ermittelt werden. Starte FiveM neu.')
        return
    end

    if not MS.DB.Ready then
        deferrals.done('Der Server startet gerade noch. Bitte versuche es in einem Moment erneut.')
        return
    end

    local ok, user = pcall(MS.DB.LoadUser, license, playerName)
    if not ok or not user then
        MS.Utils.Print('error', 'Account von %s konnte nicht geladen werden: %s', playerName, tostring(user))
        deferrals.done('Dein Account konnte nicht geladen werden. Bitte melde dich beim Support.')
        return
    end

    if user.banned == 1 then
        local expires = user.ban_expires
        if expires and expires > 0 and expires < os.time() then
            MS.DB.SetBan(license, false, nil, nil)
        else
            local until_ = expires and expires > 0
                and os.date('%d.%m.%Y %H:%M', expires)
                or 'permanent'
            deferrals.done(('Du bist gebannt.\nGrund: %s\nBis: %s'):format(user.ban_reason or 'kein Grund', until_))
            return
        end
    end

    MS.Sessions[source] = { license = license, user = user, joinedAt = os.time() }
    deferrals.done()
end)

--- Der Client meldet sich, sobald er bereit fuer die Charakterauswahl ist.
RegisterNetEvent('moonshine:server:playerReady', function()
    local source = source
    local session = MS.Sessions[source]

    if not session then
        local license = MS.GetLicense(source)
        if not license then
            DropPlayer(source, 'Identifikation fehlgeschlagen.')
            return
        end
        session = {
            license = license,
            user = MS.DB.LoadUser(license, GetPlayerName(source)),
            joinedAt = os.time(),
        }
        MS.Sessions[source] = session
    end

    MS.SendCharacterList(source)
end)

-- Verbindungsabbau -----------------------------------------------------------

AddEventHandler('playerDropped', function(reason)
    local source = source
    local player = MS.Players[source]
    local session = MS.Sessions[source]

    if player then
        if Config.SaveOnDropped then player:Save() end
        TriggerEvent('moonshine:server:playerDropped', source, player, reason)
        MS.Logger.Log('connect', ('%s hat den Server verlassen (%s)'):format(player.fullname, reason), player.license)
        MS.Players[source] = nil
    end

    if session then
        local minutes = math.floor((os.time() - session.joinedAt) / 60)
        if minutes > 0 then MS.DB.AddPlaytime(session.license, minutes) end
        MS.Sessions[source] = nil
    end
end)

-- Autosave -------------------------------------------------------------------

--- Speichert alle geladenen Spieler.
---@return number Anzahl gespeicherter Charaktere
function MS.SaveAllPlayers()
    local count = 0
    for _, player in pairs(MS.Players) do
        if player:Save() then count = count + 1 end
    end
    return count
end

CreateThread(function()
    local interval = math.max(1, Config.SaveInterval) * 60000
    while true do
        Wait(interval)
        local count = MS.SaveAllPlayers()
        if count > 0 then
            MS.Utils.Print('info', 'Autosave: %d Charakter(e) gespeichert.', count)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= MS.Resource then return end
    local count = MS.SaveAllPlayers()
    MS.Utils.Print('info', 'Resource wird gestoppt, %d Charakter(e) gespeichert.', count)
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    MS.SaveAllPlayers()
end)

-- Positions-Update vom Client ------------------------------------------------

RegisterNetEvent('moonshine:server:updatePosition', function(x, y, z, heading)
    local player = MS.Players[source]
    if not player then return end
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then return end

    player:SetPosition(x, y, z, heading)
end)

RegisterNetEvent('moonshine:server:playerDied', function()
    local player = MS.Players[source]
    if not player then return end

    player:Save()
    if Config.Inventory.dropOnDeath then
        player:ClearInventory()
    end

    TriggerEvent('moonshine:server:playerDeath', source, player)
    MS.Logger.Log('character', ('%s ist gestorben.'):format(player.fullname), player.license)
end)

CreateThread(function()
    Wait(1000)
    MS.Utils.Print('info', 'Moonshine Framework v%s gestartet.', MS.Version)
end)
