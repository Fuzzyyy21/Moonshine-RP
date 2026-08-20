--- Wer wo wohnt und was dort liegt.

Refuge.DB = {}
Refuge.DB.Ready = false

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `ms_refuges` (
    `place_id`     VARCHAR(32) NOT NULL,
    `character_id` INT         NOT NULL,
    `name`         VARCHAR(48) DEFAULT NULL,
    `stufe`        INT         NOT NULL DEFAULT 0,
    `stash`        LONGTEXT    DEFAULT NULL,
    `last_rest`    INT         NOT NULL DEFAULT 0,
    `last_refuge`  INT         NOT NULL DEFAULT 0,
    `created_at`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`place_id`),
    KEY `character_id` (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

MySQL.ready(function()
    local ok, err = pcall(function() MySQL.query.await(SCHEMA) end)

    if not ok then
        print(('^1[Zuflucht]^7 Schema konnte nicht angelegt werden: %s'):format(
            tostring(err)))
        return
    end

    Refuge.DB.Ready = true
    print('^2[Zuflucht]^7 Datenbank bereit.')
end)

function Refuge.DB.LoadAll()
    return MySQL.query.await('SELECT * FROM ms_refuges') or {}
end

function Refuge.DB.Claim(placeId, characterId, name)
    return MySQL.insert.await([[
        INSERT INTO ms_refuges (place_id, character_id, name)
        VALUES (?, ?, ?)
    ]], { placeId, characterId, name })
end

function Refuge.DB.Release(placeId)
    return MySQL.update.await('DELETE FROM ms_refuges WHERE place_id = ?', { placeId })
end

function Refuge.DB.SaveStash(placeId, stash)
    return MySQL.update.await('UPDATE ms_refuges SET stash = ? WHERE place_id = ?',
        { json.encode(stash or {}), placeId })
end

function Refuge.DB.SetStufe(placeId, stufe)
    return MySQL.update.await('UPDATE ms_refuges SET stufe = ? WHERE place_id = ?',
        { stufe, placeId })
end

function Refuge.DB.SetName(placeId, name)
    return MySQL.update.await('UPDATE ms_refuges SET name = ? WHERE place_id = ?',
        { name, placeId })
end

function Refuge.DB.Touch(placeId, feld, zeit)
    -- Nur diese beiden Spalten duerfen so gesetzt werden.
    if feld ~= 'last_rest' and feld ~= 'last_refuge' then return end

    return MySQL.update.await(
        ('UPDATE ms_refuges SET %s = ? WHERE place_id = ?'):format(feld),
        { zeit, placeId })
end
