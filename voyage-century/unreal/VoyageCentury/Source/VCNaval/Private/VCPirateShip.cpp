#include "VCPirateShip.h"
#include "Components/SceneComponent.h"
#include "EngineUtils.h"
#include "Engine/World.h"
#include "TimerManager.h"
#include "VCCore.h"
#include "VCNavalData.h"
#include "VCServerHooks.h"

namespace
{
	/** Wie oft die KI entscheidet. Kein Spielwert, sondern Serverlast gegen Reaktionszeit. */
	constexpr float ThinkInterval = 0.5f;
	/** Bevorzugter Abstand als Anteil der Kanonenreichweite [DESIGN]. */
	constexpr double PreferredRangeShare = 0.7;
}

AVCPirateShip::AVCPirateShip()
{
	bPirate = true;
	AutoPossessAI = EAutoPossessAI::Disabled; // keine Controller-KI: Segel und Ruder setzt Think() direkt
}

void AVCPirateShip::BeginPlay()
{
	Super::BeginPlay();
	if (!HasAuthority())
	{
		return;
	}
	const FVCPirateShipRow* Row = FVCNavalData::FindPirate(PirateCode);
	const FVCShipRow* ShipRow = Row ? FVCNavalData::FindShip(Row->ShipCode) : nullptr;
	if (!FVCNavalData::IsAvailable() || !Row || !ShipRow)
	{
		UE_LOG(LogVC, Error, TEXT("Piratenschiff %s ohne Daten (DT_PirateShips/DT_Ships) – entfernt"), *PirateCode.ToString());
		Destroy();
		return;
	}
	FVCShipLoadout Loadout;
	Loadout.ShipCode = Row->ShipCode;
	Loadout.HullHp = ShipRow->HullHp;
	Loadout.Crew = Row->Crew;
	Loadout.Provisions = TNumericLimits<int32>::Max(); // Piraten hungern nicht (Proviant des Gegners irrelevant)
	CannonCode = Row->CannonCode;
	const IVCServerHooks* Hooks = Cast<IVCServerHooks>(GetWorld()->GetAuthGameMode());
	ServerInit(Loadout, Hooks ? FName(*Hooks->GetZoneId()) : NAME_None); // gleicher Wind wie für Spieler
	Home = GetActorLocation();
	GetWorldTimerManager().SetTimer(ThinkTimer, this, &AVCPirateShip::Think, ThinkInterval, true);
}

void AVCPirateShip::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	GetWorldTimerManager().ClearTimer(ThinkTimer);
	Super::EndPlay(EndPlayReason);
}

void AVCPirateShip::SteerTowards(double DesiredHeadingDeg, float Sail)
{
	double Error = vc::rules::NormalizeDeg(DesiredHeadingDeg - GetActorRotation().Yaw);
	if (Error > 180.0)
	{
		Error -= 360.0;
	}
	Rudder = static_cast<float>(FMath::Clamp(Error / 30.0, -1.0, 1.0));
	SailLevel = Sail;
}

void AVCPirateShip::Think()
{
	const FVCPirateShipRow* Row = FVCNavalData::FindPirate(PirateCode);
	const FVCCannonRow* Cannon = Row ? FVCNavalData::FindCannon(Row->CannonCode) : nullptr;
	if (!Row || !Cannon || IsSunk())
	{
		SailLevel = 0.f;
		return;
	}
	const FVector Here = GetActorLocation();
	if (Row->LeashRadiusCm > 0.0 && FVector::Dist2D(Here, Home) > Row->LeashRadiusCm)
	{
		Target.Reset();
		SteerTowards((Home - Here).Rotation().Yaw, 1.f); // zurück zum Startgebiet
		return;
	}
	if (!Target.IsValid() || Target->IsSunk() || FVector::Dist2D(Here, Target->GetActorLocation()) > Row->AggroRadiusCm)
	{
		Target.Reset();
		double Best = Row->AggroRadiusCm;
		for (TActorIterator<AVCShip> It(GetWorld()); It; ++It)
		{
			const double Distance = FVector::Dist2D(Here, It->GetActorLocation());
			if (!It->IsPirate() && !It->IsSunk() && Distance <= Best)
			{
				Best = Distance;
				Target = *It;
			}
		}
	}
	if (!Target.IsValid())
	{
		SailLevel = 0.25f; // ruhig kreuzen
		Rudder = 0.f;
		return;
	}

	const FVector There = Target->GetActorLocation();
	const double Bearing = (There - Here).Rotation().Yaw;
	const double Distance = FVector::Dist2D(Here, There);

	// Festgehakt: mit Überzahl entern, sonst abwarten, bis der Haken sich löst.
	const bool bOutnumbers = GetCrew() > Target->GetCrew();
	if (GetGrappledTo())
	{
		if (bOutnumbers && GetGrappledTo() == Target.Get())
		{
			TryBoard();
		}
		return;
	}
	// Mit Überzahl [DESIGN]: nah heran, Segel reffen (der Haken hält nur bei langsamer Fahrt) und Haken werfen.
	const double GrappleRange = FVCNavalData::GrappleTuning().RangeCm;
	if (bOutnumbers && GrappleRange > 0.0 && Distance <= GrappleRange * 2.0)
	{
		SteerTowards(Bearing, 0.f);
		TryGrapple();
		return;
	}

	// Quer zum Ziel legen (die näher liegende Seite) und Abstand halten.
	const double Preferred = Cannon->RangeCm * PreferredRangeShare;
	const double Relative = vc::rules::NormalizeDeg(Bearing - GetActorRotation().Yaw);
	const double Broadside = Relative < 180.0 ? Bearing - 90.0 : Bearing + 90.0;
	const double Desired = Distance > Preferred * 1.3 ? Bearing : Broadside; // zu weit: erst annähern
	SteerTowards(Desired, Distance > Preferred ? 1.f : 0.5f);

	FireBroadside(vc::rules::SideFacing(GetActorRotation().Yaw, Here.X, Here.Y, There.X, There.Y, FVCNavalData::BroadsideTuning()));
}

void AVCPirateShip::HandleSunk(AActor* Killer)
{
	// Belohnung wie bei Landgegnern: das Backend legt sie anhand von monsters.code fest.
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(GetWorld()->GetAuthGameMode()))
	{
		Hooks->HandleMonsterKill(Killer, PirateCode);
	}
	GetWorldTimerManager().ClearTimer(ThinkTimer);
	SetLifeSpan(5.f); // kurz sichtbar sinken lassen, dann entfernen; der Spawner setzt neu ein
}

AVCPirateSpawner::AVCPirateSpawner()
{
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

void AVCPirateSpawner::BeginPlay()
{
	Super::BeginPlay();
	if (HasAuthority())
	{
		SpawnPirate();
		GetWorldTimerManager().SetTimer(CheckTimer, this, &AVCPirateSpawner::Check, 1.f, true);
	}
}

void AVCPirateSpawner::Check()
{
	if (Spawned.IsValid())
	{
		return;
	}
	const FVCPirateShipRow* Row = FVCNavalData::FindPirate(PirateCode);
	const double Now = GetWorld()->GetTimeSeconds();
	if (GoneSince < 0.0)
	{
		GoneSince = Now;
	}
	if (Row && Now - GoneSince >= Row->RespawnSeconds)
	{
		SpawnPirate();
	}
}

void AVCPirateSpawner::SpawnPirate()
{
	GoneSince = -1.0;
	AVCPirateShip* Pirate = GetWorld()->SpawnActorDeferred<AVCPirateShip>(AVCPirateShip::StaticClass(), GetActorTransform(), nullptr,
		nullptr, ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn);
	if (Pirate)
	{
		Pirate->PirateCode = PirateCode;
		Pirate->FinishSpawning(GetActorTransform());
		Spawned = Pirate;
	}
}
