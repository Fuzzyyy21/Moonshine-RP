#include "VCNavalAbilityRules.h"

#include <algorithm>
#include <cmath>

namespace vc::rules
{
	namespace
	{
		constexpr double Pi = 3.14159265358979323846;
	}

	bool IsAhead(double HeadingDeg, double X, double Y, double TargetX, double TargetY, double HalfArcDeg)
	{
		const double Dx = TargetX - X;
		const double Dy = TargetY - Y;
		if (Dx == 0.0 && Dy == 0.0)
		{
			return false;
		}
		double Relative = std::fmod(std::atan2(Dy, Dx) * 180.0 / Pi - HeadingDeg, 360.0);
		if (Relative > 180.0)
		{
			Relative -= 360.0;
		}
		else if (Relative <= -180.0)
		{
			Relative += 360.0;
		}
		return std::fabs(Relative) <= HalfArcDeg;
	}

	FRamResult ResolveRam(double SpeedMps, double AttackerHullMax, bool bTargetAhead, const FRamTuning& T)
	{
		FRamResult Result;
		if (!bTargetAhead || SpeedMps < T.MinSpeedMps || SpeedMps <= 0.0)
		{
			return Result;
		}
		Result.bRammed = true;
		Result.TargetDamage = SpeedMps * T.DamagePerMps * std::max(0.0, AttackerHullMax) / 1000.0;
		Result.SelfDamage = Result.TargetDamage * std::clamp(T.SelfDamageShare, 0.0, 1.0);
		return Result;
	}

	bool CanGrapple(double Distance, double OwnSpeed, double TargetSpeed, const FGrappleTuning& T)
	{
		return Distance >= 0.0 && Distance <= T.RangeCm && OwnSpeed <= T.MaxSpeedMps && TargetSpeed <= T.MaxSpeedMps;
	}

	FBoardingRound ResolveBoardingRound(int Attackers, int Defenders, double AttackerStrength, double DefenderStrength,
		double AttackerRoll, double DefenderRoll, const FBoardingTuning& T)
	{
		FBoardingRound Round;
		const int A = std::max(Attackers, 0);
		const int D = std::max(Defenders, 0);
		// Wurf 0 … 1 → Faktor 0,5 … 1,5
		const double Dealt = A * std::max(0.0, AttackerStrength) * T.LossFactor * (0.5 + std::clamp(AttackerRoll, 0.0, 1.0));
		const double Taken = D * std::max(0.0, DefenderStrength) * T.LossFactor * (0.5 + std::clamp(DefenderRoll, 0.0, 1.0));
		Round.DefenderLosses = std::min(D, static_cast<int>(std::lround(Dealt)));
		Round.AttackerLosses = std::min(A, static_cast<int>(std::lround(Taken)));
		return Round;
	}

	EBoardingOutcome BoardingOutcome(int Attackers, int Defenders)
	{
		if (Defenders <= 0)
		{
			return EBoardingOutcome::AttackerWins;
		}
		if (Attackers <= 0)
		{
			return EBoardingOutcome::DefenderWins;
		}
		return EBoardingOutcome::Ongoing;
	}

	bool MineTriggers(const FMine& Mine, double Now, double ShipX, double ShipY, const FMineTuning& T)
	{
		if (Now - Mine.PlacedAt < T.ArmSeconds || MineExpired(Mine, Now, T))
		{
			return false;
		}
		const double Dx = ShipX - Mine.X;
		const double Dy = ShipY - Mine.Y;
		return Dx * Dx + Dy * Dy <= T.TriggerRadiusCm * T.TriggerRadiusCm;
	}

	bool MineExpired(const FMine& Mine, double Now, const FMineTuning& T)
	{
		return Now - Mine.PlacedAt >= T.LifetimeSeconds;
	}
}
