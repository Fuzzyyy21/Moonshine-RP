--- Datenbankzugriff des Mystik-Systems.

Mystic.DB = {}
Mystic.DB.Ready = false

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `ms_mystic` (
    `character_id`    INT         NOT NULL,
    `race`            VARCHAR(32) DEFAULT NULL,
    `skill_points`    INT         NOT NULL DEFAULT 0,
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

MySQL.ready(function()
    local ok, err = pcall(function() MySQL.query.await(SCHEMA) end)
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
        MySQL.insert.await([[
            INSERT INTO ms_mystic (character_id, skill_points, personal_points, unlocked, skillbar, perks)
            VALUES (?, ?, ?, '[]', '[]', '{}')
        ]], {
            characterId,
            MysticConfig.Points.startSkillPoints,
            MysticConfig.Points.startPersonalPoints,
        })

        row = {
            character_id    = characterId,
            race            = nil,
            skill_points    = MysticConfig.Points.startSkillPoints,
            personal_points = MysticConfig.Points.startPersonalPoints,
            unlocked        = '[]',
            skillbar        = '[]',
            perks           = '{}',
            seconds_played  = 0,
        }
    end

    return row
end

--- Speichert den Datensatz eines Charakters.
function Mystic.DB.Save(characterId, payload)
    return MySQL.update.await([[
        UPDATE ms_mystic
        SET race = ?, skill_points = ?, personal_points = ?, unlocked = ?,
            skillbar = ?, perks = ?, seconds_played = ?
        WHERE character_id = ?
    ]], {
        payload.race,
        payload.skillPoints,
        payload.personalPoints,
        json.encode(payload.unlocked),
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
