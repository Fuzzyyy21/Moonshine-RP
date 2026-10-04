-- V0005 – Erscheinungsbild bei der Charaktererstellung (Phase 2, Iteration 2)
--
-- Anzahl der Auswahlmöglichkeiten je Merkmal. Die Optionen des Originals sind UNKNOWN; die Zahlen
-- kommen aus design_data/appearance.json und richten sich nach den vorhandenen Assets (is_dev).
-- characters.appearance speichert je Merkmal einen Index 0 … option_count − 1.

CREATE TABLE appearance_slots (
    slot            TEXT PRIMARY KEY CHECK (slot ~ '^[a-z][a-zA-Z]{1,31}$'),
    option_count    SMALLINT NOT NULL CHECK (option_count > 0),
    sort_order      SMALLINT NOT NULL DEFAULT 0,
    is_dev          BOOLEAN NOT NULL DEFAULT TRUE,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);
