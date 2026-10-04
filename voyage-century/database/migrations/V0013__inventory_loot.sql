-- V0013 – Inventar und Beute (Phase 6, Iteration 2)
-- Inventargröße, Beutetabellen und Goldbeute des Originals sind UNKNOWN; Inhalte aus design_data/dev_loot.json.

-- Goldbeute je Tabelle (NULL = keine bzw. UNKNOWN); Entwicklungstabellen sind markiert.
ALTER TABLE loot_tables
    ADD COLUMN gold_min BIGINT CHECK (gold_min >= 0),
    ADD COLUMN gold_max BIGINT,
    ADD COLUMN is_dev BOOLEAN NOT NULL DEFAULT FALSE,
    ADD CONSTRAINT loot_tables_gold_check CHECK ((gold_min IS NULL) = (gold_max IS NULL) AND gold_max >= gold_min);

-- Ausgerüstet ist höchstens ein Item je Platz (z. B. WEAPON); das Inventar nutzt die Plätze 0 … n−1.
-- Beides sichert schon ux_item_slot (Ort, Besitzer, Container, Platz).

-- Inventar-Aktionen mit Gold- oder Mengenwirkung genau einmal je Schlüssel (Verkauf, Wegwerfen, Admin-Vergabe).
CREATE TABLE inventory_operations (
    op_key          UUID PRIMARY KEY,
    character_id    BIGINT NOT NULL REFERENCES characters,
    kind            TEXT   NOT NULL CHECK (kind IN ('SELL', 'DISCARD', 'ADMIN_GRANT')),
    result          JSONB  NOT NULL,
    server_id       TEXT   NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Beute eines Kills (für die Antwort auf Wiederholungen und den Verlauf).
ALTER TABLE combat_kills ADD COLUMN loot JSONB;
