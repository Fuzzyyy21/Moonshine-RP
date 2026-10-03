# Unreal-Projekt (Phase 1)

> **Status: Code geschrieben, aber noch nie kompiliert.** In der Umgebung, in der
> Phase 1 entstanden ist, gibt es keine Unreal Engine. Der erste Build muss lokal
> erfolgen; Compilerfehler bitte als Issue oder direkt zurückmelden.

Engine: in `VoyageCentury.uproject` auf **5.6** eingestellt. Andere 5.x-Versionen per
Rechtsklick auf die `.uproject` → *Switch Unreal Engine version*. Build-Einstellungen
nutzen `BuildSettingsVersion.Latest`, damit kein versionsspezifischer Wert festgeschrieben ist.

## Module

| Modul | Inhalt |
|---|---|
| `VCCore` | Log-Kategorie `LogVC`, Backend-Adressen (`UVCBackendSettings`), Schnittstelle `IVCServerHooks` |
| `VCData` | Row-Structs für die generierten Data Tables |
| `VCNet` | HTTP/JSON-Client `FVCHttp`, Login-Ablauf `UVCSessionSubsystem` |
| `VoyageCentury` | Primärmodul: `AVCPlayerController` (Konsolenbefehle, Admin-RPC), `AVCCharacter` (Platzhalterfigur) |
| `VCServer` | `AVCGameMode`: Ticketprüfung, Laden/Speichern, Admin-Audit; `UVCServerSettings` |

Targets: `VoyageCentury` (Game), `VoyageCenturyEditor`, `VoyageCenturyServer`, `VoyageCenturyClient`.

## Einmalige Schritte im Editor

Binäre Assets lassen sich nicht als Text anlegen. Nach dem ersten Öffnen:

1. **Testkarte** `Content/Maps/L_DevTestZone` anlegen (Vorlage *Basic*), einen `PlayerStart` platzieren, speichern.
2. **Data Tables** importieren: jede Datei aus `Content/Data/Generated/` per Drag & Drop in den
   Content Browser ziehen und die passende Row-Struktur wählen:

   | Datei | Row-Struktur |
   |---|---|
   | `DT_Professions.json` | `VCProfessionRow` |
   | `DT_Skills.json` | `VCSkillRow` |
   | `DT_SkillStages.json` | `VCSkillStageRow` |
   | `DT_ShipClasses.json` | `VCShipClassRow` |

   Die JSON-Dateien werden von `tools/export_content.py` erzeugt. Nach einem neuen Export
   im Editor *Reimport* ausführen – nie die Tabellen im Editor von Hand ändern.

## Ablauf testen (Abnahme Phase 1)

Voraussetzung: PostgreSQL läuft, Migrationen sind eingespielt und beide Backend-Dienste
laufen (siehe [`../backend/README.md`](../backend/README.md)).

```bash
# 1. Dedicated Server (Service-Key nur über die Umgebung)
export VC_SERVICE_KEY=dev-only-service-key-0000000000000000
VoyageCenturyServer -log -port=7777 -VCZone=DEV_TESTZONE -VCServerId=zone-dev-1

# 2. Zwei Clients starten (gepackt oder "VoyageCentury.exe -game"), in der Konsole (^):
VCLogin <login> <passwort>
VCCharacters
VCCreateCharacter Seefahrer MALE ROYAL_OFFICER
VCConnect 127.0.0.1:7777 <characterId>
```

Abnahmekriterien:

| Kriterium | Prüfung |
|---|---|
| Zwei Clients sehen sich | beide Platzhalterfiguren in L_DevTestZone sichtbar |
| Position wird gespeichert | Admin-Teleport (unten) oder warten (Intervall 30 s), Client trennen |
| Position nach Neustart | Server **und** Backend neu starten, erneut verbinden → Figur an alter Position |
| Admin-Kommando im Audit-Log | Konto in der DB zum Admin machen (`UPDATE accounts SET admin_level = 1 WHERE login = '…'`), neu verbinden, dann `VCAdmin "teleport 0 0 300"` → Zeile in `admin_audit_log` mit alter und neuer Position |
| Ohne Ticket kein Zutritt | `open 127.0.0.1:7777` ohne Login → Verbindung abgelehnt |

## Sicherheitsregeln im Code

* Der Server spawnt erst einen Pawn, wenn Ticket **und** Charakterbesitz vom Backend bestätigt sind.
* Ohne Bestätigung nach `AuthTimeoutSeconds` (15 s) wird getrennt.
* Gespeicherte Positionen werden nur in der Zone verwendet, in der sie gespeichert wurden.
* Admin-Kommandos: Recht wird auf dem Server geprüft (Adminlevel kommt vom Backend, nie vom Client),
  dann **erst Audit-Eintrag, dann Ausführung**. Scheitert das Audit, passiert nichts.
* Der Service-Key kommt nur aus `VC_SERVICE_KEY`; in Client-Builds (`WITH_SERVER_CODE == 0`)
  existiert der Codepfad nicht.
* Im Editor (PIE) dürfen Spieler ohne Backend spielen (`bAllowUnauthenticatedInEditor`);
  in gepackten Builds ist das wirkungslos.

## Bekannte Grenzen von Phase 1

* Keine Steuerung (Phase 2); Positionsänderung nur per Admin-Teleport.
* Konsolenbefehle statt Login-Oberfläche; Passwort steht in der Konsolen-Historie.
* Das Ticket steht in der Verbindungs-URL und kann in ausführlichen Engine-Logs auftauchen.
* Keine Sperre gegen gleichzeitiges Einloggen desselben Charakters auf zwei Zonen (World Directory folgt).
