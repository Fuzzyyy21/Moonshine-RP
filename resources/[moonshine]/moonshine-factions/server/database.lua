--- Datenbank der Fraktionen.

Factions.DB = {}
Factions.DB.Ready = false

local SCHEMA = {
    [[
    CREATE TABLE IF NOT EXISTS `ms_factions` (
        `id`          INT          NOT NULL AUTO_INCREMENT,
        `name`        VARCHAR(32)  NOT NULL,
        `tag`         VARCHAR(8)   NOT NULL,
        `owner_id`    INT          NOT NULL,
        `base`        VARCHAR(32)  DEFAULT NULL,
        `emblem`      LONGTEXT     DEFAULT NULL,
        `ranks`       LONGTEXT     DEFAULT NULL,
        `skills`      LONGTEXT     DEFAULT NULL,
        `level`       INT          NOT NULL DEFAULT 1,
        `xp`          INT          NOT NULL DEFAULT 0,
        `points`      INT          NOT NULL DEFAULT 1,
        `kasse`       BIGINT       NOT NULL DEFAULT 0,
        `vault`       LONGTEXT     DEFAULT NULL,
        `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `name` (`name`),
        UNIQUE KEY `tag` (`tag`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],

    [[
    CREATE TABLE IF NOT EXISTS `ms_faction_members` (
        `faction_id`   INT       NOT NULL,
        `character_id` INT       NOT NULL,
        `grade`        INT       NOT NULL DEFAULT 0,
        `joined_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `contribution` BIGINT    NOT NULL DEFAULT 0,
        PRIMARY KEY (`character_id`),
        KEY `faction_id` (`faction_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],

    [[
    CREATE TABLE IF NOT EXISTS `ms_faction_vehicles` (
        `id`         INT         NOT NULL AUTO_INCREMENT,
        `faction_id` INT         NOT NULL,
        `model`      VARCHAR(32) NOT NULL,
        `label`      VARCHAR(48) NOT NULL,
        `plate`      VARCHAR(12) NOT NULL,
        `min_grade`  INT         NOT NULL DEFAULT 0,
        `stored`     TINYINT(1)  NOT NULL DEFAULT 1,
        PRIMARY KEY (`id`),
        KEY `faction_id` (`faction_id`),
        UNIQUE KEY `plate` (`plate`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],

    [[
    CREATE TABLE IF NOT EXISTS `ms_faction_territories` (
        `territory_id` VARCHAR(32) NOT NULL,
        `faction_id`   INT         DEFAULT NULL,
        `since`        INT         NOT NULL DEFAULT 0,
        `protected_until` INT      NOT NULL DEFAULT 0,
        PRIMARY KEY (`territory_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],

    [[
    CREATE TABLE IF NOT EXISTS `ms_faction_missions` (
        `id`         INT         NOT NULL AUTO_INCREMENT,
        `faction_id` INT         NOT NULL,
        `mission_id` VARCHAR(48) NOT NULL,
        `progress`   INT         NOT NULL DEFAULT 0,
        `claimed`    TINYINT(1)  NOT NULL DEFAULT 0,
        `period`     VARCHAR(16) NOT NULL,
        PRIMARY KEY (`id`),
        KEY `faction_id` (`faction_id`),
        UNIQUE KEY `mission_period` (`faction_id`, `mission_id`, `period`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],

    [[
    CREATE TABLE IF NOT EXISTS `ms_faction_log` (
        `id`         INT         NOT NULL AUTO_INCREMENT,
        `faction_id` INT         NOT NULL,
        `kind`       VARCHAR(24) NOT NULL,
        `text`       VARCHAR(255) NOT NULL,
        `created_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `faction_id` (`faction_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],
}

MySQL.ready(function()
    local ok, err = pcall(function()
        for _, statement in ipairs(SCHEMA) do MySQL.query.await(statement) end
    end)

    if not ok then
        print(('^1[Fraktionen]^7 Schema konnte nicht angelegt werden: %s'):format(tostring(err)))
        return
    end

    Factions.DB.Ready = true
    print('^2[Fraktionen]^7 Datenbank bereit.')
end)

-- Fraktionen ------------------------------------------------------------------

function Factions.DB.LoadAll()
    return MySQL.query.await('SELECT * FROM ms_factions') or {}
end

function Factions.DB.LoadMembers(factionId)
    return MySQL.query.await([[
        SELECT m.character_id, m.grade, m.contribution, m.joined_at,
               c.firstname, c.lastname
        FROM ms_faction_members m
        LEFT JOIN ms_characters c ON c.id = m.character_id
        WHERE m.faction_id = ?
    ]], { factionId }) or {}
end

function Factions.DB.Create(name, tag, ownerId, base, emblem, ranks)
    return MySQL.insert.await([[
        INSERT INTO ms_factions (name, tag, owner_id, base, emblem, ranks, skills, vault)
        VALUES (?, ?, ?, ?, ?, ?, '{}', '[]')
    ]], { name, tag, ownerId, base, json.encode(emblem), json.encode(ranks) })
end

function Factions.DB.Save(factionId, payload)
    return MySQL.update.await([[
        UPDATE ms_factions
        SET name = ?, tag = ?, owner_id = ?, base = ?, emblem = ?, ranks = ?,
            skills = ?, level = ?, xp = ?, points = ?, kasse = ?, vault = ?
        WHERE id = ?
    ]], {
        payload.name, payload.tag, payload.ownerId, payload.base,
        json.encode(payload.emblem), json.encode(payload.ranks),
        json.encode(payload.skills), payload.level, payload.xp, payload.points,
        payload.kasse, json.encode(payload.vault), factionId,
    })
end

function Factions.DB.Delete(factionId)
    MySQL.update.await('DELETE FROM ms_faction_members WHERE faction_id = ?', { factionId })
    MySQL.update.await('DELETE FROM ms_faction_vehicles WHERE faction_id = ?', { factionId })
    MySQL.update.await('DELETE FROM ms_faction_missions WHERE faction_id = ?', { factionId })
    MySQL.update.await('DELETE FROM ms_faction_log WHERE faction_id = ?', { factionId })
    MySQL.update.await('UPDATE ms_faction_territories SET faction_id = NULL WHERE faction_id = ?',
        { factionId })

    return MySQL.update.await('DELETE FROM ms_factions WHERE id = ?', { factionId })
end

-- Mitglieder -------------------------------------------------------------------

function Factions.DB.AddMember(factionId, characterId, grade)
    return MySQL.insert.await([[
        INSERT INTO ms_faction_members (faction_id, character_id, grade)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE faction_id = VALUES(faction_id), grade = VALUES(grade)
    ]], { factionId, characterId, grade or 0 })
end

function Factions.DB.RemoveMember(characterId)
    return MySQL.update.await('DELETE FROM ms_faction_members WHERE character_id = ?',
        { characterId })
end

function Factions.DB.SetGrade(characterId, grade)
    return MySQL.update.await('UPDATE ms_faction_members SET grade = ? WHERE character_id = ?',
        { grade, characterId })
end

function Factions.DB.AddContribution(characterId, amount)
    return MySQL.update.await([[
        UPDATE ms_faction_members SET contribution = contribution + ? WHERE character_id = ?
    ]], { amount, characterId })
end

function Factions.DB.FindMembership(characterId)
    return MySQL.single.await([[
        SELECT faction_id, grade FROM ms_faction_members WHERE character_id = ?
    ]], { characterId })
end

--- Charakter anhand des Namens suchen (fuer Einladungen offline).
function Factions.DB.FindCharacter(firstname, lastname)
    return MySQL.single.await([[
        SELECT id, firstname, lastname FROM ms_characters
        WHERE firstname = ? AND lastname = ? AND deleted = 0
        LIMIT 1
    ]], { firstname, lastname })
end

-- Fahrzeuge ---------------------------------------------------------------------

function Factions.DB.LoadVehicles(factionId)
    return MySQL.query.await('SELECT * FROM ms_faction_vehicles WHERE faction_id = ?',
        { factionId }) or {}
end

function Factions.DB.AddVehicle(factionId, model, label, plate, minGrade)
    return MySQL.insert.await([[
        INSERT INTO ms_faction_vehicles (faction_id, model, label, plate, min_grade)
        VALUES (?, ?, ?, ?, ?)
    ]], { factionId, model, label, plate, minGrade or 0 })
end

function Factions.DB.SetVehicleStored(vehicleId, stored)
    return MySQL.update.await('UPDATE ms_faction_vehicles SET stored = ? WHERE id = ?',
        { stored and 1 or 0, vehicleId })
end

function Factions.DB.SetVehicleGrade(vehicleId, minGrade)
    return MySQL.update.await('UPDATE ms_faction_vehicles SET min_grade = ? WHERE id = ?',
        { minGrade, vehicleId })
end

function Factions.DB.SellVehicle(vehicleId)
    return MySQL.update.await('DELETE FROM ms_faction_vehicles WHERE id = ?', { vehicleId })
end

-- Gebiete ------------------------------------------------------------------------

function Factions.DB.LoadTerritories()
    return MySQL.query.await('SELECT * FROM ms_faction_territories') or {}
end

function Factions.DB.SaveTerritory(territoryId, factionId, since, protectedUntil)
    return MySQL.insert.await([[
        INSERT INTO ms_faction_territories (territory_id, faction_id, since, protected_until)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE faction_id = VALUES(faction_id), since = VALUES(since),
            protected_until = VALUES(protected_until)
    ]], { territoryId, factionId, since, protectedUntil })
end

-- Missionen ------------------------------------------------------------------------

function Factions.DB.LoadMissions(factionId, period)
    return MySQL.query.await([[
        SELECT mission_id, progress, claimed, period
        FROM ms_faction_missions WHERE faction_id = ? AND period = ?
    ]], { factionId, period }) or {}
end

function Factions.DB.InsertMission(factionId, missionId, period)
    return MySQL.insert.await([[
        INSERT IGNORE INTO ms_faction_missions (faction_id, mission_id, period)
        VALUES (?, ?, ?)
    ]], { factionId, missionId, period })
end

function Factions.DB.SaveMission(factionId, missionId, period, progress, claimed)
    return MySQL.update.await([[
        UPDATE ms_faction_missions SET progress = ?, claimed = ?
        WHERE faction_id = ? AND mission_id = ? AND period = ?
    ]], { progress, claimed and 1 or 0, factionId, missionId, period })
end

function Factions.DB.CleanupMissions(period)
    return MySQL.update.await('DELETE FROM ms_faction_missions WHERE period <> ?', { period })
end

-- Protokoll -------------------------------------------------------------------------

function Factions.DB.Log(factionId, kind, text)
    return MySQL.insert.await([[
        INSERT INTO ms_faction_log (faction_id, kind, text) VALUES (?, ?, ?)
    ]], { factionId, kind, text:sub(1, 255) })
end

function Factions.DB.LoadLog(factionId, limit)
    return MySQL.query.await([[
        SELECT kind, text, created_at FROM ms_faction_log
        WHERE faction_id = ? ORDER BY id DESC LIMIT ?
    ]], { factionId, limit or 40 }) or {}
end
