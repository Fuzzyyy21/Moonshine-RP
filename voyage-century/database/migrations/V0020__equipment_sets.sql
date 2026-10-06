-- Phase 8, Iteration 1: Ausrüstungsplätze, Stufenanforderung und Setboni [DESIGN].
-- Belegt sind Sets mit Stufe und die Synthese (SET-*, SYS-EQUIP-SYNTHESIS); Plätze, Werte und Boni des Originals sind UNKNOWN.

-- Entwicklungs-Sets (DEV_) neben den belegten Sets; Boni als {"<Teile>": {"maxHealth": …, "attackPower": …, "defense": …}}.
ALTER TABLE item_sets ADD COLUMN is_dev BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE item_sets ADD CONSTRAINT ck_item_sets_bonuses CHECK (bonuses IS NULL OR jsonb_typeof(bonuses) = 'object');

-- Rüstung und Schmuck brauchen einen Platz, um ausgerüstet zu werden; der Waffenplatz bleibt Waffen vorbehalten.
ALTER TABLE items ADD CONSTRAINT ck_items_equip_slot CHECK (equip_slot IS NULL OR (equip_slot <> 'WEAPON' AND equip_slot ~ '^[A-Z_]{1,32}$'));
ALTER TABLE items ADD CONSTRAINT ck_items_level_req CHECK (level_req IS NULL OR level_req > 0);

CREATE INDEX ix_items_set ON items (set_id) WHERE set_id IS NOT NULL;
