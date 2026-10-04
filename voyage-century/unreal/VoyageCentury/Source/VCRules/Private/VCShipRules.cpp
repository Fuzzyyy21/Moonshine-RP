#include "VCShipRules.h"

#include <algorithm>
#include <cmath>

namespace vc::rules
{
	namespace
	{
		constexpr double Pi = 3.14159265358979323846;
	}

	double NormalizeDeg(double Deg)
	{
		double Result = std::fmod(Deg, 360.0);
		if (Result < 0.0)
		{
			Result += 360.0;
		}
		return Result;
	}

	FWind WindAt(const FWindParams& P, double Time)
	{
		const double Period = P.PeriodSeconds > 0.0 ? P.PeriodSeconds : 1.0;
		FWind Wind;
		Wind.DirectionDeg = NormalizeDeg(P.BaseDirectionDeg + P.DirectionSwingDeg * std::sin(2.0 * Pi * Time / Period));
		// Stärke schwankt mit anderer Periode, damit Richtung und Stärke nicht im Gleichschritt laufen.
		Wind.Strength = std::max(0.0, P.BaseStrength * (1.0 + P.StrengthSwing * std::sin(2.0 * Pi * Time / (Period * 0.7) + 1.0)));
		return Wind;
	}

	double AngleOffWindDeg(double HeadingDeg, double WindDirectionDeg)
	{
		const double Diff = NormalizeDeg(HeadingDeg - WindDirectionDeg);
		return Diff > 180.0 ? 360.0 - Diff : Diff;
	}

	double PolarEfficiency(const std::vector<FPolarPoint>& Polar, double Angle)
	{
		if (Polar.empty())
		{
			return 0.0;
		}
		if (Angle <= Polar.front().AngleDeg)
		{
			return Polar.front().Efficiency;
		}
		for (size_t i = 1; i < Polar.size(); ++i)
		{
			if (Angle <= Polar[i].AngleDeg)
			{
				const FPolarPoint& A = Polar[i - 1];
				const FPolarPoint& B = Polar[i];
				const double Span = B.AngleDeg - A.AngleDeg;
				const double T = Span > 0.0 ? (Angle - A.AngleDeg) / Span : 1.0;
				return A.Efficiency + (B.Efficiency - A.Efficiency) * T;
			}
		}
		return Polar.back().Efficiency;
	}

	double CrewFactor(int Crew, const FShipDef& Ship, const FSailTuning& Tuning)
	{
		if (Crew < Ship.CrewMin || Crew <= 0)
		{
			return 0.0;
		}
		if (Ship.CrewMax <= Ship.CrewMin)
		{
			return 1.0;
		}
		const double Share = std::clamp(static_cast<double>(Crew - Ship.CrewMin) / static_cast<double>(Ship.CrewMax - Ship.CrewMin), 0.0, 1.0);
		return Tuning.CrewMinFactor + (1.0 - Tuning.CrewMinFactor) * Share;
	}

	double TargetSpeed(const FShipDef& Ship, const FSailTuning& Tuning, double SailLevel, double HeadingDeg,
		const FWind& Wind, int Crew, bool bHasProvisions)
	{
		const double Sail = std::clamp(SailLevel, 0.0, 1.0);
		const double We = std::clamp(Ship.WindEfficiency, 0.0, 1.0);
		const double Polar = PolarEfficiency(Tuning.Polar, AngleOffWindDeg(HeadingDeg, Wind.DirectionDeg));
		const double WindFactor = std::max(0.0, (1.0 - We) + We * Polar * Wind.Strength);
		const double Supply = bHasProvisions ? 1.0 : Tuning.NoProvisionsFactor;
		return std::max(0.0, Ship.MaxSpeed * Sail * WindFactor * CrewFactor(Crew, Ship, Tuning) * Supply);
	}

	FShipMotion StepShip(const FShipMotion& M, const FHelm& Helm, double Target, const FShipDef& Ship, const FSailTuning& Tuning, double Dt)
	{
		FShipMotion Next = M;
		const double Step = std::max(0.0, Dt);
		if (Target > M.Speed)
		{
			Next.Speed = std::min(Target, M.Speed + Ship.Acceleration * Step);
		}
		else
		{
			Next.Speed = std::max(Target, M.Speed - Ship.Deceleration * Step);
		}
		const double SpeedShare = Ship.MaxSpeed > 0.0 ? std::min(1.0, Next.Speed / Ship.MaxSpeed) : 0.0;
		const double Steerage = Tuning.MinSteerageFactor + (1.0 - Tuning.MinSteerageFactor) * SpeedShare;
		Next.HeadingDeg = NormalizeDeg(M.HeadingDeg + std::clamp(Helm.Rudder, -1.0, 1.0) * Ship.TurnRateDeg * Steerage * Step);
		return Next;
	}

	FProvisions ConsumeProvisions(const FProvisions& State, int Crew, double Seconds, const FSailTuning& Tuning)
	{
		FProvisions Next = State;
		if (Crew <= 0 || Seconds <= 0.0 || State.Amount <= 0)
		{
			return Next;
		}
		Next.Carry += static_cast<double>(Crew) * Tuning.ProvisionsPerSailorPerMinute * Seconds / 60.0;
		const double Whole = std::floor(Next.Carry);
		const int Used = static_cast<int>(std::min(Whole, static_cast<double>(State.Amount)));
		Next.Amount = State.Amount - Used;
		Next.Carry -= Whole;
		if (Next.Amount == 0)
		{
			Next.Carry = 0.0;
		}
		return Next;
	}

	bool IsValidSailTuning(const FSailTuning& T)
	{
		if (T.Polar.empty() || T.CrewMinFactor < 0.0 || T.CrewMinFactor > 1.0 || T.MinSteerageFactor < 0.0
			|| T.MinSteerageFactor > 1.0 || T.ProvisionsPerSailorPerMinute < 0.0 || T.NoProvisionsFactor < 0.0
			|| T.NoProvisionsFactor > 1.0)
		{
			return false;
		}
		for (size_t i = 0; i < T.Polar.size(); ++i)
		{
			const FPolarPoint& P = T.Polar[i];
			if (P.Efficiency < 0.0 || P.Efficiency > 1.0 || P.AngleDeg < 0.0 || P.AngleDeg > 180.0
				|| (i > 0 && P.AngleDeg <= T.Polar[i - 1].AngleDeg))
			{
				return false;
			}
		}
		return true;
	}
}
