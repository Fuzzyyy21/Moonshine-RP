#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "VCServerSettings.generated.h"

/**
 * Einstellungen des Zonen-Servers (Projekteinstellungen > Voyage Century Server).
 * Kommandozeile: -VCZone=DEV_TESTZONE -VCServerId=zone-dev-1
 * Der Service-Key kommt nur aus der Umgebungsvariable VC_SERVICE_KEY, nie aus Dateien.
 */
UCLASS(config = Game, defaultconfig, meta = (DisplayName = "Voyage Century Server"))
class VCSERVER_API UVCServerSettings : public UDeveloperSettings
{
	GENERATED_BODY()

public:
	/** Zone dieses Servers; muss in der Tabelle zones existieren. */
	UPROPERTY(config, EditAnywhere, Category = "Zone")
	FString ZoneId = TEXT("DEV_TESTZONE");

	UPROPERTY(config, EditAnywhere, Category = "Persistenz", meta = (ClampMin = "5"))
	float SaveIntervalSeconds = 30.f;

	/** Spieler ohne erfolgreiche Ticketprüfung werden danach getrennt. */
	UPROPERTY(config, EditAnywhere, Category = "Login", meta = (ClampMin = "3"))
	float AuthTimeoutSeconds = 15.f;

	/** Mindest-Adminlevel (accounts.admin_level) für /teleport. */
	UPROPERTY(config, EditAnywhere, Category = "Admin", meta = (ClampMin = "1"))
	int32 TeleportAdminLevel = 1;

	/** Nur im Editor (PIE): Spieler ohne Backend zulassen. In gepackten Builds wirkungslos. */
	UPROPERTY(config, EditAnywhere, Category = "Login")
	bool bAllowUnauthenticatedInEditor = true;

	static FString GetZoneId();
	static FString GetServerId();
};
