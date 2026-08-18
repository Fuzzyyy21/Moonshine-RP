--- Arbeitsstatistik je Charakter.

Work.DB = {}
Work.DB.Ready = false

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `ms_work` (
    `character_id` INT         NOT NULL,
    `job`          VARCHAR(24) NOT NULL,
    `shifts`       INT         NOT NULL DEFAULT 0,
    `stops`        INT         NOT NULL DEFAULT 0,
    `earned`       BIGINT      NOT NULL DEFAULT 0,
    `updated_at`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`character_id`, `job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

MySQL.ready(function()
    local ok, err = pcall(function() MySQL.query.await(SCHEMA) end)

    if not ok then
        print(('^1[Arbeit]^7 Schema konnte nicht angelegt werden: %s'):format(tostring(err)))
        return
    end

    Work.DB.Ready = true
    print('^2[Arbeit]^7 Datenbank bereit.')
end)

--- Statistik eines Charakters ueber alle Jobs.
function Work.DB.Load(characterId)
    return MySQL.query.await('SELECT * FROM ms_work WHERE character_id = ?',
        { characterId }) or {}
end

--- Schreibt eine abgeschlossene Station bzw. Schicht fort.
function Work.DB.Track(characterId, job, stops, earned, finished)
    return MySQL.insert.await([[
        INSERT INTO ms_work (character_id, job, shifts, stops, earned)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            shifts = shifts + VALUES(shifts),
            stops  = stops + VALUES(stops),
            earned = earned + VALUES(earned)
    ]], { characterId, job, finished and 1 or 0, stops or 0, earned or 0 })
end

--- Bestenliste eines Jobs.
function Work.DB.Leaderboard(job, limit)
    return MySQL.query.await([[
        SELECT w.earned, w.shifts, w.stops, c.firstname, c.lastname
        FROM ms_work w
        LEFT JOIN ms_characters c ON c.id = w.character_id
        WHERE w.job = ?
        ORDER BY w.earned DESC
        LIMIT ?
    ]], { job, limit or 10 }) or {}
end
