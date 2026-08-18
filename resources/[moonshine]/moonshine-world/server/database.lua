--- Die Welt merkt sich Uhrzeit, Tageszaehler und Wetter ueber Neustarts hinweg.

World.DB = {}
World.DB.Ready = false

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `ms_world` (
    `id`         INT         NOT NULL DEFAULT 1,
    `day`        INT         NOT NULL DEFAULT 0,
    `hour`       INT         NOT NULL DEFAULT 20,
    `minute`     INT         NOT NULL DEFAULT 0,
    `weather`    VARCHAR(24) NOT NULL DEFAULT 'CLEAR',
    `history`    LONGTEXT    DEFAULT NULL,
    `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

MySQL.ready(function()
    local ok, err = pcall(function() MySQL.query.await(SCHEMA) end)

    if not ok then
        print(('^1[Welt]^7 Schema konnte nicht angelegt werden: %s'):format(tostring(err)))
        return
    end

    World.DB.Ready = true
    print('^2[Welt]^7 Datenbank bereit.')
end)

--- Laedt den gespeicherten Zustand oder legt ihn an.
function World.DB.Load()
    local row = MySQL.single.await('SELECT * FROM ms_world WHERE id = 1')

    if not row then
        MySQL.insert.await([[
            INSERT INTO ms_world (id, day, hour, minute, weather, history)
            VALUES (1, 0, ?, ?, 'CLEAR', '[]')
        ]], { WorldConfig.Time.startHour, WorldConfig.Time.startMinute })

        return {
            day = 0,
            hour = WorldConfig.Time.startHour,
            minute = WorldConfig.Time.startMinute,
            weather = 'CLEAR',
            history = '[]',
        }
    end

    return row
end

function World.DB.Save(payload)
    return MySQL.update.await([[
        UPDATE ms_world SET day = ?, hour = ?, minute = ?, weather = ?, history = ?
        WHERE id = 1
    ]], {
        payload.day, payload.hour, payload.minute, payload.weather,
        json.encode(payload.history or {}),
    })
end
