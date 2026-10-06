-- V0017 – Gilden (Phase 7, Iteration 2)
-- Belegt (SYS-GUILD): Leiter gründet mit Name und Banner, Ränge mindestens Leiter und Gildenoffiziere. Alles Weitere aus
-- design_data/dev_guild.json.

-- Ränge, mit denen jede neue Gilde beginnt (je Gilde in guild_ranks kopiert, damit Gilden sie später anpassen können).
CREATE TABLE guild_rank_defaults (
    rank_no         SMALLINT PRIMARY KEY CHECK (rank_no >= 0),
    name            TEXT NOT NULL,
    permissions     TEXT[] NOT NULL DEFAULT '{}',
    is_dev          BOOLEAN NOT NULL DEFAULT FALSE,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

ALTER TABLE guilds
    ADD COLUMN found_key UUID UNIQUE,                       -- Gründung genau einmal je Schlüssel
    ADD CONSTRAINT guilds_name_check CHECK (length(name) BETWEEN 3 AND 20),
    ADD CONSTRAINT guilds_tag_check CHECK (tag IS NULL OR tag ~ '^[[:upper:][:digit:]]{2,4}$');
CREATE UNIQUE INDEX ux_guilds_tag ON guilds (tag) WHERE disbanded_at IS NULL AND tag IS NOT NULL;

-- Gildenchat läuft über denselben Verteiler wie der übrige Chat.
ALTER TABLE chat_log ADD COLUMN target_guild_id BIGINT;
