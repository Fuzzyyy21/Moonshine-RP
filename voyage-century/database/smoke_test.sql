-- Rauchtest für schema.sql. Läuft in einer Wegwerf-Datenbank (tools/test_schema.sh).
-- Prüft, dass die zentralen Schutzregeln greifen. Testdaten sind künstlich und
-- enthalten bewusst keine Spielwerte aus dem Original.
\set ON_ERROR_STOP on

INSERT INTO accounts (login, password_hash, admin_level) VALUES ('tester', 'argon2id$test', 5);
INSERT INTO professions (code, name_de) VALUES ('TEST_PROF', 'Testberuf');
INSERT INTO characters (account_id, name, gender, appearance, profession_id)
VALUES (1, 'Testkapitän', 'FEMALE', '{}'::jsonb, (SELECT profession_id FROM professions WHERE code = 'TEST_PROF'));
INSERT INTO character_wallets (character_id, currency_code, balance) VALUES (1, 'GOLD', 100);
INSERT INTO items (code, item_type, weapon_class, name_de) VALUES ('TEST_SWORD', 'WEAPON', 'SWORD', 'Testschwert');
INSERT INTO item_instances (item_id, location_type, owner_character_id, slot, origin)
VALUES ((SELECT item_id FROM items WHERE code = 'TEST_SWORD'), 'INVENTORY', 1, '0', 'ADMIN');

-- Unbekannte Spielwerte bleiben NULL statt erfundener Zahlen.
INSERT INTO ship_classes (code, name_de) VALUES ('TEST_CLASS', 'Testklasse');
INSERT INTO ships (code, ship_class_id, recon_id)
VALUES ('TEST_SHIP', (SELECT ship_class_id FROM ship_classes WHERE code = 'TEST_CLASS'), 'SHIP-STATS');
DO $$ BEGIN
    ASSERT (SELECT hull_hp IS NULL AND speed IS NULL FROM ships WHERE code = 'TEST_SHIP'),
        'Schiffswerte müssen ohne Quelle NULL (UNKNOWN) bleiben';
END $$;

-- 1. Zwei Items im selben Inventarslot sind verboten.
DO $$ BEGIN
    INSERT INTO item_instances (item_id, location_type, owner_character_id, slot, origin)
    VALUES ((SELECT item_id FROM items WHERE code = 'TEST_SWORD'), 'INVENTORY', 1, '0', 'ADMIN');
    RAISE EXCEPTION 'FEHLT: doppelter Slot wurde akzeptiert';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: doppelter Slot abgelehnt';
END $$;

-- 2. Negatives Guthaben ist verboten.
DO $$ BEGIN
    UPDATE character_wallets SET balance = -1 WHERE character_id = 1;
    RAISE EXCEPTION 'FEHLT: negatives Guthaben wurde akzeptiert';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'ok: negatives Guthaben abgelehnt';
END $$;

-- 3. Geldbuchungen sind nur anfügbar und idempotent.
INSERT INTO currency_ledger (character_id, currency_code, delta, balance_after, reason, flow, idempotency_key, server_id)
VALUES (1, 'GOLD', 100, 100, 'TEST_GRANT', 'SOURCE', '00000000-0000-0000-0000-000000000001', 'test');
DO $$ BEGIN
    UPDATE currency_ledger SET delta = 999;
    RAISE EXCEPTION 'FEHLT: Ledger-Update wurde akzeptiert';
EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'FEHLT%' THEN RAISE; END IF;
    RAISE NOTICE 'ok: Ledger ist append-only';
END $$;
DO $$ BEGIN
    INSERT INTO currency_ledger (character_id, currency_code, delta, balance_after, reason, flow, idempotency_key, server_id)
    VALUES (1, 'GOLD', 100, 200, 'TEST_GRANT', 'SOURCE', '00000000-0000-0000-0000-000000000001', 'test');
    RAISE EXCEPTION 'FEHLT: doppelte Buchung wurde akzeptiert';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: doppelte Buchung abgelehnt';
END $$;

-- 4. Admin-Audit ist nur anfügbar.
INSERT INTO admin_audit_log (admin_account_id, command, target_type, target_id, server_id)
VALUES (1, '/setlevel', 'CHARACTER', '1', 'test');
DO $$ BEGIN
    DELETE FROM admin_audit_log;
    RAISE EXCEPTION 'FEHLT: Audit-Löschung wurde akzeptiert';
EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'FEHLT%' THEN RAISE; END IF;
    RAISE NOTICE 'ok: Audit-Log ist append-only';
END $$;

-- 5. Nur ein aktives Schiff pro Charakter.
INSERT INTO ship_instances (ship_id, owner_character_id, hull_hp, is_active)
VALUES ((SELECT ship_id FROM ships WHERE code = 'TEST_SHIP'), 1, 0, TRUE);
DO $$ BEGIN
    INSERT INTO ship_instances (ship_id, owner_character_id, hull_hp, is_active)
    VALUES ((SELECT ship_id FROM ships WHERE code = 'TEST_SHIP'), 1, 0, TRUE);
    RAISE EXCEPTION 'FEHLT: zweites aktives Schiff wurde akzeptiert';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: nur ein aktives Schiff';
END $$;

-- 6. Waffe ohne Waffenklasse ist verboten.
DO $$ BEGIN
    INSERT INTO items (code, item_type) VALUES ('BROKEN_WEAPON', 'WEAPON');
    RAISE EXCEPTION 'FEHLT: Waffe ohne Klasse wurde akzeptiert';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'ok: Waffenklasse erzwungen';
END $$;

-- 7. Sichten liefern das Register.
DO $$ BEGIN
    ASSERT (SELECT count(*) FROM inventory WHERE character_id = 1) = 1, 'inventory-Sicht falsch';
END $$;

-- 8. Seed aus der Reconstruction Database ist eingespielt (falls vorhanden).
DO $$ BEGIN
    ASSERT (SELECT count(*) FROM professions WHERE recon_id LIKE 'PROF-%') IN (0, 5), 'Berufe-Seed unvollständig';
    ASSERT NOT EXISTS (SELECT 1 FROM skills WHERE name_zh = 'UNKNOWN'), 'UNKNOWN darf nicht als Text in der DB landen';
END $$;

-- 9. Hotbar: Platz 0–9, jeder Platz und jede Fähigkeit nur einmal je Charakter.
INSERT INTO abilities (code, ability_kind, domain) VALUES ('TEST_ABILITY_A', 'ACTIVE', 'LAND'), ('TEST_ABILITY_B', 'ACTIVE', 'LAND');
INSERT INTO character_hotbar (character_id, slot, ability_id)
VALUES (1, 0, (SELECT ability_id FROM abilities WHERE code = 'TEST_ABILITY_A'));
DO $$ BEGIN
    INSERT INTO character_hotbar (character_id, slot, ability_id)
    VALUES (1, 0, (SELECT ability_id FROM abilities WHERE code = 'TEST_ABILITY_B'));
    RAISE EXCEPTION 'FEHLT: doppelter Hotbar-Platz wurde akzeptiert';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: Hotbar-Platz eindeutig';
END $$;
DO $$ BEGIN
    INSERT INTO character_hotbar (character_id, slot, ability_id)
    VALUES (1, 1, (SELECT ability_id FROM abilities WHERE code = 'TEST_ABILITY_A'));
    RAISE EXCEPTION 'FEHLT: Fähigkeit doppelt auf der Hotbar wurde akzeptiert';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: Fähigkeit nur einmal auf der Hotbar';
END $$;
DO $$ BEGIN
    INSERT INTO character_hotbar (character_id, slot, ability_id)
    VALUES (1, 10, (SELECT ability_id FROM abilities WHERE code = 'TEST_ABILITY_B'));
    RAISE EXCEPTION 'FEHLT: Hotbar-Platz 10 wurde akzeptiert';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'ok: Hotbar hat zehn Plätze';
END $$;
DO $$ BEGIN
    ASSERT (SELECT count(*) FROM abilities WHERE code LIKE 'DEV_%' AND NOT is_dev) = 0, 'DEV-Fähigkeit ohne is_dev';
END $$;

-- 10. Partitionierte Logs nehmen Zeilen an.
INSERT INTO game_event_log (character_id, action, new_value, server_id) VALUES (1, 'LEVEL_UP', '{"level":2}', 'test');
INSERT INTO chat_log (channel, sender_character_id, message) VALUES ('WORLD', 1, 'Hallo');

\echo 'SMOKE TEST PASSED'
