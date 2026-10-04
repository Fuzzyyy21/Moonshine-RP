// Tests der Segelregeln (VCShipRules).
#include "TestHarness.h"
#include "VCShipRules.h"

using namespace vc::rules;

namespace
{
	FSailTuning Sail()
	{
		FSailTuning T;
		T.Polar = { { 0.0, 0.8 }, { 90.0, 1.0 }, { 120.0, 0.6 }, { 150.0, 0.0 }, { 180.0, 0.0 } };
		T.CrewMinFactor = 0.5;
		T.MinSteerageFactor = 0.2;
		T.ProvisionsPerSailorPerMinute = 0.1;
		T.NoProvisionsFactor = 0.5;
		return T;
	}

	FShipDef Sloop()
	{
		FShipDef S;
		S.MaxSpeed = 1000.0;
		S.Acceleration = 100.0;
		S.Deceleration = 200.0;
		S.TurnRateDeg = 20.0;
		S.CrewMin = 10;
		S.CrewMax = 30;
		S.WindEfficiency = 1.0;
		return S;
	}

	FWind Wind(double Direction, double Strength = 1.0)
	{
		return FWind{ Direction, Strength };
	}
}

const std::vector<vctest::FCase>& vctest::ShipRulesCases()
{
	static const std::vector<FCase> Cases = {
		{ "Winkel werden normiert, Winkel zum Wind 0 … 180", []
		{
			CHECK_NEAR(NormalizeDeg(-90.0), 270.0);
			CHECK_NEAR(NormalizeDeg(725.0), 5.0);
			CHECK_NEAR(AngleOffWindDeg(0.0, 0.0), 0.0);     // Wind von achtern
			CHECK_NEAR(AngleOffWindDeg(180.0, 0.0), 180.0); // gegen den Wind
			CHECK_NEAR(AngleOffWindDeg(350.0, 80.0), 90.0);
			CHECK_NEAR(AngleOffWindDeg(80.0, 350.0), 90.0);
		} },
		{ "Polare interpoliert linear und begrenzt", []
		{
			const FSailTuning T = Sail();
			CHECK_NEAR(PolarEfficiency(T.Polar, 90.0), 1.0);
			CHECK_NEAR(PolarEfficiency(T.Polar, 45.0), 0.9);
			CHECK_NEAR(PolarEfficiency(T.Polar, 135.0), 0.3);
			CHECK_NEAR(PolarEfficiency(T.Polar, 170.0), 0.0);
			CHECK_NEAR(PolarEfficiency({}, 90.0), 0.0);
			CHECK(IsValidSailTuning(T));
			FSailTuning Bad = T;
			Bad.Polar[2].AngleDeg = 80.0; // nicht sortiert
			CHECK(!IsValidSailTuning(Bad));
			Bad = T;
			Bad.Polar[1].Efficiency = 1.5;
			CHECK(!IsValidSailTuning(Bad));
		} },
		{ "Wind ist deterministisch und pendelt um die Grundrichtung", []
		{
			FWindParams P;
			P.BaseDirectionDeg = 90.0;
			P.DirectionSwingDeg = 20.0;
			P.StrengthSwing = 0.2;
			P.PeriodSeconds = 600.0;
			const FWind A = WindAt(P, 123.0);
			const FWind B = WindAt(P, 123.0);
			CHECK_NEAR(A.DirectionDeg, B.DirectionDeg);
			CHECK_NEAR(WindAt(P, 0.0).DirectionDeg, 90.0);
			CHECK_NEAR(WindAt(P, 150.0).DirectionDeg, 110.0); // Viertelperiode: volle Auslenkung
			for (double t = 0.0; t < 1200.0; t += 37.0)
			{
				const FWind W = WindAt(P, t);
				CHECK(AngleOffWindDeg(W.DirectionDeg, 90.0) <= 20.0 + 1e-9);
				CHECK(W.Strength >= 0.8 - 1e-9 && W.Strength <= 1.2 + 1e-9);
			}
		} },
		{ "Mehr Matrosen machen schneller, unter Mindestbesatzung keine Fahrt", []
		{
			const FShipDef S = Sloop();
			const FSailTuning T = Sail();
			CHECK_NEAR(CrewFactor(9, S, T), 0.0);
			CHECK_NEAR(CrewFactor(10, S, T), 0.5);
			CHECK_NEAR(CrewFactor(20, S, T), 0.75);
			CHECK_NEAR(CrewFactor(30, S, T), 1.0);
			CHECK_NEAR(CrewFactor(99, S, T), 1.0);
			CHECK(TargetSpeed(S, T, 1.0, 90.0, Wind(0.0), 30, true) > TargetSpeed(S, T, 1.0, 90.0, Wind(0.0), 20, true));
		} },
		{ "Zielgeschwindigkeit aus Segel, Kurs zum Wind, Stärke und Proviant", []
		{
			const FShipDef S = Sloop();
			const FSailTuning T = Sail();
			CHECK_NEAR(TargetSpeed(S, T, 1.0, 90.0, Wind(0.0), 30, true), 1000.0); // halber Wind
			CHECK_NEAR(TargetSpeed(S, T, 0.5, 90.0, Wind(0.0), 30, true), 500.0);
			CHECK_NEAR(TargetSpeed(S, T, 1.0, 180.0, Wind(0.0), 30, true), 0.0);   // im Wind
			CHECK_NEAR(TargetSpeed(S, T, 1.0, 0.0, Wind(0.0), 30, true), 800.0);   // vor dem Wind
			CHECK_NEAR(TargetSpeed(S, T, 1.0, 90.0, Wind(0.0, 0.5), 30, true), 500.0);
			CHECK_NEAR(TargetSpeed(S, T, 1.0, 90.0, Wind(0.0), 30, false), 500.0); // ohne Proviant
			CHECK_NEAR(TargetSpeed(S, T, 2.0, 90.0, Wind(0.0), 30, true), 1000.0); // Segel begrenzt
			FShipDef Rowed = S;
			Rowed.WindEfficiency = 0.0;
			CHECK_NEAR(TargetSpeed(Rowed, T, 1.0, 180.0, Wind(0.0), 30, true), 1000.0);
		} },
		{ "Beschleunigen, Abbremsen, Wenden abhängig von der Fahrt", []
		{
			const FShipDef S = Sloop();
			const FSailTuning T = Sail();
			FShipMotion M;
			M = StepShip(M, FHelm{ 1.0, 0.0 }, 1000.0, S, T, 2.0);
			CHECK_NEAR(M.Speed, 200.0);
			M = StepShip(M, FHelm{ 1.0, 0.0 }, 1000.0, S, T, 100.0);
			CHECK_NEAR(M.Speed, 1000.0); // nicht über das Ziel
			M = StepShip(M, FHelm{ 0.0, 0.0 }, 0.0, S, T, 1.0);
			CHECK_NEAR(M.Speed, 800.0);

			FShipMotion Fast{ 1000.0, 350.0 };
			Fast = StepShip(Fast, FHelm{ 1.0, 1.0 }, 1000.0, S, T, 1.0);
			CHECK_NEAR(Fast.HeadingDeg, 10.0); // volle Wendigkeit, über 360 normiert
			FShipMotion Still{ 0.0, 0.0 };
			Still = StepShip(Still, FHelm{ 0.0, -1.0 }, 0.0, S, T, 1.0);
			CHECK_NEAR(Still.HeadingDeg, 356.0); // im Stand nur 20 %
			FShipMotion Odd = StepShip(FShipMotion{ 0.0, 0.0 }, FHelm{ 0.0, 5.0 }, 0.0, S, T, -1.0);
			CHECK_NEAR(Odd.HeadingDeg, 0.0); // negative Zeit bewirkt nichts
		} },
		{ "Proviant: Bruchteile werden übertragen, nie unter null", []
		{
			const FSailTuning T = Sail(); // 0,1 je Matrose und Minute
			FProvisions P{ 10, 0.0 };
			for (int i = 0; i < 4; ++i)
			{
				P = ConsumeProvisions(P, 20, 15.0, T); // 4 × 0,5
			}
			CHECK(P.Amount == 8);
			CHECK_NEAR(P.Carry, 0.0);
			P = ConsumeProvisions(P, 30, 600.0, T); // 30 Einheiten gewünscht, nur 8 da
			CHECK(P.Amount == 0);
			CHECK(ConsumeProvisions(FProvisions{ 5, 0.0 }, 0, 600.0, T).Amount == 5);
		} },
	};
	return Cases;
}
