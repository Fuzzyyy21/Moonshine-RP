#pragma once

#include "CoreMinimal.h"
#include "GameplayEffect.h"
#include "VCDamage.generated.h"

/**
 * Sofortiger Schaden in Höhe von VC.Data.Damage (SetByCaller) über das Meta-Attribut IncomingDamage.
 * Berechnet wird vorher auf dem Server (FVCCombat), damit Treffer, Krit und Statuseffekte zusammenpassen.
 */
UCLASS()
class VCABILITIES_API UVCDamageEffect : public UGameplayEffect
{
	GENERATED_BODY()

public:
	UVCDamageEffect();
};
