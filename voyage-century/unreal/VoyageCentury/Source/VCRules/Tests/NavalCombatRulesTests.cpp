// Tests der Seekampf-Regeln (VCNavalCombatRules).
#include "TestHarness.h"
#include "VCNavalCombatRules.h"

using namespace vc::rules;

namespace
{
	FCannonDef Short()
	{
		FCannonDef C;
		C.RangeCm = 1000.0;
		C.DamagePerHit = 20.0;
		C.CrewHitsPerHit = 0.5;
		C.ReloadSeconds = 8.0;
		C.HitChanceNear = 0.9;
		C.HitChanceFar = 0.5;
		return C;
	}
}

const std::vector<vctest::FCase>& vctest::NavalCombatRulesCases()
{
	static const std::vector<FCase> Cases = {
		{ "Breitseite: Ziel quer ab, nicht voraus oder achteraus", []
		{
			const FBroadsideTuning T;
			CHECK(SideFacing(0.0, 0, 0, 0, 500, T) == EBroadside::Starboard); // Kurs +X, Ziel +Y
			CHECK(SideFacing(0.0, 0, 0, 0, -500, T) == EBroadside::Port);
			CHECK(SideFacing(0.0, 0, 0, 500, 0, T) == EBroadside::None);      // voraus
			CHECK(SideFacing(0.0, 0, 0, -500, 0, T) == EBroadside::None);     // achteraus
			CHECK(SideFacing(0.0, 0, 0, 400, 500, T) == EBroadside::Starboard); // 51° vom Bug, im Winkel
			CHECK(SideFacing(0.0, 0, 0, 500, 300, T) == EBroadside::None);      // 31° vom Bug
			CHECK(SideFacing(90.0, 0, 0, 500, 0, T) == EBroadside::Port);       // Kurs +Y: +X liegt links
			CHECK(SideFacing(270.0, 0, 0, 500, 0, T) == EBroadside::Starboard);
			CHECK(SideFacing(0.0, 0, 0, 0, 0, T) == EBroadside::None);
		} },
		{ "Trefferchance sinkt mit der Entfernung, außer Reichweite null", []
		{
			CHECK_NEAR(HitChance(Short(), 0.0), 0.9);
			CHECK_NEAR(HitChance(Short(), 500.0), 0.7);
			CHECK_NEAR(HitChance(Short(), 1000.0), 0.5);
			CHECK_NEAR(HitChance(Short(), 1001.0), 0.0);
			CHECK_NEAR(HitChance(Short(), -1.0), 0.0);
		} },
		{ "Breitseite: ein Wurf je Kanone", []
		{
			const std::vector<double> Rolls = { 0.1, 0.65, 0.75, 0.95 };
			const FBroadsideResult R = ResolveBroadside(4, Short(), 500.0, Rolls); // Chance 0,7
			CHECK(R.Hits == 2);
			CHECK_NEAR(R.HullDamage, 40.0);
			CHECK(R.CrewLosses == 1);
			CHECK(ResolveBroadside(4, Short(), 2000.0, Rolls).Hits == 0);
			CHECK(ResolveBroadside(10, Short(), 0.0, Rolls).Hits == 3); // nur so viele Würfe wie übergeben
			CHECK(CannonsPerSide(7) == 3);
			CHECK(CannonsPerSide(-2) == 0);
		} },
		{ "Matrosen: Verluste treffen Gesunde, ein Teil stirbt", []
		{
			const FBroadsideTuning T; // 30 % tot
			const FCrew C = ApplyCrewLosses(FCrew{ 10, 1, 0 }, 10, T);
			CHECK(C.Healthy == 0);
			CHECK(C.Dead == 3);
			CHECK(C.Injured == 8);
			const FCrew Over = ApplyCrewLosses(FCrew{ 2, 0, 0 }, 50, T);
			CHECK(Over.Healthy == 0);
			CHECK(Over.Injured + Over.Dead == 2);
		} },
		{ "Rumpf und Nachladen", []
		{
			CHECK_NEAR(ApplyHullDamage(100.0, 30.0), 70.0);
			CHECK_NEAR(ApplyHullDamage(10.0, 30.0), 0.0);
			CHECK_NEAR(ApplyHullDamage(10.0, -5.0), 10.0);
			CHECK(IsReloaded(-1.0, 0.0, Short(), Tuning()));
			CHECK(!IsReloaded(10.0, 17.0, Short(), Tuning()));
			CHECK(IsReloaded(10.0, 17.25, Short(), Tuning())); // 10 % Toleranz: ab 7,2 s
		} },
	};
	return Cases;
}
