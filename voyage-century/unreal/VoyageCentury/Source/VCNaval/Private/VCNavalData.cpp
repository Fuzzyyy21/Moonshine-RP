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
		vc::rules::FSailTuning Tuning;
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
