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
    ('MERCHANT', '商船', 'Merchant Ship', 'Handelsschiff', 'Handel', 'SHIPCLASS-MERCHANT', 'LIKELY'::confidence_level),
    ('RAIDER', '探险船', 'Raider Ship', 'Erkundungsschiff', 'Erkundung', 'SHIPCLASS-RAIDER', 'LIKELY'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    name_zh = EXCLUDED.name_zh,
    name_en = EXCLUDED.name_en,
    name_de = EXCLUDED.name_de,
    leveled_by = EXCLUDED.leveled_by,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

INSERT INTO cities (code, name_zh, name_en, name_de, coord_as_given, recon_id, confidence) VALUES
    ('ALGIERS', '阿尔及尔', 'Algiers', 'Algier', NULL, 'CITY-ALGIERS', 'UNCERTAIN'::confidence_level),
    ('ATHENS', '雅典', 'Athens', 'Athen', 'N38E23', 'CITY-ATHENS', 'LIKELY'::confidence_level),
    ('GENOA', '热那亚', 'Genoa', 'Genua', 'N40E5', 'CITY-GENOA', 'LIKELY'::confidence_level),
    ('HAMBURG', '汉堡', 'Hamburg', 'Hamburg', NULL, 'CITY-HAMBURG', 'LIKELY'::confidence_level),
    ('LONDON', '伦敦', 'London', 'London', 'N52E0', 'CITY-LONDON', 'LIKELY'::confidence_level),
    ('MUSCAT', '马斯喀特', 'Muscat', 'Maskat', NULL, 'CITY-MUSCAT', 'UNCERTAIN'::confidence_level),
    ('QUANZHOU', '泉州', 'Quanzhou', 'Quanzhou', NULL, 'CITY-QUANZHOU', 'LIKELY'::confidence_level),
    ('SEOUL', '汉城', 'Seoul (Hanseong)', 'Seoul (Hanseong)', NULL, 'CITY-SEOUL', 'LIKELY'::confidence_level),
    ('SEVILLE', '塞维利亚', 'Seville', 'Sevilla', 'N37W6', 'CITY-SEVILLE', 'LIKELY'::confidence_level),
    ('ZHIGU', '直沽', 'Zhigu (Tianjin)', 'Zhigu (Tianjin)', NULL, 'CITY-ZHIGU', 'UNCERTAIN'::confidence_level)
ON CONFLICT (code) DO UPDATE SET
    name_zh = EXCLUDED.name_zh,
    name_en = EXCLUDED.name_en,
    name_de = EXCLUDED.name_de,
    coord_as_given = EXCLUDED.coord_as_given,
    recon_id = EXCLUDED.recon_id,
    confidence = EXCLUDED.confidence;

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
