-- V0002 – Session-Tickets für den Login-Ablauf (Phase 1)
--
-- Der Client erhält beim Login ein zufälliges Ticket. Gespeichert wird nur der
-- SHA-256-Hash, damit ein Datenbank-Leak keine gültigen Tickets preisgibt.
-- Die Spalte ist NOT NULL ohne Default; das ist nur zulässig, weil vor dieser
-- Migration noch keine Sessions existieren konnten (kein Login-Dienst vor Phase 1).

ALTER TABLE account_sessions
    ADD COLUMN token_hash   BYTEA       NOT NULL,
    ADD COLUMN last_seen_at TIMESTAMPTZ,
    ADD COLUMN server_id    TEXT;

CREATE UNIQUE INDEX ux_account_sessions_token ON account_sessions (token_hash);
CREATE INDEX ix_account_sessions_active ON account_sessions (account_id) WHERE revoked_at IS NULL;
