#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "VCCharacter.generated.h"

class UCameraComponent;
class USpringArmComponent;
class UStaticMeshComponent;

/**
 * Phase-1-Spielfigur: repliziert, sichtbar (Platzhalterform aus den Engine-Grundformen), Kamera.
 * Steuerung, Animation und echtes Modell kommen in Phase 2.
 */
UCLASS()
class VOYAGECENTURY_API AVCCharacter : public ACharacter
{
	GENERATED_BODY()

public:
	AVCCharacter();

private:
	UPROPERTY(VisibleAnywhere, Category = "Visual")
	TObjectPtr<UStaticMeshComponent> PlaceholderBody;

	UPROPERTY(VisibleAnywhere, Category = "Camera")
	TObjectPtr<USpringArmComponent> CameraBoom;

	UPROPERTY(VisibleAnywhere, Category = "Camera")
	TObjectPtr<UCameraComponent> FollowCamera;
};
