# Roadmap

Reihenfolge und Prioritäten nach Master-Prompt, Abschnitte 38 und 41.
Jede Phase endet erst, wenn ihre Abnahmekriterien erfüllt sind.

## Phase 0 – Research (laufend)

| Ergebnis | Status |
|---|---|
| Recherchebericht | ✅ erste Runde ([00](00_PHASE0_RESEARCH_REPORT.md)) |
| Reconstruction Database mit Validator | ✅ 97 Datensätze, 28 Quellen |
| GDD-Gerüst | ✅ ([01](01_GAME_DESIGN_DOCUMENT.md)) |
| Technische Architektur | ✅ bestätigt mit Start von Phase 1 ([02](02_TECHNICAL_ARCHITECTURE.md)) |
| Relationales Datenmodell | ✅ getestet ([03](03_DATA_MODEL.md)) |
| Protokoll für Dateianalyse + Inventar-Tool | ✅ ([04](04_FILE_ANALYSIS_PROTOCOL.md)) |
| Volltext der offiziellen Quellen | ❌ blockiert (Netzwerk) |
| Screenshot- und Videoanalyse | ❌ kein Material |
| Erste CONFIRMED-Datensätze | ❌ |

**Abnahme Phase 0**: Architektur und Backend-Sprache bestätigt; offene Fragen 1–4
aus dem Recherchebericht mindestens auf LIKELY oder bewusst als `[DESIGN]` entschieden.

## Phase 1 – Technische Grundlage (in Arbeit)

| Schritt | Status | Prüfung |
|---|---|---|
| Migrationen + Migrator (Prüfsummen, Reihenfolge, Rollback, Seeds) | ✅ | `tools/test_schema.sh`, Migrator-Tests |
| Export-Tool Reconstruction DB → Seed-SQL + Data-Table-JSON, `--check` für CI | ✅ | `python3 tools/export_content.py --check` |
| Auth-Dienst: Registrierung, Login (argon2id), Ticket, Logout, Ticketprüfung, Rate-Limit, Sperren | ✅ | Backend-Tests |
| GameData-Dienst: Charaktere, Zustand laden/speichern mit Besitzprüfung, Admin-Audit | ✅ | Backend-Tests |
| Strukturiertes JSON-Logging, Konfiguration pro Umgebung, Schutz vor Dev-Keys | ✅ | Backend-Tests, Prozesslauf |
| CI für Daten, Datenbank und Backend | ✅ | GitHub Actions |
| UE5-Projekt: Module, Targets, Ticket-Login, Positions-Persistenz, Admin-Teleport mit Audit | ⚠️ geschrieben, **nicht kompiliert** | lokaler Build nötig ([unreal/README.md](../unreal/README.md)) |
| UE5-Build in CI | ❌ | braucht Runner mit Unreal Engine |
| Testkarte und Data-Table-Assets | ❌ | einmalig im Editor anlegen |

**Abnahme**: Zwei Clients loggen ein, sehen sich in einer Testzone, Position wird gespeichert und nach Neustart geladen. Ein Admin-Kommando landet im Audit-Log.

Die Backend-Seite dieser Abnahme ist automatisiert getestet
(`ZoneServerFlowTests`: Login → Ticket → Laden → Speichern → Neustart → Laden → Audit).
Die Engine-Seite steht aus, bis das UE-Projekt lokal gebaut und nach
[unreal/README.md](../unreal/README.md) durchgespielt wurde.

Offen für die nächsten Iterationen: World Directory mit Sperre gegen Doppel-Login,
Redis, TLS-Terminierung, mTLS zwischen Diensten.

## Phase 2 – Charakter (Iteration 1 und 2 fertig)

Charaktererstellung, Bewegung, Kamera, Animation, Attribute, Level, XP, Skills (17 Skills, Stufen, Gesamtcap).
**Abnahme**: Skill-XP und Level werden serverseitig vergeben, überleben Zonenwechsel und Neustart; manipulierte Client-Werte haben keine Wirkung.

| Schritt | Status | Prüfung |
|---|---|---|
| Progression im Backend: Charakter-XP, Skill-XP, Level aus lückenloser Kurve, Skillstufen-Grenze, Gesamtcap 1700, Idempotenz, Sperre pro Charakter | ✅ | `ProgressionTests` (12 Tests) |
| Admin `/setlevel`, `/setskill` mit Audit in derselben Transaktion | ✅ | `ProgressionTests` |
| Entwicklungskurven klar getrennt (`is_dev`, nur mit `Progression:AllowDevCurves`) | ✅ | Test „ohne bekannte Schwellen kein Aufstieg“ |
| UE: Bewegung + Kamera (Enhanced Input, serverseitig korrigierte Character Movement) | ⚠️ geschrieben, nicht kompiliert | lokal |
| UE: replizierte Progression (Level für alle, XP/Skills nur für den Besitzer), Übernahme nur von Backend-Werten | ⚠️ geschrieben, nicht kompiliert | lokal |
| UE: Admin `givexp`, `giveskillxp`, `setlevel`, `setskill`, Client `VCStatus` | ⚠️ geschrieben, nicht kompiliert | lokal |
| Erscheinungsbild: Merkmale als Daten (`appearance_slots`), serverseitige Prüfung und Normalisierung, Endpunkt `/v1/character-options` | ✅ | `AppearanceTests` (9 Tests) |
| UE: Login-/Erstellungsoberfläche (Slate), baut sich aus `/v1/character-options` auf | ⚠️ geschrieben, nicht kompiliert | lokal |
| UE: Erscheinungsbild repliziert und auf Platzhalterfigur angewendet (Haut, Haare, Haarfarbe, Körperbau) | ⚠️ geschrieben, nicht kompiliert | lokal |
| UE: Animations-Andockstelle (`UVCAnimInstance`, Modell/AnimBP per Projekteinstellung) | ⚠️ geschrieben, nicht kompiliert | lokal |
| Echte Modelle und Animationen | ❌ blockiert | brauchen Assets (Erstellung oder Lizenz) |
| Gesicht und Kleidung sichtbar | ❌ blockiert | Platzhalterform hat keine sinnvolle Darstellung; Werte werden gespeichert |
| Attribute | ❌ blockiert | Originalattribute UNKNOWN |
| Beförderung in Skillstufe 2/3 durch Spieler | ❌ blockiert | Bedingungen UNKNOWN; nur per `/setskill` |

Zonenwechsel ist in der Abnahme enthalten, es gibt aber noch nur eine Zone. Getestet ist die gleichwertige
Bedingung „Dienst-Neustart“; der echte Zonenwechsel folgt mit dem World Directory.

## Phase 3 – Landkampf (Iteration 2 fertig)

Waffen, Angriffe, Fähigkeiten (GAS), Schaden, NPC-KI, PvE, PvP-Grundregeln.

| Schritt | Status | Prüfung |
|---|---|---|
| Kampfregeln als reines C++ (`VCRules`): Werte ableiten, Waffenschaden mit Skillbonus, Ausweichen → Block → Krit, Reichweite, Angriffsintervall | ✅ | `tools/test_rules.sh` (14 Fälle, GCC und Clang, Unreal-Compilerflags) |
| Regeln für Fähigkeiten und Statuseffekte (`VCAbilityRules`): Einsatzprüfung in fester Reihenfolge, Abklingzeit mit Toleranz, Stapeln/Auffrischen/Ablauf, Modifikatoren, Schaden/Heilung über Zeit | ✅ It. 2 | `tools/test_rules.sh` (16 weitere Fälle) |
| Kampfdaten: Tuning, 5 Entwicklungswaffen, 2 Entwicklungsgegner (`is_dev`); HP/SP pro Stufe aus der Reconstruction DB | ✅ | Export `--check`, Schematest |
| Fähigkeitsdaten: 6 Entwicklungsfähigkeiten, 5 Statuseffekte, Ausdauer-Regeneration (`design_data/dev_abilities.json`); `V0007` (Hotbar, `abilities.is_dev`) | ✅ It. 2 | Export `--check` (prüft Querverweise), Schematest |
| Backend: Hotbar speichern/laden (ganze Belegung, Besitzprüfung, nur bekannte und freigegebene Fähigkeiten) | ✅ It. 2 | `HotbarTests` (9 Tests) |
| Backend: Kill melden (XP aus Gegnerdaten, Idempotenz), PvP nur in `FREE`-Zonen, PvP-Statistik, Zoneninfo, Leben/Ausdauer speichern | ✅ | `CombatTests` (11 Tests) |
| UE: GAS – Attribute, Schadensberechnung über `VCRules`, Grundangriff (nur Server) | ⚠️ geschrieben, nicht kompiliert | lokal |
| UE: Zielwahl (Tab), Angriff (linke Maustaste), Tod, Respawn, Skill-XP pro Treffer | ⚠️ geschrieben, nicht kompiliert | lokal |
| UE: Gegner, Zustandsautomat-KI (Aggro, Verfolgen, Angriff, Leine), Spawner | ⚠️ geschrieben, nicht kompiliert | lokal, braucht NavMesh |
| UE: ein Kampfablauf für alle Angriffe (`FVCCombat`), Fähigkeiten aus Daten (`UVCAbility_UseSkill`), Statuseffekte (`UVCCombatStateComponent`), Betäubung/Verlangsamung auch für Gegner-KI | ⚠️ It. 2, geschrieben, nicht kompiliert | lokal |
| UE: Hotbar (Tasten 1–0, `VCHotbar`), Speicherung über das Backend, Abklingzeiten | ⚠️ It. 2, geschrieben, nicht kompiliert | lokal |
| UE: HUD (Leben/Ausdauer, Zielrahmen, Statuseffekte, Hotbar, Kampftexte, Hinweis bei abgelehnter Fähigkeit) | ⚠️ It. 2, geschrieben, nicht kompiliert | lokal |
| Fähigkeiten für Gegner, Combos | ❌ Combos im Original nicht belegt; Gegnerfähigkeiten folgen mit belegten Gegnern | |
| Beute/Drops | ✅ mit dem Inventar (Phase 6, It. 2) | `InventoryTests` |
| Originalwerte für Waffen, Gegner, Formeln | ❌ blockiert | UNKNOWN |

**Abnahme (Vorschlag)**: Spieler besiegt einen Gegner und erhält die im Backend hinterlegte XP; Waffenskill steigt durch Treffer; PvP-Kill nur in PvP-Zonen; Tod führt zu Respawn; manipulierte Schadens- oder Reichweitenangaben des Clients haben keine Wirkung (der Client sendet nur das Ziel).

**Abnahme Iteration 2 (Vorschlag)**: Fähigkeit auf die Hotbar legen, Server und Backend neu starten → Belegung ist noch da; Fähigkeit kostet Ausdauer und startet die Abklingzeit, zweiter Einsatz vorher wird mit Hinweis abgelehnt; ohne passende Waffe oder Skillstufe keine Wirkung; Blutung tickt und ein Kill durch Blutung zählt für den Verursacher; Betäubung stoppt Bewegung und Angriffe auch bei Gegnern; der Client kann nur einen Hotbar-Platz und ein Ziel nennen.

## Phase 4 – Welt (Iteration 2 fertig)

Erste Seezone und zwei Häfen (Kandidaten: London, Athen, weil am besten belegt), NPCs, ein Land-Dungeon, Entdeckungen.

| Schritt | Status | Prüfung |
|---|---|---|
| Weltdaten: Zonen London, Athen, technische Seezone; Übergänge; Häfen mit belegten Diensten (Rest NULL); `V0008` | ✅ It. 1 | Export `--check` (prüft Zonen, Städte, Codes), Schematest |
| Seegebiete/Regionen | ❌ blockiert | einzige Liste mit Vermischungsgefahr (`REGION-LIST-17173`) |
| World Directory: Server-Anmeldung und Lebenszeichen, eine Anwesenheit je Charakter, Zonenwechsel über Ausgänge, Server-Suche für Clients, Speichern nur vom zuständigen Server | ✅ It. 1 | `WorldTests` (13 Tests) |
| UE: Modul `VCWorld` mit `AVCZoneExit`; GameMode meldet sich an, holt den Charakter, setzt ihn am Ankunftspunkt ab, wechselt die Zone, gibt beim Ausloggen frei; Client `VCPlay` und automatische Server-Suche | ⚠️ It. 1, geschrieben, nicht kompiliert | lokal, braucht Karten |
| NPC-Daten: Werftmeister in Städten mit belegtem Schiffsumbau, Offizierskarten-Tauscher in London (Hafenarbeiter: Ort nicht belegt) | ✅ It. 2 | Export `--check`, Schematest |
| Entdeckungen: `V0009`, einmal je Charakter, nur in der eigenen Zone vom zuständigen Server, Belohnung aus Daten | ✅ It. 2 | `DiscoveryTests` (3 Tests) |
| UE: `AVCNpc` (Ansprechen mit E, Server prüft Abstand, NPC-Fenster im HUD), `AVCDiscoveryPoint`, Meldung „Entdeckt“ | ⚠️ It. 2, geschrieben, nicht kompiliert | lokal, braucht Karten |
| NPC-Dienste (Werft, Offizierskarten) | ❌ mit Phase 5 bzw. Offizieren | |
| Land-Dungeon als Instanz | ❌ Iteration 3 | Dungeons des Originals ohne Details (`DUNGEON-*`) |

**Abnahme Iteration 2 (Vorschlag)**: In London spricht man den Offizierskarten-Tauscher mit E an und sieht Rolle und Beleg; aus größerer Entfernung passiert nichts; ein Entdeckungspunkt gibt einmal XP, ein zweites Mal nichts, auch nach Neustart nicht.

**Abnahme Iteration 1 (Vorschlag)**: Drei Server (Testzone, London, Seezone) und Backend laufen; Client verbindet ohne Adresse über das World Directory; Ausgang in London führt auf die Seezone an den Ankunftspunkt LONDON; derselbe Charakter kann sich nicht gleichzeitig ein zweites Mal einloggen; nach dem Wechsel kann der alte Server den Charakter nicht mehr speichern; ein Neustart von Server und Backend lässt den Charakter in der neuen Zone weiterspielen.

## Phase 5 – Schiffe (Iteration 3 fertig)

Schiffskauf beim Werftmeister, Segelmodell, Wind, Wasser, Schiffsausrüstung, Matrosen, Seekampf, Entern. Lasttest für große Seeschlachten.

| Schritt | Status | Prüfung |
|---|---|---|
| Segelregeln (`VCShipRules`): Wind, Polare, Matrosen, Proviant, Beschleunigen, Wenden | ✅ It. 1 | `tools/test_rules.sh` (7 weitere Fälle) |
| Schiffsdaten: Klasse BEGINNER (Anfängerschiff), 4 Entwicklungsschiffe mit belegten Rangfolgen, Segel-Tuning, Wind je Seezone; `V0010` | ✅ It. 1 | Export `--check` (prüft Rangfolgen), Schematest |
| Backend: Gold mit Ledger, Admin-Gold, Kauf beim Werftmeister der eigenen Zone, aktives Schiff, Schiffszustand (nur sinkend) | ✅ It. 1 | `ShipTests` (6 Tests) |
| UE: Modul `VCNaval` – Schiff als Spielfigur auf See, Fahrt nur auf dem Server, Steuerung, Wind, HUD; Kauf und Befehle | ⚠️ It. 1, geschrieben, nicht kompiliert | lokal |
| Seekampf-Regeln (`VCNavalCombatRules`): Feuerwinkel der Breitseiten, Trefferchance nach Entfernung, Rumpfschaden, Matrosen verletzt/tot, Nachladen | ✅ It. 2 | `tools/test_rules.sh` (5 weitere Fälle) |
| Daten: Nah- und Fernkanone, Kanonenplätze (Rangfolge geprüft), Hafenpreise, Piratenschiff; `V0011` | ✅ It. 2 | Export `--check`, Schematest |
| Backend: Hafendienste beim Werftmeister (Reparatur, Heilen, Anheuern, Proviant) über den Ledger, Obergrenzen, idempotent; verletzte Matrosen im Schiffszustand | ✅ It. 2 | `ShipTests` (+2 Tests) |
| UE: Breitseiten Q/E, Kanonenwahl R, Treffer und Sinken auf dem Server, Piratenschiff mit KI und Spawner, XP für versenkte Piraten, Sinken → zurück an Land, HUD | ⚠️ It. 2, geschrieben, nicht kompiliert | lokal |
| Fähigkeiten-Regeln (`VCNavalAbilityRules`): Rammen (Bugwinkel, Tempo, Eigenschaden), Enterhaken (Reichweite, Tempo), Entern in Runden (Erkundungsschiff stärker), Minen (Scharfschalten, Radius, Lebensdauer) | ✅ It. 3 | `tools/test_rules.sh` (4 weitere Fälle) |
| Daten: Fähigkeiten-Tuning in `dev_ships.json` → `DT_ShipTuning` (Erkundungsschiff muss stärker entern, geprüft); kein Backend-Bedarf | ✅ It. 3 | Export `--check` |
| UE: Rammen beim Auflaufen, F Enterhaken, B Entern, M Mine (`AVCMine`), Pirat hakt und entert mit Überzahl, HUD-Abklingzeiten | ⚠️ It. 3, geschrieben, nicht kompiliert | lokal |
| Wasser-Optik, Strömung, Wetter | ❌ | braucht Assets |
| Lasttest große Seeschlachten | ❌ | |

**Abnahme Iteration 3 (Vorschlag)**: Mit Fahrt auf einen Piraten zuhalten → Rammstoß kostet ihn Rumpf und das eigene Schiff einen Teil davon; langsam neben den Piraten, F → beide liegen fest; B → Kampf an Deck in Runden, die Seite ohne Matrosen verliert (Pirat genommen → XP; eigenes Schiff genommen → an Land wie beim Sinken); M legt eine Mine hinter dem Heck, die ein folgendes Schiff trifft und nach Ablauf verschwindet; mit Erkundungsschiff gewinnt man Enterkämpfe bei gleicher Matrosenzahl häufiger.

**Abnahme Iteration 2 (Vorschlag)**: Auf der Seezone greift ein Piratenschiff an; Breitseiten treffen nur quer ab und in Reichweite; Treffer kosten Rumpf und Matrosen (verletzt oder tot), weniger Matrosen machen langsamer; ein versenkter Pirat gibt die XP aus dem Backend; das eigene Schiff sinkt bei Rumpf 0, man landet an Land und repariert, heilt, heuert an und kauft Proviant beim Werftmeister gegen Gold; alles ist nach Neustart gespeichert.

**Abnahme Iteration 1 (Vorschlag)**: In Athen beim Werftmeister das Anfängerschiff erhalten; über den Hafen auf die Seezone → man steuert das Schiff; gegen den Wind keine Fahrt, mit halbem Wind am schnellsten; Proviant sinkt mit der Zeit; nach Neustart sind Schiff, Rumpf, Matrosen und Proviant gespeichert; ein zweites Anfängerschiff gibt es nicht.

## Phase 6 – Wirtschaft (Iteration 4 fertig)

Handel mit Hafenpreisen, Märkte, Crafting, Sammelberufe, Auktionshaus, Ledger-Dashboard.

| Schritt | Status | Prüfung |
|---|---|---|
| Preisregeln (`TradePricing`, Backend): Preis nach Bestand zu Gleichgewicht, Spanne, Steuer, Einzelpreis je Einheit, Auffüllen über Zeit; Rückkauf im selben Hafen nie mit Gewinn | ✅ It. 1 | `TradePricingTests` (9 Fälle) |
| Daten: drei Testwaren, Märkte in London und Athen mit gegenläufigem Preisgefälle, Händler als Entwicklungs-NPC, Preismodell in `game_rules`; `V0012` (Märkte, Ladungsstapel, `trade_transactions`) | ✅ It. 1 | Export `--check` (prüft Märkte), Schematest |
| Backend: Markt ansehen, Kaufen/Verkaufen beim Händler der eigenen Zone in den Laderaum des aktiven Schiffs, Ledger (Kauf Senke, Verkauf Quelle), idempotent, Preisgrenze; Wirtschaftsübersicht Quellen/Senken je Tag | ✅ It. 1 | `TradeTests` (5 Tests) |
| UE: Händler-Rolle, `VCMarket`, `VCTrade` | ⚠️ It. 1, geschrieben, nicht kompiliert | lokal |
| Rhetorik-Wirkung auf Preise, Handels-Erfahrung für Handelsschiffe | ❌ | belegt als vorhanden, Wirkung UNKNOWN |
| Regeln (`InventoryRules`, Backend): Stapel auffüllen, freie Plätze, Überlauf; Beute würfeln (Chance UNKNOWN → fällt nie), Goldbeute | ✅ It. 2 | `InventoryRulesTests` (5 Fälle) |
| Daten: zwei Testmaterialien, Ankaufspreise, Beutetabellen für Übungsgegner und Piratenschiff, Inventargröße; `V0013` (Goldbeute, `inventory_operations`, Beute im Kill) | ✅ It. 2 | Export `--check` (prüft Beute), Schematest |
| Backend: Inventar, Waffe aus dem Inventar ausrüsten (Tausch), ablegen, wegwerfen, an den Händler verkaufen (Quelle `ITEM_SELL`), Admin-Vergabe mit Audit; Beute aus Kills ins Inventar, Gold als Quelle `LOOT_GOLD`; Waffe im Charakterzustand | ✅ It. 2 | `InventoryTests` (4 Tests) |
| UE: `VCInventory`, `VCEquip`, `VCUnequip`, `VCDiscard`, `VCSellItem`, `VCAdmin "giveitem"`, Beutemeldung; Admin-`equip` entfällt | ⚠️ It. 2, geschrieben, nicht kompiliert | lokal |
| Regeln (`CraftingRules`, Backend): Fehlmaterial je Durchlauf, Verbrauch kleinster Stapel zuerst, Ausbeute; Skill-XP-Vergabe intern nutzbar | ✅ It. 3 | `CraftingRulesTests` (3 Fälle) |
| Daten: Sammelpunkte (Bergbau, Holzfällerei, Landwirtschaft) in der Testzone, drei Rezepte (Schmieden, Schneiderei), zwei Materialien; `V0014` (`gather_nodes`, Zonen, Rezept-XP) | ✅ It. 3 | Export `--check` (prüft Skill-Kategorien), Schematest |
| Backend: Sammeln (Zone, Skillstufe, Ausbeute, Skill-XP), Rezepte mit Vorrat, Herstellen (Material, Gebühr `CRAFT_FEE`, Skill-XP; alles oder nichts), genau einmal je Schlüssel | ✅ It. 3 | `CraftingTests` (3 Tests) |
| UE: `VCGatherNode` (Sammelzeit, Nachwachsen, ein Sammler), E sammelt, `VCRecipes`, `VCCraft`; `DT_GatherNodes` | ⚠️ It. 3, geschrieben, nicht kompiliert | lokal |
| Fischen, Alchemie, Schiffbau, Qualität, Herstellzeit | ❌ | Orte, Rezepte, Qualitätsstufen UNKNOWN |
| Haltbarkeit, Sockel, Verfeinerung | ❌ | Mechanik teils belegt (SYS-SOCKETING, SYS-REFINEMENT), Werte UNKNOWN |
| Regeln (`AuctionRules`, Backend): Einstellgebühr (aufgerundet, Mindestgebühr), Verkaufssteuer (abgerundet), Preisgrenzen, abgeleitete Ledger-Schlüssel | ✅ It. 4 | `AuctionRulesTests` (4 Fälle) |
| Daten: Gebühr 2 %, Steuer 5 %, Laufzeit 24 h, 10 Angebote je Spieler; Auktionatoren in London und Athen; `V0015` (`market_listings` erweitert) | ✅ It. 4 | Export `--check`, Schematest |
| Backend: einstellen (Stapel teilbar, Gebühr als Senke), suchen, kaufen (Verkäufer erhält Preis − Steuer, Steuer als Senke, Einzelstücke behalten ihr Exemplar), zurückziehen, Abgelaufenes abholen; Sperrreihenfolge, genau einmal je Schlüssel | ✅ It. 4 | `AuctionTests` (5 Tests) |
| UE: Auktionator-Rolle, `VCAuction`, `VCAuctionSell`, `VCAuctionBuy`, `VCAuctionMine`, `VCAuctionCancel`, `VCAuctionCollect` | ⚠️ It. 4, geschrieben, nicht kompiliert | lokal |
| Direkter Handel zwischen zwei Spielern (Handelsfenster), Post | ❌ | Phase 7 (Sozial) |
| Ledger-Dashboard als Oberfläche | ❌ | Daten liegen über `/internal/v1/economy/summary` vor |

**Abnahme Iteration 4 (Vorschlag)**: Spieler A stellt beim Auktionator 10 Stoff für 1000 Gold ein (20 Gold Gebühr); Spieler B findet das Angebot mit `VCAuction DEV_MAT_CLOTH`, kauft es in einer anderen Stadt (Auktionshaus für alle Häfen), B zahlt 1000, A erhält 950, 50 verlassen das Spiel; ein wiederholter Kauf bucht nichts doppelt; ein abgelaufenes Angebot ist nicht mehr kaufbar und kommt mit `VCAuctionCollect` zurück; die Wirtschaftsübersicht zeigt Gebühr und Steuer als Senken.

**Abnahme Iteration 3 (Vorschlag)**: In der Testzone Baum und Eisenader mit E abbauen (stillstehen, Punkt ist danach erschöpft und wächst nach), Holzfällerei und Bergbau steigen; die reiche Ader verweigert unter Bergbau 5; mit 3 Eisen und 1 Holz ein Schwert schmieden (10 Gold Gebühr), ohne Material oder mit vollem Inventar passiert nichts; Wiederholungen buchen nichts doppelt.

**Abnahme Iteration 2 (Vorschlag)**: Übungspirat besiegen → Beute erscheint im Inventar, Gold steigt; eine erbeutete Klinge ausrüsten, sie bleibt nach Neustart ausgerüstet; Material beim Händler verkaufen (Gold steigt genau einmal, auch bei Wiederholung); volles Inventar meldet verlorene Beute; ohne Inventar-Eintrag kann der Client keine Waffe ausrüsten.

**Abnahme Iteration 1 (Vorschlag)**: In Athen beim Händler Öl kaufen (Gold sinkt, Ware im Laderaum, Laderaum begrenzt), über die Seezone nach London segeln und dort mit Gewinn verkaufen; viele Käufe hintereinander machen die Ware teurer, nach einer Weile füllt sich der Bestand wieder auf; ein wiederholter Auftrag bucht nichts doppelt; die Wirtschaftsübersicht zeigt Kauf als Senke und Verkauf als Quelle.

## Phase 7 – Sozial (Iteration 4 fertig)

Freunde, Chat, Gilden, Gildenlager, Gildenmissionen, Städtebesitz, Belagerung.

| Schritt | Status | Prüfung |
|---|---|---|
| Regeln (`ChatRules`, Backend): Nachricht bereinigen (Steuer- und Richtungszeichen, Leerraum), Länge, Rate-Limit je Kanal | ✅ It. 1 | `ChatRulesTests` (4 Fälle) |
| Backend: Chat (LOCAL, WORLD, TRADE, WHISPER; SYSTEM nur Admin) mit Stummschaltung und Rate-Limit, Verteilung über `chat_log` an alle Zonen-Server, Flüstern nur an Online-Spieler, die nicht ignorieren; Freunde mit Online-Status und Zone; Ignorieren (im Charakterzustand); Melden mit Nachrichtenkontext; Admin `mute`/`announce` mit Audit; `V0016` | ✅ It. 1 | `SocialTests` (4 Tests) |
| UE: `VCSay`, `VCWorld`, `VCTradeChat`, `VCWhisper`, `VCFriends`/`VCFriendAdd`/`VCFriendRemove`, `VCIgnores`/`VCIgnore`/`VCUnignore`, `VCReport`, `VCAdmin "mute"`/`"announce"`; Abfrage jede Sekunde, Zustellung ohne Ignorierte | ⚠️ It. 1, geschrieben, nicht kompiliert | lokal |
| Chat-Fenster im HUD | ❌ | UI-Layout des Originals UNKNOWN |
| Regeln (`GuildRules`, Backend): Name, Kürzel, Banner, Rechte der Ränge (Entfernen nur nach unten, Ränge nur unter dem eigenen, Leitung nur vom Leiter) | ✅ It. 2 | `GuildRulesTests` (4 Fälle) |
| Daten: Rang-Vorlagen Gildenleiter/Gildenoffizier (belegt) und Mitglied, Gründungskosten 1000, 50 Mitglieder, Einladung 48 h; `V0017` | ✅ It. 2 | Export `--check` (prüft Ränge), Schematest |
| Backend: gründen (Senke `GUILD_FOUND`, genau einmal), Gilde ansehen, einladen/annehmen/ablehnen, entfernen, Rang setzen und Leitung übergeben, austreten (letztes Mitglied löst auf), auflösen; Gildenchat über den Chat-Verteiler | ✅ It. 2 | `GuildTests` (4 Tests) |
| UE: `VCGuild…`-Befehle, `VCGuildChat`, Zustellung an die vom Backend genannten Mitglieder | ⚠️ It. 2, geschrieben, nicht kompiliert | lokal |
| Gildenlager, Gildenlevel und -skills, Gildenmissionen | ❌ | belegt als vorhanden (SYS-GUILD), Inhalte UNKNOWN |
| Regeln: Steueranteil im Handelspreis (`TradeQuote.Tax`), `CityRules` (Besitzeranteil, Steuergrenzen, geltender Steuersatz) | ✅ It. 3 | `CityRulesTests` (3 Fälle) |
| Daten: Rechte CITY (Leiter, Offiziere) und TREASURY (Leiter), London 20 000 und Athen 15 000 Gold, Anteil 50 %, Steuer 0–15 %; `V0018` (`guild_ledger`, `territories.is_dev`) | ✅ It. 3 | Export `--check`, Schematest |
| Backend: Gildenkasse (einzahlen = Beitrag, auszahlen mit Recht, genau einmal), Städteliste, Stadt aus der Kasse kaufen (Senke `CITY_BUY`), Steuersatz setzen, Steueranteil beim Handel im Hafen (Quelle `CITY_TAX`), Auflösen gibt Städte frei und zahlt die Kasse an den Leiter; Wirtschaftsübersicht mit Gildenkassen | ✅ It. 3 | `GuildCityTests` (3 Tests) |
| UE: `VCGuildDeposit`, `VCGuildWithdraw`, `VCCities`, `VCGuildBuyCity`, `VCGuildCityTax`; `VCGuild` zeigt Kasse und Städte | ⚠️ It. 3, geschrieben, nicht kompiliert | lokal |
| Regeln (`SiegeRules`, Backend): Phase nach Uhrzeit, Ansage nur gegen fremde Gildenstadt ohne offene Belagerung, Wertung nur für Kills zwischen den beiden Gilden, Gleichstand für den Verteidiger | ✅ It. 4 | `SiegeRulesTests` (4 Fälle) |
| Daten: Ansage 5000 Gold aus der Kasse, Vorlauf 24 h, Dauer 60 min; `V0019` (`territory_wars` mit Zeitplan und Punkten, höchstens eine offene Belagerung je Stadt, `combat_kills.war_id`) | ✅ It. 4 | Export `--check`, Schematest |
| Backend: Belagerung ansagen (Recht CITY, Senke `SIEGE_DECLARE`, genau einmal, Systemmeldung), Liste, laufende Belagerungen je Zone mit Online-Teilnehmern (Stadt und angrenzende Seezonen), PvP-Kills zwischen den Seiten auch in sicheren Zonen zählen, Auswertung nach Ablauf (Stadt geht an den Angreifer, Steuersatz zurückgesetzt), Auflösen einer Gilde bricht ihre Belagerungen ab | ✅ It. 4 | `SiegeTests` (3 Tests) |
| UE: `IsPvPAllowedBetween` (Zone oder Belagerungsgegner) für Nah- und Seekampf, Abfrage der Belagerungen alle 10 s, `VCSieges`, `VCGuildSiege` | ⚠️ It. 4, geschrieben, nicht kompiliert | lokal |
| Getrennte Land- und Seephase, Belagerungswaffen, Gruppen, Post, Handelsfenster | ❌ | Regeln UNKNOWN |

**Abnahme Iteration 3 (Vorschlag)**: Mitglieder zahlen in die Gildenkasse ein, nur der Leiter zahlt aus; ein Offizier kauft mit `VCGuildBuyCity ATHENS` die Stadt aus der Kasse; ein Handel in Athen bringt der Gilde die Hälfte der Steuer; `VCGuildCityTax ATHENS 150` macht Waren dort teurer, 151 wird abgelehnt; `VCCities` zeigt den Besitzer; nach dem Auflösen ist Athen wieder frei und der Leiter hat das Restgeld.

**Abnahme Iteration 4 (Vorschlag)**: Gilde B sagt mit `VCGuildSiege ATHENS` die Belagerung von Gilde As Stadt an (5000 Gold aus der Kasse, Systemmeldung, zweite Ansage abgelehnt); nach dem Vorlauf dürfen sich Mitglieder beider Gilden in Athen und auf der angrenzenden See bekämpfen, Unbeteiligte nicht; jeder Kill zählt einen Punkt (`VCSieges`); nach Ablauf gehört Athen bei mehr Punkten Gilde B, bei Gleichstand bleibt es bei A.

**Abnahme Iteration 2 (Vorschlag)**: Spieler A gründet mit `VCGuildCreate "Die Seefahrer" SEE` (1000 Gold weg), lädt B ein, B nimmt an (`VCGuildInvites`, `VCGuildAccept`); B kann als Mitglied niemanden einladen, nach Beförderung zum Offizier schon; `VCGuildChat` erreicht nur Mitglieder, auch auf anderen Servern; A übergibt die Leitung an B und tritt aus; B tritt als Letzter aus und die Gilde ist aufgelöst, der Name wieder frei.

**Abnahme Iteration 1 (Vorschlag)**: Zwei Spieler auf verschiedenen Servern (Testzone und Athen): `VCWorld "Hallo"` erscheint bei beiden innerhalb von etwa einer Sekunde, `VCSay` nur in 50 m Umkreis; `VCWhisper` erreicht den anderen Server, nach `VCIgnore` nicht mehr; ein dritter WORLD-Satz in 10 s wird abgelehnt; `VCFriends` zeigt den anderen online mit Zone; ein Admin schaltet per `mute` stumm (Audit-Eintrag), `announce` erscheint bei allen als [System].

## Phase 8 – Endgame

Stufenbänder 180+ bis zum belegten Cap; Inhalte erst nach Klärung des aktuellen Caps (`CONTRA-002`).

## Arbeitsweise je System

Code → Kompilieren → Fehler analysieren → Testen → Netzwerk testen →
Datenbank testen → Performance prüfen → Dokumentation aktualisieren → nächstes System.
