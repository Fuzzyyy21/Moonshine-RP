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
	/** Position und (falls bekannt) Leben/Ausdauer speichern. Vitals mit MaxHealth <= 0 werden nicht mitgeschickt. */
	static void SaveCharacter(int64 CharacterId, int64 AccountId, const FString& ZoneId,
		const FVector& Location, float Yaw, const FIntVector4& Vitals, FVCHttpCallback Callback);
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
