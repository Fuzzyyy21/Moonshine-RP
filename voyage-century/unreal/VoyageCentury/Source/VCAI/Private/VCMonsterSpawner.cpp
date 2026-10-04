#include "VCMonsterSpawner.h"
#include "Components/SceneComponent.h"
#include "Engine/World.h"
#include "TimerManager.h"
#include "VCCombatData.h"
#include "VCCore.h"
#include "VCMonster.h"

AVCMonsterSpawner::AVCMonsterSpawner()
{
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
	bReplicates = false;
}

void AVCMonsterSpawner::BeginPlay()
{
	Super::BeginPlay();
	if (HasAuthority())
	{
		SpawnMonster();
	}
}

void AVCMonsterSpawner::SpawnMonster()
{
	if (!FVCCombatData::FindMonster(MonsterCode))
	{
		UE_LOG(LogVC, Error, TEXT("Spawner %s: Gegner %s fehlt in DT_Monsters"), *GetName(), *MonsterCode.ToString());
		return;
	}
	AVCMonster* Monster = GetWorld()->SpawnActorDeferred<AVCMonster>(AVCMonster::StaticClass(), GetActorTransform(),
		nullptr, nullptr, ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn);
	if (!Monster)
	{
		return;
	}
	Monster->MonsterCode = MonsterCode; // vor BeginPlay setzen, damit der Gegner seine Werte findet
	Monster->OnDestroyed.AddDynamic(this, &AVCMonsterSpawner::OnMonsterDestroyed);
	Monster->FinishSpawning(GetActorTransform());
}

void AVCMonsterSpawner::OnMonsterDestroyed(AActor*)
{
	const FVCMonsterRow* Row = FVCCombatData::FindMonster(MonsterCode);
	UWorld* World = GetWorld();
	if (Row && World && !World->bIsTearingDown)
	{
		World->GetTimerManager().SetTimer(RespawnTimer, this, &AVCMonsterSpawner::SpawnMonster,
			FMath::Max(1.f, static_cast<float>(Row->RespawnSeconds)), false);
	}
}
