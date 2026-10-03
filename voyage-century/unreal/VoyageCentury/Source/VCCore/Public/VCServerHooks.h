#pragma once

#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "VCServerHooks.generated.h"

class APlayerController;

UINTERFACE(MinimalAPI)
class UVCServerHooks : public UInterface
{
	GENERATED_BODY()
};

/**
 * Wird vom Server-GameMode (Modul VCServer) implementiert. So können Klassen aus dem
 * gemeinsamen Spielmodul (z. B. der PlayerController) Serverlogik aufrufen, ohne von
 * VCServer abzuhängen. Aufrufe nur mit Autorität.
 */
class VCCORE_API IVCServerHooks
{
	GENERATED_BODY()

public:
	/** Admin-Kommando eines Spielers, z. B. "teleport 0 0 500". Rechteprüfung und Audit liegen beim Server. */
	virtual void HandleAdminCommand(APlayerController* Issuer, const FString& CommandLine) = 0;
};
