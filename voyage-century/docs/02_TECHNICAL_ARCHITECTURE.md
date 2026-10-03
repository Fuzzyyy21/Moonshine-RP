# Technische Architektur

Stand: 2026-10-03 · Phase 0 · Status: **Entwurf, vor Phase 1 zu bestätigen**

Alle Entscheidungen hier sind Designentscheidungen (Priorität 6). Die Architektur
des Originals ist unbekannt und wird nicht nachgebaut.

## 1. Überblick

```
                    ┌───────────────────────── Backend (zustandslos skalierbar) ─────────────────────────┐
 ┌────────┐  TLS    │ ┌───────────┐   ┌───────────────┐   ┌──────────┐ ┌──────────┐ ┌────────┐ ┌────────┐ │
 │ Client │────────►│ │   Auth    │──►│ World Directory│   │   Chat   │ │  Guild   │ │ Market │ │  Mail  │ │
 │ (UE5)  │         │ └───────────┘   └───────┬───────┘   └────┬─────┘ └────┬─────┘ └───┬────┘ └───┬────┘ │
 └───┬────┘         │                         │ weist Zone zu    │            │           │          │      │
     │ UE-Netzwerk  │ ┌───────────────────────┴──────────────────┴────────────┴───────────┴──────────┴────┐ │
     │ (UDP)        │ │                         Persistence Service                                       │ │
     ▼              │ └──────────────┬─────────────────────────────────────────────┬─────────────────────┘ │
 ┌──────────────────┴─┐              │                                             │                       │
 │ UE5 Dedicated      │  gRPC/mTLS   │                                             │                       │
 │ Server je Zone     │─────────────►│                                             │                       │
 │ (See, Stadt,       │              ▼                                             ▼                       │
 │  Dungeon-Instanz)  │        ┌────────────┐                                ┌──────────┐                  │
 └────────────────────┘        │ PostgreSQL │                                │  Redis   │                  │
                               └────────────┘                                └──────────┘                  │
                    └──────────────────────────────────────────────────────────────────────────────────────┘
```

| Baustein | Aufgabe | Autorität |
|---|---|---|
| UE5-Client | Darstellung, Eingabe, Vorhersage | keine |
| Auth | Login, Passwort-Hash (argon2id), Session-Ticket | Accounts, Sessions |
| World Directory | Liste laufender Zonen-Server, Zuweisung, Zonenwechsel | Wer ist wo |
| UE5 Dedicated Server | Simulation einer Zone: Bewegung, Kampf, Schiffe, NPCs, Quests, Drops | alles, was in der Zone passiert |
| Persistence Service | einziger Schreibzugang zur Datenbank für Spielzustand | Speicherung, Transaktionen |
| Chat / Guild / Market / Mail | zonenübergreifende Systeme | jeweils ihr Bereich |
| PostgreSQL | Wahrheit für alles Dauerhafte | — |
| Redis | Sessions, Präsenz, Marktpreis-Cache, Pub/Sub für Chat | nur Cache, nie Wahrheit |

**Empfehlung Backend-Sprache: C# (.NET 8 LTS oder neuer).** Gründe: starke
Typisierung, ausgereifter PostgreSQL-Treiber (Npgsql), gRPC erstklassig,
leicht zu testen. Zu bestätigen vor Phase 1.

## 2. Server-Autorität

Der Client sendet **nur Absichten** (Eingaben, „benutze Fähigkeit X auf Ziel Y“,
„kaufe Ware Z“). Der Server entscheidet über Level, XP, HP, Schaden, Items,
Geld, Inventar, Questfortschritt, Schiffswerte, PvP, Drops, Crafting, Handel,
Positionen und Besitz.

Umsetzungsregeln für UE5:

* Spielrelevante Zustände nur in replizierten Properties mit `COND_*`-Bedingungen, gesetzt ausschließlich mit `HasAuthority()`.
* Server-RPCs (`Server_*`) sind `WithValidation`, rate-limitiert und prüfen jede Eingabe gegen Server-Zustand.
* GAS: Fähigkeiten mit `LocalPredicted` nur für Kosmetik/Vorhersage; Kosten, Cooldowns und Effekte werden vom Server bestätigt.
* Drops, Belohnungen, Itemerzeugung laufen nur über einen serverseitigen `UItemGrantSubsystem`, das jede Erzeugung loggt.

## 3. Zonen und Sharding

| Zonentyp | Inhalt | Spieler pro Prozess (Startziel) |
|---|---|---|
| SEA | ein Seegebiet (World Partition) | 100–200, zu messen |
| CITY | eine Hafenstadt | 100–200 |
| DUNGEON | Instanz pro Gruppe | Gruppengröße |
| BATTLEFIELD | Seeschlacht / Belagerung | Ziel: große Schlachten, Machbarkeit in Phase 5 messen |

* Zonenwechsel (Hafen verlassen, Regionsgrenze) über **Server Travel mit Ticket**: Server A speichert Zustand → World Directory reserviert Platz auf Server B → Client verbindet mit Ticket → Server B lädt Zustand.
* Ein Charakter ist immer genau einer Zone zugeordnet (Sperre im World Directory), damit kein Zustand doppelt existiert.
* Ob der Übergang Land/See im Original nahtlos war, ist UNKNOWN. Die Zonengrenzen sind deshalb eine Konfiguration, kein Code.
* Die beworbenen „hunderte Schiffe“ in einer Schlacht sind ein **Risiko**: UE5-Standard-Replikation trägt das nicht ohne Weiteres. Prototyp in Phase 5 mit Iris-Replikation (sofern in der gewählten Engine-Version produktionsreif, sonst ReplicationGraph), Schiffen als leichtgewichtigen Actors und Projektilen ohne eigene Actors.

## 4. UE5-Projektstruktur

```
VoyageCentury/
├── Source/
│   ├── VCCore/          Logging, Konfiguration, Fehlercodes, gemeinsame Typen
│   ├── VCData/          Row-Structs der Data Tables, DataRegistry, Validierung beim Laden
│   ├── VCNet/           Backend-Clients (gRPC), Tickets, Zonenwechsel
│   ├── VCAbilities/     GAS: AttributeSets, Abilities, Effects, Tags
│   ├── VCCharacter/     Charakter, Erscheinung, Level, Skills
│   ├── VCCombat/        Landkampf, Schadens-Execution, Zielwahl
│   ├── VCNaval/         Schiff-Pawn, Segelbewegung, Wind, Kanonen, Entern
│   ├── VCWorld/         Zonen, Häfen, Spawner, Entdeckungen, Wetter
│   ├── VCAI/            StateTrees, Gegnerprofile, Piratenflotten
│   ├── VCEconomy/       Inventar-Client, Handel, Crafting-Logik
│   ├── VCQuests/        Questzustände, Objective-Events
│   ├── VCSocial/        Chat-, Gilden-, Freundes-, Mail-Anbindung
│   ├── VCUI/            CommonUI, ViewModels, HUD, Fenster
│   └── VCServer/        nur Server: Persistenz-Brücke, Anti-Cheat, Admin-Kommandos
├── Content/
│   ├── Data/            generierte Data Tables (nicht von Hand bearbeiten)
│   └── …
└── Tests/               Automation- und Functional-Tests
```

Regeln:

* Kein Modul kennt die UI; die UI bindet über ViewModels.
* `VCServer` wird im Client-Build nicht kompiliert (`Type = "Server"` bzw. `#if WITH_SERVER_CODE`).
* Jede Klasse hat eine Aufgabe; keine „GameManager“-Monolithen. Subsysteme (`UWorldSubsystem`, `UGameInstanceSubsystem`) statt Singletons.

## 5. Datenpipeline (eine Wahrheit)

```
reconstruction_db/*.json  ──(Export-Tool, Phase 1)──►  Content/Data/*.json  (UE Data Tables)
         │                                        └──►  database/seed/*.sql (statische Tabellen)
         └── Validator (tools/validate_reconstruction_db.py) läuft in CI
```

* Die Reconstruction Database ist die **einzige** Quelle für Spielwerte. Data Tables und Seed-SQL werden erzeugt, nie von Hand gepflegt. So entstehen keine widersprüchlichen Parallelversionen.
* Neue Befunde (Dateien, Screenshots) → Datensatz in der DB ändern → Export → Build. Git-Historie ist das Änderungsprotokoll.
* `UNKNOWN` wird beim Export zu einem leeren Feld; der Ladecode (`VCData`) meldet beim Serverstart jede leere Pflichtspalte und sperrt das betroffene Feature.

## 6. Persistenz

* Der Zonen-Server hält den aktiven Zustand im Speicher und speichert über den Persistence Service:
  * **Write-behind** alle N Sekunden und bei Zonenwechsel/Logout für unkritische Werte (Position, HP).
  * **Sofort und transaktional** für alles Wertvolle: Handel zwischen Spielern, Auktionshaus, Mail mit Anhang, Itemerzeugung, Gold-Buchungen, Umbau.
* Jede wertvolle Operation trägt einen **Idempotency-Key** (`currency_ledger.idempotency_key`), damit Wiederholungen nach Netzwerkfehlern nicht doppelt buchen.
* Items haben genau einen Ort (`item_instances.location_type` + Slot, eindeutiger Index). Verschieben ist ein einzelnes UPDATE mit Versionsprüfung (`version`). Das verhindert Duplikation strukturell.
* Datenbankzugriffe laufen nie auf dem Game Thread.

## 7. Netzwerk

* Bewegung Charakter: Character Movement Component mit Server-Korrektur.
* Bewegung Schiff: eigene `UShipMovementComponent` mit Client-Vorhersage für das eigene Schiff und Server-Korrektur; Fremdschiffe interpoliert. Schiffe sind träge, daher sind Korrekturen selten und klein.
* Wind- und Wetterzustand: niederfrequent repliziert (z. B. alle paar Sekunden), Clients interpolieren.
* Projektile: Server simuliert Ballistik und Treffer; Clients erhalten ein „Schuss abgefeuert“-Ereignis (Startpunkt, Richtung, Zeitstempel) und simulieren kosmetisch.
* Relevanz nach Distanz und Sichtweite; statische Actors mit Net Dormancy.
* Server-Tick: Startwert 30 Hz für Zonen, Feinabstimmung nach Messung. Kein Wert ist festgelegt, bevor er gemessen wurde.

## 8. Anti-Cheat

| Prüfung | Verfahren |
|---|---|
| Geschwindigkeit, Schiffsbewegung | Server kennt Maximaltempo aus Schiffswerten, Wind und Buffs; Abweichung über Toleranz → Korrektur + Flag |
| Position, Teleport | Positionssprung größer als möglich → Rücksetzung + Flag |
| Schaden | Schaden wird nur serverseitig berechnet; Client sendet keine Schadenswerte |
| Feuerrate | Nachladezeit der Kanone serverseitig; zu frühe Schüsse werden verworfen |
| Skill-Nutzung | GAS-Cooldowns und Kosten serverseitig |
| Inventar, Itemerzeugung | nur Server erzeugt Items, jede Erzeugung im Log |
| Währung | jede Änderung im Ledger; Anomalie-Erkennung (z. B. Gold-Zuwachs pro Stunde über Perzentil) |
| RPC-Flut | Rate-Limit pro RPC und Verbindung |

Flags landen in `anticheat_flags` mit Schweregrad. Automatische Strafen erst ab
bestätigten Mustern; zunächst Review durch Admins.

## 9. Logging

* Strukturierte Logs (JSON) aus allen Diensten mit `player`, `timestamp`, `action`, `old_value`, `new_value`, `session`, `ip`, `server`.
* Spielrelevante Ereignisse zusätzlich in `game_event_log` (partitioniert nach Zeit).
* Admin-Aktionen in `admin_audit_log` (append-only per Datenbank-Trigger).
* Geldbewegungen in `currency_ledger` (append-only).

## 10. Performance-Ziele (vorläufig, zu messen)

| Bereich | Ziel |
|---|---|
| Server-Frame | < 33 ms bei Ziel-Spielerzahl der Zone |
| Bandbreite pro Client | messen in Phase 1, Budget danach festlegen |
| DB-Latenz kritischer Operationen | p99 < 50 ms |
| NPCs | KI-Updates nach Relevanz gedrosselt; Hintergrund-NPCs über Mass |
| Welt-Streaming | World Partition mit Data Layers für Häfen und Inseln |

## 11. Tests

| Ebene | Werkzeug |
|---|---|
| Datenqualität | `tools/validate_reconstruction_db.py` |
| Datenbank | `tools/test_schema.sh` (Schema + Schutzregeln) |
| UE-Logik | Automation Tests (Spec) pro Modul |
| Replikation | Functional Tests mit PIE, ein Server + mehrere Clients |
| Backend | Unit- und Integrationstests mit echter PostgreSQL-Instanz |
| Last | Headless-Bot-Clients gegen Zonen-Server |

## 12. Entwicklungsablauf je System

Wie im Master-Prompt, Abschnitt 37: Code → Kompilieren → Fehler analysieren →
Testen → Netzwerk testen → Datenbank testen → Performance prüfen →
Dokumentation aktualisieren → erst dann nächstes System.
