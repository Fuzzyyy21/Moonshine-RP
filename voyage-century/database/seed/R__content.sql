-- GENERIERT von tools/export_content.py aus reconstruction_db/ und design_data/.
-- Nicht von Hand bearbeiten. Wird vom Migrator als wiederholbares Skript ausgeführt,
-- sobald sich der Inhalt ändert. Feldgenaue Confidence steht im Datensatz recon_id.
-- Entfernte Datensätze werden hier nicht gelöscht, weil Laufzeitdaten darauf verweisen können.

INSERT INTO professions (code, name_zh, name_en, name_de, recon_id, confidence) VALUES
    ('ARMED_MERCHANT', '武装商人', 'Armed Businessman', 'Bewaffneter Händler', 'PROF-ARMED_MERCHANT', 'LIKELY'::confidence_level),
    ('CARIBBEAN_PIRATE', '加勒比海盗', 'Caribbean Pirate', 'Karibik-Pirat', 'PROF-CARIBBEAN_PIRATE', 'LIKELY'::confidence_level),
    ('IMPERIAL_GUARD', '帝国禁卫军', 'Imperial Guardian', 'Kaiserliche Garde', 'PROF-IMPERIAL_GUARD', 'LIKELY'::confidence_level),
    ('ROYAL_OFFICER', '皇家军官', 'Royal Military Officer', 'Königlicher Offizier', 'PROF-ROYAL_OFFICER', 'LIKELY'::confidence_level),
    ('TREASURE_HUNTER', '宝藏猎人', 'Treasure Hunter', 'Schatzjäger', 'PROF-TREASURE_HUNTER', 'UNCERTAIN'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    name_zh = EXCLUDED.name_zh,
    name_en = EXCLUDED.name_en,
    name_de = EXCLUDED.name_de,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

INSERT INTO skills (code, category_cn, ui_group, name_zh, name_en, name_de, recon_id, confidence) VALUES
    ('ALCHEMY', 'PRODUCTION', 'PROFESSION', NULL, 'Alchemy', 'Alchemie', 'SKILL-ALCHEMY', 'LIKELY'::confidence_level),
    ('AXE', 'COMBAT', 'COMBAT', '斧术', 'Axe-playing', 'Axt', 'SKILL-AXE', 'LIKELY'::confidence_level),
    ('BAREHAND', 'COMBAT', 'COMBAT', NULL, 'Bare-hand fighting', 'Unbewaffnet', 'SKILL-BAREHAND', 'LIKELY'::confidence_level),
    ('ELOQUENCE', 'TRADE', 'PROFESSION', NULL, 'Eloquence', 'Rhetorik', 'SKILL-ELOQUENCE', 'LIKELY'::confidence_level),
    ('FALCHION', 'COMBAT', 'COMBAT', '刀术', 'Falchion-playing', 'Klinge', 'SKILL-FALCHION', 'LIKELY'::confidence_level),
    ('FISHING', 'GATHERING', 'PROFESSION', NULL, 'Fishing', 'Fangen / Fischen', 'SKILL-FISHING', 'LIKELY'::confidence_level),
    ('FOUNDRY', 'PRODUCTION', 'PROFESSION', NULL, 'Foundry', 'Schmieden', 'SKILL-FOUNDRY', 'LIKELY'::confidence_level),
    ('MEDICINE', NULL, 'COMBAT', NULL, 'Medicine', 'Medizin', 'SKILL-MEDICINE', 'LIKELY'::confidence_level),
    ('MINING', 'GATHERING', 'PROFESSION', NULL, 'Mining', 'Bergbau', 'SKILL-MINING', 'LIKELY'::confidence_level),
    ('NAVIGATION', NULL, 'SEAFARING', NULL, 'Navigation', 'Navigation', 'SKILL-NAVIGATION', 'LIKELY'::confidence_level),
    ('PLANTING', 'GATHERING', 'PROFESSION', NULL, 'Planting', 'Landwirtschaft', 'SKILL-PLANTING', 'LIKELY'::confidence_level),
    ('SEA_BATTLE', NULL, 'SEAFARING', NULL, 'Sea Battle', 'Seekampf', 'SKILL-SEA_BATTLE', 'LIKELY'::confidence_level),
    ('SEWING', 'PRODUCTION', 'PROFESSION', NULL, 'Sewing', 'Schneiderei', 'SKILL-SEWING', 'LIKELY'::confidence_level),
    ('SHIPBUILDING', 'PRODUCTION', 'PROFESSION', NULL, 'Ship building', 'Schiffbau', 'SKILL-SHIPBUILDING', 'LIKELY'::confidence_level),
    ('SHOOTING', 'COMBAT', 'COMBAT', NULL, 'Shooting', 'Schusswaffen', 'SKILL-SHOOTING', 'LIKELY'::confidence_level),
    ('SWORD', 'COMBAT', 'COMBAT', '剑术', 'Sword-playing', 'Schwert', 'SKILL-SWORD', 'LIKELY'::confidence_level),
    ('TIMBER', 'GATHERING', 'PROFESSION', NULL, 'Timber-felling', 'Holzfällerei', 'SKILL-TIMBER', 'LIKELY'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    category_cn = EXCLUDED.category_cn,
    ui_group = EXCLUDED.ui_group,
    name_zh = EXCLUDED.name_zh,
    name_en = EXCLUDED.name_en,
    name_de = EXCLUDED.name_de,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

INSERT INTO skill_stages (stage_no, max_level, recon_id, confidence) VALUES
    (1, 31, 'SKILL-STAGES', 'LIKELY'::confidence_level),
    (2, 100, 'SKILL-STAGES', 'LIKELY'::confidence_level),
    (3, 120, 'SKILL-STAGES', 'LIKELY'::confidence_level)
ON CONFLICT (stage_no) DO UPDATE SET
    max_level = EXCLUDED.max_level,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

INSERT INTO ship_classes (code, name_zh, name_en, name_de, leveled_by, recon_id, confidence) VALUES
    ('BATTLE', '战船', 'Battle Ship', 'Kriegsschiff', 'Kämpfe gegen andere Schiffe auf Schlachtfeldern', 'SHIPCLASS-BATTLE', 'LIKELY'::confidence_level),
    ('BEGINNER', NULL, NULL, 'Anfängerschiff', NULL, 'SHIP-TIERS-INTL', 'UNCERTAIN'::confidence_level),
    ('MERCHANT', '商船', 'Merchant Ship', 'Handelsschiff', 'Handel', 'SHIPCLASS-MERCHANT', 'LIKELY'::confidence_level),
    ('RAIDER', '探险船', 'Raider Ship', 'Erkundungsschiff', 'Erkundung', 'SHIPCLASS-RAIDER', 'LIKELY'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    name_zh = EXCLUDED.name_zh,
    name_en = EXCLUDED.name_en,
    name_de = EXCLUDED.name_de,
    leveled_by = EXCLUDED.leveled_by,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

-- Zonen und Übergänge (design_data/world_layout.json, Designentscheidung). Zonen vor Städten wegen cities.zone_id.

INSERT INTO zones (zone_id, zone_kind, map_asset, max_players, pvp_mode, is_dev) VALUES
    ('CITY_ATHENS', 'CITY', '/Game/Maps/L_Athens', 150, 'NONE', FALSE),
    ('CITY_LONDON', 'CITY', '/Game/Maps/L_London', 150, 'NONE', FALSE),
    ('SEA_DEV', 'SEA', '/Game/Maps/L_SeaDev', 150, 'NONE', TRUE)
ON CONFLICT (zone_id) DO UPDATE SET
    zone_kind = EXCLUDED.zone_kind,
    map_asset = EXCLUDED.map_asset,
    max_players = EXCLUDED.max_players,
    pvp_mode = EXCLUDED.pvp_mode,
    is_dev = EXCLUDED.is_dev;

INSERT INTO cities (code, name_zh, name_en, name_de, coord_as_given, zone_id, recon_id, confidence) VALUES
    ('ALGIERS', '阿尔及尔', 'Algiers', 'Algier', NULL, NULL, 'CITY-ALGIERS', 'UNCERTAIN'::confidence_level),
    ('ATHENS', '雅典', 'Athens', 'Athen', 'N38E23', 'CITY_ATHENS', 'CITY-ATHENS', 'LIKELY'::confidence_level),
    ('GENOA', '热那亚', 'Genoa', 'Genua', 'N40E5', NULL, 'CITY-GENOA', 'LIKELY'::confidence_level),
    ('HAMBURG', '汉堡', 'Hamburg', 'Hamburg', NULL, NULL, 'CITY-HAMBURG', 'LIKELY'::confidence_level),
    ('LONDON', '伦敦', 'London', 'London', 'N52E0', 'CITY_LONDON', 'CITY-LONDON', 'LIKELY'::confidence_level),
    ('MUSCAT', '马斯喀特', 'Muscat', 'Maskat', NULL, NULL, 'CITY-MUSCAT', 'UNCERTAIN'::confidence_level),
    ('QUANZHOU', '泉州', 'Quanzhou', 'Quanzhou', NULL, NULL, 'CITY-QUANZHOU', 'LIKELY'::confidence_level),
    ('SEOUL', '汉城', 'Seoul (Hanseong)', 'Seoul (Hanseong)', NULL, NULL, 'CITY-SEOUL', 'LIKELY'::confidence_level),
    ('SEVILLE', '塞维利亚', 'Seville', 'Sevilla', 'N37W6', NULL, 'CITY-SEVILLE', 'LIKELY'::confidence_level),
    ('ZHIGU', '直沽', 'Zhigu (Tianjin)', 'Zhigu (Tianjin)', NULL, NULL, 'CITY-ZHIGU', 'UNCERTAIN'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    name_zh = EXCLUDED.name_zh,
    name_en = EXCLUDED.name_en,
    name_de = EXCLUDED.name_de,
    coord_as_given = EXCLUDED.coord_as_given,
    zone_id = EXCLUDED.zone_id,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

INSERT INTO ports (city_id, has_shipyard, services, recon_id, confidence) VALUES
    ((SELECT city_id FROM cities WHERE code = 'ALGIERS'), TRUE, '{}'::jsonb, 'SHIPMOD-T03_04', 'UNCERTAIN'::confidence_level),
    ((SELECT city_id FROM cities WHERE code = 'ATHENS'), TRUE, '{}'::jsonb, 'SHIPMOD-T01', 'UNCERTAIN'::confidence_level),
    ((SELECT city_id FROM cities WHERE code = 'GENOA'), TRUE, '{}'::jsonb, 'SHIPMOD-T02', 'UNCERTAIN'::confidence_level),
    ((SELECT city_id FROM cities WHERE code = 'HAMBURG'), TRUE, '{}'::jsonb, 'SHIPMOD-T07_08', 'UNCERTAIN'::confidence_level),
    ((SELECT city_id FROM cities WHERE code = 'LONDON'), NULL, '{"officer_card_exchange": true}'::jsonb, 'SYS-OFFICER-CARDS', 'UNCERTAIN'::confidence_level),
    ((SELECT city_id FROM cities WHERE code = 'MUSCAT'), TRUE, '{}'::jsonb, 'SHIPMOD-T09', 'UNCERTAIN'::confidence_level),
    ((SELECT city_id FROM cities WHERE code = 'SEOUL'), TRUE, '{}'::jsonb, 'SHIPMOD-T10', 'UNCERTAIN'::confidence_level),
    ((SELECT city_id FROM cities WHERE code = 'SEVILLE'), TRUE, '{}'::jsonb, 'SHIPMOD-T05_06', 'UNCERTAIN'::confidence_level),
    ((SELECT city_id FROM cities WHERE code = 'ZHIGU'), TRUE, '{}'::jsonb, 'SHIPMOD-T10', 'UNCERTAIN'::confidence_level)
ON CONFLICT (city_id) DO UPDATE SET
    has_shipyard = EXCLUDED.has_shipyard,
    services = EXCLUDED.services,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

INSERT INTO npcs (code, name_zh, name_en, name_de, npc_role, port_id, zone_id, recon_id, confidence) VALUES
    ('ALGIERS_SHIPYARD', '船老板', 'Shipyard Boss', 'Werftmeister', 'SHIPYARD', (SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'ALGIERS'), NULL, 'SHIP-ACQUISITION', 'UNCERTAIN'::confidence_level),
    ('ATHENS_SHIPYARD', '船老板', 'Shipyard Boss', 'Werftmeister', 'SHIPYARD', (SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'ATHENS'), 'CITY_ATHENS', 'SHIP-ACQUISITION', 'UNCERTAIN'::confidence_level),
    ('GENOA_SHIPYARD', '船老板', 'Shipyard Boss', 'Werftmeister', 'SHIPYARD', (SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'GENOA'), NULL, 'SHIP-ACQUISITION', 'UNCERTAIN'::confidence_level),
    ('HAMBURG_SHIPYARD', '船老板', 'Shipyard Boss', 'Werftmeister', 'SHIPYARD', (SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'HAMBURG'), NULL, 'SHIP-ACQUISITION', 'UNCERTAIN'::confidence_level),
    ('LONDON_OFFICER_EXCHANGE', '副官卡片兑换员', NULL, 'Offizierskarten-Tauscher', 'OFFICER_EXCHANGE', (SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'LONDON'), 'CITY_LONDON', 'SYS-OFFICER-CARDS', 'UNCERTAIN'::confidence_level),
    ('MUSCAT_SHIPYARD', '船老板', 'Shipyard Boss', 'Werftmeister', 'SHIPYARD', (SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'MUSCAT'), NULL, 'SHIP-ACQUISITION', 'UNCERTAIN'::confidence_level),
    ('SEOUL_SHIPYARD', '船老板', 'Shipyard Boss', 'Werftmeister', 'SHIPYARD', (SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'SEOUL'), NULL, 'SHIP-ACQUISITION', 'UNCERTAIN'::confidence_level),
    ('SEVILLE_SHIPYARD', '船老板', 'Shipyard Boss', 'Werftmeister', 'SHIPYARD', (SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'SEVILLE'), NULL, 'SHIP-ACQUISITION', 'UNCERTAIN'::confidence_level),
    ('ZHIGU_SHIPYARD', '船老板', 'Shipyard Boss', 'Werftmeister', 'SHIPYARD', (SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'ZHIGU'), NULL, 'SHIP-ACQUISITION', 'UNCERTAIN'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    name_zh = EXCLUDED.name_zh,
    name_en = EXCLUDED.name_en,
    name_de = EXCLUDED.name_de,
    npc_role = EXCLUDED.npc_role,
    port_id = EXCLUDED.port_id,
    zone_id = EXCLUDED.zone_id,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

-- Entdeckungen (design_data/dev_discoveries.json, is_dev = TRUE).

INSERT INTO discoveries (code, zone_id, name_de, xp_reward, is_dev, confidence) VALUES
    ('DEV_DISC_LONDON_LOOKOUT', 'CITY_LONDON', 'Aussichtspunkt (Test)', 30, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_DISC_SEA_WRECK', 'SEA_DEV', 'Wrack (Test)', 80, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_DISC_TESTZONE_RUIN', 'DEV_TESTZONE', 'Übungsruine', 50, TRUE, 'UNKNOWN'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    zone_id = EXCLUDED.zone_id,
    name_de = EXCLUDED.name_de,
    xp_reward = EXCLUDED.xp_reward,
    is_dev = EXCLUDED.is_dev,
    confidence = EXCLUDED.confidence;

INSERT INTO zone_links (from_zone_id, exit_code, to_zone_id, arrival_tag) VALUES
    ('CITY_ATHENS', 'HARBOR', 'SEA_DEV', 'ATHENS'),
    ('CITY_LONDON', 'HARBOR', 'SEA_DEV', 'LONDON'),
    ('CITY_LONDON', 'TO_TESTZONE', 'DEV_TESTZONE', 'FROM_LONDON'),
    ('DEV_TESTZONE', 'TO_LONDON', 'CITY_LONDON', 'FROM_TESTZONE'),
    ('SEA_DEV', 'ATHENS', 'CITY_ATHENS', 'HARBOR'),
    ('SEA_DEV', 'LONDON', 'CITY_LONDON', 'HARBOR')
ON CONFLICT (from_zone_id, exit_code) DO UPDATE SET
    to_zone_id = EXCLUDED.to_zone_id,
    arrival_tag = EXCLUDED.arrival_tag;

INSERT INTO item_sets (code, name_zh, name_en, name_de, level, recon_id, confidence) VALUES
    ('230-TRADE', NULL, NULL, '230er-Set mit Handels-Buff', 230, 'SET-230-TRADE', 'UNCERTAIN'::confidence_level),
    ('KING-148', '国王套装', NULL, 'Königs-Set', 148, 'SET-KING-148', 'LIKELY'::confidence_level),
    ('SIDONIA-150', '西多尼亚套装', NULL, 'Sidonia-Set', 150, 'SET-SIDONIA-150', 'LIKELY'::confidence_level),
    ('TALOS-168', '塔洛斯套装', NULL, 'Talos-Set', 168, 'SET-TALOS-168', 'LIKELY'::confidence_level),
    ('THOMAS-155', '托马斯套装', NULL, 'Thomas-Set', 155, 'SET-THOMAS-155', 'LIKELY'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    name_zh = EXCLUDED.name_zh,
    name_en = EXCLUDED.name_en,
    name_de = EXCLUDED.name_de,
    level = EXCLUDED.level,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

INSERT INTO game_rules (rule_key, int_value, recon_id, confidence) VALUES
    ('SKILL_TOTAL_CAP', 1700, 'SKILL-TOTAL-CAP', 'LIKELY'::confidence_level)
ON CONFLICT (rule_key) DO UPDATE SET
    int_value = EXCLUDED.int_value,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

-- Entwicklungskurven (design_data/dev_curves.json). Echte Werte aus der Reconstruction Database
-- überschreiben einzelne Stufen, sobald sie belegt sind (dann is_dev = FALSE).

INSERT INTO appearance_slots (slot, option_count, sort_order, is_dev, recon_id, confidence) VALUES
    ('face', 4, 0, TRUE, NULL, 'UNKNOWN'::confidence_level),
    ('hair', 4, 1, TRUE, NULL, 'UNKNOWN'::confidence_level),
    ('hairColor', 6, 2, TRUE, NULL, 'UNKNOWN'::confidence_level),
    ('skin', 4, 3, TRUE, NULL, 'UNKNOWN'::confidence_level),
    ('body', 3, 4, TRUE, NULL, 'UNKNOWN'::confidence_level),
    ('outfit', 2, 5, TRUE, NULL, 'UNKNOWN'::confidence_level)
ON CONFLICT (slot) DO UPDATE SET
    option_count = EXCLUDED.option_count,
    sort_order = EXCLUDED.sort_order,
    is_dev = EXCLUDED.is_dev,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

-- Entwicklungsinhalte Landkampf (design_data/dev_combat.json, is_dev = TRUE).

INSERT INTO items (code, item_type, weapon_class, name_de, base_stats, durability_max, is_dev, confidence) VALUES
    ('DEV_SWORD', 'WEAPON', 'SWORD', 'Übungsschwert', '{"attackInterval": 1.2, "baseDamage": 12, "rangeCm": 200, "skill": "SWORD"}'::jsonb, 100, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_BLADE', 'WEAPON', 'BLADE', 'Übungsklinge', '{"attackInterval": 1.0, "baseDamage": 10, "rangeCm": 190, "skill": "FALCHION"}'::jsonb, 100, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_AXE', 'WEAPON', 'AXE', 'Übungsaxt', '{"attackInterval": 2.0, "baseDamage": 18, "rangeCm": 180, "skill": "AXE"}'::jsonb, 100, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_PISTOL', 'WEAPON', 'FIREARM', 'Übungspistole', '{"attackInterval": 2.5, "baseDamage": 15, "rangeCm": 1500, "skill": "SHOOTING"}'::jsonb, 100, TRUE, 'UNKNOWN'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    item_type = EXCLUDED.item_type,
    weapon_class = EXCLUDED.weapon_class,
    name_de = EXCLUDED.name_de,
    base_stats = EXCLUDED.base_stats,
    durability_max = EXCLUDED.durability_max,
    is_dev = EXCLUDED.is_dev,
    confidence = EXCLUDED.confidence;

INSERT INTO monsters (code, name_de, domain, is_pirate, level, hp, stats, xp_reward, is_dev, confidence) VALUES
    ('DEV_TRAINING_DUMMY', 'Übungspuppe', 'LAND', FALSE, 1, 200, '{"aggro_radius_cm": 0, "attack_interval": 1.0, "attack_power": 0, "base_damage": 0, "defense": 0, "leash_radius_cm": 0, "range_cm": 0, "respawn_seconds": 10}'::jsonb, 20, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_PIRATE_BRAWLER', 'Übungspirat', 'LAND', TRUE, 3, 120, '{"aggro_radius_cm": 800, "attack_interval": 1.5, "attack_power": 2, "base_damage": 8, "defense": 5, "leash_radius_cm": 2000, "range_cm": 180, "respawn_seconds": 30}'::jsonb, 60, TRUE, 'UNKNOWN'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    name_de = EXCLUDED.name_de,
    domain = EXCLUDED.domain,
    is_pirate = EXCLUDED.is_pirate,
    level = EXCLUDED.level,
    hp = EXCLUDED.hp,
    stats = EXCLUDED.stats,
    xp_reward = EXCLUDED.xp_reward,
    is_dev = EXCLUDED.is_dev,
    confidence = EXCLUDED.confidence;

-- Entwicklungsfähigkeiten (design_data/dev_abilities.json, is_dev = TRUE). Statuseffekte sind reine
-- Laufzeit des Zonen-Servers (DT_StatusEffects) und werden nicht gespeichert.

INSERT INTO abilities (code, skill_id, name_de, ability_kind, domain, required_skill_level, gas_ability_class, params, is_dev, confidence) VALUES
    ('DEV_AIMED_SHOT', (SELECT skill_id FROM skills WHERE code = 'SHOOTING'), 'Gezielter Schuss', 'ACTIVE', 'LAND', 1, 'VCAbility_UseSkill', '{"applies": [], "cooldown_seconds": 12, "damage_multiplier": 2.0, "range_cm": 2000, "stamina_cost": 15, "target": "ENEMY", "weapon_class": "FIREARM"}'::jsonb, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_CRIPPLING_SLASH', (SELECT skill_id FROM skills WHERE code = 'FALCHION'), 'Sehnenschnitt', 'ACTIVE', 'LAND', 5, 'VCAbility_UseSkill', '{"applies": ["DEV_SLOW", "DEV_BLEED"], "cooldown_seconds": 10, "damage_multiplier": 1.0, "range_cm": 0, "stamina_cost": 12, "target": "ENEMY", "weapon_class": "BLADE"}'::jsonb, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_FIRST_AID', (SELECT skill_id FROM skills WHERE code = 'MEDICINE'), 'Erste Hilfe', 'ACTIVE', 'LAND', 1, 'VCAbility_UseSkill', '{"applies": ["DEV_REGEN"], "cooldown_seconds": 30, "damage_multiplier": 0, "range_cm": 0, "stamina_cost": 20, "target": "SELF", "weapon_class": null}'::jsonb, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_POWER_STRIKE', (SELECT skill_id FROM skills WHERE code = 'SWORD'), 'Wuchtschlag', 'ACTIVE', 'LAND', 1, 'VCAbility_UseSkill', '{"applies": [], "cooldown_seconds": 6, "damage_multiplier": 1.8, "range_cm": 0, "stamina_cost": 10, "target": "ENEMY", "weapon_class": "SWORD"}'::jsonb, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_STUNNING_BLOW', (SELECT skill_id FROM skills WHERE code = 'BAREHAND'), 'Betäubungsschlag', 'ACTIVE', 'LAND', 10, 'VCAbility_UseSkill', '{"applies": ["DEV_STUN"], "cooldown_seconds": 20, "damage_multiplier": 0.5, "range_cm": 0, "stamina_cost": 20, "target": "ENEMY", "weapon_class": "UNARMED"}'::jsonb, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_SUNDER', (SELECT skill_id FROM skills WHERE code = 'AXE'), 'Rüstungsbrecher', 'ACTIVE', 'LAND', 5, 'VCAbility_UseSkill', '{"applies": ["DEV_ARMOR_BREAK"], "cooldown_seconds": 8, "damage_multiplier": 1.2, "range_cm": 0, "stamina_cost": 15, "target": "ENEMY", "weapon_class": "AXE"}'::jsonb, TRUE, 'UNKNOWN'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    skill_id = EXCLUDED.skill_id,
    name_de = EXCLUDED.name_de,
    ability_kind = EXCLUDED.ability_kind,
    domain = EXCLUDED.domain,
    required_skill_level = EXCLUDED.required_skill_level,
    gas_ability_class = EXCLUDED.gas_ability_class,
    params = EXCLUDED.params,
    is_dev = EXCLUDED.is_dev,
    confidence = EXCLUDED.confidence;

-- Entwicklungsschiffe (design_data/dev_ships.json, is_dev = TRUE).

INSERT INTO ships (code, name_de, ship_class_id, ship_level, hull_hp, speed, acceleration, deceleration, turning, crew_min, crew_capacity, cargo_capacity, wind_efficiency, cost_gold, one_per_character, start_crew, start_provisions, provisions_max, cannon_slots, is_dev, confidence) VALUES
    ('DEV_BATTLE_SLOOP', 'Kriegsschaluppe (Test)', (SELECT ship_class_id FROM ship_classes WHERE code = 'BATTLE'), 2, 1500, 1000, 90, 180, 14, 10, 30, 80, 0.9, 5000, FALSE, 15, 400, 400, 16, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_MERCHANT_COG', 'Handelskogge (Test)', (SELECT ship_class_id FROM ship_classes WHERE code = 'MERCHANT'), 2, 1200, 750, 60, 150, 10, 8, 20, 300, 0.9, 5000, FALSE, 10, 400, 400, 6, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_RAIDER_CUTTER', 'Erkundungskutter (Test)', (SELECT ship_class_id FROM ship_classes WHERE code = 'RAIDER'), 2, 900, 1300, 140, 220, 22, 12, 40, 60, 0.9, 5000, FALSE, 20, 400, 400, 8, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_STARTER_SHIP', 'Anfängerschiff (Test)', (SELECT ship_class_id FROM ship_classes WHERE code = 'BEGINNER'), 1, 500, 900, 120, 200, 18, 4, 12, 50, 0.8, 0, TRUE, 6, 200, 200, 4, TRUE, 'UNKNOWN'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    name_de = EXCLUDED.name_de,
    ship_class_id = EXCLUDED.ship_class_id,
    ship_level = EXCLUDED.ship_level,
    hull_hp = EXCLUDED.hull_hp,
    speed = EXCLUDED.speed,
    acceleration = EXCLUDED.acceleration,
    deceleration = EXCLUDED.deceleration,
    turning = EXCLUDED.turning,
    crew_min = EXCLUDED.crew_min,
    crew_capacity = EXCLUDED.crew_capacity,
    cargo_capacity = EXCLUDED.cargo_capacity,
    wind_efficiency = EXCLUDED.wind_efficiency,
    cost_gold = EXCLUDED.cost_gold,
    one_per_character = EXCLUDED.one_per_character,
    start_crew = EXCLUDED.start_crew,
    start_provisions = EXCLUDED.start_provisions,
    provisions_max = EXCLUDED.provisions_max,
    cannon_slots = EXCLUDED.cannon_slots,
    is_dev = EXCLUDED.is_dev,
    confidence = EXCLUDED.confidence;

-- Hafenpreise (design_data/dev_ships.json, UNKNOWN im Original, is_dev = TRUE).

INSERT INTO game_rules (rule_key, int_value, is_dev, confidence) VALUES
    ('PROVISION_GOLD_PER_UNIT', 1, TRUE, 'UNKNOWN'::confidence_level),
    ('SAILOR_HEAL_GOLD', 20, TRUE, 'UNKNOWN'::confidence_level),
    ('SAILOR_HIRE_GOLD', 50, TRUE, 'UNKNOWN'::confidence_level),
    ('SHIP_REPAIR_GOLD_PER_HP', 2, TRUE, 'UNKNOWN'::confidence_level)
ON CONFLICT (rule_key) DO UPDATE SET
    int_value = EXCLUDED.int_value,
    is_dev = EXCLUDED.is_dev,
    confidence = EXCLUDED.confidence;

-- Piratenschiffe als Gegner (Kill-Belohnung wie bei Landgegnern über monsters).

INSERT INTO monsters (code, name_de, domain, is_pirate, hp, stats, xp_reward, is_dev, confidence) VALUES
    ('DEV_PIRATE_SLOOP', 'Piratenschaluppe (Test)', 'SEA', TRUE, 800, '{"aggro_radius_cm": 5000, "cannon": "DEV_CANNON_NEAR", "crew": 16, "leash_radius_cm": 15000, "respawn_seconds": 60}'::jsonb, 150, TRUE, 'UNKNOWN'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    name_de = EXCLUDED.name_de,
    domain = EXCLUDED.domain,
    is_pirate = EXCLUDED.is_pirate,
    hp = EXCLUDED.hp,
    stats = EXCLUDED.stats,
    xp_reward = EXCLUDED.xp_reward,
    is_dev = EXCLUDED.is_dev,
    confidence = EXCLUDED.confidence;

-- Hafenhandel (design_data/dev_trade.json, is_dev = TRUE). Bestände nur beim Anlegen: danach Laufzeitstand.

INSERT INTO items (code, item_type, name_de, stackable, max_stack, is_dev, confidence) VALUES
    ('DEV_GOOD_OIL', 'TRADE_GOOD', 'Öl (Test)', TRUE, 1000000, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_GOOD_SPICE', 'TRADE_GOOD', 'Gewürze (Test)', TRUE, 1000000, TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_GOOD_WOOL', 'TRADE_GOOD', 'Wolle (Test)', TRUE, 1000000, TRUE, 'UNKNOWN'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    item_type = EXCLUDED.item_type,
    name_de = EXCLUDED.name_de,
    stackable = EXCLUDED.stackable,
    max_stack = EXCLUDED.max_stack,
    is_dev = EXCLUDED.is_dev,
    confidence = EXCLUDED.confidence;

INSERT INTO npcs (code, name_de, npc_role, port_id, zone_id, is_dev, confidence) VALUES
    ('DEV_ATHENS_MERCHANT', 'Händler (Test)', 'MERCHANT', (SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'ATHENS'), 'CITY_ATHENS', TRUE, 'UNKNOWN'::confidence_level),
    ('DEV_LONDON_MERCHANT', 'Händler (Test)', 'MERCHANT', (SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'LONDON'), 'CITY_LONDON', TRUE, 'UNKNOWN'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    name_de = EXCLUDED.name_de,
    npc_role = EXCLUDED.npc_role,
    port_id = EXCLUDED.port_id,
    zone_id = EXCLUDED.zone_id,
    is_dev = EXCLUDED.is_dev,
    confidence = EXCLUDED.confidence;

INSERT INTO markets (port_id, item_id, base_price, stock, target_stock, restock_per_hour, tax_rate, is_dev) VALUES
    ((SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'ATHENS'), (SELECT item_id FROM items WHERE code = 'DEV_GOOD_OIL'), 45, 600, 600, 300, 0.05, TRUE),
    ((SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'ATHENS'), (SELECT item_id FROM items WHERE code = 'DEV_GOOD_SPICE'), 240, 100, 100, 40, 0.05, TRUE),
    ((SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'ATHENS'), (SELECT item_id FROM items WHERE code = 'DEV_GOOD_WOOL'), 95, 200, 200, 100, 0.05, TRUE),
    ((SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'LONDON'), (SELECT item_id FROM items WHERE code = 'DEV_GOOD_OIL'), 110, 200, 200, 100, 0.05, TRUE),
    ((SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'LONDON'), (SELECT item_id FROM items WHERE code = 'DEV_GOOD_SPICE'), 260, 100, 100, 40, 0.05, TRUE),
    ((SELECT port_id FROM ports JOIN cities USING (city_id) WHERE cities.code = 'LONDON'), (SELECT item_id FROM items WHERE code = 'DEV_GOOD_WOOL'), 40, 600, 600, 300, 0.05, TRUE)
ON CONFLICT (port_id, item_id) DO UPDATE SET
    base_price = EXCLUDED.base_price,
    target_stock = EXCLUDED.target_stock,
    restock_per_hour = EXCLUDED.restock_per_hour,
    tax_rate = EXCLUDED.tax_rate,
    is_dev = EXCLUDED.is_dev;

INSERT INTO game_rules (rule_key, int_value, is_dev, confidence) VALUES
    ('TRADE_ELASTICITY_PERMILLE', 700, TRUE, 'UNKNOWN'::confidence_level),
    ('TRADE_MAX_FACTOR_PERMILLE', 2500, TRUE, 'UNKNOWN'::confidence_level),
    ('TRADE_MIN_FACTOR_PERMILLE', 400, TRUE, 'UNKNOWN'::confidence_level),
    ('TRADE_SPREAD_PERMILLE', 100, TRUE, 'UNKNOWN'::confidence_level)
ON CONFLICT (rule_key) DO UPDATE SET
    int_value = EXCLUDED.int_value,
    is_dev = EXCLUDED.is_dev,
    confidence = EXCLUDED.confidence;

INSERT INTO level_table (level, xp_required, is_dev, recon_id, confidence) VALUES
    (1, 0, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (2, 100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (3, 400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (4, 900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (5, 1600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (6, 2500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (7, 3600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (8, 4900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (9, 6400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (10, 8100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (11, 10000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (12, 12100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (13, 14400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (14, 16900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (15, 19600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (16, 22500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (17, 25600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (18, 28900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (19, 32400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (20, 36100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (21, 40000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (22, 44100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (23, 48400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (24, 52900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (25, 57600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (26, 62500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (27, 67600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (28, 72900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (29, 78400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (30, 84100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (31, 90000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (32, 96100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (33, 102400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (34, 108900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (35, 115600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (36, 122500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (37, 129600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (38, 136900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (39, 144400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (40, 152100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (41, 160000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (42, 168100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (43, 176400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (44, 184900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (45, 193600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (46, 202500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (47, 211600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (48, 220900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (49, 230400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (50, 240100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (51, 250000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (52, 260100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (53, 270400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (54, 280900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (55, 291600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (56, 302500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (57, 313600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (58, 324900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (59, 336400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (60, 348100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (61, 360000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (62, 372100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (63, 384400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (64, 396900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (65, 409600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (66, 422500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (67, 435600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (68, 448900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (69, 462400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (70, 476100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (71, 490000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (72, 504100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (73, 518400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (74, 532900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (75, 547600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (76, 562500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (77, 577600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (78, 592900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (79, 608400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (80, 624100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (81, 640000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (82, 656100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (83, 672400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (84, 688900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (85, 705600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (86, 722500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (87, 739600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (88, 756900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (89, 774400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (90, 792100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (91, 810000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (92, 828100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (93, 846400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (94, 864900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (95, 883600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (96, 902500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (97, 921600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (98, 940900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (99, 960400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (100, 980100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (101, 1000000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (102, 1020100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (103, 1040400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (104, 1060900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (105, 1081600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (106, 1102500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (107, 1123600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (108, 1144900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (109, 1166400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (110, 1188100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (111, 1210000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (112, 1232100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (113, 1254400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (114, 1276900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (115, 1299600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (116, 1322500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (117, 1345600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (118, 1368900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (119, 1392400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (120, 1416100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (121, 1440000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (122, 1464100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (123, 1488400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (124, 1512900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (125, 1537600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (126, 1562500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (127, 1587600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (128, 1612900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (129, 1638400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (130, 1664100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (131, 1690000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (132, 1716100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (133, 1742400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (134, 1768900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (135, 1795600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (136, 1822500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (137, 1849600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (138, 1876900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (139, 1904400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (140, 1932100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (141, 1960000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (142, 1988100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (143, 2016400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (144, 2044900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (145, 2073600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (146, 2102500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (147, 2131600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (148, 2160900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (149, 2190400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (150, 2220100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (151, 2250000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (152, 2280100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (153, 2310400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (154, 2340900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (155, 2371600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (156, 2402500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (157, 2433600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (158, 2464900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (159, 2496400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (160, 2528100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (161, 2560000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (162, 2592100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (163, 2624400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (164, 2656900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (165, 2689600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (166, 2722500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (167, 2755600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (168, 2788900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (169, 2822400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (170, 2856100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (171, 2890000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (172, 2924100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (173, 2958400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (174, 2992900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (175, 3027600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (176, 3062500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (177, 3097600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (178, 3132900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (179, 3168400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (180, 3204100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (181, 3240000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (182, 3276100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (183, 3312400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (184, 3348900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (185, 3385600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (186, 3422500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (187, 3459600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (188, 3496900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (189, 3534400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (190, 3572100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (191, 3610000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (192, 3648100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (193, 3686400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (194, 3724900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (195, 3763600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (196, 3802500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (197, 3841600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (198, 3880900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (199, 3920400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (200, 3960100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (201, 4000000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (202, 4040100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (203, 4080400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (204, 4120900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (205, 4161600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (206, 4202500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (207, 4243600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (208, 4284900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (209, 4326400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (210, 4368100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (211, 4410000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (212, 4452100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (213, 4494400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (214, 4536900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (215, 4579600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (216, 4622500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (217, 4665600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (218, 4708900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (219, 4752400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (220, 4796100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (221, 4840000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (222, 4884100, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (223, 4928400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (224, 4972900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (225, 5017600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (226, 5062500, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (227, 5107600, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (228, 5152900, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (229, 5198400, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (230, 5244100, TRUE, NULL, 'UNKNOWN'::confidence_level)
ON CONFLICT (level) DO UPDATE SET
    xp_required = EXCLUDED.xp_required,
    is_dev = EXCLUDED.is_dev,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

INSERT INTO skill_level_table (level, xp_required, is_dev, recon_id, confidence) VALUES
    (1, 0, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (2, 50, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (3, 200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (4, 450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (5, 800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (6, 1250, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (7, 1800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (8, 2450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (9, 3200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (10, 4050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (11, 5000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (12, 6050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (13, 7200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (14, 8450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (15, 9800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (16, 11250, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (17, 12800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (18, 14450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (19, 16200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (20, 18050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (21, 20000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (22, 22050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (23, 24200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (24, 26450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (25, 28800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (26, 31250, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (27, 33800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (28, 36450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (29, 39200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (30, 42050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (31, 45000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (32, 48050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (33, 51200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (34, 54450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (35, 57800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (36, 61250, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (37, 64800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (38, 68450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (39, 72200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (40, 76050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (41, 80000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (42, 84050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (43, 88200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (44, 92450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (45, 96800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (46, 101250, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (47, 105800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (48, 110450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (49, 115200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (50, 120050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (51, 125000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (52, 130050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (53, 135200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (54, 140450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (55, 145800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (56, 151250, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (57, 156800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (58, 162450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (59, 168200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (60, 174050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (61, 180000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (62, 186050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (63, 192200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (64, 198450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (65, 204800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (66, 211250, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (67, 217800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (68, 224450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (69, 231200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (70, 238050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (71, 245000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (72, 252050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (73, 259200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (74, 266450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (75, 273800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (76, 281250, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (77, 288800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (78, 296450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (79, 304200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (80, 312050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (81, 320000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (82, 328050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (83, 336200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (84, 344450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (85, 352800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (86, 361250, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (87, 369800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (88, 378450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (89, 387200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (90, 396050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (91, 405000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (92, 414050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (93, 423200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (94, 432450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (95, 441800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (96, 451250, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (97, 460800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (98, 470450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (99, 480200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (100, 490050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (101, 500000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (102, 510050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (103, 520200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (104, 530450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (105, 540800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (106, 551250, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (107, 561800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (108, 572450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (109, 583200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (110, 594050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (111, 605000, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (112, 616050, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (113, 627200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (114, 638450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (115, 649800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (116, 661250, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (117, 672800, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (118, 684450, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (119, 696200, TRUE, NULL, 'UNKNOWN'::confidence_level),
    (120, 708050, TRUE, NULL, 'UNKNOWN'::confidence_level)
ON CONFLICT (level) DO UPDATE SET
    xp_required = EXCLUDED.xp_required,
    is_dev = EXCLUDED.is_dev,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;
