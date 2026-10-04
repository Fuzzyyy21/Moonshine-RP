-- V0011 – Seekampf und Hafendienste (Phase 5, Iteration 2)

-- Spielregel-Zahlen ohne Originalbeleg (z. B. Hafenpreise aus design_data/dev_ships.json) sind markiert;
-- die Dienste nutzen sie nur mit Content:AllowDevContent.
ALTER TABLE game_rules ADD COLUMN is_dev BOOLEAN NOT NULL DEFAULT FALSE;

-- Proviant-Obergrenze je Schiff (Kapazität im Original UNKNOWN; Entwicklungswert).
ALTER TABLE ships ADD COLUMN provisions_max INT CHECK (provisions_max >= 0);
