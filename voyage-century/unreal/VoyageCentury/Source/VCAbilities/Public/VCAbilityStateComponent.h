#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "VCAbilityStateComponent.generated.h"

/** Warum eine Fähigkeit nicht eingesetzt wurde. Gleiche Reihenfolge wie vc::rules::EAbilityBlock, plus Unavailable. */
UENUM(BlueprintType)
enum class EVCAbilityBlock : uint8
{
	None,
	Dead,
	Stunned,
	WrongWeapon,
	SkillTooLow,
	OnCooldown,
	NotEnoughStamina,
	NoTarget,
	TargetNotHostile,
	OutOfRange,
	/** Unbekannte Fähigkeit oder Daten fehlen. */
	Unavailable
};

/** Anzeige-Kopie einer laufenden Abklingzeit. */
USTRUCT(BlueprintType)
struct VCABILITIES_API FVCCooldownView
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "Fähigkeit") FName Code;
	/** Server-Weltzeit, ab der die Fähigkeit wieder bereit ist (ohne Latenztoleranz). */
	UPROPERTY(BlueprintReadOnly, Category = "Fähigkeit") double ReadyAt = 0.0;
};

DECLARE_MULTICAST_DELEGATE_TwoParams(FVCAbilityBlockedEvent, FName /*Code*/, EVCAbilityBlock /*Reason*/);

/**
 * Fähigkeiten eines Spielers: Hotbar-Belegung und Abklingzeiten. Sitzt am PlayerState, damit beides
 * Tod und Respawn überdauert. Der Server ist die Wahrheit; der Besitzer bekommt eine Anzeige-Kopie.
 * Die Hotbar setzt nur der Server, und erst nachdem das Backend sie gespeichert hat.
 */
UCLASS(ClassGroup = (VC), meta = (BlueprintSpawnableComponent))
class VCABILITIES_API UVCAbilityStateComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	/** Muss zu character_hotbar (V0007) und HotbarEndpoints.SlotCount im Backend passen. */
	static constexpr int32 HotbarSlots = 10;

	UVCAbilityStateComponent();

	/** Am PlayerState oder über die Spielfigur zu dessen PlayerState. */
	static UVCAbilityStateComponent* Find(const AActor* Actor);

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

	FName GetHotbarSlot(int32 Slot) const;
	const TArray<FName>& GetHotbar() const { return Hotbar; }

	/** Restliche Abklingzeit in Sekunden (für die Anzeige, Server-Weltzeit über den GameState). */
	double GetRemainingCooldown(FName Code) const;

	/** Nur Server: neue Belegung (bereits vom Backend bestätigt). Länge wird auf HotbarSlots gebracht. */
	void ServerSetHotbar(const TArray<FName>& Slots);

	/** Nur Server: letzter Einsatz in Weltzeit, < 0 = noch nie. */
	double GetLastUse(FName Code) const;
	void ServerMarkUsed(FName Code, double Now, double CooldownSeconds);

	/** Nur Server: Besitzer erfährt, warum ein Einsatz scheiterte. */
	void ServerReportBlocked(FName Code, EVCAbilityBlock Reason);

	/** Auf dem Client des Besitzers. */
	FVCAbilityBlockedEvent OnAbilityBlocked;
	FSimpleMulticastDelegate OnHotbarChanged;

protected:
	UFUNCTION(Client, Unreliable)
	void ClientAbilityBlocked(FName Code, EVCAbilityBlock Reason);

	UFUNCTION()
	void OnRep_Hotbar();

private:
	/** Code aus DT_Abilities je Platz; None = leer. */
	UPROPERTY(ReplicatedUsing = OnRep_Hotbar)
	TArray<FName> Hotbar;

	UPROPERTY(Replicated)
	TArray<FVCCooldownView> Cooldowns;

	TMap<FName, double> LastUse;
};
