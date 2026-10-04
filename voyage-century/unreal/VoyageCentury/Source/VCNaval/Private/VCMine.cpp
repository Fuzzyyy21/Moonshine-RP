#include "VCMine.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/GameStateBase.h"
#include "TimerManager.h"
#include "UObject/ConstructorHelpers.h"
#include "VCNavalData.h"
#include "VCShip.h"

namespace
{
	/** Prüfabstand: Serverlast gegen Genauigkeit, kein Spielwert. */
	constexpr float CheckInterval = 0.2f;
}

AVCMine::AVCMine()
{
	bReplicates = true;
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Sphere(TEXT("/Engine/BasicShapes/Sphere.Sphere"));
	Body = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Body"));
	Body->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	Body->SetRelativeScale3D(FVector(1.5f));
	if (Sphere.Succeeded())
	{
		Body->SetStaticMesh(Sphere.Object);
	}
	RootComponent = Body;
}

void AVCMine::Arm(AVCShip* InLayer, double Now)
{
	if (!HasAuthority())
	{
		return;
	}
	Layer = InLayer;
	const FVector Location = GetActorLocation();
	Mine = vc::rules::FMine{ Location.X, Location.Y, Now };
	GetWorldTimerManager().SetTimer(CheckTimer, this, &AVCMine::Check, CheckInterval, true);
}

void AVCMine::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	GetWorldTimerManager().ClearTimer(CheckTimer);
	Super::EndPlay(EndPlayReason);
}

void AVCMine::Check()
{
	const vc::rules::FMineTuning& Tuning = FVCNavalData::MineTuning();
	const AGameStateBase* GameState = GetWorld()->GetGameState();
	const double Now = GameState ? GameState->GetServerWorldTimeSeconds() : GetWorld()->GetTimeSeconds();
	AVCShip* LayerShip = Layer.Get();
	if (!LayerShip || vc::rules::MineExpired(Mine, Now, Tuning))
	{
		Destroy();
		return;
	}
	for (TActorIterator<AVCShip> It(GetWorld()); It; ++It)
	{
		AVCShip* Ship = *It;
		if (Ship->IsSunk() || (Ship != LayerShip && !LayerShip->IsHostileTo(Ship)))
		{
			continue;
		}
		const FVector There = Ship->GetActorLocation();
		if (vc::rules::MineTriggers(Mine, Now, There.X, There.Y, Tuning))
		{
			Ship->ServerTakeDamage(Tuning.Damage, FMath::RoundToInt(Tuning.CrewHits), 1, LayerShip);
			Destroy();
			return;
		}
	}
}
