#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "UObject/ObjectKey.h"
#include "VCAppearance.h"
#include "VCServerHooks.h"
#include "VCGameMode.generated.h"

struct FVCHttpResult;
class FJsonObject;

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
 * Progression: XP vergibt nur dieser Server über den GameData-Dienst; übernommen wird nur, was das
 *   Backend bestätigt. Clients können Level, XP und Skills nicht setzen.
 * Admin: jedes Kommando wird protokolliert, bevor es wirkt (Teleport/XP: erst Audit, dann Aktion;
 *   setlevel/setskill: Backend schreibt Änderung und Audit in einer Transaktion).
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

	/** Charakter-XP vergeben (z. B. aus Kampf oder Quest, ab Phase 3). Nur Server. */
	void GrantExperience(APlayerController* PC, int64 Amount, const FString& Source);

	/** Skill-XP vergeben (Skill-Code aus DT_Skills). Nur Server. */
	void GrantSkillExperience(APlayerController* PC, FName SkillCode, int64 Amount, const FString& Source);

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
		FVCAppearance Appearance;
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
	void AdminSetLevel(APlayerController* Issuer, const FPlayerSession& Session, const FString& SkillCode, const FString& LevelArg);
	void AdminGiveXp(APlayerController* Issuer, const FPlayerSession& Session, const FString& SkillCode, const FString& AmountArg);

	/** Schreibt den Audit-Eintrag und führt Action nur aus, wenn das Backend ihn bestätigt hat. */
	void AuditThenRun(APlayerController* Issuer, const FPlayerSession& Session, const FString& Command,
		const TSharedRef<FJsonObject>& Args, const TSharedRef<FJsonObject>& OldValue, const TSharedRef<FJsonObject>& NewValue,
		TFunction<void(APlayerController*)> Action);

	TSharedRef<FJsonObject> AdminContext(const APlayerController* Issuer, const FPlayerSession& Session) const;
	void RequestGrant(APlayerController* PC, const FString& SkillCode, int64 Amount, const FString& Source);
};
