#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VCGatherNode.generated.h"

class APawn;
class UStaticMeshComponent;
class UTextRenderComponent;

/**
 * Sammelpunkt (Erzader, Baum, Feld …; Art aus DT_GatherNodes). Ansprechen mit E startet das Sammeln: Der Server wartet die
 * Sammelzeit ab, prüft dann den Abstand erneut und meldet das Ergebnis über IVCServerHooks::HandleGather. Bestätigt das Backend,
 * ist der Punkt erschöpft und wächst nach RespawnSeconds nach. Immer nur ein Sammler gleichzeitig.
 */
UCLASS()
class VCWORLD_API AVCGatherNode : public AActor
{
	GENERATED_BODY()

public:
	AVCGatherNode();

	/** Code aus DT_GatherNodes (= gather_nodes.code im Backend). */
	UPROPERTY(EditAnywhere, Category = "Sammeln")
	FName NodeCode;

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
	virtual void OnConstruction(const FTransform& Transform) override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	bool IsAvailable() const { return bAvailable && !Gatherer.IsValid(); }

	/** Nur Server: Sammeln beginnen. Gibt die Sammelzeit zurück, oder einen negativen Wert, wenn es nicht geht. */
	float ServerStartGather(APawn* Pawn);

private:
	UPROPERTY(VisibleAnywhere, Category = "Sammeln")
	TObjectPtr<UStaticMeshComponent> Body;

	UPROPERTY(VisibleAnywhere, Category = "Sammeln")
	TObjectPtr<UTextRenderComponent> Label;

	UPROPERTY(ReplicatedUsing = OnRep_Available)
	bool bAvailable = true;

	TWeakObjectPtr<APawn> Gatherer;
	FVector StartLocation = FVector::ZeroVector;
	FTimerHandle GatherTimer;
	FTimerHandle RespawnTimer;

	UFUNCTION()
	void OnRep_Available();

	void FinishGather();
	void SetAvailable(bool bNow);
};
