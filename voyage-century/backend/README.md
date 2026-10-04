# Backend (.NET 10)

| Projekt | Zweck | Port (Development) |
|---|---|---|
| `src/VC.Auth` | Konten, Login (argon2id), Session-Tickets, Ticketprüfung für Zonen-Server | 5100 |
| `src/VC.GameData` | Charaktere, Spielzustand laden/speichern, Admin-Audit, World Directory (Zonen-Server, Anwesenheit, Zonenwechsel) | 5200 |
| `src/VC.Migrations` | Migrator für `database/migrations` und `database/seed` | – |
| `src/VC.Common` | Konfiguration, JSON-Logging, Service-Key- und Session-Filter, Passwort-Hash | – |
| `tests/VC.Tests` | Integrationstests gegen echte PostgreSQL | – |

## Lokal starten

```bash
# PostgreSQL mit Benutzer vc / Passwort vc_dev und Datenbank voyage_century (Werte aus appsettings.Development.json)
export VC_DB="Host=localhost;Port=5432;Username=vc;Password=vc_dev;Database=voyage_century"
dotnet run --project src/VC.Migrations      # Migrationen + Seeds

dotnet run --project src/VC.Auth            # http://localhost:5100
dotnet run --project src/VC.GameData        # http://localhost:5200
```

Tests (startet bei Bedarf eine Wegwerf-PostgreSQL):

```bash
../tools/test_backend.sh
```

## Konfiguration

Alles über `appsettings.json`, `appsettings.{Environment}.json` und Umgebungsvariablen
(`Abschnitt__Schluessel`, z. B. `Database__ConnectionString`, `ServiceKeys__Keys__0`).
Fehlende oder ungültige Pflichtwerte verhindern den Start.

| Schlüssel | Bedeutung |
|---|---|
| `Service:Name`, `Service:InstanceId` | Dienstname und Instanz-ID in jedem Log-Eintrag |
| `Database:ConnectionString` | Npgsql-Verbindung |
| `ServiceKeys:Keys` | erlaubte Service-Keys der Zonen-Server (je ≥ 32 Zeichen); Schlüssel mit `dev-only-` werden außerhalb von Development abgelehnt |
| `Auth:AllowRegistration` | offene Registrierung (Produktion: aus) |
| `Auth:TicketLifetime` | Gültigkeit eines Tickets (Standard 12 h) |
| `Auth:LoginAttemptsPerMinute` | Login-Versuche pro IP und Minute |
| `PasswordHash:*` | argon2id-Parameter; Änderungen wirken beim nächsten Login per Rehash |
| `GameData:MaxCharactersPerAccount` | technisches Limit, kein Originalwert |
| `Progression:AllowDevCurves` | Entwicklungs-XP-Kurven verwenden (nur Development/Tests) |
| `Progression:MaxCharacterXpPerGrant`, `MaxSkillXpPerGrant` | Plausibilitätsgrenze je Vergabe |
| `Content:AllowDevContent` | Entwicklungsinhalte (`is_dev`: DEV_-Waffen, -Gegner, -Fähigkeiten und -Entdeckungen) zulassen (nur Development/Tests) |
| `Progression:AdminMinLevel` | Mindest-Adminlevel für `/setlevel`, `/setskill` |
| `World:StartZoneId` | Zone neuer Charaktere (Development: `DEV_TESTZONE`). Startstadt des Originals UNKNOWN; ohne Wert können neue Charaktere nicht verbinden |
| `World:ServerTimeoutSeconds` | ohne Lebenszeichen gilt ein Zonen-Server danach als ausgefallen (Standard 30) |
| `World:TransferTimeoutSeconds` | so lange bleibt der Platz eines Zonenwechsels reserviert (Standard 60) |

## Endpunkte

| Dienst | Methode und Pfad | Zugriff |
|---|---|---|
| Auth | `POST /v1/accounts` | offen, falls Registrierung an |
| Auth | `POST /v1/sessions` | offen, rate-limitiert → `ticket` |
| Auth | `DELETE /v1/sessions/current` | `Authorization: Bearer <ticket>` |
| Auth | `POST /internal/v1/sessions/validate` | `X-Service-Key` |
| GameData | `GET/POST /v1/characters` | `Authorization: Bearer <ticket>`; `appearance` wird gegen `appearance_slots` geprüft |
| GameData | `GET /v1/character-options` | `Authorization: Bearer <ticket>` → Berufe, Geschlechter, Aussehen-Merkmale |
| GameData | `GET/PUT /internal/v1/characters/{id}/state` | `X-Service-Key`, mit `accountId` (Besitzprüfung); PUT nur vom Server, auf dem der Charakter ONLINE ist (`serverId`), `releasePresence` beim Ausloggen |
| GameData | `GET /v1/characters/{id}/server` | `Authorization: Bearer <ticket>` → `zoneId`, `address` eines lebenden Servers mit Platz |
| GameData | `POST /internal/v1/world/servers/{serverId}` | `X-Service-Key`; Prozessstart (`zoneId`, `address`, `capacity`), verwirft alte Anwesenheiten → `heartbeatSeconds` |
| GameData | `PUT /internal/v1/world/servers/{serverId}/heartbeat`, `DELETE …/{serverId}` | `X-Service-Key`; Lebenszeichen bzw. Abmelden |
| GameData | `POST /internal/v1/world/characters/{id}/claim`, `DELETE …/claim?serverId=` | `X-Service-Key`; Charakter auf diesem Server ONLINE setzen (409, wenn anderswo online oder in anderer Zone) bzw. freigeben |
| GameData | `POST /internal/v1/world/discoveries` | `X-Service-Key`; Entdeckung (`discoveryCode`) einmal je Charakter, nur vom Server mit Anwesenheit in der Zone des Punktes; XP aus `discoveries.xp_reward`; `GET …/state` liefert `discoveries` |
| GameData | `POST /internal/v1/characters/{id}/ships` | `X-Service-Key`; Kauf (`npcCode`, `shipCode`, `purchaseKey`) nur beim Werftmeister der Zone, in der der Charakter auf diesem Server ist; Gold über den Ledger |
| GameData | `PUT …/ships/{instanceId}/active`, `PUT …/ships/{instanceId}/state` | `X-Service-Key`; aktives Schiff; Rumpf/Matrosen/Proviant (dürfen nicht steigen); `GET …/state` liefert `ships`, `gold` |
| GameData | `POST …/ships/{instanceId}/services` | `X-Service-Key`; `kind` REPAIR, HEAL, HIRE, PROVISIONS (`amount`) beim Werftmeister der Zone; Preise aus `game_rules`, Ledger, idempotent (`key`) |
| GameData | `POST /internal/v1/characters/{id}/gold` | Admin (`Progression:AdminMinLevel`), Ledger und Audit in einer Transaktion, idempotent |
| GameData | `POST /internal/v1/world/transfers` | `X-Service-Key`; Zonenwechsel über Ausgang (`exitCode`) → Zielserver, Ankunftspunkt |
| GameData | `POST /internal/v1/admin-audit` | `X-Service-Key`, Konto braucht `admin_level > 0` |
| GameData | `POST /internal/v1/characters/{id}/experience` | `X-Service-Key`; `amount`, `source`, `idempotencyKey`, `serverId` |
| GameData | `POST /internal/v1/characters/{id}/skills/{code}/experience` | wie oben, für Skill-XP |
| GameData | `PUT /internal/v1/characters/{id}/level` bzw. `…/skills/{code}/level` | Admin (`Progression:AdminMinLevel`), Audit in derselben Transaktion |
| GameData | `GET /internal/v1/zones/{zoneId}` | `X-Service-Key` → Zonenart und `pvpMode` |
| GameData | `POST /internal/v1/combat/kills` | `X-Service-Key`; XP aus `monsters.xp_reward`, PvP nur in `FREE`-Zonen, idempotent |
| GameData | `PUT /internal/v1/characters/{id}/hotbar` | `X-Service-Key`; ersetzt die ganze Belegung (`accountId`, `slots: [{slot, abilityCode}]`), Plätze 0–9, nur freigegebene Fähigkeiten; `GET …/state` liefert `hotbar` |
| beide | `GET /health` | offen |

Fehler kommen als RFC-7807-ProblemDetails (`title`, `status`).

## Produktion (noch offen)

TLS-Terminierung vor den Diensten, `ForwardedHeaders` für echte Client-IPs im Rate-Limit,
mTLS zwischen Zonen-Servern und internen Endpunkten.
