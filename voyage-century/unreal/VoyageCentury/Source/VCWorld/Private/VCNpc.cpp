#include "VCNpc.h"
#include "Components/CapsuleComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Components/TextRenderComponent.h"
#include "Engine/StaticMesh.h"
#include "UObject/ConstructorHelpers.h"
#include "VCWorldData.h"

AVCNpc::AVCNpc()
{
	Capsule = CreateDefaultSubobject<UCapsuleComponent>(TEXT("Capsule"));
	Capsule->InitCapsuleSize(40.f, 90.f);
	Capsule->SetCollisionProfileName(TEXT("Pawn"));
	RootComponent = Capsule;

	PlaceholderBody = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("PlaceholderBody"));
	PlaceholderBody->SetupAttachment(Capsule);
	PlaceholderBody->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	PlaceholderBody->SetRelativeScale3D(FVector(0.8f, 0.8f, 1.76f));
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cone(TEXT("/Engine/BasicShapes/Cone.Cone"));
	if (Cone.Succeeded())
	{
		PlaceholderBody->SetStaticMesh(Cone.Object); // Kegel = NPC, Zylinder = Spieler, Würfel = Gegner
	}

	NameLabel = CreateDefaultSubobject<UTextRenderComponent>(TEXT("NameLabel"));
	NameLabel->SetupAttachment(Capsule);
	NameLabel->SetRelativeLocation(FVector(0.f, 0.f, 130.f));
	NameLabel->SetHorizontalAlignment(EHTA_Center);
	NameLabel->SetWorldSize(28.f);
}

void AVCNpc::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	NameLabel->SetText(FText::FromName(NpcCode));
}

void AVCNpc::BeginPlay()
{
	Super::BeginPlay();
	UpdateLabel();
}

void AVCNpc::UpdateLabel()
{
	if (GetNetMode() != NM_DedicatedServer)
	{
		NameLabel->SetText(FText::FromString(FVCWorldData::NpcDisplayName(NpcCode)));
	}
}
