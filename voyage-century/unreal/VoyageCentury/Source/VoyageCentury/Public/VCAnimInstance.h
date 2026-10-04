#pragma once

#include "CoreMinimal.h"
#include "Animation/AnimInstance.h"
#include "VCAnimInstance.generated.h"

/**
 * Basisklasse für das Animation Blueprint der Spielfigur. Liefert die Werte, die ein
 * Fortbewegungs-State-Machine braucht; Animationen selbst kommen als Assets dazu.
 * Alle Werte stammen aus der replizierten Bewegung, daher sehen alle Clients dasselbe.
 */
UCLASS()
class VOYAGECENTURY_API UVCAnimInstance : public UAnimInstance
{
	GENERATED_BODY()

public:
	virtual void NativeUpdateAnimation(float DeltaSeconds) override;

protected:
	/** Horizontale Geschwindigkeit in cm/s. */
	UPROPERTY(BlueprintReadOnly, Category = "Bewegung")
	float GroundSpeed = 0.f;

	/** Richtung relativ zur Blickrichtung, −180 bis 180 Grad. */
	UPROPERTY(BlueprintReadOnly, Category = "Bewegung")
	float Direction = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "Bewegung")
	bool bIsMoving = false;

	UPROPERTY(BlueprintReadOnly, Category = "Bewegung")
	bool bIsFalling = false;

	/** Ab dieser Geschwindigkeit gilt die Figur als in Bewegung. */
	UPROPERTY(EditDefaultsOnly, Category = "Bewegung")
	float MovingThreshold = 3.f;
};
