-- V0006 – Landkampf (Phase 3): Entwicklungsinhalte, Gegner-XP, PvP-Regel je Zone, Kill-Protokoll

-- Inhalte ohne Originalbeleg (Waffen und Gegner aus design_data/dev_combat.json) sind markiert und
-- werden von den Diensten nur mit Content:AllowDevContent verwendet.
ALTER TABLE items ADD COLUMN is_dev BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE monsters
    ADD COLUMN is_dev    BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN xp_reward BIGINT CHECK (xp_reward >= 0);   -- NULL = UNKNOWN, Kill gibt dann keine XP

-- PvP je Zone: NONE = kein Spielerkampf, FREE = jeder gegen jeden. Weitere Modi folgen (Gilden, Flaggen).
ALTER TABLE zones ADD COLUMN pvp_mode TEXT NOT NULL DEFAULT 'NONE' CHECK (pvp_mode IN ('NONE', 'FREE'));
-- Die technische Testzone erlaubt PvP, damit die Regeln testbar sind.
UPDATE zones SET pvp_mode = 'FREE' WHERE zone_id = 'DEV_TESTZONE';

-- Jeder gemeldete Kill genau einmal (Idempotenz) und nachvollziehbar.
CREATE TABLE combat_kills (
    idempotency_key     UUID PRIMARY KEY,
    zone_id             TEXT NOT NULL REFERENCES zones,
    killer_character_id BIGINT NOT NULL REFERENCES characters,
    victim_character_id BIGINT REFERENCES characters,
    monster_id          INT REFERENCES monsters,
    xp_awarded          BIGINT,
    server_id           TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK ((victim_character_id IS NULL) <> (monster_id IS NULL)),
    CHECK (victim_character_id IS NULL OR victim_character_id <> killer_character_id)
);
CREATE INDEX ix_combat_kills_killer ON combat_kills (killer_character_id, created_at);
