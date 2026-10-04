#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "VCServerSettings.generated.h"

/**
 * Einstellungen des Zonen-Servers (Projekteinstellungen > Voyage Century Server).
 * Kommandozeile: -VCZone=DEV_TESTZONE -VCServerId=zone-dev-1 -VCPublicAddress=203.0.113.5:7777
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

	/** Host, unter dem Clients diesen Server erreichen; der Port kommt aus dem Server-Start (-port=). */
	UPROPERTY(config, EditAnywhere, Category = "World Directory")
	FString PublicHost = TEXT("127.0.0.1");

	/** Höchstens so viele Spieler schickt das World Directory hierher (technische Grenze, kein Originalwert). */
	UPROPERTY(config, EditAnywhere, Category = "World Directory", meta = (ClampMin = "1"))
	int32 Capacity = 100;

	/** Wird ein Client nach einem Zonenwechsel nicht innerhalb dieser Zeit weitergereist, wird er getrennt. */
	UPROPERTY(config, EditAnywhere, Category = "World Directory", meta = (ClampMin = "3"))
	float TransferKickSeconds = 15.f;

	/** Nur im Editor (PIE): Spieler ohne Backend zulassen. In gepackten Builds wirkungslos. */
	UPROPERTY(config, EditAnywhere, Category = "Login")
	bool bAllowUnauthenticatedInEditor = true;

	static FString GetZoneId();
	static FString GetServerId();

	/** host:port für das World Directory: -VCPublicAddress= oder PublicHost plus Port der laufenden Welt. */
	static FString GetPublicAddress(const UWorld* World);
};
