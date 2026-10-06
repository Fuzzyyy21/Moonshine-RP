-- V0018 – Gildenkasse und Städtebesitz (Phase 7, Iteration 3)
-- Belegt (SYS-GUILD): Gildenoffiziere kaufen und besetzen Städte und erhalten Belohnungen und Verwaltungsrechte. Preise,
-- Belohnung und Rechte sind Designwerte (design_data/dev_guild.json).

-- Jede Bewegung der Gildenkasse (guilds.treasury_gold), wie currency_ledger für Charaktere.
CREATE TABLE guild_ledger (
    ledger_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    guild_id        BIGINT NOT NULL REFERENCES guilds,
    character_id    BIGINT REFERENCES characters,            -- wer es ausgelöst hat (NULL = System, z. B. Steueranteil)
    delta           BIGINT NOT NULL CHECK (delta <> 0),
    balance_after   BIGINT NOT NULL CHECK (balance_after >= 0),
    reason          TEXT   NOT NULL,
    flow            TEXT   NOT NULL CHECK (flow IN ('SOURCE', 'SINK', 'TRANSFER')),
    idempotency_key UUID UNIQUE,
    server_id       TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_guild_ledger_guild ON guild_ledger (guild_id, created_at);
CREATE INDEX ix_guild_ledger_reason ON guild_ledger (reason, created_at);

-- Käufliche Städte (Preis NULL = UNKNOWN, nicht käuflich); tax_rate des Besitzers ersetzt die Marktsteuer im Hafen.
ALTER TABLE territories ADD COLUMN is_dev BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX ix_territories_owner ON territories (owner_guild_id);
