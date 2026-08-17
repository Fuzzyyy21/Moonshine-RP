--- Multicharacter: Auswahl, Erstellung, Loeschung.

--- Schickt die Charakterliste einer Session an den Client.
function MS.SendCharacterList(source)
    local session = MS.Sessions[source]
    if not session then return end

    local rows = MS.DB.LoadCharacters(session.license)
    local characters = {}

    for _, row in ipairs(rows) do
        local accounts = MS.Utils.DecodeJson(row.accounts, {})
        local job = MS.BuildJob(row.job, row.job_grade)

        characters[#characters + 1] = {
            id         = row.id,
            slot       = row.slot,
            firstname  = row.firstname,
            lastname   = row.lastname,
            dob        = row.dob,
            gender     = row.gender,
            job        = job.label,
            jobGrade   = job.gradeLabel,
            cash       = accounts.cash or 0,
            bank       = accounts.bank or 0,
            lastPlayed = row.last_played,
        }
    end

    TriggerClientEvent('moonshine:client:characterList', source, {
        characters    = characters,
        maxCharacters = Config.MaxCharacters,
        allowDeletion = Config.AllowDeletion,
        camera        = Config.SelectionCamera,
        serverName    = Config.ServerName,
    })
end

--- Laedt einen Charakter und bringt den Spieler ins Spiel.
local function loadCharacter(source, characterId)
    local session = MS.Sessions[source]
    if not session then return end

    if MS.Players[source] then
        MS.Utils.Print('warn', 'Spieler %d hat bereits einen geladenen Charakter.', source)
        return
    end

    local row = MS.DB.LoadCharacter(characterId, session.license)
    if not row then
        MS.Utils.Print('warn', 'Spieler %d wollte fremden Charakter %s laden.', source, tostring(characterId))
        TriggerClientEvent('moonshine:client:characterError', source, 'Dieser Charakter gehoert dir nicht.')
        return
    end

    local player = MS.CreatePlayer(source, session.user, row)

    TriggerClientEvent('moonshine:client:playerLoaded', source, player:GetData(), player.position)
    TriggerEvent('moonshine:server:playerLoaded', source, player)

    MS.Logger.Log('connect', ('%s hat den Server betreten (Slot %d)'):format(player.fullname, player.slot), player.license)
end

RegisterNetEvent('moonshine:server:selectCharacter', function(characterId)
    local source = source
    characterId = tonumber(characterId)
    if not characterId then return end

    loadCharacter(source, characterId)
end)

RegisterNetEvent('moonshine:server:createCharacter', function(data)
    local source = source
    local session = MS.Sessions[source]
    if not session or MS.Players[source] then return end
    if type(data) ~= 'table' then return end

    local firstname = MS.Utils.Trim(data.firstname or '')
    local lastname  = MS.Utils.Trim(data.lastname or '')
    local dob       = MS.Utils.Trim(data.dob or '')
    local gender    = (data.gender == 'w' or data.gender == 'f') and 'w' or 'm'

    if not MS.Utils.IsValidName(firstname) or not MS.Utils.IsValidName(lastname) then
        TriggerClientEvent('moonshine:client:characterError', source, 'Bitte gib einen gueltigen Vor- und Nachnamen an.')
        return
    end

    if not MS.Utils.IsValidDate(dob) then
        TriggerClientEvent('moonshine:client:characterError', source, 'Geburtsdatum muss im Format TT.MM.JJJJ vorliegen.')
        return
    end

    local slot = MS.DB.GetFreeSlot(session.license)
    if not slot then
        TriggerClientEvent('moonshine:client:characterError', source, 'Du hast bereits die maximale Anzahl an Charakteren.')
        return
    end

    local characterId = MS.DB.CreateCharacter(session.license, slot, {
        firstname = firstname,
        lastname  = lastname,
        dob       = dob,
        gender    = gender,
    })

    if not characterId then
        TriggerClientEvent('moonshine:client:characterError', source, 'Charakter konnte nicht angelegt werden.')
        return
    end

    MS.Logger.Log('character', ('Neuer Charakter erstellt: %s %s (ID %d)'):format(firstname, lastname, characterId), session.license)
    loadCharacter(source, characterId)
end)

RegisterNetEvent('moonshine:server:deleteCharacter', function(characterId)
    local source = source
    local session = MS.Sessions[source]
    if not session or not Config.AllowDeletion then return end

    characterId = tonumber(characterId)
    if not characterId then return end

    if MS.DB.DeleteCharacter(characterId, session.license) then
        MS.Logger.Log('character', ('Charakter %d geloescht'):format(characterId), session.license)
    end

    MS.SendCharacterList(source)
end)

--- Zurueck zur Charakterauswahl (z.B. per Command).
function MS.ReturnToSelection(source)
    local player = MS.Players[source]
    if player then
        player:Save()
        TriggerEvent('moonshine:server:playerUnloaded', source, player)
        MS.Players[source] = nil
    end

    TriggerClientEvent('moonshine:client:returnToSelection', source)
    MS.SendCharacterList(source)
end

RegisterCommand('charakter', function(source)
    if source == 0 then return end
    MS.ReturnToSelection(source)
end, false)
