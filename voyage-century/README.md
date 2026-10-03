# Voyage Century Reconstruction

Eigenständiges Seefahrts-MMORPG, das sich spielerisch und strukturell an der
chinesischen Woniu-Version von 航海世纪 (Voyage Century) orientiert.
Geplante Technik: Unreal Engine 5, Dedicated Server, server-autoritativ,
PostgreSQL.

Unabhängig vom FiveM-Framework im Repo-Wurzelverzeichnis.

**Aktueller Stand: Phase 0 – Research.** Es gibt noch keinen Spielcode, nur
Dokumentation, Datenbasis, Datenmodell und Werkzeuge.

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
| [`database/schema.sql`](database/schema.sql) | PostgreSQL-Schema |
| [`tools/`](tools/) | Validator, Datei-Inventar, Schematest |

## Befehle

```bash
# Reconstruction Database prüfen
python3 tools/validate_reconstruction_db.py

# Schema in Wegwerf-PostgreSQL einspielen und Schutzregeln testen
tools/test_schema.sh

# Gelieferte Dateien read-only inventarisieren
python3 tools/inventory_files.py /pfad/zu/originalen --out analysis/inventory.csv
```

## Regeln

* Keine erfundenen Fakten: unbekannt heißt `UNKNOWN` bzw. `NULL`.
* Quellen-Hierarchie: Entwicklerdateien > offizielle CN-Quellen > CN-Videos/Screenshots > CN-Community > sonstige > eigenes Design.
* Originaldateien werden nie verändert.
* Eine Wahrheit: Spielwerte nur in `reconstruction_db/`, alles andere wird daraus erzeugt.
