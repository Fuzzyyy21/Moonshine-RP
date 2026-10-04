#include "VCNavalCombatRules.h"

#include <algorithm>
#include <cmath>

namespace vc::rules
{
	namespace
	{
		constexpr double Pi = 3.14159265358979323846;
	}

	EBroadside SideFacing(double HeadingDeg, double ShipX, double ShipY, double TargetX, double TargetY, const FBroadsideTuning& Tuning)
	{
		const double Dx = TargetX - ShipX;
		const double Dy = TargetY - ShipY;
		if (Dx == 0.0 && Dy == 0.0)
		{
			return EBroadside::None;
		}
		const double Bearing = std::atan2(Dy, Dx) * 180.0 / Pi;
		// Relative Peilung in (-180, 180]: positiv = rechts (Unreal: +Y ist rechts bei Yaw 0).
		double Relative = std::fmod(Bearing - HeadingDeg, 360.0);
		if (Relative > 180.0)
		{
			Relative -= 360.0;
		}
		else if (Relative <= -180.0)
		{
			Relative += 360.0;
		}
		const double OffBeam = std::fabs(std::fabs(Relative) - 90.0);
		if (OffBeam > Tuning.ArcHalfWidthDeg)
		{
			return EBroadside::None;
		}
		return Relative > 0.0 ? EBroadside::Starboard : EBroadside::Port;
	}

	double HitChance(const FCannonDef& Cannon, double Distance)
	{
		if (Cannon.RangeCm <= 0.0 || Distance < 0.0 || Distance > Cannon.RangeCm)
		{
			return 0.0;
		}
		const double T = Distance / Cannon.RangeCm;
		return std::clamp(Cannon.HitChanceNear + (Cannon.HitChanceFar - Cannon.HitChanceNear) * T, 0.0, 1.0);
	}

	FBroadsideResult ResolveBroadside(int Cannons, const FCannonDef& Cannon, double Distance, const std::vector<double>& Rolls)
	{
		FBroadsideResult Result;
		const double Chance = HitChance(Cannon, Distance);
		const int Shots = std::min(std::max(Cannons, 0), static_cast<int>(Rolls.size()));
		for (int i = 0; i < Shots; ++i)
		{
			if (Rolls[static_cast<size_t>(i)] < Chance)
			{
				++Result.Hits;
			}
		}
		Result.HullDamage = Result.Hits * Cannon.DamagePerHit;
		Result.CrewLosses = static_cast<int>(std::lround(Result.Hits * Cannon.CrewHitsPerHit));
		return Result;
	}

	int CannonsPerSide(int CannonSlots)
	{
		return std::max(CannonSlots, 0) / 2;
	}

	FCrew ApplyCrewLosses(const FCrew& Crew, int Losses, const FBroadsideTuning& Tuning)
	{
		FCrew Next = Crew;
		const int Taken = std::min(std::max(Losses, 0), Crew.Healthy);
		const int Dead = static_cast<int>(std::lround(Taken * std::clamp(Tuning.DeathShare, 0.0, 1.0)));
		Next.Healthy -= Taken;
		Next.Dead += Dead;
		Next.Injured += Taken - Dead;
		return Next;
	}

	double ApplyHullDamage(double Hull, double Damage)
	{
		return std::max(0.0, Hull - std::max(0.0, Damage));
	}

	bool IsReloaded(double LastFireTime, double Now, const FCannonDef& Cannon, const FCombatTuning& Tuning)
	{
		return LastFireTime < 0.0 || Now - LastFireTime >= Cannon.ReloadSeconds * (1.0 - Tuning.IntervalTolerance);
	}
}
