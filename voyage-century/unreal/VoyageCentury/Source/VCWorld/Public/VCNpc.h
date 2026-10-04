#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VCNpc.generated.h"

class UCapsuleComponent;
class UStaticMeshComponent;
class UTextRenderComponent;

/**
 * NPC in einer Stadt (Platzhalter-Figur). Wer er ist, steht in DT_Npcs (NpcCode); platziert wird er in der Karte,
 * weil Stadtpläne des Originals UNKNOWN sind. Ansprechen: Taste E in der Nähe; Abstand prüft der Server.
 * Die Dienste selbst (Werft, Offizierskarten) folgen mit Phase 5 und 6.
 */
UCLASS()
class VCWORLD_API AVCNpc : public AActor
{
	GENERATED_BODY()

public:
	AVCNpc();

	/** Code aus DT_Npcs, z. B. LONDON_OFFICER_EXCHANGE. */
	UPROPERTY(EditAnywhere, Category = "NPC")
	FName NpcCode;

	virtual void BeginPlay() override;
	virtual void OnConstruction(const FTransform& Transform) override;

private:
	UPROPERTY(VisibleAnywhere, Category = "NPC")
	TObjectPtr<UCapsuleComponent> Capsule;

	UPROPERTY(VisibleAnywhere, Category = "NPC")
	TObjectPtr<UStaticMeshComponent> PlaceholderBody;

	UPROPERTY(VisibleAnywhere, Category = "NPC")
	TObjectPtr<UTextRenderComponent> NameLabel;

	void UpdateLabel();
};
