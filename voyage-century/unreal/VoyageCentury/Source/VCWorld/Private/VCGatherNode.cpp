#include "VCGatherNode.h"
#include "Components/StaticMeshComponent.h"
#include "Components/TextRenderComponent.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"
#include "Net/UnrealNetwork.h"
#include "TimerManager.h"
#include "UObject/ConstructorHelpers.h"
#include "VCServerHooks.h"
#include "VCWorldData.h"

namespace
{
	/** Wer sich während des Sammelns weiter als das entfernt, bricht ab (Latenz-Toleranz wie beim Ansprechen). */
	constexpr double MoveToleranceCm = 150.0;
}

AVCGatherNode::AVCGatherNode()
{
	bReplicates = true;
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cylinder(TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));
	Body = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Body"));
	Body->SetRelativeScale3D(FVector(1.f, 1.f, 1.5f));
	Body->SetCollisionProfileName(TEXT("BlockAll"));
	if (Cylinder.Succeeded())
	{
		Body->SetStaticMesh(Cylinder.Object); // Platzhalter, bis es Assets gibt
	}
	RootComponent = Body;

	Label = CreateDefaultSubobject<UTextRenderComponent>(TEXT("Label"));
	Label->SetupAttachment(Body);
	Label->SetRelativeLocation(FVector(0.f, 0.f, 120.f));
	Label->SetHorizontalAlignment(EHTA_Center);
	Label->SetWorldSize(40.f);
}

void AVCGatherNode::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);
	DOREPLIFETIME(AVCGatherNode, bAvailable);
}

void AVCGatherNode::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	const FVCGatherNodeRow* Row = FVCWorldData::FindGatherNode(NodeCode);
	Label->SetText(FText::FromString(Row ? Row->NameDe : NodeCode.ToString()));
}

void AVCGatherNode::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	GetWorldTimerManager().ClearTimer(GatherTimer);
	GetWorldTimerManager().ClearTimer(RespawnTimer);
	Super::EndPlay(EndPlayReason);
}

float AVCGatherNode::ServerStartGather(APawn* Pawn)
{
	const FVCGatherNodeRow* Row = FVCWorldData::FindGatherNode(NodeCode);
	if (!HasAuthority() || !Pawn || !Row || !IsAvailable())
	{
		return -1.f;
	}
	Gatherer = Pawn;
	StartLocation = Pawn->GetActorLocation();
	const float Seconds = FMath::Max(0.01f, static_cast<float>(Row->GatherSeconds));
	GetWorldTimerManager().SetTimer(GatherTimer, this, &AVCGatherNode::FinishGather, Seconds, false);
	return Seconds;
}

void AVCGatherNode::FinishGather()
{
	APawn* Pawn = Gatherer.Get();
	IVCServerHooks* Hooks = Cast<IVCServerHooks>(GetWorld()->GetAuthGameMode());
	if (!Pawn || !Hooks || FVector::Dist(Pawn->GetActorLocation(), StartLocation) > MoveToleranceCm)
	{
		Gatherer.Reset(); // bewegt, gestorben oder ausgeloggt: abgebrochen, der Punkt bleibt voll
		return;
	}
	// Bis zur Antwort des Backends erschöpft, damit niemand denselben Punkt doppelt erntet.
	SetAvailable(false);
	TWeakObjectPtr<AVCGatherNode> WeakThis(this);
	Hooks->HandleGather(Pawn, NodeCode, [WeakThis](bool bSuccess)
	{
		AVCGatherNode* Node = WeakThis.Get();
		if (!Node)
		{
			return;
		}
		Node->Gatherer.Reset();
		const FVCGatherNodeRow* Row = FVCWorldData::FindGatherNode(Node->NodeCode);
		if (!bSuccess || !Row || Row->RespawnSeconds <= 0.0)
		{
			Node->SetAvailable(true);
			return;
		}
		Node->GetWorldTimerManager().SetTimer(Node->RespawnTimer, FTimerDelegate::CreateWeakLambda(Node, [Node]()
		{
			Node->SetAvailable(true);
		}), static_cast<float>(Row->RespawnSeconds), false);
	});
}

void AVCGatherNode::SetAvailable(bool bNow)
{
	bAvailable = bNow;
	OnRep_Available();
}

void AVCGatherNode::OnRep_Available()
{
	// Erschöpft: Platzhalter flach und Beschriftung aus (Clients und Listen-Server).
	Body->SetRelativeScale3D(bAvailable ? FVector(1.f, 1.f, 1.5f) : FVector(1.f, 1.f, 0.2f));
	Label->SetVisibility(bAvailable);
}
