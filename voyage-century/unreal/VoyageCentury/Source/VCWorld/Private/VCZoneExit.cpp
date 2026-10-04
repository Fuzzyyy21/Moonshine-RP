#include "VCZoneExit.h"
#include "Components/BoxComponent.h"
#include "Components/TextRenderComponent.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PlayerController.h"
#include "VCServerHooks.h"

AVCZoneExit::AVCZoneExit()
{
	Volume = CreateDefaultSubobject<UBoxComponent>(TEXT("Volume"));
	Volume->SetBoxExtent(FVector(200.f, 200.f, 200.f));
	Volume->SetCollisionProfileName(TEXT("Trigger"));
	Volume->SetGenerateOverlapEvents(true);
	RootComponent = Volume;

	Label = CreateDefaultSubobject<UTextRenderComponent>(TEXT("Label"));
	Label->SetupAttachment(Volume);
	Label->SetHorizontalAlignment(EHTA_Center);
	Label->SetWorldSize(60.f);
	Label->SetHiddenInGame(true);
}

void AVCZoneExit::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	Label->SetText(FText::FromString(FString::Printf(TEXT("Ausgang %s"), *ExitCode.ToString())));
}

void AVCZoneExit::NotifyActorBeginOverlap(AActor* OtherActor)
{
	Super::NotifyActorBeginOverlap(OtherActor);
	APawn* Pawn = Cast<APawn>(OtherActor);
	if (!HasAuthority() || !Pawn || !Cast<APlayerController>(Pawn->GetController()) || ExitCode.IsNone())
	{
		return;
	}
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(GetWorld()->GetAuthGameMode()))
	{
		Hooks->HandleZoneExit(Pawn, ExitCode);
	}
}
