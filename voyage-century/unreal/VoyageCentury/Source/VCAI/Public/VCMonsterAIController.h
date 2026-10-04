#pragma once

#include "CoreMinimal.h"
#include "AIController.h"
#include "VCMonsterAIController.generated.h"

class AVCMonster;

/**
 * Einfache Gegner-KI als Zustandsautomat (keine Behavior-Tree-Assets nötig):
 * Ruhe → (Spieler im Aggro-Radius) Verfolgen → (in Reichweite) Angreifen →
 * (weiter als Leine vom Startpunkt) Zurückkehren und heilen. Läuft nur auf dem Server.
 * Bewegung braucht ein NavMesh (NavMeshBoundsVolume in der Karte).
 */
UCLASS()
class VCAI_API AVCMonsterAIController : public AAIController
{
	GENERATED_BODY()

public:
	AVCMonsterAIController();

protected:
	virtual void OnPossess(APawn* InPawn) override;
	virtual void OnUnPossess() override;

private:
	enum class EState : uint8 { Idle, Chase, Return };

	EState State = EState::Idle;
	TWeakObjectPtr<AActor> Target;
	FTimerHandle ThinkTimer;

	void Think();
	AActor* FindTarget(const AVCMonster& Monster, double AggroRadius) const;
};
