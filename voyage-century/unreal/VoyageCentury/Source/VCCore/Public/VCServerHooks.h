#pragma once

#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "VCServerHooks.generated.h"

class AActor;
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

	/** Erlaubt die Zone Kämpfe zwischen Spielern? (aus zones.pvp_mode, vom Backend geladen) */
	virtual bool IsPvPAllowed() const = 0;

	/** Ein Kämpfer ist gestorben. Killer ist die verursachende Spielfigur oder null. Meldet ans Backend, steuert Respawn. */
	virtual void HandleKill(AActor* Killer, AActor* Victim) = 0;

	/** Ein Spieler hat mit einer Waffe getroffen; der Server vergibt dafür Skill-XP. */
	virtual void HandleWeaponHit(AActor* Attacker, FName SkillCode) = 0;
};
