--- Datenbank des Fortschrittssystems.

Progress.DB = {}
Progress.DB.Ready = false

local SCHEMA = {
    [[
    CREATE TABLE IF NOT EXISTS `ms_progress` (
        `character_id`      INT        NOT NULL,
        `playtime_day`      VARCHAR(10) DEFAULT NULL,
        `playtime_minutes`  INT        NOT NULL DEFAULT 0,
        `playtime_claimed`  LONGTEXT   DEFAULT NULL,
        `playtime_total`    INT        NOT NULL DEFAULT 0,
        `bp_season`         INT        NOT NULL DEFAULT 1,
        `bp_xp`             INT        NOT NULL DEFAULT 0,
        `bp_premium`        TINYINT(1) NOT NULL DEFAULT 0,
        `bp_claimed`        LONGTEXT   DEFAULT NULL,
        `cases`             LONGTEXT   DEFAULT NULL,
        `updated_at`        TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`character_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],

    [[
    CREATE TABLE IF NOT EXISTS `ms_missions` (
        `id`           INT         NOT NULL AUTO_INCREMENT,
        `character_id` INT         NOT NULL,
        `mission_id`   VARCHAR(64) NOT NULL,
        `kind`         VARCHAR(16) NOT NULL,
        `progress`     INT         NOT NULL DEFAULT 0,
        `claimed`      TINYINT(1)  NOT NULL DEFAULT 0,
        `period`       VARCHAR(16) NOT NULL,
        PRIMARY KEY (`id`),
        KEY `character_id` (`character_id`),
        UNIQUE KEY `mission_period` (`character_id`, `mission_id`, `period`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],
}

MySQL.ready(function()
    local ok, err = pcall(function()
        for _, statement in ipairs(SCHEMA) do MySQL.query.await(statement) end
    end)

    if not ok then
        print(('^1[Progress]^7 Schema konnte nicht angelegt werden: %s'):format(tostring(err)))
        return
    end

    Progress.DB.Ready = true
    print('^2[Progress]^7 Datenbank bereit.')
end)

--- Laedt (oder erstellt) den Fortschritt eines Charakters.
function Progress.DB.Load(characterId)
    local row = MySQL.single.await('SELECT * FROM ms_progress WHERE character_id = ?', { characterId })

    if not row then
        MySQL.insert.await([[
            INSERT INTO ms_progress (character_id, bp_season, playtime_claimed, bp_claimed, cases)
            VALUES (?, ?, '[]', '[]', '{}')
        ]], { characterId, ProgressConfig.BattlePass.season })

        row = {
            character_id     = characterId,
            playtime_day     = nil,
            playtime_minutes = 0,
            playtime_claimed = '[]',
            playtime_total   = 0,
            bp_season        = ProgressConfig.BattlePass.season,
            bp_xp            = 0,
            bp_premium       = 0,
            bp_claimed       = '[]',
            cases            = '{}',
        }
    end

    return row
end

function Progress.DB.Save(characterId, payload)
    return MySQL.update.await([[
        UPDATE ms_progress
        SET playtime_day = ?, playtime_minutes = ?, playtime_claimed = ?, playtime_total = ?,
            bp_season = ?, bp_xp = ?, bp_premium = ?, bp_claimed = ?, cases = ?
        WHERE character_id = ?
    ]], {
        payload.playtimeDay,
        payload.playtimeMinutes,
        json.encode(payload.playtimeClaimed),
        payload.playtimeTotal,
        payload.season,
        payload.bpXp,
        payload.premium and 1 or 0,
        json.encode(payload.bpClaimed),
        json.encode(payload.cases),
        characterId,
    })
end

--- Missionen eines Charakters fuer die laufenden Zeitraeume.
function Progress.DB.LoadMissions(characterId, dailyPeriod, weeklyPeriod)
    return MySQL.query.await([[
        SELECT mission_id, kind, progress, claimed, period
        FROM ms_missions
        WHERE character_id = ? AND period IN (?, ?)
    ]], { characterId, dailyPeriod, weeklyPeriod }) or {}
end

function Progress.DB.InsertMission(characterId, missionId, kind, period)
    return MySQL.insert.await([[
        INSERT IGNORE INTO ms_missions (character_id, mission_id, kind, period)
        VALUES (?, ?, ?, ?)
    ]], { characterId, missionId, kind, period })
end

function Progress.DB.SaveMission(characterId, missionId, period, progress, claimed)
    return MySQL.update.await([[
        UPDATE ms_missions SET progress = ?, claimed = ?
        WHERE character_id = ? AND mission_id = ? AND period = ?
    ]], { progress, claimed and 1 or 0, characterId, missionId, period })
end

--- Raeumt alte Missionszeitraeume auf.
function Progress.DB.CleanupMissions(dailyPeriod, weeklyPeriod)
    return MySQL.update.await('DELETE FROM ms_missions WHERE period NOT IN (?, ?)',
        { dailyPeriod, weeklyPeriod })
end
