-- V0004 – Progression (Phase 2): Level, Charakter-XP, Skill-XP
--
-- Originale XP-Kurven sind UNKNOWN (LVL-XP-CURVE). Damit Entwicklung möglich ist, dürfen
-- Kurvenzeilen als Entwicklungswerte markiert werden (is_dev). Die Dienste verwenden sie nur,
-- wenn Progression:AllowDevCurves gesetzt ist (Development/Tests). Ohne nutzbare Zeile gibt es
-- keinen Aufstieg: XP sammelt sich, das Level bleibt.

ALTER TABLE level_table ADD COLUMN is_dev BOOLEAN NOT NULL DEFAULT FALSE;

-- XP-Schwelle (kumuliert) je Skillstufe; gilt für alle Skills, solange keine skillspezifischen Kurven bekannt sind.
CREATE TABLE skill_level_table (
    level           SMALLINT PRIMARY KEY CHECK (level > 0),
    xp_required     BIGINT CHECK (xp_required >= 0),
    is_dev          BOOLEAN NOT NULL DEFAULT FALSE,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

-- Einzelne Spielregel-Zahlen aus der Reconstruction Database (z. B. SKILL_TOTAL_CAP = 1700).
CREATE TABLE game_rules (
    rule_key        TEXT PRIMARY KEY,
    int_value       BIGINT NOT NULL,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

-- Jede XP-Vergabe trägt einen Idempotenzschlüssel; Wiederholungen nach Netzwerkfehlern wirken nicht doppelt.
CREATE TABLE progression_grants (
    idempotency_key UUID PRIMARY KEY,
    character_id    BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    kind            TEXT NOT NULL CHECK (kind IN ('CHARACTER_XP', 'SKILL_XP')),
    skill_id        SMALLINT REFERENCES skills,
    amount          BIGINT NOT NULL CHECK (amount > 0),
    source          TEXT NOT NULL,
    server_id       TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK ((kind = 'SKILL_XP') = (skill_id IS NOT NULL))
);
CREATE INDEX ix_progression_grants_char ON progression_grants (character_id, created_at);
