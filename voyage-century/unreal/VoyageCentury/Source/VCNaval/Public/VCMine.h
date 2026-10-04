#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VCNavalAbilityRules.h"
#include "VCMine.generated.h"

class AVCShip;
class UStaticMeshComponent;

/**
 * Seemine (Fähigkeit belegt, Mechanik [DESIGN]). Der Server prüft regelmäßig, ob ein Schiff im Auslöseradius liegt
 * (vc::rules::MineTriggers): feindliche Schiffe des Legers und nach der Scharfschaltzeit auch der Leger selbst.
 * Verschwindet nach der Lebensdauer oder wenn der Leger die Zone verlässt. Platzhalter-Kugel, bis es Assets gibt.
 */
UCLASS()
class VCNAVAL_API AVCMine : public AActor
{
	GENERATED_BODY()

public:
	AVCMine();

	/** Nur Server, direkt nach dem Spawnen. */
	void Arm(AVCShip* InLayer, double Now);

	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

private:
	UPROPERTY(VisibleAnywhere, Category = "Mine")
	TObjectPtr<UStaticMeshComponent> Body;

	TWeakObjectPtr<AVCShip> Layer;
	vc::rules::FMine Mine;
	FTimerHandle CheckTimer;

	void Check();
};
