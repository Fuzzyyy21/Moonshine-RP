#pragma once

#include "CoreMinimal.h"
#include "GameplayEffect.h"
#include "GameplayEffectExecutionCalculation.h"
#include "VCDamage.generated.h"

/**
 * Schadensberechnung: liest die Attribute von Angreifer und Ziel, würfelt auf dem Server und
 * überlässt die Formel vc::rules::ResolveAttack (eigenständig getestet).
 */
UCLASS()
class VCABILITIES_API UVCDamageExecution : public UGameplayEffectExecutionCalculation
{
	GENERATED_BODY()

public:
	UVCDamageExecution();

	virtual void Execute_Implementation(const FGameplayEffectCustomExecutionParameters& ExecutionParams,
		FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const override;
};

/** Sofortiger Schaden über UVCDamageExecution. Waffenschaden kommt per SetByCaller (VC.Data.WeaponDamage). */
UCLASS()
class VCABILITIES_API UVCDamageEffect : public UGameplayEffect
{
	GENERATED_BODY()

public:
	UVCDamageEffect();
};
