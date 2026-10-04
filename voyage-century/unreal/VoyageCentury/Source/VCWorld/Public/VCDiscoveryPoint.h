#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VCDiscoveryPoint.generated.h"

class UBoxComponent;
class UTextRenderComponent;

/**
 * Entdeckungspunkt (z. B. Ruine, Wrack). Betritt eine Spielfigur das Volumen, meldet der Server die Entdeckung
 * an das Backend; dort zählt sie je Charakter einmal und nur in der Zone, zu der der Punkt gehört (DT_Discoveries).
 */
UCLASS()
class VCWORLD_API AVCDiscoveryPoint : public AActor
{
	GENERATED_BODY()

public:
	AVCDiscoveryPoint();

	/** Code aus DT_Discoveries. */
	UPROPERTY(EditAnywhere, Category = "Entdeckung")
	FName DiscoveryCode;

	virtual void OnConstruction(const FTransform& Transform) override;

protected:
	virtual void NotifyActorBeginOverlap(AActor* OtherActor) override;

private:
	UPROPERTY(VisibleAnywhere, Category = "Entdeckung")
	TObjectPtr<UBoxComponent> Volume;

	UPROPERTY(VisibleAnywhere, Category = "Entdeckung")
	TObjectPtr<UTextRenderComponent> Label;
};
