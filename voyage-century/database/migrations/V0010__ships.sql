-- V0010 – Schiffe (Phase 5, Iteration 1): Entwicklungsschiffe, Startausstattung, Kauf

-- Schiffe ohne Originalbeleg (design_data/dev_ships.json) sind markiert und nur mit Content:AllowDevContent nutzbar.
ALTER TABLE ships
    ADD COLUMN is_dev            BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN crew_min          INT CHECK (crew_min >= 0),
    ADD COLUMN deceleration      REAL,
    ADD COLUMN start_crew        INT CHECK (start_crew >= 0),
    ADD COLUMN start_provisions  INT CHECK (start_provisions >= 0),
    -- z. B. Anfängerschiff: höchstens eins je Charakter (Bezugsweg im Original UNKNOWN)
    ADD COLUMN one_per_character BOOLEAN NOT NULL DEFAULT FALSE,
    ADD CONSTRAINT ships_crew_range CHECK (crew_min IS NULL OR crew_capacity IS NULL OR crew_min <= crew_capacity);

-- Jeder Kauf genau einmal (Wiederholung nach Netzwerkfehler bucht nicht doppelt).
ALTER TABLE ship_instances ADD COLUMN purchase_key UUID UNIQUE;
CREATE INDEX ix_ship_instances_owner ON ship_instances (owner_character_id);
