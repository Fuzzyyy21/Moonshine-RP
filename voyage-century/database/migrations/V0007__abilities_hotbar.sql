-- V0007 – Fähigkeiten und Hotbar (Phase 3, Iteration 2)

-- Fähigkeiten ohne Originalbeleg (design_data/dev_abilities.json) sind markiert und werden von den
-- Diensten nur mit Content:AllowDevContent verwendet – wie Waffen und Gegner aus V0006.
ALTER TABLE abilities ADD COLUMN is_dev BOOLEAN NOT NULL DEFAULT FALSE;

-- Die Hotbar hat eine eigene Tabelle: Fähigkeiten werden über die Skillstufe freigeschaltet und
-- brauchen dafür keine Zeile in character_abilities. Die dort aus V0001 vorgesehene, nie benutzte
-- Spalte hotbar_slot entfällt, damit es nur eine Stelle für die Belegung gibt.
ALTER TABLE character_abilities DROP COLUMN hotbar_slot;

-- Zehn Plätze (Tasten 1–0). Anzahl im Original UNKNOWN; Designentscheidung (Priorität 6).
-- Jede Fähigkeit höchstens einmal je Charakter, damit Abklingzeiten eindeutig angezeigt werden.
CREATE TABLE character_hotbar (
    character_id    BIGINT   NOT NULL REFERENCES characters ON DELETE CASCADE,
    slot            SMALLINT NOT NULL CHECK (slot BETWEEN 0 AND 9),
    ability_id      INT      NOT NULL REFERENCES abilities,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (character_id, slot),
    UNIQUE (character_id, ability_id)
);
