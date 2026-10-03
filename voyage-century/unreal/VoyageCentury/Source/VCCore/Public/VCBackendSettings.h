#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "VCBackendSettings.generated.h"

/**
 * Adressen der Backend-Dienste (Projekteinstellungen > Voyage Century Backend).
 * Server und Clients können die Werte per Kommandozeile überschreiben:
 *   -VCAuthUrl=https://auth.example  -VCGameDataUrl=https://gamedata.example
 */
UCLASS(config = Game, defaultconfig, meta = (DisplayName = "Voyage Century Backend"))
class VCCORE_API UVCBackendSettings : public UDeveloperSettings
{
	GENERATED_BODY()

public:
	UPROPERTY(config, EditAnywhere, Category = "Backend")
	FString AuthBaseUrl = TEXT("http://localhost:5100");

	UPROPERTY(config, EditAnywhere, Category = "Backend")
	FString GameDataBaseUrl = TEXT("http://localhost:5200");

	UPROPERTY(config, EditAnywhere, Category = "Backend", meta = (ClampMin = "1", ClampMax = "60"))
	float RequestTimeoutSeconds = 10.f;

	static FString GetAuthBaseUrl();
	static FString GetGameDataBaseUrl();
};
