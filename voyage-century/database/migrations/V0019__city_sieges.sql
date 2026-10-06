-- V0019 – Stadtbelagerung (Phase 7, Iteration 4)
-- Belegt (SYS-CITY-SIEGE): Belagerungen gibt es, beworben als Land-See-Kampf. Ablauf und Siegbedingung sind Design.

ALTER TABLE territory_wars
    ADD COLUMN declare_key UUID UNIQUE,                     -- Ansagen genau einmal je Schlüssel
    ADD COLUMN ends_at TIMESTAMPTZ,
    ADD COLUMN attacker_score INT NOT NULL DEFAULT 0 CHECK (attacker_score >= 0),
    ADD COLUMN defender_score INT NOT NULL DEFAULT 0 CHECK (defender_score >= 0),
    ADD COLUMN declared_by BIGINT REFERENCES characters,
    ADD COLUMN declared_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN resolved_at TIMESTAMPTZ;
-- Je Stadt höchstens eine offene Belagerung (angesagt oder laufend; „läuft“ ergibt sich aus der Zeit).
CREATE UNIQUE INDEX ux_territory_wars_open ON territory_wars (territory_id) WHERE state IN ('SCHEDULED', 'RUNNING');
CREATE INDEX ix_territory_wars_open_time ON territory_wars (scheduled_at, ends_at) WHERE state IN ('SCHEDULED', 'RUNNING');

-- Welcher Kill für welche Belagerung zählte (Nachvollziehbarkeit der Wertung).
ALTER TABLE combat_kills ADD COLUMN war_id BIGINT REFERENCES territory_wars;
