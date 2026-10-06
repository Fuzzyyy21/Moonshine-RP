-- Phase 8, Iteration 3: Haltbarkeit, Reparatur und Seltenheit [DESIGN].
-- Seltenheitsstufen des Originals sind UNKNOWN (SYS-RARITY); die Stufen hier sind Entwicklungswerte (is_dev).

CREATE TABLE item_rarities (
    code            TEXT PRIMARY KEY CHECK (code ~ '^[A-Z_]{1,32}$'),
    sort_order      SMALLINT NOT NULL UNIQUE,
    name_de         TEXT,
    -- Gewicht der Reparaturkosten in Promille (1000 = einfach).
    repair_factor_permille INT NOT NULL CHECK (repair_factor_permille >= 0),
    is_dev          BOOLEAN NOT NULL DEFAULT FALSE,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

-- items.rarity war frei (Originalstufen UNKNOWN); jetzt nur noch bekannte Stufen oder NULL.
UPDATE items SET rarity = NULL WHERE rarity IS NOT NULL AND rarity NOT IN (SELECT code FROM item_rarities);
ALTER TABLE items ADD CONSTRAINT fk_items_rarity FOREIGN KEY (rarity) REFERENCES item_rarities (code);

-- Abnutzung beim Tod und Reparatur genau einmal je Schlüssel.
ALTER TABLE inventory_operations DROP CONSTRAINT inventory_operations_kind_check;
ALTER TABLE inventory_operations ADD CONSTRAINT inventory_operations_kind_check
    CHECK (kind IN ('SELL', 'DISCARD', 'ADMIN_GRANT', 'GATHER', 'CRAFT', 'AUCTION_BUY', 'AUCTION_CANCEL', 'DRILL', 'SOCKET', 'REFINE',
                    'REPAIR', 'DEATH'));
