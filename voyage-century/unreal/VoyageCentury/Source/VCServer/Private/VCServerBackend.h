#pragma once

#include "CoreMinimal.h"
#include "VCHttp.h"

/**
 * Aufrufe des Zonen-Servers an die internen Backend-Endpunkte (mit Service-Key).
 * In Client-Builds (WITH_SERVER_CODE == 0) liefern alle Aufrufe sofort einen Fehler,
 * damit kein Codepfad mit Service-Key im Client existiert.
 */
class FVCServerBackend
{
public:
	/** true, wenn VC_SERVICE_KEY gesetzt ist. */
	static bool IsConfigured();

	static void ValidateTicket(const FString& Ticket, FVCHttpCallback Callback);
	static void LoadCharacter(int64 CharacterId, int64 AccountId, FVCHttpCallback Callback);
	/**
	 * Position und (falls bekannt) Leben/Ausdauer speichern. Vitals mit MaxHealth <= 0 werden nicht mitgeschickt.
	 * Das Backend nimmt nur Speicherstände des Servers an, auf dem der Charakter ONLINE ist.
	 * bReleasePresence: letzter Stand beim Ausloggen, gibt die Anwesenheit in derselben Transaktion frei.
	 */
	static void SaveCharacter(int64 CharacterId, int64 AccountId, const FString& ZoneId,
		const FVector& Location, float Yaw, const FIntVector4& Vitals, bool bReleasePresence, FVCHttpCallback Callback);

	/** World Directory: Prozessstart melden (verwirft Anwesenheiten eines früheren Laufs). Antwort: heartbeatSeconds. */
	static void StartServer(const FString& Address, int32 Capacity, FVCHttpCallback Callback);
	/** Lebenszeichen. Kein Abmelden beim Beenden: ausstehende Speicherstände sollen nicht abgelehnt werden; der Timeout genügt. */
	static void Heartbeat(const FString& Address, int32 Capacity, FVCHttpCallback Callback);

	/** Charakter auf diesem Server ONLINE setzen. 409, wenn er anderswo online ist oder in einer anderen Zone steht. */
	static void ClaimCharacter(int64 CharacterId, int64 AccountId, FVCHttpCallback Callback);
	/** Anwesenheit freigeben, wenn kein letzter Speicherstand folgt (z. B. Abbruch vor dem Spawn). */
	static void ReleaseCharacter(int64 CharacterId);

	/** Entdeckung melden. Antwort: firstTime, xpAwarded, progress (Belohnung legt das Backend fest). */
	static void ReportDiscovery(int64 CharacterId, int64 AccountId, const FString& DiscoveryCode, FVCHttpCallback Callback);

	/** Schiff beim Werftmeister kaufen; PurchaseKey macht Wiederholungen unschädlich. Antwort: duplicate, ship, gold. */
	static void BuyShip(int64 CharacterId, int64 AccountId, const FString& NpcCode, const FString& ShipCode, const FGuid& PurchaseKey,
		FVCHttpCallback Callback);
	static void SetActiveShip(int64 CharacterId, int64 AccountId, int64 InstanceId, FVCHttpCallback Callback);
	/** Rumpf, Besatzung, Proviant nach der Fahrt (können ohne Werft nur sinken). */
	static void SaveShip(int64 CharacterId, int64 AccountId, int64 InstanceId, int32 HullHp, int32 Crew, int32 Provisions,
		FVCHttpCallback Callback);
	/** Admin: Gold gutschreiben; Rechte, Ledger und Audit prüft/schreibt das Backend in einer Transaktion. */
	static void AdminGrantGold(int64 CharacterId, int64 Amount, const TSharedRef<FJsonObject>& AdminContext, FVCHttpCallback Callback);

	/** Zonenwechsel über einen Ausgang. Antwort: zoneId, address, arrivalTag. */
	static void RequestTransfer(int64 CharacterId, int64 AccountId, const FString& ExitCode, FVCHttpCallback Callback);
	static void WriteAdminAudit(const TSharedRef<FJsonObject>& Entry, FVCHttpCallback Callback);

	/** XP-Vergabe; jeder Aufruf bekommt einen neuen Idempotenzschlüssel. SkillCode leer = Charakter-XP. */
	static void GrantExperience(int64 CharacterId, int64 AccountId, const FString& SkillCode, int64 Amount,
		const FString& Source, FVCHttpCallback Callback);

	/** PvP-Regel und Art der Zone laden. */
	static void LoadZone(const FString& ZoneId, FVCHttpCallback Callback);

	/** Kill melden; das Backend vergibt XP aus den Gegnerdaten und führt die PvP-Statistik. */
	static void ReportKill(const TSharedRef<FJsonObject>& Kill, FVCHttpCallback Callback);

	/** Ganze Hotbar ersetzen (Index = Platz, None = leer). Das Backend prüft Besitz, Plätze und Fähigkeiten. */
	static void SaveHotbar(int64 CharacterId, int64 AccountId, const TArray<FName>& Slots, FVCHttpCallback Callback);

	/** Admin: Level bzw. Skillstufe setzen. Das Backend prüft Rechte und schreibt Audit in derselben Transaktion. */
	static void AdminSetLevel(int64 CharacterId, const FString& SkillCode, int32 Level,
		const TSharedRef<FJsonObject>& AdminContext, FVCHttpCallback Callback);
};
