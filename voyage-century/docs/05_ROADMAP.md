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

## Phase 2 – Charakter

Charaktererstellung, Bewegung, Kamera, Animation, Attribute, Level, XP, Skills (17 Skills, Stufen, Gesamtcap).
**Abnahme**: Skill-XP und Level werden serverseitig vergeben, überleben Zonenwechsel und Neustart; manipulierte Client-Werte haben keine Wirkung.

## Phase 3 – Landkampf

Waffen, Angriffe, Fähigkeiten (GAS), Schaden, NPC-KI, PvE, PvP-Grundregeln.

## Phase 4 – Welt

Erste Seezone und zwei Häfen (Kandidaten: London, Athen, weil am besten belegt), NPCs, ein Land-Dungeon, Entdeckungen.

## Phase 5 – Schiffe

Schiffskauf beim Werftmeister, Segelmodell, Wind, Wasser, Schiffsausrüstung, Matrosen, Seekampf, Entern. Lasttest für große Seeschlachten.

## Phase 6 – Wirtschaft

Handel mit Hafenpreisen, Märkte, Crafting, Sammelberufe, Auktionshaus, Ledger-Dashboard.

## Phase 7 – Sozial

Freunde, Chat, Gilden, Gildenlager, Gildenmissionen, Städtebesitz, Belagerung.

## Phase 8 – Endgame

Stufenbänder 180+ bis zum belegten Cap; Inhalte erst nach Klärung des aktuellen Caps (`CONTRA-002`).

## Arbeitsweise je System

Code → Kompilieren → Fehler analysieren → Testen → Netzwerk testen →
Datenbank testen → Performance prüfen → Dokumentation aktualisieren → nächstes System.
