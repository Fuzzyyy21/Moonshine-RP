-- V0015 – Auktionshaus (Phase 6, Iteration 4)
-- Gebühren, Steuer und Laufzeit des Originals sind UNKNOWN (design_data/dev_auction.json).

-- Ein angebotenes Item liegt mit location_type = MARKET im Register und gehört weiter dem Verkäufer, bis es verkauft ist.
ALTER TABLE market_listings
    ADD COLUMN listing_key UUID UNIQUE,                     -- Einstellen genau einmal je Schlüssel
    ADD COLUMN item_id INT REFERENCES items,                -- für Suche und Verlauf, auch wenn das Exemplar aufgeht
    ADD COLUMN quantity INT CHECK (quantity > 0),
    ADD COLUMN sale_tax BIGINT CHECK (sale_tax >= 0),       -- bei Verkauf: verlässt das Spiel (Senke)
    ADD COLUMN sold_at TIMESTAMPTZ,
    ADD COLUMN closed_at TIMESTAMPTZ;                       -- verkauft, zurückgezogen oder abgeholt
-- Ein verkauftes Stapel-Item geht im Inventar des Käufers auf; die Angebotszeile bleibt als Verlauf.
ALTER TABLE market_listings ALTER COLUMN item_instance_id DROP NOT NULL;
ALTER TABLE market_listings DROP CONSTRAINT market_listings_item_instance_id_fkey;
ALTER TABLE market_listings ADD CONSTRAINT market_listings_item_instance_id_fkey
    FOREIGN KEY (item_instance_id) REFERENCES item_instances ON DELETE SET NULL;
CREATE INDEX ix_market_listings_item ON market_listings (item_id, price) WHERE status = 'OPEN';
CREATE INDEX ix_market_listings_seller ON market_listings (seller_character_id, status);

-- Kaufen und Zurückziehen genau einmal je Schlüssel.
ALTER TABLE inventory_operations DROP CONSTRAINT inventory_operations_kind_check;
ALTER TABLE inventory_operations ADD CONSTRAINT inventory_operations_kind_check
    CHECK (kind IN ('SELL', 'DISCARD', 'ADMIN_GRANT', 'GATHER', 'CRAFT', 'AUCTION_BUY', 'AUCTION_CANCEL'));
