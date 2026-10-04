#pragma once

#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "VCServerHooks.generated.h"

class AActor;
class APawn;
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

	/** Ein Spieler hat einen Skill erfolgreich eingesetzt (Waffentreffer oder Fähigkeit); der Server vergibt Skill-XP. */
	virtual void HandleSkillUse(AActor* User, FName SkillCode) = 0;

	/** Ein Spieler will einen Hotbar-Platz belegen (Code None = leeren). Prüfen, speichern, dann übernehmen. */
	virtual void HandleHotbarChange(APlayerController* Player, int32 Slot, FName AbilityCode) = 0;

	/** Eine Spielfigur hat einen Zonenausgang betreten (AVCZoneExit). Wechsel nur, wenn das Backend ihn erlaubt. */
	virtual void HandleZoneExit(APawn* Pawn, FName ExitCode) = 0;

	/** Eine Spielfigur hat einen Entdeckungspunkt betreten (AVCDiscoveryPoint). Zählt das Backend einmal je Charakter. */
	virtual void HandleDiscovery(APawn* Pawn, FName DiscoveryCode) = 0;

	/** Schiffsbefehle eines Spielers: "list", "buy <SCHIFF>" (beim Werftmeister in der Nähe), "activate <instanceId>". */
	virtual void HandleShipCommand(APlayerController* Player, const FString& Command, const FString& Argument) = 0;
};
