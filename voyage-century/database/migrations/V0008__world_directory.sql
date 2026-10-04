-- V0008 – Welt (Phase 4, Iteration 1): Zonenübergänge, Häfen mit unbekannten Diensten, World Directory

-- Technische Zonen ohne Spielinhalt (z. B. DEV_TESTZONE, SEA_DEV) sind markiert; das World Directory
-- leitet nur mit Content:AllowDevContent dorthin.
ALTER TABLE zones ADD COLUMN is_dev BOOLEAN NOT NULL DEFAULT FALSE;
UPDATE zones SET is_dev = TRUE WHERE zone_id = 'DEV_TESTZONE';

-- Dienste eines Hafens sind meist UNKNOWN. NOT NULL DEFAULT FALSE hätte "gibt es nicht" behauptet;
-- ab jetzt gilt auch hier NULL = UNKNOWN.
ALTER TABLE ports
    ALTER COLUMN has_shipyard DROP NOT NULL, ALTER COLUMN has_shipyard DROP DEFAULT,
    ALTER COLUMN has_bank     DROP NOT NULL, ALTER COLUMN has_bank     DROP DEFAULT,
    ALTER COLUMN has_storage  DROP NOT NULL, ALTER COLUMN has_storage  DROP DEFAULT,
    ALTER COLUMN has_market   DROP NOT NULL, ALTER COLUMN has_market   DROP DEFAULT,
    ALTER COLUMN has_auction  DROP NOT NULL, ALTER COLUMN has_auction  DROP DEFAULT,
    ALTER COLUMN has_tavern   DROP NOT NULL, ALTER COLUMN has_tavern   DROP DEFAULT;

-- Übergänge zwischen Zonen: Ausgang (in der Karte) → Zielzone und Ankunftspunkt (PlayerStart-Tag).
-- Wie das Original Land und See verband, ist UNKNOWN; die Übergänge sind deshalb Daten, kein Code.
CREATE TABLE zone_links (
    from_zone_id    TEXT NOT NULL REFERENCES zones,
    exit_code       TEXT NOT NULL CHECK (exit_code ~ '^[A-Z0-9_]{1,32}$'),
    to_zone_id      TEXT NOT NULL REFERENCES zones,
    arrival_tag     TEXT NOT NULL CHECK (arrival_tag ~ '^[A-Z0-9_]{1,32}$'),
    PRIMARY KEY (from_zone_id, exit_code),
    CHECK (from_zone_id <> to_zone_id)
);

-- Laufende Zonen-Server. Lebendig = Lebenszeichen jünger als World:ServerTimeoutSeconds.
CREATE TABLE zone_servers (
    server_id       TEXT PRIMARY KEY CHECK (length(server_id) BETWEEN 1 AND 64),
    zone_id         TEXT NOT NULL REFERENCES zones,
    address         TEXT NOT NULL,                        -- host:port, wie Clients den Server erreichen
    capacity        INT  NOT NULL CHECK (capacity > 0),
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_heartbeat  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_zone_servers_zone ON zone_servers (zone_id, last_heartbeat);

-- Wo ein Charakter gerade ist: genau eine Zeile je Charakter, damit kein Zustand doppelt existiert.
-- ONLINE: auf server_id gespielt (gültig, solange der Server lebt).
-- TRANSFER: für server_id reserviert, bis expires_at; arrival_tag sagt, wo er ankommt.
CREATE TABLE character_presence (
    character_id    BIGINT PRIMARY KEY REFERENCES characters ON DELETE CASCADE,
    server_id       TEXT NOT NULL REFERENCES zone_servers ON DELETE CASCADE,
    zone_id         TEXT NOT NULL REFERENCES zones,
    state           TEXT NOT NULL CHECK (state IN ('ONLINE', 'TRANSFER')),
    arrival_tag     TEXT,
    since           TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ,
    CHECK ((state = 'TRANSFER') = (expires_at IS NOT NULL))
);
CREATE INDEX ix_character_presence_server ON character_presence (server_id);
