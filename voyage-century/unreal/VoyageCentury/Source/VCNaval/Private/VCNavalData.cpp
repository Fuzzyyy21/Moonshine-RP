#include "VCNavalData.h"
#include "Engine/DataTable.h"
#include "VCCore.h"

namespace
{
	UDataTable* Load(const TSoftObjectPtr<UDataTable>& Ref)
	{
		UDataTable* Table = Ref.IsNull() ? nullptr : Ref.LoadSynchronous();
		if (Table && !Table->IsRooted())
		{
			Table->AddToRoot(); // Konfigurationsdaten: für die Laufzeit des Prozesses geladen halten
		}
		return Table;
	}

	struct FCache
	{
		UDataTable* Ships = nullptr;
		UDataTable* Wind = nullptr;
		UDataTable* Cannons = nullptr;
		UDataTable* Pirates = nullptr;
		vc::rules::FSailTuning Tuning;
		vc::rules::FBroadsideTuning Broadside;
		vc::rules::FRamTuning Ram;
		vc::rules::FGrappleTuning Grapple;
		vc::rules::FBoardingTuning Boarding;
		vc::rules::FMineTuning Mines;
		bool bValid = false;
	};

	const FCache& Cache()
	{
		static const FCache Instance = []
		{
			FCache C;
			const UVCNavalSettings* Settings = GetDefault<UVCNavalSettings>();
			C.Ships = Load(Settings->ShipsTable);
			C.Wind = Load(Settings->ZoneWindTable);
			C.Cannons = Load(Settings->CannonsTable);
			C.Pirates = Load(Settings->PirateShipsTable);
			UDataTable* TuningTable = Load(Settings->ShipTuningTable);
			const FVCShipTuningRow* Row = TuningTable ? TuningTable->FindRow<FVCShipTuningRow>(TEXT("Default"), TEXT("VCNavalData")) : nullptr;
			if (Row && Row->PolarAngles.Num() == Row->PolarEfficiencies.Num())
			{
				for (int32 i = 0; i < Row->PolarAngles.Num(); ++i)
				{
					C.Tuning.Polar.push_back(vc::rules::FPolarPoint{ Row->PolarAngles[i], Row->PolarEfficiencies[i] });
				}
				C.Tuning.CrewMinFactor = Row->CrewMinFactor;
				C.Tuning.MinSteerageFactor = Row->MinSteerageFactor;
				C.Tuning.ProvisionsPerSailorPerMinute = Row->ProvisionsPerSailorPerMinute;
				C.Tuning.NoProvisionsFactor = Row->NoProvisionsFactor;
				C.Broadside.ArcHalfWidthDeg = Row->ArcHalfWidthDeg;
				C.Broadside.DeathShare = Row->DeathShare;
				C.Ram = { Row->RamDamagePerMps, Row->RamSelfDamageShare, Row->RamFrontArcDeg, Row->RamMinSpeedMps };
				C.Grapple = { Row->GrappleRangeCm, Row->GrappleMaxSpeedMps, Row->GrappleDurationSeconds, Row->GrappleCooldownSeconds };
				C.Boarding = { Row->BoardingLossFactor, Row->BoardingRaiderStrength, Row->BoardingRoundSeconds };
				C.Mines = { Row->MineDamage, Row->MineCrewHits, Row->MineTriggerRadiusCm, Row->MineLifetimeSeconds,
					Row->MineCooldownSeconds, Row->MineDropDistanceCm, Row->MineArmSeconds };
			}
			C.bValid = C.Ships && vc::rules::IsValidSailTuning(C.Tuning);
			if (!C.bValid)
			{
				UE_LOG(LogVC, Error, TEXT("Schiffsdaten fehlen oder sind ungültig – keine Schiffe (Projekteinstellungen > Voyage Century Naval)"));
			}
			return C;
		}();
		return Instance;
	}
}

bool FVCNavalData::IsAvailable()
{
	return Cache().bValid;
}

const FVCShipRow* FVCNavalData::FindShip(FName Code)
{
	UDataTable* Table = Cache().Ships;
	return Table && !Code.IsNone() ? Table->FindRow<FVCShipRow>(Code, TEXT("VCNavalData"), false) : nullptr;
}

const vc::rules::FSailTuning& FVCNavalData::SailTuning()
{
	return Cache().Tuning;
}

vc::rules::FWindParams FVCNavalData::WindFor(FName ZoneId)
{
	vc::rules::FWindParams Params;
	Params.BaseStrength = 0.0;
	UDataTable* Table = Cache().Wind;
	if (const FVCZoneWindRow* Row = Table && !ZoneId.IsNone() ? Table->FindRow<FVCZoneWindRow>(ZoneId, TEXT("VCNavalData"), false) : nullptr)
	{
		Params.BaseDirectionDeg = Row->BaseDirectionDeg;
		Params.BaseStrength = Row->BaseStrength;
		Params.DirectionSwingDeg = Row->DirectionSwingDeg;
		Params.StrengthSwing = Row->StrengthSwing;
		Params.PeriodSeconds = Row->PeriodSeconds;
	}
	return Params;
}

vc::rules::FShipDef FVCNavalData::ToRules(const FVCShipRow& Row)
{
	vc::rules::FShipDef Def;
	Def.MaxSpeed = Row.MaxSpeed;
	Def.Acceleration = Row.Acceleration;
	Def.Deceleration = Row.Deceleration;
	Def.TurnRateDeg = Row.TurnRateDeg;
	Def.CrewMin = Row.CrewMin;
	Def.CrewMax = Row.CrewMax;
	Def.WindEfficiency = Row.WindEfficiency;
	return Def;
}

const FVCCannonRow* FVCNavalData::FindCannon(FName Code)
{
	UDataTable* Table = Cache().Cannons;
	return Table && !Code.IsNone() ? Table->FindRow<FVCCannonRow>(Code, TEXT("VCNavalData"), false) : nullptr;
}

const FVCPirateShipRow* FVCNavalData::FindPirate(FName Code)
{
	UDataTable* Table = Cache().Pirates;
	return Table && !Code.IsNone() ? Table->FindRow<FVCPirateShipRow>(Code, TEXT("VCNavalData"), false) : nullptr;
}

vc::rules::FCannonDef FVCNavalData::ToRules(const FVCCannonRow& Row)
{
	vc::rules::FCannonDef Def;
	Def.RangeCm = Row.RangeCm;
	Def.DamagePerHit = Row.DamagePerHit;
	Def.CrewHitsPerHit = Row.CrewHitsPerHit;
	Def.ReloadSeconds = Row.ReloadSeconds;
	Def.HitChanceNear = Row.HitChanceNear;
	Def.HitChanceFar = Row.HitChanceFar;
	return Def;
}

const vc::rules::FBroadsideTuning& FVCNavalData::BroadsideTuning()
{
	return Cache().Broadside;
}

const vc::rules::FRamTuning& FVCNavalData::RamTuning()
{
	return Cache().Ram;
}

const vc::rules::FGrappleTuning& FVCNavalData::GrappleTuning()
{
	return Cache().Grapple;
}

const vc::rules::FBoardingTuning& FVCNavalData::BoardingTuning()
{
	return Cache().Boarding;
}

const vc::rules::FMineTuning& FVCNavalData::MineTuning()
{
	return Cache().Mines;
}
