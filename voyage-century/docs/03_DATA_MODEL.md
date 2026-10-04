# Datenmodell

Stand: 2026-10-03 · Schema: [`../database/migrations/`](../database/migrations/) (PostgreSQL 16)

Getestet mit `tools/test_schema.sh`: alle Migrationen und Seeds werden in eine Wegwerf-Instanz
eingespielt, danach prüft [`../database/smoke_test.sql`](../database/smoke_test.sql)
die Schutzregeln (doppelter Slot, negatives Guthaben, append-only-Protokolle,
doppelte Buchung, ein aktives Schiff, Waffenklasse).

## Grundregeln

| Regel | Umsetzung |
|---|---|
| Keine erfundenen Werte | Spielwerte sind nullable; **NULL = UNKNOWN** |
| Herkunft nachvollziehbar | Inhaltstabellen haben `recon_id` und `confidence` |
| Eine Wahrheit für Items | `item_instances` mit genau einem Ort; `inventory`, `equipment`, `ship_equipment`, `guild_storage` sind Sichten |
| Eine Wahrheit für Geld | nur `character_wallets` (+ `guilds.treasury_gold`), jede Änderung in `currency_ledger` |
| Protokolle unveränderbar | Trigger verbieten UPDATE/DELETE auf `admin_audit_log` und `currency_ledger` |
| Große Logs | `game_event_log` und `chat_log` nach Zeit partitioniert |

## Tabellen nach Bereich

Die im Master-Prompt geforderten Tabellen sind **fett**.

| Bereich | Statisch (aus Reconstruction DB) | Laufzeit |
|---|---|---|
| Accounts | – | **accounts**, account_sessions |
| Welt | continents, regions, zones, **cities**, **ports** | – |
| Charakter | professions, level_table, titles, achievements | **characters**, **character_stats**, character_titles, character_reputation, character_achievements |
| Skills | **skills**, skill_stages, abilities | **skill_progress**, character_abilities |
| Geld | currencies | character_wallets, currency_ledger |
| Items | **items**, item_sets, **materials** | **item_instances**, Sichten **inventory**, **equipment** |
| NPC/Gegner | **npcs**, **monsters**, loot_tables, loot_entries | – |
| Quests | **quests**, quest_objectives | **quest_progress** |
| Schiffe | ship_classes, **ships**, ship_mod_tiers, ship_mod_tier_ports | **ship_instances**, Sicht **ship_equipment** |
| Offiziere | **officers** | officer_instances |
| Handel | – | **markets**, **trade_routes**, market_listings |
| Crafting | **recipes**, recipe_materials | – |
| Gilden | – | **guilds**, guild_ranks, **guild_members**, guild_invites, guild_skills, Sicht guild_storage |
| Territorium | **territories** | territory_wars |
| Inhalte | **dungeons**, **events** | event_runs |
| Sozial | – | **mail**, **friends**, ignores, chat_log, chat_mutes, player_reports |
| PvP/Piraten | – | **pvp_statistics**, bounties |
| Betrieb | – | game_event_log, admin_audit_log, anticheat_flags |

## Abbildung wichtiger Original-Befunde

| Befund | Abbildung |
|---|---|
| 17 Skills in 4 Kategorien (`SKILL-*`) | `skills.category_cn` (Original) + `skills.ui_group` (Prompt-Gruppierung) |
| Skillstufen 31/100/120 (`SKILL-STAGES`) | `skill_stages` + `skill_progress.stage_no` |
| Gesamtcap 1700 (`SKILL-TOTAL-CAP`) | Serverprüfung; Wert in Spielkonfiguration aus der Reconstruction DB |
| Militärrang (`SYS-MILITARY-RANK`) | `characters.military_rank` |
| Schiffsstufe vs. Umbaustufe (`CONTRA-003`) | `ships.ship_level` getrennt von `ship_instances.mod_tier` |
| Umbau an Städte gebunden (`SHIPMOD-T*`) | `ship_mod_tiers` + `ship_mod_tier_ports` |
| Drei Umbaurichtungen | `ship_instances.mod_direction` |
| Schiffs-Skills (`SHIP-SKILLS`) | `ship_instances.exp_military / exp_maneuver / exp_structure` |
| Matrosen gesund/verletzt (`SAILOR-SYSTEM`) | `crew_healthy`, `crew_injured`; tote Matrosen werden abgezogen |
| Proviant | `ship_instances.provisions` |
| Galionsfiguren, Kanonen, Panzerung | Items mit `item_type` FIGUREHEAD, CANNON, SHIP_PART, Ort SHIP_EQUIPMENT |
| Offizierskarten | `items.item_type = 'OFFICER_CARD'`, `officers.card_item_id` |
| Sockel, Verfeinerung | `item_instances.sockets`, `refinement_level` |
| Städte besetzen (`SYS-GUILD`) | `territories.owner_guild_id` |
| Koordinaten wie in der Quelle | `cities.coord_as_given` (Text, unverändert) |

## Bewusst offen gelassene Stellen

* `character_stats.attributes` ist JSON, weil die Originalattribute UNKNOWN sind. Sobald sie bekannt sind, werden sie zu Spalten.
* `items.rarity` ist Freitext ohne CHECK, weil die Originalstufen UNKNOWN sind.
* `officer_instances.role` ist Freitext aus demselben Grund.
## Migrationen

| Datei | Inhalt |
|---|---|
| `V0001__initial_schema.sql` | Ausgangsschema aus Phase 0 |
| `V0002__session_tickets.sql` | `account_sessions.token_hash` (SHA-256 des Tickets), `last_seen_at`, `server_id` |
| `V0003__dev_test_zone.sql` | technische Zone `DEV_TESTZONE` für Phase 1 |
| `V0004__progression.sql` | `level_table.is_dev`, `skill_level_table`, `game_rules` (z. B. `SKILL_TOTAL_CAP`), `progression_grants` (Idempotenz jeder XP-Vergabe) |
| `V0005__appearance.sql` | `appearance_slots` (Merkmale der Charaktererstellung und Anzahl Optionen, Designdaten) |
| `V0006__land_combat.sql` | `items.is_dev`, `monsters.is_dev`/`xp_reward`, `zones.pvp_mode` (Testzone = FREE), `combat_kills` (Kill-Protokoll, Idempotenz) |
| `seed/R__content.sql` | **generiert** aus der Reconstruction Database (Berufe, Skills, Skillstufen, Schiffsklassen, Städte, Sets) |

Regeln: Eine angewendete `V`-Datei wird nie mehr geändert (der Migrator bricht sonst ab);
Änderungen kommen als neue Datei. `R__content.sql` wird nur über `tools/export_content.py`
geändert und bei jeder Inhaltsänderung neu eingespielt. Der Migrator legt die Tabelle
`schema_migrations` selbst an.
