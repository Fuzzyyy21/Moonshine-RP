MS.DB = {}

local SCHEMA = {
    [[
    CREATE TABLE IF NOT EXISTS `ms_users` (
        `license`     VARCHAR(64)  NOT NULL,
        `name`        VARCHAR(64)  DEFAULT NULL,
        `discord`     VARCHAR(64)  DEFAULT NULL,
        `admin_level` INT          NOT NULL DEFAULT 0,
        `playtime`    INT          NOT NULL DEFAULT 0,
        `banned`      TINYINT(1)   NOT NULL DEFAULT 0,
        `ban_reason`  VARCHAR(255) DEFAULT NULL,
        `ban_expires` INT          DEFAULT NULL,
        `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `last_seen`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],

    [[
    CREATE TABLE IF NOT EXISTS `ms_characters` (
        `id`         INT          NOT NULL AUTO_INCREMENT,
        `license`    VARCHAR(64)  NOT NULL,
        `slot`       INT          NOT NULL DEFAULT 1,
        `firstname`  VARCHAR(32)  NOT NULL,
        `lastname`   VARCHAR(32)  NOT NULL,
        `dob`        VARCHAR(16)  NOT NULL,
        `gender`     VARCHAR(8)   NOT NULL DEFAULT 'm',
        `job`        VARCHAR(32)  NOT NULL DEFAULT 'unemployed',
        `job_grade`  INT          NOT NULL DEFAULT 0,
        `accounts`   LONGTEXT     DEFAULT NULL,
        `inventory`  LONGTEXT     DEFAULT NULL,
        `position`   LONGTEXT     DEFAULT NULL,
        `appearance` LONGTEXT     DEFAULT NULL,
        `metadata`   LONGTEXT     DEFAULT NULL,
        `deleted`    TINYINT(1)   NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `last_played` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `license` (`license`),
        UNIQUE KEY `license_slot` (`license`, `slot`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],

    [[
    CREATE TABLE IF NOT EXISTS `ms_transactions` (
        `id`           INT         NOT NULL AUTO_INCREMENT,
        `character_id` INT         DEFAULT NULL,
        `account`      VARCHAR(16) NOT NULL,
        `amount`       INT         NOT NULL,
        `balance`      INT         NOT NULL,
        `reason`       VARCHAR(128) DEFAULT NULL,
        `created_at`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `character_id` (`character_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],

    [[
    CREATE TABLE IF NOT EXISTS `ms_logs` (
        `id`         INT          NOT NULL AUTO_INCREMENT,
        `category`   VARCHAR(32)  NOT NULL,
        `license`    VARCHAR(64)  DEFAULT NULL,
        `message`    TEXT         NOT NULL,
        `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `category` (`category`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],
}

MS.DB.Ready = false

--- Legt fehlende Tabellen an. Laeuft bei jedem Serverstart (CREATE IF NOT EXISTS).
local function ensureSchema()
    for _, statement in ipairs(SCHEMA) do
        MySQL.query.await(statement)
    end
    MS.DB.Ready = true
    MS.Utils.Print('info', 'Datenbankschema geprueft, %d Tabellen bereit.', #SCHEMA)
end

MySQL.ready(function()
    local ok, err = pcall(ensureSchema)
    if not ok then
        MS.Utils.Print('error', 'Schema konnte nicht angelegt werden: %s', tostring(err))
        return
    end
    TriggerEvent('moonshine:server:databaseReady')
end)

--- Laedt (oder erstellt) den Account-Datensatz einer Lizenz.
function MS.DB.LoadUser(license, name)
    local user = MySQL.single.await(
        'SELECT license, name, admin_level, playtime, banned, ban_reason, ban_expires FROM ms_users WHERE license = ?',
        { license }
    )

    if not user then
        MySQL.insert.await('INSERT INTO ms_users (license, name) VALUES (?, ?)', { license, name })
        user = {
            license = license, name = name, admin_level = 0,
            playtime = 0, banned = 0, ban_reason = nil, ban_expires = nil,
        }
        MS.Utils.Print('info', 'Neuer Account angelegt: %s (%s)', name, license)
    else
        MySQL.update.await('UPDATE ms_users SET name = ? WHERE license = ?', { name, license })
    end

    return user
end

--- Alle nicht geloeschten Charaktere einer Lizenz.
function MS.DB.LoadCharacters(license)
    return MySQL.query.await([[
        SELECT id, slot, firstname, lastname, dob, gender, job, job_grade, accounts, metadata, last_played
        FROM ms_characters
        WHERE license = ? AND deleted = 0
        ORDER BY slot ASC
    ]], { license }) or {}
end

--- Vollstaendiger Charakter-Datensatz.
function MS.DB.LoadCharacter(characterId, license)
    return MySQL.single.await([[
        SELECT * FROM ms_characters WHERE id = ? AND license = ? AND deleted = 0
    ]], { characterId, license })
end

--- Legt einen Charakter an und liefert dessen ID.
function MS.DB.CreateCharacter(license, slot, data)
    local accounts = {}
    for account, definition in pairs(Config.Accounts) do
        accounts[account] = definition.default
    end

    return MySQL.insert.await([[
        INSERT INTO ms_characters (license, slot, firstname, lastname, dob, gender, job, job_grade, accounts, inventory, position, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        license,
        slot,
        data.firstname,
        data.lastname,
        data.dob,
        data.gender,
        MS.DefaultJob,
        0,
        json.encode(accounts),
        json.encode({}),
        json.encode({
            x = Config.DefaultSpawn.x,
            y = Config.DefaultSpawn.y,
            z = Config.DefaultSpawn.z,
            heading = Config.DefaultSpawn.w,
        }),
        json.encode({ hunger = 100.0, thirst = 100.0, armor = 0 }),
    })
end

--- Markiert einen Charakter als geloescht (soft delete).
--- Der Slot wird auf -id gesetzt, damit er wieder frei wird ohne den
--- UNIQUE-Index (license, slot) zu verletzen.
function MS.DB.DeleteCharacter(characterId, license)
    local affected = MySQL.update.await(
        'UPDATE ms_characters SET deleted = 1, slot = -id WHERE id = ? AND license = ?',
        { characterId, license }
    )
    return (affected or 0) > 0
end

--- Persistiert einen Charakter.
function MS.DB.SaveCharacter(characterId, payload)
    return MySQL.update.await([[
        UPDATE ms_characters
        SET job = ?, job_grade = ?, accounts = ?, inventory = ?, position = ?, appearance = ?, metadata = ?
        WHERE id = ?
    ]], {
        payload.job,
        payload.jobGrade,
        json.encode(payload.accounts),
        json.encode(payload.inventory),
        json.encode(payload.position),
        json.encode(payload.appearance or {}),
        json.encode(payload.metadata),
        characterId,
    })
end

--- Erster freier Charakter-Slot einer Lizenz, oder nil wenn alle belegt sind.
function MS.DB.GetFreeSlot(license)
    local rows = MySQL.query.await(
        'SELECT slot FROM ms_characters WHERE license = ? AND deleted = 0', { license }
    ) or {}

    local used = {}
    for _, row in ipairs(rows) do used[row.slot] = true end

    for slot = 1, Config.MaxCharacters do
        if not used[slot] then return slot end
    end
    return nil
end

function MS.DB.SetAdminLevel(license, level)
    return MySQL.update.await('UPDATE ms_users SET admin_level = ? WHERE license = ?', { level, license })
end

function MS.DB.SetBan(license, banned, reason, expires)
    return MySQL.update.await(
        'UPDATE ms_users SET banned = ?, ban_reason = ?, ban_expires = ? WHERE license = ?',
        { banned and 1 or 0, reason, expires, license }
    )
end

function MS.DB.AddPlaytime(license, minutes)
    return MySQL.update.await('UPDATE ms_users SET playtime = playtime + ? WHERE license = ?', { minutes, license })
end
