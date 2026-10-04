-- V0009 – Welt (Phase 4, Iteration 2): Entdeckungen

-- Entdeckungspunkte je Zone. xp_reward NULL = UNKNOWN (dann keine Belohnung).
CREATE TABLE discoveries (
    discovery_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE CHECK (code ~ '^[A-Z0-9_]{1,64}$'),
    zone_id         TEXT NOT NULL REFERENCES zones,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    xp_reward       BIGINT CHECK (xp_reward >= 0),
    is_dev          BOOLEAN NOT NULL DEFAULT FALSE,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

-- Jede Entdeckung zählt je Charakter genau einmal.
CREATE TABLE character_discoveries (
    character_id    BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    discovery_id    INT    NOT NULL REFERENCES discoveries,
    discovered_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    server_id       TEXT NOT NULL,
    xp_awarded      BIGINT,
    PRIMARY KEY (character_id, discovery_id)
);
