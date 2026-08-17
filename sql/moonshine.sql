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
