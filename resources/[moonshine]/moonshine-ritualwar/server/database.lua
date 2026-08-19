--- Wer haelt welchen Ritualpunkt.

RitualWar.DB = {}
RitualWar.DB.Ready = false

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `ms_ritual_claims` (
    `point_id`        VARCHAR(32) NOT NULL,
    `faction_id`      INT         DEFAULT NULL,
    `since`           INT         NOT NULL DEFAULT 0,
    `protected_until` INT         NOT NULL DEFAULT 0,
    `payouts`         INT         NOT NULL DEFAULT 0,
    `updated_at`      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`point_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

MySQL.ready(function()
    local ok, err = pcall(function() MySQL.query.await(SCHEMA) end)

    if not ok then
        print(('^1[Ritualkrieg]^7 Schema konnte nicht angelegt werden: %s'):format(
            tostring(err)))
        return
    end

    RitualWar.DB.Ready = true
    print('^2[Ritualkrieg]^7 Datenbank bereit.')
end)

function RitualWar.DB.LoadAll()
    return MySQL.query.await('SELECT * FROM ms_ritual_claims') or {}
end

function RitualWar.DB.Save(pointId, factionId, since, protectedUntil, payouts)
    return MySQL.insert.await([[
        INSERT INTO ms_ritual_claims (point_id, faction_id, since, protected_until, payouts)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            faction_id = VALUES(faction_id), since = VALUES(since),
            protected_until = VALUES(protected_until), payouts = VALUES(payouts)
    ]], { pointId, factionId, since, protectedUntil, payouts or 0 })
end

--- Gibt alle Punkte einer Fraktion frei (beim Aufloesen).
function RitualWar.DB.Release(factionId)
    return MySQL.update.await([[
        UPDATE ms_ritual_claims
        SET faction_id = NULL, since = 0, protected_until = 0
        WHERE faction_id = ?
    ]], { factionId })
end
