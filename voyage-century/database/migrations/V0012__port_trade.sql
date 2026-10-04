-- V0012 – Hafenhandel (Phase 6, Iteration 1)
-- Preismodell, Waren und Steuern des Originals sind UNKNOWN (SYS-TRADE); die Inhalte kommen aus design_data/dev_trade.json.

-- Händler ohne belegten Ort sind Entwicklungsinhalt.
ALTER TABLE npcs ADD COLUMN is_dev BOOLEAN NOT NULL DEFAULT FALSE;

-- Märkte: Bestand und Gleichgewichtsbestand bestimmen den Preis (Formel im Backend, TradePricing). Zwischengespeicherte
-- Preise gibt es nicht – sie würden mit der Zeit (Auffüllen) veralten.
ALTER TABLE markets RENAME COLUMN supply TO stock;
ALTER TABLE markets RENAME COLUMN demand TO target_stock;
ALTER TABLE markets DROP COLUMN current_buy;
ALTER TABLE markets DROP COLUMN current_sell;
ALTER TABLE markets
    ADD COLUMN restock_per_hour INT NOT NULL DEFAULT 0 CHECK (restock_per_hour >= 0),
    ADD COLUMN is_dev BOOLEAN NOT NULL DEFAULT FALSE,
    ADD CONSTRAINT markets_stock_check CHECK (stock >= 0),
    ADD CONSTRAINT markets_target_stock_check CHECK (target_stock >= 0);
COMMENT ON COLUMN markets.stock IS 'Aktueller Bestand; bewegt sich mit restock_per_hour zum Gleichgewicht (updated_at = Stand der Rechnung)';
COMMENT ON COLUMN markets.target_stock IS 'Gleichgewichtsbestand: bei diesem Bestand gilt base_price';

-- Ladung: je Schiff und Ware genau ein Stapel (container_ref = ship_instance_id).
CREATE UNIQUE INDEX ux_ship_cargo ON item_instances (container_ref, item_id) WHERE location_type = 'SHIP_CARGO';

-- Jeder Handel genau einmal je Schlüssel, auch wenn kein Gold fließt; zugleich Handelsverlauf für die Auswertung.
CREATE TABLE trade_transactions (
    trade_key       UUID PRIMARY KEY,
    character_id    BIGINT NOT NULL REFERENCES characters,
    port_id         INT    NOT NULL REFERENCES ports,
    item_id         INT    NOT NULL REFERENCES items,
    ship_instance_id BIGINT NOT NULL REFERENCES ship_instances,
    side            TEXT   NOT NULL CHECK (side IN ('BUY', 'SELL')),
    quantity        INT    NOT NULL CHECK (quantity > 0),
    total_gold      BIGINT NOT NULL CHECK (total_gold >= 0),
    server_id       TEXT   NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_trade_transactions_char ON trade_transactions (character_id, created_at);
