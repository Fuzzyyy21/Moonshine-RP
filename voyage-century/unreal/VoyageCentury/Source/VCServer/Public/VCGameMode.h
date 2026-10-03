#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "UObject/ObjectKey.h"
#include "VCServerHooks.h"
#include "VCGameMode.generated.h"

struct FVCHttpResult;

/**
 * Server-GameMode einer Zone (Phase 1).
 *
 * Ablauf beim Verbinden:
 *   1. PreLogin: URL-Optionen ?ticket=...?character=... müssen vorhanden sein.
 *   2. HandleStartingNewPlayer: noch kein Pawn. Ticket beim Auth-Dienst prüfen,
 *      dann Charakter beim GameData-Dienst laden (inkl. Besitzprüfung).
 *   3. Erst danach Pawn an gespeicherter Position (gleiche Zone) oder am PlayerStart.
 *   Scheitert ein Schritt oder dauert er länger als AuthTimeoutSeconds, wird der Spieler getrennt.
 *
 * Speichern: periodisch, beim Zerstören des Pawns (Logout) und nach Admin-Teleport.
 * Admin: jedes Kommando wird erst ins Audit-Log geschrieben und nur bei Erfolg ausgeführt.
 */
UCLASS()
class VCSERVER_API AVCGameMode : public AGameModeBase, public IVCServerHooks
{
	GENERATED_BODY()

public:
	AVCGameMode();

	virtual void PreLogin(const FString& Options, const FString& Address, const FUniqueNetIdRepl& UniqueId,
		FString& ErrorMessage) override;
	virtual FString InitNewPlayer(APlayerController* NewPlayerController, const FUniqueNetIdRepl& UniqueId,
		const FString& Options, const FString& Portal = TEXT("")) override;
	virtual void HandleStartingNewPlayer_Implementation(APlayerController* NewPlayer) override;
	virtual void Logout(AController* Exiting) override;

	// IVCServerHooks
	virtual void HandleAdminCommand(APlayerController* Issuer, const FString& CommandLine) override;

protected:
	virtual void BeginPlay() override;

private:
	struct FPlayerSession
	{
		FString Ticket;
		int64 CharacterId = 0;
		int64 AccountId = 0;
		FString SessionId;
		int32 AdminLevel = 0;
		bool bAuthenticated = false;
		double ConnectedAt = 0.0;
		TWeakObjectPtr<APawn> Pawn;
	};

	TMap<TObjectKey<APlayerController>, FPlayerSession> Sessions;
	FTimerHandle SaveTimer;
	FTimerHandle AuthTimeoutTimer;

	bool IsAuthRequired() const;
	void BeginAuthentication(APlayerController* PC);
	void OnTicketValidated(APlayerController* PC, const FVCHttpResult& Result);
	void OnCharacterLoaded(APlayerController* PC, const FVCHttpResult& Result);
	void SpawnAuthenticatedPlayer(APlayerController* PC, const TOptional<FTransform>& SavedTransform);
	void Reject(APlayerController* PC, const FString& Reason);

	void SaveSession(const FPlayerSession& Session, const APawn& Pawn) const;
	void SaveAllPlayers();
	void DisconnectTimedOutPlayers();

	UFUNCTION()
	void OnPlayerPawnDestroyed(AActor* DestroyedActor);

	void AdminTeleport(APlayerController* Issuer, const FPlayerSession& Session, const TArray<FString>& Args);
};
