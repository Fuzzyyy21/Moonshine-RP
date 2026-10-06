# Voyage Century Reconstruction

Eigenständiges Seefahrts-MMORPG, das sich spielerisch und strukturell an der
chinesischen Woniu-Version von 航海世纪 (Voyage Century) orientiert.
Geplante Technik: Unreal Engine 5, Dedicated Server, server-autoritativ,
PostgreSQL.

Unabhängig vom FiveM-Framework im Repo-Wurzelverzeichnis.

**Aktueller Stand: Phase 8 – Endgame (Iteration 1: Ausrüstungsplätze, Stufenanforderung, Setboni, Synthese); Phase 7 – Sozial (Iteration 4: Stadtbelagerung; davor Gildenkasse, Städtebesitz, Gilden, Gildenchat, Chat, Freunde, Moderation); Phase 5 – Schiffe (Iteration 3: Rammen, Enterhaken, Entern, Minen; davor Seekampf, Piraten, Hafendienste, Kauf, Segeln, Wind); Phase 6 – Wirtschaft (Iteration 4: Auktionshaus; davor Sammeln, Herstellen, Inventar, Beute, Hafenhandel, Wirtschaftsübersicht).**
Backend (Login, Charaktere, Progression, Kampf, Hotbar, World Directory) und die Kampf- und Fähigkeitsregeln sind getestet; der Unreal-Code ist
geschrieben, aber noch nicht kompiliert (siehe [`unreal/README.md`](unreal/README.md)).
Stand je Phase: [`docs/05_ROADMAP.md`](docs/05_ROADMAP.md).

## Inhalt

| Pfad | Zweck |
|---|---|
| [`docs/00_PHASE0_RESEARCH_REPORT.md`](docs/00_PHASE0_RESEARCH_REPORT.md) | Was über das Original belegt ist, Widersprüche, offene Fragen |
| [`docs/01_GAME_DESIGN_DOCUMENT.md`](docs/01_GAME_DESIGN_DOCUMENT.md) | Systeme: Original-Befund, Design, Offenes |
| [`docs/02_TECHNICAL_ARCHITECTURE.md`](docs/02_TECHNICAL_ARCHITECTURE.md) | Client/Server, Zonen, UE5-Module, Persistenz, Anti-Cheat |
| [`docs/03_DATA_MODEL.md`](docs/03_DATA_MODEL.md) | Relationales Modell und Abbildung der Befunde |
| [`docs/04_FILE_ANALYSIS_PROTOCOL.md`](docs/04_FILE_ANALYSIS_PROTOCOL.md) | Ablauf für später bereitgestellte Dateien |
| [`docs/05_ROADMAP.md`](docs/05_ROADMAP.md) | Phasen 0–8 mit Abnahmekriterien |
| [`reconstruction_db/`](reconstruction_db/) | Reconstruction Database (JSON, mit Quellen und Confidence) |
| [`design_data/`](design_data/) | Designentscheidungen als Daten (getrennt von Originalbefunden) |
| [`database/migrations/`](database/migrations/) | PostgreSQL-Schema als Migrationen; `database/seed/` ist generiert |
| [`backend/`](backend/) | .NET-10-Dienste: Auth, GameData, Migrator, Tests |
| [`unreal/`](unreal/) | UE5-Projekt (Module, Targets, Konfiguration, generierte Data-Table-Quellen) |
| [`tools/`](tools/) | Validator, Export, Datei-Inventar, Testskripte |

## Befehle

```bash
# Reconstruction Database prüfen
python3 tools/validate_reconstruction_db.py

# Abgeleitete Daten (Seed-SQL, Data-Table-JSON) neu erzeugen bzw. prüfen
python3 tools/export_content.py
python3 tools/export_content.py --check

# Migrationen in Wegwerf-PostgreSQL einspielen und Schutzregeln testen
tools/test_schema.sh

# Backend bauen und alle Tests gegen echte PostgreSQL ausführen
tools/test_backend.sh

# Kampfregeln (reines C++) bauen und testen
tools/test_rules.sh

# Gelieferte Dateien read-only inventarisieren
python3 tools/inventory_files.py /pfad/zu/originalen --out analysis/inventory.csv
```

## Regeln

* Keine erfundenen Fakten: unbekannt heißt `UNKNOWN` bzw. `NULL`.
* Quellen-Hierarchie: Entwicklerdateien > offizielle CN-Quellen > CN-Videos/Screenshots > CN-Community > sonstige > eigenes Design.
* Originaldateien werden nie verändert.
* Eine Wahrheit: Spielwerte nur in `reconstruction_db/`, alles andere wird daraus erzeugt.
