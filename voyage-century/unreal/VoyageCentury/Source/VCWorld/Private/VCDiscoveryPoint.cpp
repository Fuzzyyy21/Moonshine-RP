#include "VCDiscoveryPoint.h"
#include "Components/BoxComponent.h"
#include "Components/TextRenderComponent.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PlayerController.h"
#include "VCServerHooks.h"

AVCDiscoveryPoint::AVCDiscoveryPoint()
{
	Volume = CreateDefaultSubobject<UBoxComponent>(TEXT("Volume"));
	Volume->SetBoxExtent(FVector(400.f, 400.f, 300.f));
	Volume->SetCollisionProfileName(TEXT("Trigger"));
	Volume->SetGenerateOverlapEvents(true);
	RootComponent = Volume;

	Label = CreateDefaultSubobject<UTextRenderComponent>(TEXT("Label"));
	Label->SetupAttachment(Volume);
	Label->SetHorizontalAlignment(EHTA_Center);
	Label->SetWorldSize(60.f);
	Label->SetHiddenInGame(true);
}

void AVCDiscoveryPoint::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	Label->SetText(FText::FromString(FString::Printf(TEXT("Entdeckung %s"), *DiscoveryCode.ToString())));
}

void AVCDiscoveryPoint::NotifyActorBeginOverlap(AActor* OtherActor)
{
	Super::NotifyActorBeginOverlap(OtherActor);
	APawn* Pawn = Cast<APawn>(OtherActor);
	if (!HasAuthority() || !Pawn || !Cast<APlayerController>(Pawn->GetController()) || DiscoveryCode.IsNone())
	{
		return;
	}
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(GetWorld()->GetAuthGameMode()))
	{
		Hooks->HandleDiscovery(Pawn, DiscoveryCode);
	}
}
