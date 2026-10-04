#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "VCAbilityRules.h"
#include "VCCombatStateComponent.generated.h"

/** Art eines Kampftextes über dem Kopf (nur Anzeige). */
UENUM(BlueprintType)
enum class EVCCombatText : uint8
{
	Hit,
	Critical,
	Blocked,
	Dodged,
	Periodic,
	Heal
};

/** Anzeige-Kopie eines aktiven Statuseffekts. */
USTRUCT(BlueprintType)
struct VCABILITIES_API FVCStatusView
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "Status") FName Code;
	UPROPERTY(BlueprintReadOnly, Category = "Status") int32 Stacks = 0;
	/** Ablauf in Server-Weltzeit (GameState->GetServerWorldTimeSeconds()). */
	UPROPERTY(BlueprintReadOnly, Category = "Status") double ExpiresAt = 0.0;
};

DECLARE_MULTICAST_DELEGATE_ThreeParams(FVCCombatTextEvent, AActor* /*Target*/, EVCCombatText /*Kind*/, int32 /*Amount*/);

/**
 * Kampfzustand eines Kämpfers (Spielfigur und Gegner): aktive Statuseffekte, periodischer Schaden und
 * Heilung, Verlangsamung und Betäubung, Ausdauer-Regeneration und Kampftexte.
 *
 * Die Wahrheit liegt nur auf dem Server (Regeln aus VCRules). Clients erhalten eine Anzeige-Kopie
 * (Statusliste, Tempo-Faktor, Betäubt) und die Kampftexte. Statuseffekte werden nicht gespeichert:
 * Tod, Respawn und Ausloggen beenden sie.
 */
UCLASS(ClassGroup = (VC), meta = (BlueprintSpawnableComponent))
class VCABILITIES_API UVCCombatStateComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UVCCombatStateComponent();

	static UVCCombatStateComponent* Find(const AActor* Actor);

	/** Kampftext an einem beliebigen Kämpfer angekommen (Clients; für das HUD). */
	static FVCCombatTextEvent OnCombatText;

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	/** Nur Server: Statuseffekt (DT_StatusEffects) anwenden oder auffrischen. Instigator bekommt Kills durch Schaden über Zeit. */
	void ServerApplyStatus(FName Code, AActor* Instigator);

	/** Nur Server: alle Effekte beenden (Tod). */
	void ServerClearAll();

	/** Nur Server: Kampftext an alle in Reichweite. */
	void ShowCombatText(EVCCombatText Kind, double Amount);

	/** Summe der Statusmodifikatoren (nur auf dem Server gefüllt). */
	const vc::rules::FStatModifiers& GetModifiers() const { return Modifiers; }

	bool IsStunned() const { return bStunned; }
	float GetMoveSpeedFactor() const { return MoveSpeedFactor; }
	const TArray<FVCStatusView>& GetStatuses() const { return Statuses; }

	/** Spieler regenerieren Ausdauer (StaminaRegenPerSecond aus DT_CombatTuning). */
	UPROPERTY(EditDefaultsOnly, Category = "Kampf")
	bool bRegenerateStamina = false;

protected:
	UFUNCTION(NetMulticast, Unreliable)
	void MulticastCombatText(EVCCombatText Kind, int32 Amount);

	UFUNCTION()
	void OnRep_MoveSpeedFactor();

private:
	UPROPERTY(Replicated)
	TArray<FVCStatusView> Statuses;

	UPROPERTY(ReplicatedUsing = OnRep_MoveSpeedFactor)
	float MoveSpeedFactor = 1.f;

	UPROPERTY(Replicated)
	bool bStunned = false;

	/** Serverzustand; DefIndex zeigt in FVCCombatData::StatusDefs(). */
	std::vector<vc::rules::FActiveStatus> Active;
	TMap<int32, TWeakObjectPtr<AActor>> Instigators;
	vc::rules::FStatModifiers Modifiers;
	FTimerHandle TickTimer;
	float BaseWalkSpeed = -1.f;

	void ServerTick();
	void Refresh();
	void ApplyWalkSpeed();
};
