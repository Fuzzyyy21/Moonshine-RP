-- =============================================================================
-- V0001 – Ausgangsschema (PostgreSQL 16)
-- =============================================================================
-- Konventionen
--   * Inhaltstabellen (statische Spieldaten) tragen recon_id + confidence und
--     verweisen damit auf den Datensatz in reconstruction_db/. Sie werden nie
--     von Hand gepflegt, sondern aus der Reconstruction Database erzeugt.
--   * NULL in einem Spielwert bedeutet UNKNOWN. Es werden keine Platzhalterzahlen
--     eingetragen. Der Server muss NULL-Werte als "nicht freigeschaltet" behandeln.
--   * Laufzeittabellen (Charaktere, Instanzen, Fortschritt) gehören ausschließlich
--     dem Game Server bzw. den Backend-Diensten. Clients schreiben nie direkt.
--   * Geld liegt nur in character_wallets; jede Änderung erzeugt eine Zeile in
--     currency_ledger (Grundlage für Inflationsmonitoring und Anti-Cheat).
--   * Transaktionen setzt der Migrator; diese Datei enthält kein BEGIN/COMMIT.
--   * Jedes Item-Exemplar existiert genau einmal in item_instances und hat genau
--     einen Ort (location_type + Besitzer + Container + Slot). Damit sind Dupes
--     durch "gleichzeitig in Inventar und Mail" strukturell ausgeschlossen.
-- =============================================================================


CREATE TYPE confidence_level AS ENUM ('CONFIRMED', 'LIKELY', 'UNCERTAIN', 'UNKNOWN');

-- -----------------------------------------------------------------------------
-- Accounts und Sessions
-- -----------------------------------------------------------------------------
CREATE TABLE accounts (
    account_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    login           TEXT        NOT NULL,
    email           TEXT,
    password_hash   TEXT        NOT NULL,                 -- argon2id, nie Klartext
    admin_level     SMALLINT    NOT NULL DEFAULT 0 CHECK (admin_level BETWEEN 0 AND 10),
    status          TEXT        NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'BANNED', 'DELETED')),
    banned_until    TIMESTAMPTZ,
    ban_reason      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_login_at   TIMESTAMPTZ
);
CREATE UNIQUE INDEX ux_accounts_login ON accounts (lower(login));
CREATE UNIQUE INDEX ux_accounts_email ON accounts (lower(email)) WHERE email IS NOT NULL;

CREATE TABLE account_sessions (
    session_id      UUID        PRIMARY KEY,
    account_id      BIGINT      NOT NULL REFERENCES accounts ON DELETE CASCADE,
    ip              INET,
    client_version  TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ
);
CREATE INDEX ix_account_sessions_account ON account_sessions (account_id);

-- -----------------------------------------------------------------------------
-- Welt (statisch)
-- -----------------------------------------------------------------------------
CREATE TABLE continents (
    continent_id    SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE regions (
    region_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    continent_id    SMALLINT REFERENCES continents,
    code            TEXT NOT NULL UNIQUE,
    region_kind     TEXT NOT NULL CHECK (region_kind IN ('SEA', 'LAND', 'MIXED')),
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

-- Eine Zone ist eine vom Server geladene Karte (Seegebiet, Stadt, Dungeon-Vorlage).
CREATE TABLE zones (
    zone_id         TEXT PRIMARY KEY,
    region_id       INT REFERENCES regions,
    zone_kind       TEXT NOT NULL CHECK (zone_kind IN ('SEA', 'CITY', 'LAND', 'DUNGEON', 'BATTLEFIELD')),
    map_asset       TEXT NOT NULL,                        -- UE5-Map-Pfad
    max_players     INT CHECK (max_players > 0)
);

CREATE TABLE cities (
    city_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    region_id       INT REFERENCES regions,
    zone_id         TEXT REFERENCES zones,
    code            TEXT NOT NULL UNIQUE,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    coord_as_given  TEXT,                                 -- exakt wie in der Quelle, z. B. 'N38E23'
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE ports (
    port_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_id         INT NOT NULL UNIQUE REFERENCES cities,
    has_shipyard    BOOLEAN NOT NULL DEFAULT FALSE,
    has_bank        BOOLEAN NOT NULL DEFAULT FALSE,
    has_storage     BOOLEAN NOT NULL DEFAULT FALSE,
    has_market      BOOLEAN NOT NULL DEFAULT FALSE,
    has_auction     BOOLEAN NOT NULL DEFAULT FALSE,
    has_tavern      BOOLEAN NOT NULL DEFAULT FALSE,
    services        JSONB   NOT NULL DEFAULT '{}'::jsonb, -- weitere, noch nicht modellierte Dienste
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

-- -----------------------------------------------------------------------------
-- Berufe, Level, Skills (statisch)
-- -----------------------------------------------------------------------------
CREATE TABLE professions (
    profession_id   SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

-- Eine Zeile pro Stufe. xp_required NULL = UNKNOWN; der Server sperrt den
-- Aufstieg auf eine Stufe ohne bekannte XP-Schwelle.
CREATE TABLE level_table (
    level           SMALLINT PRIMARY KEY CHECK (level > 0),
    xp_required     BIGINT CHECK (xp_required >= 0),
    hp_bonus        INT,
    sp_bonus        INT,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE skills (
    skill_id        SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    category_cn     TEXT CHECK (category_cn IN ('COMBAT', 'TRADE', 'GATHERING', 'PRODUCTION')),
    ui_group        TEXT CHECK (ui_group IN ('COMBAT', 'SEAFARING', 'PROFESSION')),
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    max_level       SMALLINT CHECK (max_level > 0),
    requirements    JSONB NOT NULL DEFAULT '{}'::jsonb,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

-- Grundstufe / 2. Stufe / 3. Stufe mit ihren Obergrenzen (31 / 100 / 120 laut Quellen).
CREATE TABLE skill_stages (
    stage_no        SMALLINT PRIMARY KEY CHECK (stage_no > 0),
    max_level       SMALLINT NOT NULL CHECK (max_level > 0),
    promotion_requirements JSONB,                         -- NULL = UNKNOWN
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE abilities (
    ability_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    skill_id        SMALLINT REFERENCES skills,
    code            TEXT NOT NULL UNIQUE,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    ability_kind    TEXT NOT NULL CHECK (ability_kind IN ('ACTIVE', 'PASSIVE')),
    domain          TEXT NOT NULL CHECK (domain IN ('LAND', 'SEA', 'BOTH')),
    required_skill_level SMALLINT,
    gas_ability_class TEXT,                               -- UE5-Gameplay-Ability-Klasse
    params          JSONB NOT NULL DEFAULT '{}'::jsonb,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE titles (
    title_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    effects         JSONB NOT NULL DEFAULT '{}'::jsonb,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE achievements (
    achievement_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    name_de         TEXT,
    criteria        JSONB NOT NULL,
    reward          JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- -----------------------------------------------------------------------------
-- Charaktere (Laufzeit)
-- -----------------------------------------------------------------------------
CREATE TABLE characters (
    character_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id      BIGINT   NOT NULL REFERENCES accounts,
    name            TEXT     NOT NULL CHECK (length(name) BETWEEN 2 AND 24),
    gender          TEXT     NOT NULL CHECK (gender IN ('MALE', 'FEMALE')),
    appearance      JSONB    NOT NULL,                    -- Gesicht, Haare, Haarfarbe, Haut, Körper
    profession_id   SMALLINT NOT NULL REFERENCES professions,
    level           SMALLINT NOT NULL DEFAULT 1 CHECK (level > 0),
    experience      BIGINT   NOT NULL DEFAULT 0 CHECK (experience >= 0),
    military_rank   SMALLINT NOT NULL DEFAULT 0 CHECK (military_rank >= 0),  -- 军阶
    zone_id         TEXT     REFERENCES zones,
    pos_x           DOUBLE PRECISION, pos_y DOUBLE PRECISION, pos_z DOUBLE PRECISION,
    yaw             REAL,
    active_title_id INT REFERENCES titles,
    playtime_seconds BIGINT  NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_saved_at   TIMESTAMPTZ,
    deleted_at      TIMESTAMPTZ
);
CREATE UNIQUE INDEX ux_characters_name ON characters (lower(name)) WHERE deleted_at IS NULL;
CREATE INDEX ix_characters_account ON characters (account_id);

CREATE TABLE character_stats (
    character_id    BIGINT PRIMARY KEY REFERENCES characters ON DELETE CASCADE,
    hp              INT NOT NULL CHECK (hp >= 0),
    hp_max          INT NOT NULL CHECK (hp_max > 0),
    sp              INT NOT NULL CHECK (sp >= 0),          -- Stamina Points
    sp_max          INT NOT NULL CHECK (sp_max > 0),
    attributes      JSONB NOT NULL DEFAULT '{}'::jsonb,    -- Attributcodes sind UNKNOWN, daher flexibel
    CHECK (hp <= hp_max), CHECK (sp <= sp_max)
);

CREATE TABLE skill_progress (
    character_id    BIGINT   NOT NULL REFERENCES characters ON DELETE CASCADE,
    skill_id        SMALLINT NOT NULL REFERENCES skills,
    stage_no        SMALLINT NOT NULL DEFAULT 1 REFERENCES skill_stages,
    level           SMALLINT NOT NULL DEFAULT 1 CHECK (level > 0),
    experience      BIGINT   NOT NULL DEFAULT 0 CHECK (experience >= 0),
    PRIMARY KEY (character_id, skill_id)
);

CREATE TABLE character_abilities (
    character_id    BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    ability_id      INT    NOT NULL REFERENCES abilities,
    rank            SMALLINT NOT NULL DEFAULT 1,
    hotbar_slot     SMALLINT,
    PRIMARY KEY (character_id, ability_id)
);

CREATE TABLE character_titles (
    character_id    BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    title_id        INT    NOT NULL REFERENCES titles,
    earned_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (character_id, title_id)
);

CREATE TABLE character_reputation (
    character_id    BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    faction_code    TEXT   NOT NULL,
    value           INT    NOT NULL DEFAULT 0,
    PRIMARY KEY (character_id, faction_code)
);

CREATE TABLE character_achievements (
    character_id    BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    achievement_id  INT    NOT NULL REFERENCES achievements,
    progress        JSONB  NOT NULL DEFAULT '{}'::jsonb,
    completed_at    TIMESTAMPTZ,
    PRIMARY KEY (character_id, achievement_id)
);

-- -----------------------------------------------------------------------------
-- Währungen (Laufzeit) – keine Geldspalten an anderen Tabellen
-- -----------------------------------------------------------------------------
CREATE TABLE currencies (
    currency_code   TEXT PRIMARY KEY CHECK (currency_code IN ('GOLD', 'PREMIUM', 'GUILD', 'EVENT')),
    tradeable       BOOLEAN NOT NULL
);

CREATE TABLE character_wallets (
    character_id    BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    currency_code   TEXT   NOT NULL REFERENCES currencies,
    balance         BIGINT NOT NULL DEFAULT 0 CHECK (balance >= 0),
    PRIMARY KEY (character_id, currency_code)
);

-- Jede Geldbewegung. reason unterscheidet Quellen (Drop, Quest, Verkauf) und
-- Senken (Reparatur, Steuer, Gebühr, Umbau) für das Inflationsmonitoring.
CREATE TABLE currency_ledger (
    ledger_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id    BIGINT NOT NULL REFERENCES characters,
    currency_code   TEXT   NOT NULL REFERENCES currencies,
    delta           BIGINT NOT NULL CHECK (delta <> 0),
    balance_after   BIGINT NOT NULL CHECK (balance_after >= 0),
    reason          TEXT   NOT NULL,
    flow            TEXT   NOT NULL CHECK (flow IN ('SOURCE', 'SINK', 'TRANSFER')),
    ref_type        TEXT,
    ref_id          BIGINT,
    idempotency_key UUID UNIQUE,                           -- verhindert doppelte Buchung bei Retry
    server_id       TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_currency_ledger_char ON currency_ledger (character_id, created_at);
CREATE INDEX ix_currency_ledger_reason ON currency_ledger (reason, created_at);

-- -----------------------------------------------------------------------------
-- Items (statisch + Laufzeit)
-- -----------------------------------------------------------------------------
CREATE TABLE item_sets (
    set_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    level           SMALLINT,
    bonuses         JSONB,                                 -- NULL = UNKNOWN
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE items (
    item_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    item_type       TEXT NOT NULL CHECK (item_type IN (
                        'WEAPON', 'ARMOR', 'ACCESSORY', 'CONSUMABLE', 'MATERIAL', 'GEM',
                        'REFINE_STONE', 'TRADE_GOOD', 'SHIP_PART', 'FIGUREHEAD', 'CANNON',
                        'OFFICER_CARD', 'QUEST', 'TREASURE_MAP', 'MISC')),
    weapon_class    TEXT CHECK (weapon_class IN ('SWORD', 'BLADE', 'AXE', 'FIREARM', 'UNARMED', 'SPECIAL')),
    equip_slot      TEXT,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    level_req       SMALLINT,
    rarity          TEXT,                                  -- Originalstufen UNKNOWN, daher frei
    base_stats      JSONB,                                 -- NULL = UNKNOWN
    requirements    JSONB NOT NULL DEFAULT '{}'::jsonb,
    durability_max  INT CHECK (durability_max > 0),
    socket_max      SMALLINT CHECK (socket_max >= 0),
    set_id          INT REFERENCES item_sets,
    stackable       BOOLEAN NOT NULL DEFAULT FALSE,
    max_stack       INT NOT NULL DEFAULT 1 CHECK (max_stack > 0),
    tradeable       BOOLEAN NOT NULL DEFAULT TRUE,
    npc_price       BIGINT CHECK (npc_price >= 0),
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN',
    CHECK (stackable OR max_stack = 1),
    CHECK ((item_type = 'WEAPON') = (weapon_class IS NOT NULL))
);

CREATE TABLE materials (
    item_id         INT PRIMARY KEY REFERENCES items,
    material_category TEXT NOT NULL,
    gather_skill_id SMALLINT REFERENCES skills,
    gather_skill_level SMALLINT
);

CREATE TYPE item_location AS ENUM (
    'INVENTORY', 'EQUIPMENT', 'STORAGE', 'GUILD_STORAGE', 'MAIL', 'MARKET',
    'SHIP_EQUIPMENT', 'SHIP_CARGO', 'OFFICER_EQUIPMENT', 'TRADE_WINDOW', 'DESTROYED');

-- Einziges Register aller Item-Exemplare. container_ref verweist je nach Ort auf
-- port_id (STORAGE), ship_instance_id, mail_id, listing_id oder officer_instance_id.
CREATE TABLE item_instances (
    item_instance_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_id         INT NOT NULL REFERENCES items,
    quantity        INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    location_type   item_location NOT NULL,
    owner_character_id BIGINT REFERENCES characters,
    owner_guild_id  BIGINT,                                -- FK unten, guilds wird später angelegt
    container_ref   BIGINT,
    slot            TEXT,
    durability      INT CHECK (durability >= 0),
    enhancement_level SMALLINT NOT NULL DEFAULT 0 CHECK (enhancement_level >= 0),
    refinement_level  SMALLINT NOT NULL DEFAULT 0 CHECK (refinement_level >= 0),
    sockets         JSONB NOT NULL DEFAULT '[]'::jsonb,    -- [{ "gem_item_id": .. } | null]
    bound           BOOLEAN NOT NULL DEFAULT FALSE,
    origin          TEXT NOT NULL CHECK (origin IN ('DROP', 'CRAFT', 'QUEST', 'NPC_SHOP', 'MARKET', 'ADMIN', 'EVENT', 'SPLIT', 'MIGRATION')),
    origin_ref      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    version         INT NOT NULL DEFAULT 0,                -- optimistisches Locking
    CHECK (location_type = 'DESTROYED' OR owner_character_id IS NOT NULL OR owner_guild_id IS NOT NULL
           OR location_type IN ('MARKET', 'MAIL'))
);
CREATE UNIQUE INDEX ux_item_slot ON item_instances (
    location_type, COALESCE(owner_character_id, 0), COALESCE(owner_guild_id, 0),
    COALESCE(container_ref, 0), slot)
    WHERE slot IS NOT NULL AND location_type <> 'DESTROYED';
CREATE INDEX ix_item_instances_owner ON item_instances (owner_character_id, location_type);

-- Die in der Anforderung genannten Tabellen inventory / equipment sind Sichten
-- auf das Register, damit es nur eine Wahrheit gibt.
CREATE VIEW inventory AS
    SELECT owner_character_id AS character_id, slot, item_instance_id, item_id, quantity
    FROM item_instances WHERE location_type = 'INVENTORY';

CREATE VIEW equipment AS
    SELECT owner_character_id AS character_id, slot, item_instance_id, item_id
    FROM item_instances WHERE location_type = 'EQUIPMENT';

-- -----------------------------------------------------------------------------
-- NPCs, Monster, Loot (statisch)
-- -----------------------------------------------------------------------------
CREATE TABLE loot_tables (
    loot_table_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE
);

CREATE TABLE loot_entries (
    loot_table_id   INT NOT NULL REFERENCES loot_tables ON DELETE CASCADE,
    item_id         INT NOT NULL REFERENCES items,
    chance          NUMERIC(7,6) CHECK (chance > 0 AND chance <= 1),  -- NULL = UNKNOWN, droppt nicht
    min_qty         INT NOT NULL DEFAULT 1,
    max_qty         INT NOT NULL DEFAULT 1,
    PRIMARY KEY (loot_table_id, item_id),
    CHECK (min_qty > 0 AND max_qty >= min_qty)
);

CREATE TABLE npcs (
    npc_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    npc_role        TEXT NOT NULL CHECK (npc_role IN (
                        'HARBOR_MASTER', 'SHIPYARD', 'MERCHANT', 'BANK', 'STORAGE', 'QUEST',
                        'CRAFTING', 'GUILD', 'AUCTION', 'TAVERN', 'TRAVEL', 'DOCK_WORKER',
                        'OFFICER_EXCHANGE', 'OTHER')),
    port_id         INT REFERENCES ports,
    zone_id         TEXT REFERENCES zones,
    spawn           JSONB,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE monsters (
    monster_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    domain          TEXT NOT NULL CHECK (domain IN ('LAND', 'SEA')),
    is_pirate       BOOLEAN NOT NULL DEFAULT FALSE,
    is_boss         BOOLEAN NOT NULL DEFAULT FALSE,
    level           SMALLINT,
    hp              INT,
    stats           JSONB,
    ship_id         INT,                                   -- See-Gegner: Schiffsvorlage, FK unten
    loot_table_id   INT REFERENCES loot_tables,
    ai_profile      TEXT,                                  -- UE5 StateTree / Behavior Tree Asset
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

-- -----------------------------------------------------------------------------
-- Quests
-- -----------------------------------------------------------------------------
CREATE TABLE quests (
    quest_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    quest_type      TEXT NOT NULL CHECK (quest_type IN (
                        'MAIN', 'SIDE', 'PROFESSION', 'PIRATE', 'TREASURE', 'DUNGEON',
                        'DAILY', 'EVENT', 'GUILD', 'EXPLORATION')),
    title_zh        TEXT, title_en TEXT, title_de TEXT,
    description_de  TEXT,
    giver_npc_id    INT REFERENCES npcs,
    turn_in_npc_id  INT REFERENCES npcs,
    requirements    JSONB NOT NULL DEFAULT '{}'::jsonb,
    rewards         JSONB NOT NULL DEFAULT '{}'::jsonb,
    next_quest_id   INT REFERENCES quests,
    unlocks         JSONB NOT NULL DEFAULT '[]'::jsonb,
    repeatable      TEXT NOT NULL DEFAULT 'NO' CHECK (repeatable IN ('NO', 'DAILY', 'WEEKLY', 'ALWAYS')),
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE quest_objectives (
    quest_id        INT NOT NULL REFERENCES quests ON DELETE CASCADE,
    objective_no    SMALLINT NOT NULL,
    objective_type  TEXT NOT NULL CHECK (objective_type IN (
                        'KILL', 'COLLECT', 'DELIVER', 'TALK', 'REACH', 'SINK_SHIP', 'TRADE', 'CRAFT', 'DISCOVER')),
    target_ref      TEXT NOT NULL,
    required_count  INT NOT NULL DEFAULT 1 CHECK (required_count > 0),
    PRIMARY KEY (quest_id, objective_no)
);

CREATE TABLE quest_progress (
    character_id    BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    quest_id        INT    NOT NULL REFERENCES quests,
    status          TEXT   NOT NULL CHECK (status IN ('ACTIVE', 'COMPLETED', 'FAILED', 'ABANDONED')),
    objective_progress JSONB NOT NULL DEFAULT '{}'::jsonb,
    accepted_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    times_completed INT NOT NULL DEFAULT 0,
    PRIMARY KEY (character_id, quest_id)
);

-- -----------------------------------------------------------------------------
-- Schiffe
-- -----------------------------------------------------------------------------
CREATE TABLE ship_classes (
    ship_class_id   SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,                  -- BATTLE, RAIDER, MERCHANT, BEGINNER, SPECIAL
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    leveled_by      TEXT,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

-- Schiffsvorlagen. Alle Werte NULL = UNKNOWN; ein Schiff mit NULL in einem
-- Pflichtwert für die Bewegung kann vom Server nicht ausgegeben werden.
CREATE TABLE ships (
    ship_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    ship_class_id   SMALLINT NOT NULL REFERENCES ship_classes,
    ship_level      SMALLINT,
    hull_hp         INT, armor INT,
    speed           REAL, acceleration REAL, turning REAL,
    cargo_capacity  INT, crew_capacity INT,
    cannon_slots    SMALLINT, cannon_range REAL, reload_time REAL,
    sail_power      REAL, wind_efficiency REAL,
    cost_gold       BIGINT CHECK (cost_gold >= 0),
    requirements    JSONB,
    upgrade_slots   SMALLINT,
    mesh_asset      TEXT,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);
ALTER TABLE monsters ADD CONSTRAINT fk_monsters_ship FOREIGN KEY (ship_id) REFERENCES ships;

-- Umbaustufen 1..14, getrennt von der Schiffsstufe (siehe CONTRA-003).
CREATE TABLE ship_mod_tiers (
    tier            SMALLINT NOT NULL CHECK (tier > 0),
    direction       TEXT NOT NULL CHECK (direction IN ('BATTLE', 'RAIDER', 'MERCHANT')),
    cost_gold       BIGINT,
    materials       JSONB,
    level_req       SMALLINT,
    stat_bonus      JSONB,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN',
    PRIMARY KEY (tier, direction)
);

CREATE TABLE ship_mod_tier_ports (
    tier            SMALLINT NOT NULL,
    port_id         INT NOT NULL REFERENCES ports,
    PRIMARY KEY (tier, port_id)
);

CREATE TABLE ship_instances (
    ship_instance_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ship_id         INT    NOT NULL REFERENCES ships,
    owner_character_id BIGINT NOT NULL REFERENCES characters,
    custom_name     TEXT,
    hull_hp         INT NOT NULL CHECK (hull_hp >= 0),
    sail_hp         INT CHECK (sail_hp >= 0),
    crew_healthy    INT NOT NULL DEFAULT 0 CHECK (crew_healthy >= 0),
    crew_injured    INT NOT NULL DEFAULT 0 CHECK (crew_injured >= 0),
    provisions      INT NOT NULL DEFAULT 0 CHECK (provisions >= 0),
    mod_direction   TEXT CHECK (mod_direction IN ('BATTLE', 'RAIDER', 'MERCHANT')),
    mod_tier        SMALLINT NOT NULL DEFAULT 0 CHECK (mod_tier >= 0),
    exp_military    BIGINT NOT NULL DEFAULT 0,             -- Schiffs-Skills (SHIP-SKILLS)
    exp_maneuver    BIGINT NOT NULL DEFAULT 0,
    exp_structure   BIGINT NOT NULL DEFAULT 0,
    docked_port_id  INT REFERENCES ports,
    is_active       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (mod_tier = 0 OR mod_direction IS NOT NULL)
);
CREATE UNIQUE INDEX ux_ship_active ON ship_instances (owner_character_id) WHERE is_active;

-- Ausrüstung eines Schiffs (Kanonen, Panzerung, Galionsfigur, Segel, Module).
CREATE VIEW ship_equipment AS
    SELECT container_ref AS ship_instance_id, slot, item_instance_id, item_id
    FROM item_instances WHERE location_type = 'SHIP_EQUIPMENT';

-- -----------------------------------------------------------------------------
-- Offiziere / Adjutanten (副官)
-- -----------------------------------------------------------------------------
CREATE TABLE officers (
    officer_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    rarity          TEXT,
    base_attributes JSONB,
    skills          JSONB,
    special_ability TEXT,
    card_item_id    INT REFERENCES items,                  -- Offizierskarte
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE officer_instances (
    officer_instance_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    officer_id      INT    NOT NULL REFERENCES officers,
    owner_character_id BIGINT NOT NULL REFERENCES characters,
    level           SMALLINT NOT NULL DEFAULT 1,
    experience      BIGINT NOT NULL DEFAULT 0,
    role            TEXT,                                  -- Originalrollen UNKNOWN
    assigned_ship_instance_id BIGINT REFERENCES ship_instances
);

-- -----------------------------------------------------------------------------
-- Handel und Markt
-- -----------------------------------------------------------------------------
-- Warenpreise je Hafen. Der Server berechnet den Preis; Clients sehen nur das Ergebnis.
CREATE TABLE markets (
    port_id         INT NOT NULL REFERENCES ports,
    item_id         INT NOT NULL REFERENCES items,
    base_price      BIGINT CHECK (base_price > 0),         -- NULL = UNKNOWN, nicht handelbar
    supply          INT NOT NULL DEFAULT 0,
    demand          INT NOT NULL DEFAULT 0,
    current_buy     BIGINT,
    current_sell    BIGINT,
    tax_rate        NUMERIC(5,4) NOT NULL DEFAULT 0 CHECK (tax_rate BETWEEN 0 AND 1),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (port_id, item_id)
);

CREATE TABLE trade_routes (
    trade_route_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    from_port_id    INT NOT NULL REFERENCES ports,
    to_port_id      INT NOT NULL REFERENCES ports,
    owner_character_id BIGINT REFERENCES characters,       -- NULL = feste Route aus den Spieldaten
    distance        REAL,
    notes           TEXT,
    CHECK (from_port_id <> to_port_id)
);

-- Auktionshaus. Das angebotene Item liegt solange mit location_type = MARKET im Register.
CREATE TABLE market_listings (
    listing_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_character_id BIGINT NOT NULL REFERENCES characters,
    item_instance_id BIGINT NOT NULL UNIQUE REFERENCES item_instances,
    currency_code   TEXT NOT NULL REFERENCES currencies,
    price           BIGINT NOT NULL CHECK (price > 0),
    listing_fee     BIGINT NOT NULL DEFAULT 0 CHECK (listing_fee >= 0),
    status          TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'SOLD', 'CANCELLED', 'EXPIRED')),
    buyer_character_id BIGINT REFERENCES characters,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_market_listings_open ON market_listings (status, expires_at);

-- -----------------------------------------------------------------------------
-- Crafting
-- -----------------------------------------------------------------------------
CREATE TABLE recipes (
    recipe_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    required_skill_id SMALLINT NOT NULL REFERENCES skills,
    required_level  SMALLINT,
    craft_time_seconds INT CHECK (craft_time_seconds >= 0),
    result_item_id  INT NOT NULL REFERENCES items,
    result_quantity INT NOT NULL DEFAULT 1 CHECK (result_quantity > 0),
    quality_rule    JSONB,
    gold_cost       BIGINT CHECK (gold_cost >= 0),        -- Gold-Senke
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE recipe_materials (
    recipe_id       INT NOT NULL REFERENCES recipes ON DELETE CASCADE,
    item_id         INT NOT NULL REFERENCES items,
    quantity        INT NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (recipe_id, item_id)
);

-- -----------------------------------------------------------------------------
-- Gilden, Territorien, Kriege
-- -----------------------------------------------------------------------------
CREATE TABLE guilds (
    guild_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            TEXT NOT NULL,
    tag             TEXT,
    leader_character_id BIGINT NOT NULL REFERENCES characters,
    guild_level     SMALLINT NOT NULL DEFAULT 1,
    guild_exp       BIGINT NOT NULL DEFAULT 0,
    treasury_gold   BIGINT NOT NULL DEFAULT 0 CHECK (treasury_gold >= 0),
    banner          JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    disbanded_at    TIMESTAMPTZ
);
CREATE UNIQUE INDEX ux_guilds_name ON guilds (lower(name)) WHERE disbanded_at IS NULL;
ALTER TABLE item_instances ADD CONSTRAINT fk_item_owner_guild FOREIGN KEY (owner_guild_id) REFERENCES guilds;

CREATE TABLE guild_ranks (
    guild_id        BIGINT NOT NULL REFERENCES guilds ON DELETE CASCADE,
    rank_no         SMALLINT NOT NULL,
    name            TEXT NOT NULL,
    permissions     TEXT[] NOT NULL DEFAULT '{}',          -- z. B. INVITE, KICK, STORAGE_TAKE, CITY_MANAGE
    PRIMARY KEY (guild_id, rank_no)
);

CREATE TABLE guild_members (
    guild_id        BIGINT NOT NULL REFERENCES guilds ON DELETE CASCADE,
    character_id    BIGINT NOT NULL UNIQUE REFERENCES characters ON DELETE CASCADE,
    rank_no         SMALLINT NOT NULL,
    contribution    BIGINT NOT NULL DEFAULT 0,
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (guild_id, character_id),
    FOREIGN KEY (guild_id, rank_no) REFERENCES guild_ranks (guild_id, rank_no)
);

CREATE TABLE guild_invites (
    guild_id        BIGINT NOT NULL REFERENCES guilds ON DELETE CASCADE,
    character_id    BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    invited_by      BIGINT NOT NULL REFERENCES characters,
    expires_at      TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (guild_id, character_id)
);

CREATE TABLE guild_skills (
    guild_id        BIGINT NOT NULL REFERENCES guilds ON DELETE CASCADE,
    skill_code      TEXT NOT NULL,
    level           SMALLINT NOT NULL DEFAULT 1,
    PRIMARY KEY (guild_id, skill_code)
);

CREATE VIEW guild_storage AS
    SELECT owner_guild_id AS guild_id, slot, item_instance_id, item_id, quantity
    FROM item_instances WHERE location_type = 'GUILD_STORAGE';

-- Besetzbare Städte (SYS-GUILD: Städte kaufen und besetzen).
CREATE TABLE territories (
    territory_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_id         INT NOT NULL UNIQUE REFERENCES cities,
    owner_guild_id  BIGINT REFERENCES guilds,
    captured_at     TIMESTAMPTZ,
    tax_rate        NUMERIC(5,4) CHECK (tax_rate BETWEEN 0 AND 1),
    purchase_price  BIGINT,                                -- NULL = UNKNOWN
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE territory_wars (
    war_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    territory_id    INT NOT NULL REFERENCES territories,
    attacker_guild_id BIGINT NOT NULL REFERENCES guilds,
    defender_guild_id BIGINT REFERENCES guilds,
    scheduled_at    TIMESTAMPTZ NOT NULL,
    state           TEXT NOT NULL DEFAULT 'SCHEDULED' CHECK (state IN ('SCHEDULED', 'RUNNING', 'FINISHED', 'CANCELLED')),
    winner_guild_id BIGINT REFERENCES guilds,
    result          JSONB
);

-- -----------------------------------------------------------------------------
-- Dungeons und Events
-- -----------------------------------------------------------------------------
CREATE TABLE dungeons (
    dungeon_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    name_zh         TEXT, name_en TEXT, name_de TEXT,
    domain          TEXT CHECK (domain IN ('LAND', 'SEA')),
    zone_id         TEXT REFERENCES zones,
    min_level       SMALLINT,
    max_players     SMALLINT,
    loot_table_id   INT REFERENCES loot_tables,
    recon_id        TEXT,
    confidence      confidence_level NOT NULL DEFAULT 'UNKNOWN'
);

CREATE TABLE events (
    event_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    event_type      TEXT NOT NULL CHECK (event_type IN (
                        'PIRATE_ATTACK', 'TRADE', 'WORLD_BOSS', 'TREASURE_HUNT', 'NAVAL_BATTLE',
                        'GUILD_WAR', 'SEASONAL')),
    schedule        JSONB NOT NULL,                        -- Cron oder Intervall
    config          JSONB NOT NULL DEFAULT '{}'::jsonb,
    active          BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE event_runs (
    event_run_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id        INT NOT NULL REFERENCES events,
    zone_id         TEXT REFERENCES zones,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at        TIMESTAMPTZ,
    result          JSONB
);

-- -----------------------------------------------------------------------------
-- Soziales: Mail, Freunde, Chat, Moderation
-- -----------------------------------------------------------------------------
CREATE TABLE mail (
    mail_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sender_character_id BIGINT REFERENCES characters,      -- NULL = System
    recipient_character_id BIGINT NOT NULL REFERENCES characters,
    subject         TEXT NOT NULL,
    body            TEXT NOT NULL DEFAULT '',
    gold_attached   BIGINT NOT NULL DEFAULT 0 CHECK (gold_attached >= 0),
    sent_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at         TIMESTAMPTZ,
    claimed_at      TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_mail_recipient ON mail (recipient_character_id, sent_at);

CREATE TABLE friends (
    character_id    BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    friend_character_id BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (character_id, friend_character_id),
    CHECK (character_id <> friend_character_id)
);

CREATE TABLE ignores (
    character_id    BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    ignored_character_id BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    PRIMARY KEY (character_id, ignored_character_id),
    CHECK (character_id <> ignored_character_id)
);

CREATE TABLE chat_log (
    message_id      BIGINT GENERATED ALWAYS AS IDENTITY,
    channel         TEXT NOT NULL CHECK (channel IN ('LOCAL', 'WORLD', 'TRADE', 'GUILD', 'PARTY', 'WHISPER', 'SYSTEM', 'COMBAT')),
    sender_character_id BIGINT,
    target_ref      TEXT,                                  -- Gilde, Gruppe oder Empfänger
    zone_id         TEXT,
    message         TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (message_id, created_at)
) PARTITION BY RANGE (created_at);
CREATE TABLE chat_log_default PARTITION OF chat_log DEFAULT;

CREATE TABLE chat_mutes (
    character_id    BIGINT NOT NULL REFERENCES characters ON DELETE CASCADE,
    channel         TEXT,                                  -- NULL = alle Kanäle
    muted_until     TIMESTAMPTZ NOT NULL,
    reason          TEXT NOT NULL,
    admin_account_id BIGINT REFERENCES accounts,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_chat_mutes_char ON chat_mutes (character_id, muted_until);

CREATE TABLE player_reports (
    report_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reporter_character_id BIGINT NOT NULL REFERENCES characters,
    reported_character_id BIGINT NOT NULL REFERENCES characters,
    reason          TEXT NOT NULL,
    context         JSONB NOT NULL DEFAULT '{}'::jsonb,
    status          TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'REVIEWED', 'ACTIONED', 'DISMISSED')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- PvP und Piraten
-- -----------------------------------------------------------------------------
CREATE TABLE pvp_statistics (
    character_id    BIGINT PRIMARY KEY REFERENCES characters ON DELETE CASCADE,
    land_kills      INT NOT NULL DEFAULT 0,
    land_deaths     INT NOT NULL DEFAULT 0,
    ships_sunk      INT NOT NULL DEFAULT 0,
    ships_lost      INT NOT NULL DEFAULT 0,
    boardings_won   INT NOT NULL DEFAULT 0,
    wars_joined     INT NOT NULL DEFAULT 0,
    infamy          INT NOT NULL DEFAULT 0                 -- Grundlage für Kopfgelder
);

CREATE TABLE bounties (
    bounty_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    target_character_id BIGINT REFERENCES characters,
    target_monster_id INT REFERENCES monsters,
    placed_by_character_id BIGINT REFERENCES characters,   -- NULL = System
    amount_gold     BIGINT NOT NULL CHECK (amount_gold > 0),
    status          TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLAIMED', 'EXPIRED')),
    claimed_by_character_id BIGINT REFERENCES characters,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK ((target_character_id IS NULL) <> (target_monster_id IS NULL))
);

-- -----------------------------------------------------------------------------
-- Logging, Admin, Anti-Cheat
-- -----------------------------------------------------------------------------
CREATE TABLE game_event_log (
    log_id          BIGINT GENERATED ALWAYS AS IDENTITY,
    account_id      BIGINT,
    character_id    BIGINT,
    action          TEXT NOT NULL,                         -- z. B. ITEM_CREATE, TRADE_COMPLETE, LEVEL_UP
    old_value       JSONB,
    new_value       JSONB,
    session_id      UUID,
    ip              INET,
    server_id       TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (log_id, created_at)
) PARTITION BY RANGE (created_at);
CREATE TABLE game_event_log_default PARTITION OF game_event_log DEFAULT;
CREATE INDEX ix_game_event_log_char ON game_event_log (character_id, created_at);

-- Jede Admin-Aktion (/give, /setlevel, /ban ...) erzeugt genau eine Zeile.
CREATE TABLE admin_audit_log (
    audit_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    admin_account_id BIGINT NOT NULL REFERENCES accounts,
    command         TEXT NOT NULL,
    target_type     TEXT,
    target_id       TEXT,
    args            JSONB NOT NULL DEFAULT '{}'::jsonb,
    old_value       JSONB,
    new_value       JSONB,
    session_id      UUID,
    ip              INET,
    server_id       TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE anticheat_flags (
    flag_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id    BIGINT REFERENCES characters,
    check_type      TEXT NOT NULL CHECK (check_type IN (
                        'SPEED', 'POSITION', 'TELEPORT', 'DAMAGE', 'FIRE_RATE', 'INVENTORY',
                        'CURRENCY', 'ITEM_CREATION', 'SKILL_USAGE', 'SHIP_MOVEMENT', 'RPC_RATE')),
    severity        SMALLINT NOT NULL CHECK (severity BETWEEN 1 AND 5),
    details         JSONB NOT NULL,
    server_id       TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_by     BIGINT REFERENCES accounts,
    reviewed_at     TIMESTAMPTZ
);
CREATE INDEX ix_anticheat_flags_char ON anticheat_flags (character_id, created_at);

-- Admin-Protokolle sind nur anfügbar.
CREATE FUNCTION forbid_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION '% ist nur anfügbar (append-only)', TG_TABLE_NAME;
END $$;
CREATE TRIGGER trg_admin_audit_append_only
    BEFORE UPDATE OR DELETE ON admin_audit_log
    FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
CREATE TRIGGER trg_currency_ledger_append_only
    BEFORE UPDATE OR DELETE ON currency_ledger
    FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- Grunddaten ohne Spielwerte
INSERT INTO currencies (currency_code, tradeable) VALUES
    ('GOLD', TRUE), ('PREMIUM', FALSE), ('GUILD', FALSE), ('EVENT', FALSE);
