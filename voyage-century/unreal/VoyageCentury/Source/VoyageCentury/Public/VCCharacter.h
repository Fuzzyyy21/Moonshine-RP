#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "VCCharacter.generated.h"

class UCameraComponent;
class UInputAction;
class UInputMappingContext;
class USpringArmComponent;
class UStaticMeshComponent;
struct FInputActionValue;

/**
 * Spielfigur an Land. Bewegung über die Character Movement Component: der Client sagt voraus,
 * der Server rechnet nach und korrigiert. Der Client sendet nur Eingaben, keine Positionen.
 *
 * Steuerung (Enhanced Input, zur Laufzeit erzeugt, damit keine Binär-Assets nötig sind):
 *   WASD bewegen, Maus umsehen, Leertaste springen.
 * Laufgeschwindigkeit und Sprunghöhe des Originals sind UNKNOWN; es gelten die Engine-Standardwerte.
 */
UCLASS()
class VOYAGECENTURY_API AVCCharacter : public ACharacter
{
	GENERATED_BODY()

public:
	AVCCharacter();

	virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;
	virtual void PawnClientRestart() override;

private:
	UPROPERTY(VisibleAnywhere, Category = "Visual")
	TObjectPtr<UStaticMeshComponent> PlaceholderBody;

	UPROPERTY(VisibleAnywhere, Category = "Camera")
	TObjectPtr<USpringArmComponent> CameraBoom;

	UPROPERTY(VisibleAnywhere, Category = "Camera")
	TObjectPtr<UCameraComponent> FollowCamera;

	UPROPERTY(Transient)
	TObjectPtr<UInputMappingContext> InputContext;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> MoveAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> LookAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> JumpAction;

	void CreateInputObjects();
	void Move(const FInputActionValue& Value);
	void Look(const FInputActionValue& Value);
};
