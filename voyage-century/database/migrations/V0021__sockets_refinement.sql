-- Phase 8, Iteration 2: Sockeln (SYS-SOCKETING, LIKELY) und Verfeinern (SYS-REFINEMENT, UNCERTAIN).
-- Kosten, Höchststufe und Wirkung sind Entwicklungswerte (game_rules SOCKET_* / REFINE_*, is_dev).

-- Stufe eines Edelsteins oder Verfeinerungssteins (Verfeinern verlangt bestimmte Stufen).
ALTER TABLE items ADD COLUMN tier SMALLINT CHECK (tier > 0);
ALTER TABLE items ADD CONSTRAINT ck_items_socket_max CHECK (socket_max IS NULL OR socket_max <= 3); -- beobachtet: 3

-- Stufe des zuletzt beim Verfeinern verwendeten Edelsteins (der nächste muss höher sein).
ALTER TABLE item_instances ADD COLUMN refine_gem_tier SMALLINT NOT NULL DEFAULT 0 CHECK (refine_gem_tier >= 0);
-- Gebohrte Sockel: [null | {"gem_item_id": …}], Länge = Zahl der Sockel.
ALTER TABLE item_instances ADD CONSTRAINT ck_item_instances_sockets CHECK (jsonb_typeof(sockets) = 'array');

-- Bohren, Sockeln und Verfeinern genau einmal je Schlüssel.
ALTER TABLE inventory_operations DROP CONSTRAINT inventory_operations_kind_check;
ALTER TABLE inventory_operations ADD CONSTRAINT inventory_operations_kind_check
    CHECK (kind IN ('SELL', 'DISCARD', 'ADMIN_GRANT', 'GATHER', 'CRAFT', 'AUCTION_BUY', 'AUCTION_CANCEL', 'DRILL', 'SOCKET', 'REFINE'));
