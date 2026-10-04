-- V0014 – Herstellen und Sammeln (Phase 6, Iteration 3)
-- Belegt sind nur die Berufs-Skills; Rezepte, Sammelorte, Mengen und Zeiten sind UNKNOWN (design_data/dev_crafting.json).

ALTER TABLE recipes
    ADD COLUMN name_de TEXT,
    ADD COLUMN skill_xp BIGINT CHECK (skill_xp >= 0),            -- NULL = UNKNOWN → keine Skill-XP
    ADD COLUMN is_dev BOOLEAN NOT NULL DEFAULT FALSE;

-- Sammelpunkt-Arten. Wo sie stehen, legen die Karten fest (Actor mit Code); erlaubt ist ein Punkt nur in seinen Zonen.
-- Sammelzeit und Nachwachsen steuert der Zonen-Server (Werte hier, für die Data Table exportiert).
CREATE TABLE gather_nodes (
    gather_node_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE CHECK (code ~ '^[A-Z0-9_]{1,64}$'),
    name_de         TEXT,
    skill_id        SMALLINT NOT NULL REFERENCES skills,
    required_level  SMALLINT NOT NULL DEFAULT 1 CHECK (required_level > 0),
    item_id         INT NOT NULL REFERENCES items,
    min_qty         INT NOT NULL CHECK (min_qty > 0),
    max_qty         INT NOT NULL,
    gather_seconds  REAL CHECK (gather_seconds >= 0),
    respawn_seconds REAL CHECK (respawn_seconds >= 0),
    skill_xp        BIGINT CHECK (skill_xp >= 0),
    is_dev          BOOLEAN NOT NULL DEFAULT FALSE,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN',
    CHECK (max_qty >= min_qty)
);

CREATE TABLE gather_node_zones (
    gather_node_id  INT  NOT NULL REFERENCES gather_nodes ON DELETE CASCADE,
    zone_id         TEXT NOT NULL REFERENCES zones,
    PRIMARY KEY (gather_node_id, zone_id)
);

-- Sammeln und Herstellen genau einmal je Schlüssel.
ALTER TABLE inventory_operations DROP CONSTRAINT inventory_operations_kind_check;
ALTER TABLE inventory_operations ADD CONSTRAINT inventory_operations_kind_check
    CHECK (kind IN ('SELL', 'DISCARD', 'ADMIN_GRANT', 'GATHER', 'CRAFT'));
