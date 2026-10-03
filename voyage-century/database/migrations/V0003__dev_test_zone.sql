-- V0003 – Testzone für Phase 1
--
-- Technische Zone (kein Spielinhalt), damit Positionen gespeichert werden können,
-- bevor echte Seegebiete und Städte existieren. Wird in Phase 4 durch die
-- Weltzonen ergänzt; die Zeile bleibt für Entwicklung und Tests bestehen.

INSERT INTO zones (zone_id, zone_kind, map_asset, max_players)
VALUES ('DEV_TESTZONE', 'LAND', '/Game/Maps/L_DevTestZone', 100);
