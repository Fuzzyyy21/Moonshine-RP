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
	static void SaveCharacter(int64 CharacterId, int64 AccountId, const FString& ZoneId,
		const FVector& Location, float Yaw, FVCHttpCallback Callback);
	static void WriteAdminAudit(const TSharedRef<FJsonObject>& Entry, FVCHttpCallback Callback);
};
