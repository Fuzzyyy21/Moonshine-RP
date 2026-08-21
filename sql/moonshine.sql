-- Moonshine Framework - Datenbankschema
--
-- Die Tabellen werden beim Start von moonshine-core automatisch angelegt.
-- Diese Datei dient als Referenz bzw. fuer manuelle Imports.

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

CREATE TABLE IF NOT EXISTS `ms_characters` (
    `id`          INT         NOT NULL AUTO_INCREMENT,
    `license`     VARCHAR(64) NOT NULL,
    `slot`        INT         NOT NULL DEFAULT 1,
    `firstname`   VARCHAR(32) NOT NULL,
    `lastname`    VARCHAR(32) NOT NULL,
    `dob`         VARCHAR(16) NOT NULL,
    `gender`      VARCHAR(8)  NOT NULL DEFAULT 'm',
    `job`         VARCHAR(32) NOT NULL DEFAULT 'unemployed',
    `job_grade`   INT         NOT NULL DEFAULT 0,
    `accounts`    LONGTEXT    DEFAULT NULL,
    `inventory`   LONGTEXT    DEFAULT NULL,
    `position`    LONGTEXT    DEFAULT NULL,
    `appearance`  LONGTEXT    DEFAULT NULL,
    `metadata`    LONGTEXT    DEFAULT NULL,
    `deleted`     TINYINT(1)  NOT NULL DEFAULT 0,
    `created_at`  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_played` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `license` (`license`),
    UNIQUE KEY `license_slot` (`license`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ms_transactions` (
    `id`           INT          NOT NULL AUTO_INCREMENT,
    `character_id` INT          DEFAULT NULL,
    `account`      VARCHAR(16)  NOT NULL,
    `amount`       INT          NOT NULL,
    `balance`      INT          NOT NULL,
    `reason`       VARCHAR(128) DEFAULT NULL,
    `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `character_id` (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ms_logs` (
    `id`         INT         NOT NULL AUTO_INCREMENT,
    `category`   VARCHAR(32) NOT NULL,
    `license`    VARCHAR(64) DEFAULT NULL,
    `message`    TEXT        NOT NULL,
    `created_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Beispiel: sich selbst zum Owner machen (Lizenz anpassen!)
-- UPDATE `ms_users` SET `admin_level` = 4 WHERE `license` = 'license:deinelizenz';

-- ---------------------------------------------------------------------------
-- Mystik (moonshine-mystic)
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Fortschritt (moonshine-progress)
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Fraktionen (moonshine-factions)
-- ---------------------------------------------------------------------------

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

CREATE TABLE IF NOT EXISTS `ms_faction_members` (
    `faction_id`   INT       NOT NULL,
    `character_id` INT       NOT NULL,
    `grade`        INT       NOT NULL DEFAULT 0,
    `joined_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `contribution` BIGINT    NOT NULL DEFAULT 0,
    PRIMARY KEY (`character_id`),
    KEY `faction_id` (`faction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

CREATE TABLE IF NOT EXISTS `ms_faction_territories` (
    `territory_id` VARCHAR(32) NOT NULL,
    `faction_id`   INT         DEFAULT NULL,
    `since`        INT         NOT NULL DEFAULT 0,
    `protected_until` INT      NOT NULL DEFAULT 0,
    PRIMARY KEY (`territory_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

CREATE TABLE IF NOT EXISTS `ms_faction_log` (
    `id`         INT         NOT NULL AUTO_INCREMENT,
    `faction_id` INT         NOT NULL,
    `kind`       VARCHAR(24) NOT NULL,
    `text`       VARCHAR(255) NOT NULL,
    `created_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `faction_id` (`faction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ---------------------------------------------------------------------------
-- Auktionshaus (moonshine-auction)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `ms_auctions` (
    `id`           INT          NOT NULL AUTO_INCREMENT,
    `seller_id`    INT          NOT NULL,
    `seller_name`  VARCHAR(64)  NOT NULL,
    `item`         VARCHAR(48)  NOT NULL,
    `label`        VARCHAR(64)  NOT NULL,
    `count`        INT          NOT NULL DEFAULT 1,
    `metadata`     LONGTEXT     DEFAULT NULL,
    `category`     VARCHAR(24)  NOT NULL DEFAULT 'sonstiges',
    `start_price`  BIGINT       NOT NULL,
    `buyout`       BIGINT       DEFAULT NULL,
    `bid`          BIGINT       NOT NULL DEFAULT 0,
    `bidder_id`    INT          DEFAULT NULL,
    `bidder_name`  VARCHAR(64)  DEFAULT NULL,
    `ends_at`      INT          NOT NULL,
    `status`       VARCHAR(16)  NOT NULL DEFAULT 'offen',
    `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `status` (`status`),
    KEY `seller_id` (`seller_id`),
    KEY `bidder_id` (`bidder_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ms_auction_mail` (
    `id`           INT          NOT NULL AUTO_INCREMENT,
    `character_id` INT          NOT NULL,
    `kind`         VARCHAR(12)  NOT NULL,
    `item`         VARCHAR(48)  DEFAULT NULL,
    `label`        VARCHAR(64)  DEFAULT NULL,
    `count`        INT          NOT NULL DEFAULT 0,
    `metadata`     LONGTEXT     DEFAULT NULL,
    `amount`       BIGINT       NOT NULL DEFAULT 0,
    `reason`       VARCHAR(128) NOT NULL DEFAULT '',
    `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `character_id` (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ---------------------------------------------------------------------------
-- Welt (moonshine-world)
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Fahrzeuge (moonshine-vehicles)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `ms_vehicles` (
    `id`           INT          NOT NULL AUTO_INCREMENT,
    `owner_id`     INT          NOT NULL,
    `plate`        VARCHAR(12)  NOT NULL,
    `model`        VARCHAR(32)  NOT NULL,
    `label`        VARCHAR(48)  NOT NULL,
    `category`     VARCHAR(24)  NOT NULL DEFAULT 'kompakt',
    `price`        BIGINT       NOT NULL DEFAULT 0,
    `state`        VARCHAR(12)  NOT NULL DEFAULT 'garage',
    `garage`       VARCHAR(32)  DEFAULT NULL,
    `fuel`         FLOAT        NOT NULL DEFAULT 100,
    `engine`       FLOAT        NOT NULL DEFAULT 1000,
    `body`         FLOAT        NOT NULL DEFAULT 1000,
    `mods`         LONGTEXT     DEFAULT NULL,
    `keys`         LONGTEXT     DEFAULT NULL,
    `position`     LONGTEXT     DEFAULT NULL,
    `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `plate` (`plate`),
    KEY `owner_id` (`owner_id`),
    KEY `state` (`state`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- Arbeit (moonshine-jobs)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `ms_work` (
    `character_id` INT         NOT NULL,
    `job`          VARCHAR(24) NOT NULL,
    `shifts`       INT         NOT NULL DEFAULT 0,
    `stops`        INT         NOT NULL DEFAULT 0,
    `earned`       BIGINT      NOT NULL DEFAULT 0,
    `updated_at`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`character_id`, `job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- Aussehen (moonshine-appearance)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `ms_outfits` (
    `id`           INT         NOT NULL AUTO_INCREMENT,
    `character_id` INT         NOT NULL,
    `label`        VARCHAR(32) NOT NULL,
    `data`         LONGTEXT    NOT NULL,
    `created_at`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `character_id` (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- Ritualkrieg (moonshine-ritualwar)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `ms_ritual_claims` (
    `point_id`        VARCHAR(32) NOT NULL,
    `faction_id`      INT         DEFAULT NULL,
    `since`           INT         NOT NULL DEFAULT 0,
    `protected_until` INT         NOT NULL DEFAULT 0,
    `payouts`         INT         NOT NULL DEFAULT 0,
    `updated_at`      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`point_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- Zufluchtsorte (moonshine-refuge)
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Wachhund-Beweise (moonshine-admin)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `ms_flags` (
    `id`         INT          NOT NULL AUTO_INCREMENT,
    `license`    VARCHAR(64)  NOT NULL,
    `name`       VARCHAR(64)  DEFAULT NULL,
    `reason`     VARCHAR(128) NOT NULL,
    `weight`     INT          NOT NULL DEFAULT 1,
    `strikes`    INT          NOT NULL DEFAULT 0,
    `details`    LONGTEXT     DEFAULT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `license` (`license`),
    KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- Banne ueber alle Kennungen (moonshine-core)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `ms_bans` (
    `id`         INT          NOT NULL AUTO_INCREMENT,
    `kind`       VARCHAR(16)  NOT NULL,
    `value`      VARCHAR(96)  NOT NULL,
    `license`    VARCHAR(64)  DEFAULT NULL,
    `name`       VARCHAR(64)  DEFAULT NULL,
    `reason`     VARCHAR(160) NOT NULL,
    `by`         VARCHAR(64)  DEFAULT NULL,
    `expires`    INT          NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `kind_value` (`kind`, `value`),
    KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
