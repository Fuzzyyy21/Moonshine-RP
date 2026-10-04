#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "UObject/ObjectKey.h"
#include "VCAppearance.h"
#include "VCServerHooks.h"
#include "VCGameMode.generated.h"

enum class EVCNpcRole : uint8;

struct FVCHttpResult;
class FJsonObject;

/**
 * Server-GameMode einer Zone (Phase 1).
 *
 * Ablauf beim Verbinden:
 *   1. PreLogin: URL-Optionen ?ticket=...?character=... müssen vorhanden sein.
 *   2. HandleStartingNewPlayer: noch kein Pawn. Ticket beim Auth-Dienst prüfen,
 *      dann Charakter im World Directory auf diesen Server holen (nur, wenn er nirgends sonst online ist
 *      und in dieser Zone steht), dann beim GameData-Dienst laden (inkl. Besitzprüfung).
 *   3. Erst danach Pawn an gespeicherter Position (gleiche Zone), am Ankunftspunkt eines Zonenwechsels
 *      (PlayerStart mit passendem Tag) oder am PlayerStart.
 *
 * World Directory: Der Server meldet sich beim Start an und sendet Lebenszeichen. Zonenausgänge
 *   (AVCZoneExit) führen über das Backend in die Zielzone: speichern → Wechsel anfordern → Client reist.
 *   Scheitert ein Schritt oder dauert er länger als AuthTimeoutSeconds, wird der Spieler getrennt.
 *
 * Speichern: periodisch, beim Zerstören des Pawns (Logout: letzter Stand gibt die Anwesenheit frei) und nach
 *   Admin-Teleport. Nach einem Zonenwechsel speichert nur noch der Zielserver.
 * Progression: XP vergibt nur dieser Server über den GameData-Dienst; übernommen wird nur, was das
 *   Backend bestätigt. Clients können Level, XP und Skills nicht setzen.
 * Hotbar: wird beim Laden übernommen; Änderungen erst nach Bestätigung durch das Backend.
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
	virtual bool IsPvPAllowed() const override { return bPvPAllowed; }
	virtual FString GetZoneId() const override;
	virtual void HandleKill(AActor* Killer, AActor* Victim) override;
	virtual void HandleSkillUse(AActor* User, FName SkillCode) override;
	virtual void HandleHotbarChange(APlayerController* Player, int32 Slot, FName AbilityCode) override;
	virtual void HandleZoneExit(APawn* Pawn, FName ExitCode) override;
	virtual void HandleDiscovery(APawn* Pawn, FName DiscoveryCode) override;
	virtual void HandleShipCommand(APlayerController* Player, const FString& Command, const FString& Argument) override;
	virtual void HandleInventoryCommand(APlayerController* Player, const FString& Command, const FString& Argument) override;
	virtual void HandleShipSunk(APawn* Ship, AActor* Killer) override;
	virtual void HandleMonsterKill(AActor* Killer, FName MonsterCode) override;

	/** Auf See (Zonenart SEA) und mit aktivem Schiff ist das Schiff die Spielfigur, sonst die Figur an Land. */
	virtual UClass* GetDefaultPawnClassForController_Implementation(AController* InController) override;

	/** Charakter-XP vergeben (z. B. aus Kampf oder Quest, ab Phase 3). Nur Server. */
	void GrantExperience(APlayerController* PC, int64 Amount, const FString& Source);

	/** Skill-XP vergeben (Skill-Code aus DT_Skills). Nur Server. */
	void GrantSkillExperience(APlayerController* PC, FName SkillCode, int64 Amount, const FString& Source);

protected:
	virtual void BeginPlay() override;

private:
	/** NPC dieser Rolle in Interaktionsreichweite des Spielers (mit Latenz-Toleranz); None, wenn keiner. */
	FName FindNpcInRange(const APlayerController* Player, EVCNpcRole Role) const;

	/** Inventar-Antwort des Backends anzeigen und die ausgerüstete Waffe übernehmen (nur was das Backend bestätigt). */
	void ApplyInventory(APlayerController* PC, const TSharedPtr<FJsonObject>& Inventory, bool bPrint);

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
		/** Zuletzt gespeicherte Vitals (Health, MaxHealth, Stamina, MaxStamina); Y == 0 = keine. */
		FIntVector4 SavedVitals = FIntVector4(0, 0, 0, 0);
		/** Ausgerüstete Waffe; überdauert Tod und Respawn. */
		FName EquippedWeapon;
		/** Eine Hotbar-Speicherung zur Zeit; weitere Änderungen werden bis zur Antwort abgewiesen. */
		bool bHotbarSaveInFlight = false;
		/** Im World Directory auf diesem Server ONLINE gesetzt. */
		bool bClaimed = false;
		/** Zonenwechsel läuft oder ist erfolgt: dieser Server speichert den Charakter nicht mehr. */
		bool bTransferring = false;
		/** Letzter Speicherstand (mit Freigabe) ist unterwegs; Logout gibt dann nicht noch einmal frei. */
		bool bFinalSaveSent = false;
		/** PlayerStart-Tag aus einem Zonenwechsel; leer = gespeicherte Position oder Standard-Start. */
		FString ArrivalTag;
		/** Bereits entdeckt (aus dem Charakterzustand) oder Meldung unterwegs: nicht erneut melden. */
		TSet<FName> Discoveries;
		/** Schiffe laut Backend (Stand des letzten Ladens, Kaufs bzw. Speicherns). */
		struct FShip
		{
			int64 InstanceId = 0;
			FName Code;
			bool bActive = false;
			int32 HullHp = 0;
			int32 HullMax = 0;
			int32 Crew = 0;
			int32 Injured = 0;
			int32 Provisions = 0;

			static bool FromJson(const TSharedPtr<FJsonObject>& Json, FShip& Out);
		};
		TArray<FShip> Ships;
		int64 Gold = 0;
		bool bShipRequestInFlight = false;
	};

	/** PvP-Regel der Zone; bis das Backend antwortet, ist PvP aus. */
	bool bPvPAllowed = false;

	/** Zonenart (SEA, CITY, …) aus dem Backend; bis zur Antwort leer (dann keine Schiffe). */
	FString ZoneKind;

	TMap<TObjectKey<APlayerController>, FPlayerSession> Sessions;
	FTimerHandle SaveTimer;
	FTimerHandle AuthTimeoutTimer;
	FTimerHandle DirectoryTimer;

	bool IsAuthRequired() const;
	void BeginAuthentication(APlayerController* PC);
	void OnTicketValidated(APlayerController* PC, const FVCHttpResult& Result);
	void OnCharacterClaimed(APlayerController* PC, const FVCHttpResult& Result);
	void OnCharacterLoaded(APlayerController* PC, const FVCHttpResult& Result);
	void SpawnAuthenticatedPlayer(APlayerController* PC, const TOptional<FTransform>& SavedTransform);
	void Reject(APlayerController* PC, const FString& Reason);

	/** bFinal: letzter Stand beim Ausloggen, gibt die Anwesenheit im World Directory frei. */
	void SaveSession(const APlayerController* PC, const FPlayerSession& Session, const APawn& Pawn, bool bFinal) const;

	/**
	 * Schiff (falls die Spielfigur eines ist) und danach Charakter speichern; Done bekommt das Ergebnis des Charakters.
	 * Reihenfolge ist wichtig: Der letzte Charakter-Stand gibt die Anwesenheit frei, danach nimmt das Backend nichts mehr an.
	 */
	static void SaveShipThenCharacter(const APlayerController* PC, int64 CharacterId, int64 AccountId, const APawn& Pawn, bool bFinal,
		TFunction<void(const FVCHttpResult&)> Done);

	void RegisterWithDirectory();
	void SendHeartbeat();
	void CompleteTransfer(APlayerController* PC, int64 CharacterId, const FString& Address);
	void CancelTransfer(APlayerController* PC, const FString& Reason);
	void ReportKill(APlayerController* KillerPC, const FPlayerSession& Killer, const TSharedRef<FJsonObject>& Kill);
	void ScheduleRespawn(APlayerController* PC);
	void RespawnPlayer(APlayerController* PC);
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
