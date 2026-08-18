--- Datenbankzugriff des Mystik-Systems.

Mystic.DB = {}
Mystic.DB.Ready = false

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `ms_mystic` (
    `character_id`    INT         NOT NULL,
    `race`            VARCHAR(32) DEFAULT NULL,
    `xp`              INT         NOT NULL DEFAULT 0,
    `xp_total`        INT         NOT NULL DEFAULT 0,
    `meditation`      INT         NOT NULL DEFAULT 0,
    `personal_points` INT         NOT NULL DEFAULT 0,
    `unlocked`        LONGTEXT    DEFAULT NULL,
    `skillbar`        LONGTEXT    DEFAULT NULL,
    `perks`           LONGTEXT    DEFAULT NULL,
    `seconds_played`  INT         NOT NULL DEFAULT 0,
    `awakened_at`     TIMESTAMP   NULL DEFAULT NULL,
    `updated_at`      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

--- Ergaenzt Spalten, die in aelteren Installationen fehlen.
local function migrate()
    local columns = MySQL.query.await([[
        SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ms_mystic'
    ]]) or {}

    local present = {}
    for _, row in ipairs(columns) do
        present[(row.COLUMN_NAME or row.column_name):lower()] = true
    end

    if not present.xp then
        MySQL.query.await('ALTER TABLE `ms_mystic` ADD COLUMN `xp` INT NOT NULL DEFAULT 0')
        print('^3[Mystic]^7 Spalte ms_mystic.xp ergaenzt.')
    end

    if not present.meditation then
        MySQL.query.await('ALTER TABLE `ms_mystic` ADD COLUMN `meditation` INT NOT NULL DEFAULT 0')
        print('^3[Mystic]^7 Spalte ms_mystic.meditation ergaenzt.')
    end

    if not present.xp_total then
        MySQL.query.await('ALTER TABLE `ms_mystic` ADD COLUMN `xp_total` INT NOT NULL DEFAULT 0')
        MySQL.query.await('UPDATE `ms_mystic` SET `xp_total` = `xp` WHERE `xp_total` = 0')
        print('^3[Mystic]^7 Spalte ms_mystic.xp_total ergaenzt.')
    end
end

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(SCHEMA)
        migrate()
    end)

    if not ok then
        print(('^1[Mystic]^7 Tabelle ms_mystic konnte nicht angelegt werden: %s'):format(tostring(err)))
        return
    end

    Mystic.DB.Ready = true
    print('^2[Mystic]^7 Datenbank bereit.')
end)

--- Laedt (oder erstellt) den Mystik-Datensatz eines Charakters.
function Mystic.DB.Load(characterId)
    local row = MySQL.single.await('SELECT * FROM ms_mystic WHERE character_id = ?', { characterId })

    if not row then
        local startXp = MysticConfig.Progression.startXp

        MySQL.insert.await([[
            INSERT INTO ms_mystic (character_id, xp, xp_total, unlocked, skillbar, perks)
            VALUES (?, ?, ?, '{}', '[]', '{}')
        ]], { characterId, startXp, startXp })

        row = {
            character_id   = characterId,
            race           = nil,
            xp             = startXp,
            xp_total       = startXp,
            unlocked       = '{}',
            skillbar       = '[]',
            perks          = '{}',
            seconds_played = 0,
        }
    end

    return row
end

--- Speichert den Datensatz eines Charakters.
function Mystic.DB.Save(characterId, payload)
    return MySQL.update.await([[
        UPDATE ms_mystic
        SET race = ?, xp = ?, xp_total = ?, meditation = ?, unlocked = ?,
            skillbar = ?, perks = ?, seconds_played = ?
        WHERE character_id = ?
    ]], {
        payload.race,
        payload.xp,
        payload.xpTotal,
        payload.meditationPoints,
        json.encode(payload.ranks),
        json.encode(payload.skillbar),
        json.encode(payload.perks),
        payload.secondsPlayed,
        characterId,
    })
end

--- Setzt die Rasse und vermerkt den Zeitpunkt der Erweckung.
function Mystic.DB.SetRace(characterId, race)
    return MySQL.update.await(
        'UPDATE ms_mystic SET race = ?, awakened_at = CURRENT_TIMESTAMP WHERE character_id = ?',
        { race, characterId }
    )
end
