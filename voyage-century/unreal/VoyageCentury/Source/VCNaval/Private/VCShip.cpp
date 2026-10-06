#include "VCShip.h"
#include "Camera/CameraComponent.h"
#include "Components/BoxComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/LocalPlayer.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "GameFramework/GameStateBase.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/SpringArmComponent.h"
#include "InputAction.h"
#include "InputMappingContext.h"
#include "InputModifiers.h"
#include "Net/UnrealNetwork.h"
#include "UObject/ConstructorHelpers.h"
#include "VCCore.h"
#include "EngineUtils.h"
#include "TimerManager.h"
#include "VCMine.h"
#include "VCNavalData.h"
#include "VCServerHooks.h"

namespace
{
	constexpr float SailStep = 0.25f;
}

FVCShipHitEvent AVCShip::OnShipHit;

AVCShip::AVCShip()
{
	PrimaryActorTick.bCanEverTick = true;
	bReplicates = true;
	SetReplicateMovement(true);
	bUseControllerRotationYaw = false;

	Hull = CreateDefaultSubobject<UBoxComponent>(TEXT("Hull"));
	Hull->SetBoxExtent(FVector(600.f, 200.f, 150.f));
	Hull->SetCollisionProfileName(TEXT("Pawn"));
	RootComponent = Hull;

	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(TEXT("/Engine/BasicShapes/Cube.Cube"));
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cylinder(TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));
	PlaceholderBody = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("PlaceholderBody"));
	PlaceholderBody->SetupAttachment(Hull);
	PlaceholderBody->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	PlaceholderBody->SetRelativeScale3D(FVector(12.f, 4.f, 3.f));
	PlaceholderMast = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("PlaceholderMast"));
	PlaceholderMast->SetupAttachment(Hull);
	PlaceholderMast->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	PlaceholderMast->SetRelativeLocation(FVector(0.f, 0.f, 500.f));
	PlaceholderMast->SetRelativeScale3D(FVector(0.4f, 0.4f, 8.f));
	if (Cube.Succeeded())
	{
		PlaceholderBody->SetStaticMesh(Cube.Object);
	}
	if (Cylinder.Succeeded())
	{
		PlaceholderMast->SetStaticMesh(Cylinder.Object);
	}

	CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
	CameraBoom->SetupAttachment(Hull);
	CameraBoom->TargetArmLength = 2500.f;
	CameraBoom->bUsePawnControlRotation = true;
	FollowCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FollowCamera"));
	FollowCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
}

void AVCShip::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);
	DOREPLIFETIME(AVCShip, ShipCode);
	DOREPLIFETIME(AVCShip, ZoneId);
	DOREPLIFETIME(AVCShip, Speed);
	DOREPLIFETIME(AVCShip, SailLevel);
	DOREPLIFETIME(AVCShip, Rudder);
	DOREPLIFETIME(AVCShip, HullHp);
	DOREPLIFETIME_CONDITION(AVCShip, Crew, COND_OwnerOnly);
	DOREPLIFETIME_CONDITION(AVCShip, Provisions, COND_OwnerOnly);
	DOREPLIFETIME_CONDITION(AVCShip, Injured, COND_OwnerOnly);
	DOREPLIFETIME_CONDITION(AVCShip, LastFirePort, COND_OwnerOnly);
	DOREPLIFETIME_CONDITION(AVCShip, LastFireStarboard, COND_OwnerOnly);
	DOREPLIFETIME(AVCShip, CannonCode);
	DOREPLIFETIME(AVCShip, bPirate);
	DOREPLIFETIME(AVCShip, bSunk);
	DOREPLIFETIME(AVCShip, GrappledTo);
	DOREPLIFETIME(AVCShip, bBoarding);
	DOREPLIFETIME_CONDITION(AVCShip, LastGrapple, COND_OwnerOnly);
	DOREPLIFETIME_CONDITION(AVCShip, LastMine, COND_OwnerOnly);
}

void AVCShip::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (HasAuthority())
	{
		ReleaseGrapple(); // Gegner nicht festgehakt an einem verschwundenen Schiff zurücklassen
	}
	Super::EndPlay(EndPlayReason);
}

double AVCShip::ServerNow() const
{
	const UWorld* World = GetWorld();
	const AGameStateBase* GameState = World ? World->GetGameState() : nullptr;
	return GameState ? GameState->GetServerWorldTimeSeconds() : (World ? World->GetTimeSeconds() : 0.0);
}

bool AVCShip::IsHostileTo(const AVCShip* Other) const
{
	if (!Other || Other == this)
	{
		return false;
	}
	const UWorld* World = GetWorld();
	const IVCServerHooks* Hooks = World ? Cast<IVCServerHooks>(World->GetAuthGameMode()) : nullptr;
	const bool bPvP = Hooks && Hooks->IsPvPAllowedBetween(this, Other); // Zonen-PvP oder Belagerung (Land-See-Kampf)
	return Other->bPirate != bPirate || (!bPirate && !Other->bPirate && bPvP);
}

void AVCShip::ServerInit(const FVCShipLoadout& Loadout, FName InZoneId)
{
	if (!HasAuthority())
	{
		return;
	}
	InstanceId = Loadout.InstanceId;
	ShipCode = Loadout.ShipCode;
	HullHp = Loadout.HullHp;
	Crew = Loadout.Crew;
	Injured = Loadout.Injured;
	Provisions = Loadout.Provisions;
	ZoneId = InZoneId;
	if (CannonCode.IsNone())
	{
		CannonCode = GetDefault<UVCNavalSettings>()->DefaultCannon;
	}
	FVector Location = GetActorLocation();
	Location.Z = GetDefault<UVCNavalSettings>()->SeaLevelZ;
	SetActorLocation(Location);
}

FVCShipLoadout AVCShip::GetLoadout() const
{
	FVCShipLoadout Loadout;
	Loadout.InstanceId = InstanceId;
	Loadout.ShipCode = ShipCode;
	Loadout.HullHp = HullHp;
	Loadout.Crew = Crew;
	Loadout.Injured = Injured;
	Loadout.Provisions = Provisions;
	return Loadout;
}

vc::rules::FWind AVCShip::GetWind() const
{
	return vc::rules::WindAt(FVCNavalData::WindFor(ZoneId), ServerNow());
}

void AVCShip::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	if (HasAuthority())
	{
		ServerSimulate(DeltaSeconds);
	}
}

void AVCShip::ServerSimulate(float DeltaSeconds)
{
	const FVCShipRow* Row = FVCNavalData::IsAvailable() ? FVCNavalData::FindShip(ShipCode) : nullptr;
	if (!Row || bSunk)
	{
		Speed = 0.f;
		return;
	}
	// Festgehakt: Haken lösen, wenn die Zeit um ist (außer beim Entern) oder der Gegner weg ist; sonst liegen beide still.
	if (GrappledTo && (!IsValid(GrappledTo) || GrappledTo->bSunk || (!bBoarding && ServerNow() >= GrappleUntil)))
	{
		ReleaseGrapple();
	}
	const vc::rules::FSailTuning& Tuning = FVCNavalData::SailTuning();
	if (GrappledTo)
	{
		Speed = 0.f;
	}
	else
	{
		const vc::rules::FShipDef Def = FVCNavalData::ToRules(*Row);
		vc::rules::FShipMotion Motion{ Speed, GetActorRotation().Yaw };
		const double Target = vc::rules::TargetSpeed(Def, Tuning, SailLevel, Motion.HeadingDeg, GetWind(), Crew, Provisions > 0);
		Motion = vc::rules::StepShip(Motion, vc::rules::FHelm{ SailLevel, Rudder }, Target, Def, Tuning, DeltaSeconds);

		const FRotator NewRotation(0.f, static_cast<float>(Motion.HeadingDeg), 0.f);
		const FVector Delta = NewRotation.Vector() * Motion.Speed * DeltaSeconds;
		FHitResult Hit;
		SetActorLocationAndRotation(GetActorLocation() + Delta, NewRotation, true, &Hit);
		// Auflaufen (Land, andere Schiffe): stehen bleiben; ein feindliches Schiff vor dem Bug wird dabei gerammt.
		if (Hit.bBlockingHit)
		{
			TryRam(Hit, Motion.Speed);
		}
		Speed = Hit.bBlockingHit ? 0.f : static_cast<float>(Motion.Speed);
	}

	const vc::rules::FProvisions Used = vc::rules::ConsumeProvisions(vc::rules::FProvisions{ Provisions, ProvisionCarry }, Crew, DeltaSeconds, Tuning);
	Provisions = Used.Amount;
	ProvisionCarry = Used.Carry;
}

bool AVCShip::ServerSetHelm_Validate(float NewSailLevel, float NewRudder)
{
	return FMath::IsFinite(NewSailLevel) && FMath::IsFinite(NewRudder);
}

void AVCShip::ServerSetHelm_Implementation(float NewSailLevel, float NewRudder)
{
	SailLevel = FMath::Clamp(NewSailLevel, 0.f, 1.f);
	Rudder = FMath::Clamp(NewRudder, -1.f, 1.f);
}

double AVCShip::GetReloadRemaining(bool bStarboard) const
{
	const FVCCannonRow* Cannon = FVCNavalData::FindCannon(CannonCode);
	const double Last = bStarboard ? LastFireStarboard : LastFirePort;
	const UWorld* World = GetWorld();
	const AGameStateBase* GameState = World ? World->GetGameState() : nullptr;
	if (!Cannon || Last < 0.0 || !GameState)
	{
		return 0.0;
	}
	return FMath::Max(0.0, Last + Cannon->ReloadSeconds - GameState->GetServerWorldTimeSeconds());
}

void AVCShip::ServerFire_Implementation(bool bStarboard)
{
	FireBroadside(bStarboard ? vc::rules::EBroadside::Starboard : vc::rules::EBroadside::Port);
}

void AVCShip::ServerToggleCannon_Implementation()
{
	const UVCNavalSettings* Settings = GetDefault<UVCNavalSettings>();
	CannonCode = CannonCode == Settings->DefaultCannon ? Settings->AlternateCannon : Settings->DefaultCannon;
}

bool AVCShip::FireBroadside(vc::rules::EBroadside Side)
{
	const FVCShipRow* Row = FVCNavalData::FindShip(ShipCode);
	const FVCCannonRow* CannonRow = FVCNavalData::FindCannon(CannonCode);
	if (!HasAuthority() || bSunk || !Row || !CannonRow || Side == vc::rules::EBroadside::None || Crew < Row->CrewMin)
	{
		return false; // ohne Mindestbesatzung keine Bedienung der Kanonen [DESIGN]
	}
	const vc::rules::FCannonDef Cannon = FVCNavalData::ToRules(*CannonRow);
	double& LastFire = Side == vc::rules::EBroadside::Starboard ? LastFireStarboard : LastFirePort;
	const double Now = GetWorld()->GetTimeSeconds();
	vc::rules::FCombatTuning Tolerance;
	Tolerance.IntervalTolerance = 0.1;
	if (!vc::rules::IsReloaded(LastFire, Now, Cannon, Tolerance))
	{
		return false;
	}

	// Nächstes feindliches Schiff im Feuerwinkel dieser Seite und in Reichweite.
	AVCShip* Target = nullptr;
	double BestDistance = Cannon.RangeCm;
	const FVector Here = GetActorLocation();
	for (TActorIterator<AVCShip> It(GetWorld()); It; ++It)
	{
		AVCShip* Other = *It;
		if (Other->bSunk || !IsHostileTo(Other))
		{
			continue;
		}
		const FVector There = Other->GetActorLocation();
		const double Distance = FVector::Dist2D(Here, There);
		if (Distance <= BestDistance
			&& vc::rules::SideFacing(GetActorRotation().Yaw, Here.X, Here.Y, There.X, There.Y, FVCNavalData::BroadsideTuning()) == Side)
		{
			BestDistance = Distance;
			Target = Other;
		}
	}
	LastFire = Now; // auch ohne Ziel: die Breitseite ist abgefeuert
	if (!Target)
	{
		return true;
	}
	std::vector<double> Rolls;
	const int32 Cannons = vc::rules::CannonsPerSide(Row->CannonSlots);
	for (int32 i = 0; i < Cannons; ++i)
	{
		Rolls.push_back(FMath::FRand());
	}
	Target->ServerTakeBroadside(vc::rules::ResolveBroadside(Cannons, Cannon, BestDistance, Rolls), this);
	return true;
}

void AVCShip::ServerTakeBroadside(const vc::rules::FBroadsideResult& Result, AActor* Attacker)
{
	ServerTakeDamage(Result.HullDamage, Result.CrewLosses, Result.Hits, Attacker);
}

void AVCShip::ServerTakeDamage(double HullDamage, int32 CrewLosses, int32 Hits, AActor* Attacker)
{
	if (!HasAuthority() || bSunk)
	{
		return;
	}
	HullHp = static_cast<int32>(vc::rules::ApplyHullDamage(HullHp, HullDamage));
	const vc::rules::FCrew After = vc::rules::ApplyCrewLosses(vc::rules::FCrew{ Crew, Injured, Dead }, CrewLosses,
		FVCNavalData::BroadsideTuning());
	Crew = After.Healthy;
	Injured = After.Injured;
	Dead = After.Dead;
	MulticastHit(Hits, FMath::RoundToInt(HullDamage), CrewLosses);
	if (HullHp <= 0)
	{
		Sink(Attacker);
	}
}

void AVCShip::Sink(AActor* Killer)
{
	if (bSunk)
	{
		return;
	}
	bSunk = true;
	Speed = 0.f;
	SailLevel = 0.f;
	ReleaseGrapple();
	HandleSunk(Killer);
}

void AVCShip::TryRam(const FHitResult& Hit, double SpeedCmPerSecond)
{
	AVCShip* Other = Cast<AVCShip>(Hit.GetActor());
	const FVCShipRow* Row = FVCNavalData::FindShip(ShipCode);
	if (!Other || Other->bSunk || !Row || !IsHostileTo(Other))
	{
		return; // Land oder befreundetes Schiff: nur stehen bleiben
	}
	const vc::rules::FRamTuning& Tuning = FVCNavalData::RamTuning();
	const FVector Here = GetActorLocation();
	const FVector There = Other->GetActorLocation();
	const bool bAhead = vc::rules::IsAhead(GetActorRotation().Yaw, Here.X, Here.Y, There.X, There.Y, Tuning.FrontArcDeg);
	const vc::rules::FRamResult Ram = vc::rules::ResolveRam(SpeedCmPerSecond / 100.0, Row->HullHp, bAhead, Tuning);
	if (!Ram.bRammed)
	{
		return;
	}
	// Danach steht das Schiff (Speed 0): ein neuer Rammstoß braucht wieder Fahrt, kein Treffer je Tick.
	Other->ServerTakeDamage(Ram.TargetDamage, 0, 1, this);
	ServerTakeDamage(Ram.SelfDamage, 0, 1, Other);
}

double AVCShip::GetGrappleCooldown() const
{
	const double Cooldown = FVCNavalData::GrappleTuning().CooldownSeconds;
	return LastGrapple < 0.0 ? 0.0 : FMath::Max(0.0, LastGrapple + Cooldown - ServerNow());
}

double AVCShip::GetMineCooldown() const
{
	const double Cooldown = FVCNavalData::MineTuning().CooldownSeconds;
	return LastMine < 0.0 ? 0.0 : FMath::Max(0.0, LastMine + Cooldown - ServerNow());
}

bool AVCShip::TryGrapple()
{
	const vc::rules::FGrappleTuning& Tuning = FVCNavalData::GrappleTuning();
	const FVCShipRow* Row = FVCNavalData::FindShip(ShipCode);
	const double Now = ServerNow();
	if (!HasAuthority() || bSunk || GrappledTo || !Row || Crew < Row->CrewMin || GetGrappleCooldown() > 0.0)
	{
		return false;
	}
	AVCShip* Target = nullptr;
	double BestDistance = Tuning.RangeCm;
	const FVector Here = GetActorLocation();
	for (TActorIterator<AVCShip> It(GetWorld()); It; ++It)
	{
		AVCShip* Other = *It;
		const double Distance = FVector::Dist2D(Here, Other->GetActorLocation());
		if (!Other->bSunk && !Other->GrappledTo && IsHostileTo(Other) && Distance <= BestDistance
			&& vc::rules::CanGrapple(Distance, FMath::Abs(Speed) / 100.0, FMath::Abs(Other->Speed) / 100.0, Tuning))
		{
			BestDistance = Distance;
			Target = Other;
		}
	}
	LastGrapple = Now; // auch ein Fehlwurf kostet die Abklingzeit
	if (!Target)
	{
		return false;
	}
	Grapple(Target, Now);
	return true;
}

void AVCShip::Grapple(AVCShip* Other, double Now)
{
	const double Until = Now + FVCNavalData::GrappleTuning().DurationSeconds;
	GrappledTo = Other;
	GrappleUntil = Until;
	Speed = 0.f;
	Other->GrappledTo = this;
	Other->GrappleUntil = Until;
	Other->Speed = 0.f;
}

void AVCShip::ReleaseGrapple()
{
	EndBoarding();
	AVCShip* Other = GrappledTo;
	GrappledTo = nullptr;
	if (IsValid(Other) && Other->GrappledTo == this)
	{
		Other->EndBoarding();
		Other->GrappledTo = nullptr;
	}
}

double AVCShip::BoardingStrength() const
{
	const FVCShipRow* Row = FVCNavalData::FindShip(ShipCode);
	// Belegt: das Erkundungsschiff ist stark beim Entern (SHIPCLASS-RAIDER); wie stark, ist ein Entwicklungswert.
	return Row && Row->ShipClass == EVCShipClass::Raider ? FVCNavalData::BoardingTuning().RaiderStrength : 1.0;
}

bool AVCShip::TryBoard()
{
	const vc::rules::FBoardingTuning& Tuning = FVCNavalData::BoardingTuning();
	if (!HasAuthority() || bSunk || bBoarding || !IsValid(GrappledTo) || GrappledTo->bBoarding || Crew <= 0
		|| Tuning.RoundSeconds <= 0.0)
	{
		return false;
	}
	BoardingDefender = GrappledTo;
	bBoarding = true;
	GrappledTo->bBoarding = true;
	GetWorldTimerManager().SetTimer(BoardingTimer, this, &AVCShip::BoardingRound, static_cast<float>(Tuning.RoundSeconds), true);
	return true;
}

void AVCShip::BoardingRound()
{
	AVCShip* Defender = BoardingDefender.Get();
	if (!Defender || Defender->bSunk || bSunk)
	{
		EndBoarding();
		return;
	}
	const vc::rules::FBoardingRound Round = vc::rules::ResolveBoardingRound(Crew, Defender->Crew, BoardingStrength(),
		Defender->BoardingStrength(), FMath::FRand(), FMath::FRand(), FVCNavalData::BoardingTuning());
	ServerTakeDamage(0.0, Round.AttackerLosses, 0, Defender);
	Defender->ServerTakeDamage(0.0, Round.DefenderLosses, 0, this);
	switch (vc::rules::BoardingOutcome(Crew, Defender->Crew))
	{
	case vc::rules::EBoardingOutcome::AttackerWins:
		// Genommen: für den Verlierer wie Versenken [DESIGN] – Pirat bringt die Belohnung, Spieler kommt an Land zurück.
		Defender->Sink(this);
		break;
	case vc::rules::EBoardingOutcome::DefenderWins:
		ReleaseGrapple();
		break;
	case vc::rules::EBoardingOutcome::Ongoing:
		break;
	}
}

void AVCShip::EndBoarding()
{
	if (UWorld* World = GetWorld())
	{
		World->GetTimerManager().ClearTimer(BoardingTimer);
	}
	AVCShip* Defender = BoardingDefender.Get();
	BoardingDefender.Reset();
	if (bBoarding)
	{
		bBoarding = false;
		if (Defender)
		{
			Defender->bBoarding = false;
		}
		else if (IsValid(GrappledTo) && GrappledTo->BoardingDefender.Get() == this)
		{
			GrappledTo->EndBoarding(); // Verteidiger-Seite: der Angreifer hält den Timer
		}
	}
}

bool AVCShip::TryDropMine()
{
	const vc::rules::FMineTuning& Tuning = FVCNavalData::MineTuning();
	if (!HasAuthority() || bSunk || GetMineCooldown() > 0.0 || Tuning.LifetimeSeconds <= 0.0)
	{
		return false;
	}
	FVector Location = GetActorLocation() - GetActorForwardVector() * Tuning.DropDistanceCm;
	Location.Z = GetDefault<UVCNavalSettings>()->SeaLevelZ;
	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
	AVCMine* Mine = GetWorld()->SpawnActor<AVCMine>(AVCMine::StaticClass(), Location, FRotator::ZeroRotator, Params);
	if (!Mine)
	{
		return false;
	}
	LastMine = ServerNow();
	Mine->Arm(this, LastMine);
	return true;
}

void AVCShip::ServerGrapple_Implementation()
{
	TryGrapple();
}

void AVCShip::ServerBoard_Implementation()
{
	TryBoard();
}

void AVCShip::ServerDropMine_Implementation()
{
	TryDropMine();
}

void AVCShip::HandleSunk(AActor* Killer)
{
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(GetWorld()->GetAuthGameMode()))
	{
		Hooks->HandleShipSunk(this, Killer);
	}
}

void AVCShip::MulticastHit_Implementation(int32 Hits, int32 HullDamage, int32 CrewLosses)
{
	if (GetNetMode() != NM_DedicatedServer)
	{
		OnShipHit.Broadcast(this, Hits, HullDamage, CrewLosses);
	}
}

void AVCShip::FirePort(const FInputActionValue& Value)
{
	ServerFire(false);
}

void AVCShip::FireStarboard(const FInputActionValue& Value)
{
	ServerFire(true);
}

void AVCShip::ToggleCannon(const FInputActionValue& Value)
{
	ServerToggleCannon();
}

void AVCShip::GrappleInput(const FInputActionValue& Value)
{
	ServerGrapple();
}

void AVCShip::BoardInput(const FInputActionValue& Value)
{
	ServerBoard();
}

void AVCShip::MineInput(const FInputActionValue& Value)
{
	ServerDropMine();
}

void AVCShip::CreateInputObjects()
{
	if (InputContext)
	{
		return;
	}
	InputContext = NewObject<UInputMappingContext>(this, TEXT("IMC_Ship"));
	SailAction = NewObject<UInputAction>(this, TEXT("IA_Sail"));
	SailAction->ValueType = EInputActionValueType::Axis1D;
	InputContext->MapKey(SailAction, EKeys::W);
	InputContext->MapKey(SailAction, EKeys::S).Modifiers.Add(NewObject<UInputModifierNegate>(this));

	RudderAction = NewObject<UInputAction>(this, TEXT("IA_Rudder"));
	RudderAction->ValueType = EInputActionValueType::Axis1D;
	InputContext->MapKey(RudderAction, EKeys::D);
	InputContext->MapKey(RudderAction, EKeys::A).Modifiers.Add(NewObject<UInputModifierNegate>(this));

	LookAction = NewObject<UInputAction>(this, TEXT("IA_ShipLook"));
	LookAction->ValueType = EInputActionValueType::Axis2D;
	UInputModifierNegate* InvertY = NewObject<UInputModifierNegate>(this);
	InvertY->bX = false;
	InvertY->bZ = false;
	InputContext->MapKey(LookAction, EKeys::Mouse2D).Modifiers.Add(InvertY);

	FirePortAction = NewObject<UInputAction>(this, TEXT("IA_FirePort"));
	FirePortAction->ValueType = EInputActionValueType::Boolean;
	InputContext->MapKey(FirePortAction, EKeys::Q);
	FireStarboardAction = NewObject<UInputAction>(this, TEXT("IA_FireStarboard"));
	FireStarboardAction->ValueType = EInputActionValueType::Boolean;
	InputContext->MapKey(FireStarboardAction, EKeys::E);
	CannonAction = NewObject<UInputAction>(this, TEXT("IA_Cannon"));
	CannonAction->ValueType = EInputActionValueType::Boolean;
	InputContext->MapKey(CannonAction, EKeys::R);
	GrappleAction = NewObject<UInputAction>(this, TEXT("IA_Grapple"));
	GrappleAction->ValueType = EInputActionValueType::Boolean;
	InputContext->MapKey(GrappleAction, EKeys::F);
	BoardAction = NewObject<UInputAction>(this, TEXT("IA_Board"));
	BoardAction->ValueType = EInputActionValueType::Boolean;
	InputContext->MapKey(BoardAction, EKeys::B);
	MineAction = NewObject<UInputAction>(this, TEXT("IA_Mine"));
	MineAction->ValueType = EInputActionValueType::Boolean;
	InputContext->MapKey(MineAction, EKeys::M);
}

void AVCShip::PawnClientRestart()
{
	Super::PawnClientRestart();
	CreateInputObjects();
	const APlayerController* PC = Cast<APlayerController>(GetController());
	const ULocalPlayer* LocalPlayer = PC ? PC->GetLocalPlayer() : nullptr;
	if (UEnhancedInputLocalPlayerSubsystem* Input = LocalPlayer ? LocalPlayer->GetSubsystem<UEnhancedInputLocalPlayerSubsystem>() : nullptr)
	{
		Input->AddMappingContext(InputContext, 0);
	}
}

void AVCShip::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);
	CreateInputObjects();
	if (UEnhancedInputComponent* Input = Cast<UEnhancedInputComponent>(PlayerInputComponent))
	{
		Input->BindAction(SailAction, ETriggerEvent::Started, this, &AVCShip::ChangeSail);
		Input->BindAction(RudderAction, ETriggerEvent::Triggered, this, &AVCShip::Steer);
		Input->BindAction(RudderAction, ETriggerEvent::Completed, this, &AVCShip::StopSteering);
		Input->BindAction(LookAction, ETriggerEvent::Triggered, this, &AVCShip::Look);
		Input->BindAction(FirePortAction, ETriggerEvent::Started, this, &AVCShip::FirePort);
		Input->BindAction(FireStarboardAction, ETriggerEvent::Started, this, &AVCShip::FireStarboard);
		Input->BindAction(CannonAction, ETriggerEvent::Started, this, &AVCShip::ToggleCannon);
		Input->BindAction(GrappleAction, ETriggerEvent::Started, this, &AVCShip::GrappleInput);
		Input->BindAction(BoardAction, ETriggerEvent::Started, this, &AVCShip::BoardInput);
		Input->BindAction(MineAction, ETriggerEvent::Started, this, &AVCShip::MineInput);
	}
}

void AVCShip::ChangeSail(const FInputActionValue& Value)
{
	// Segel in Vierteln: gewünschter Wert lokal, der Server übernimmt ihn geprüft.
	SailLevel = FMath::Clamp(SailLevel + (Value.Get<float>() > 0.f ? SailStep : -SailStep), 0.f, 1.f);
	ServerSetHelm(SailLevel, SentRudder);
}

void AVCShip::Steer(const FInputActionValue& Value)
{
	const float Wanted = FMath::Clamp(Value.Get<float>(), -1.f, 1.f);
	if (!FMath::IsNearlyEqual(Wanted, SentRudder))
	{
		SentRudder = Wanted;
		ServerSetHelm(SailLevel, SentRudder);
	}
}

void AVCShip::StopSteering(const FInputActionValue& Value)
{
	SentRudder = 0.f;
	ServerSetHelm(SailLevel, 0.f);
}

void AVCShip::Look(const FInputActionValue& Value)
{
	const FVector2D Axis = Value.Get<FVector2D>();
	AddControllerYawInput(Axis.X);
	AddControllerPitchInput(Axis.Y);
}
