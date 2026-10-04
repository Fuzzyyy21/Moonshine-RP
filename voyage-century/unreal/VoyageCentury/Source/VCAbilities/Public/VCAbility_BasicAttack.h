#pragma once

#include "CoreMinimal.h"
#include "Abilities/GameplayAbility.h"
#include "VCAbility_BasicAttack.generated.h"

/**
 * Grundangriff. Läuft nur auf dem Server und wird durch das Ereignis VC.Event.Attack ausgelöst
 * (Ziel im Payload). Prüft: beide leben, Angreifer nicht betäubt, Ziel ist feindlich (PvP nur, wenn die
 * Zone es erlaubt), Ziel in Waffenreichweite, Angriffsintervall abgelaufen – alles mit den Regeln aus VCRules.
 */
UCLASS()
class VCABILITIES_API UVCAbility_BasicAttack : public UGameplayAbility
{
	GENERATED_BODY()

public:
	UVCAbility_BasicAttack();

	virtual void ActivateAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
		const FGameplayAbilityActivationInfo ActivationInfo, const FGameplayEventData* TriggerEventData) override;

private:
	double LastAttackTime = -1.0;

	bool PerformAttack(const FGameplayAbilityActorInfo* ActorInfo, AActor* Target);
};
