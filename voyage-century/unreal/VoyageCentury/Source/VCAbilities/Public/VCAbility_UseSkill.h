#pragma once

#include "CoreMinimal.h"
#include "Abilities/GameplayAbility.h"
#include "Abilities/GameplayAbilityTargetTypes.h"
#include "VCAbilityStateComponent.h"
#include "VCAbility_UseSkill.generated.h"

/** Welche Fähigkeit eingesetzt werden soll; reist als Target Data im Event-Payload (nur auf dem Server). */
USTRUCT()
struct VCABILITIES_API FVCAbilityRequest : public FGameplayAbilityTargetData
{
	GENERATED_BODY()

	UPROPERTY()
	FName AbilityCode;

	virtual UScriptStruct* GetScriptStruct() const override { return FVCAbilityRequest::StaticStruct(); }
};

/**
 * Setzt eine Fähigkeit aus DT_Abilities ein. Eine Ability-Klasse für alle Fähigkeiten: Die Werte kommen
 * aus den Daten, die Prüfung aus vc::rules::CheckAbilityUse (eigenständig getestet).
 *
 * Läuft nur auf dem Server, ausgelöst durch VC.Event.UseAbility. Der Client nennt nur den Hotbar-Platz
 * und sein Ziel; Skillstufe, Waffe, Ausdauer, Abklingzeit, Ziel und Reichweite prüft der Server.
 * Ablauf: prüfen → Ausdauer abziehen → Abklingzeit starten → Schaden würfeln (falls vorgesehen) →
 * Statuseffekte bei Treffer (nicht bei Ausweichen) → Skill-XP.
 */
UCLASS()
class VCABILITIES_API UVCAbility_UseSkill : public UGameplayAbility
{
	GENERATED_BODY()

public:
	UVCAbility_UseSkill();

	virtual void ActivateAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
		const FGameplayAbilityActivationInfo ActivationInfo, const FGameplayEventData* TriggerEventData) override;

	/** Payload für SendGameplayEventToActor(User, TAG_VC_Event_UseAbility, ...). */
	static FGameplayEventData MakeRequest(AActor* User, FName AbilityCode, AActor* Target);

private:
	EVCAbilityBlock Use(const FGameplayAbilityActorInfo* ActorInfo, FName Code, AActor* Target);
};
