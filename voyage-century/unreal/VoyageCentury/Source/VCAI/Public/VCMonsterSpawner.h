#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VCMonsterSpawner.generated.h"

class AVCMonster;

/** Im Level platzieren: setzt einen Gegner ein und ersetzt ihn nach RespawnSeconds (aus DT_Monsters). Nur Server. */
UCLASS()
class VCAI_API AVCMonsterSpawner : public AActor
{
	GENERATED_BODY()

public:
	AVCMonsterSpawner();

	UPROPERTY(EditAnywhere, Category = "Spawn")
	FName MonsterCode;

protected:
	virtual void BeginPlay() override;

private:
	FTimerHandle RespawnTimer;

	void SpawnMonster();

	UFUNCTION()
	void OnMonsterDestroyed(AActor* DestroyedActor);
};
