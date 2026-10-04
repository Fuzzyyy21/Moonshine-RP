#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerState.h"
#include "VCPlayerState.generated.h"

class UVCProgressionComponent;

/** PlayerState mit Progression. Überlebt Pawn-Wechsel und Tod, nicht aber das Verlassen der Zone. */
UCLASS()
class VOYAGECENTURY_API AVCPlayerState : public APlayerState
{
	GENERATED_BODY()

public:
	AVCPlayerState();

	UVCProgressionComponent* GetProgression() const { return Progression; }

private:
	UPROPERTY(VisibleAnywhere, Category = "Progression")
	TObjectPtr<UVCProgressionComponent> Progression;
};
