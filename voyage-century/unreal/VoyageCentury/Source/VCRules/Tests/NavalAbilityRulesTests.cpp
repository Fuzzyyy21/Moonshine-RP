// Tests der Seekampf-Fähigkeiten (VCNavalAbilityRules).
#include "TestHarness.h"
#include "VCNavalAbilityRules.h"

using namespace vc::rules;

const std::vector<vctest::FCase>& vctest::NavalAbilityRulesCases()
{
	static const std::vector<FCase> Cases = {
		{ "Rammen nur mit dem Bug und mit Fahrt", []
		{
			FRamTuning T;
			T.DamagePerMps = 10.0;
			T.SelfDamageShare = 0.25;
			T.FrontArcDeg = 30.0;
			T.MinSpeedMps = 2.0;
			CHECK(IsAhead(0.0, 0, 0, 500, 100, 30.0));
			CHECK(!IsAhead(0.0, 0, 0, 100, 500, 30.0));  // seitlich
			CHECK(!IsAhead(0.0, 0, 0, -500, 0, 30.0));   // achteraus
			CHECK(IsAhead(90.0, 0, 0, 0, 500, 30.0));
			const FRamResult Hit = ResolveRam(8.0, 1500.0, true, T);
			CHECK(Hit.bRammed);
			CHECK_NEAR(Hit.TargetDamage, 120.0); // 8 × 10 × 1,5
			CHECK_NEAR(Hit.SelfDamage, 30.0);
			CHECK(!ResolveRam(1.0, 1500.0, true, T).bRammed);  // zu langsam
			CHECK(!ResolveRam(8.0, 1500.0, false, T).bRammed); // nicht vor dem Bug
		} },
		{ "Enterhaken: nah und beide langsam", []
		{
			FGrappleTuning T;
			T.RangeCm = 800.0;
			T.MaxSpeedMps = 4.0;
			CHECK(CanGrapple(700.0, 3.0, 4.0, T));
			CHECK(!CanGrapple(900.0, 3.0, 3.0, T));
			CHECK(!CanGrapple(700.0, 5.0, 3.0, T));
			CHECK(!CanGrapple(700.0, 3.0, 6.0, T));
		} },
		{ "Entern: Runden nach Mannschaftsstärke, Erkundungsschiff stärker", []
		{
			FBoardingTuning T;
			T.LossFactor = 0.2;
			T.RaiderStrength = 1.5;
			const FBoardingRound Even = ResolveBoardingRound(20, 20, 1.0, 1.0, 0.5, 0.5, T);
			CHECK(Even.AttackerLosses == 4);
			CHECK(Even.DefenderLosses == 4);
			const FBoardingRound Raider = ResolveBoardingRound(20, 20, T.RaiderStrength, 1.0, 0.5, 0.5, T);
			CHECK(Raider.DefenderLosses == 6);
			CHECK(Raider.AttackerLosses == 4);
			const FBoardingRound Overkill = ResolveBoardingRound(40, 3, 1.0, 1.0, 1.0, 0.0, T);
			CHECK(Overkill.DefenderLosses == 3); // nie mehr, als da sind
			CHECK(BoardingOutcome(5, 0) == EBoardingOutcome::AttackerWins);
			CHECK(BoardingOutcome(0, 5) == EBoardingOutcome::DefenderWins);
			CHECK(BoardingOutcome(5, 5) == EBoardingOutcome::Ongoing);
		} },
		{ "Minen: scharf erst nach kurzer Zeit, Radius, Lebensdauer", []
		{
			FMineTuning T;
			T.TriggerRadiusCm = 300.0;
			T.LifetimeSeconds = 60.0;
			T.ArmSeconds = 3.0;
			const FMine M{ 0.0, 0.0, 10.0 };
			CHECK(!MineTriggers(M, 11.0, 0.0, 0.0, T));   // noch nicht scharf
			CHECK(MineTriggers(M, 14.0, 200.0, 200.0, T));
			CHECK(!MineTriggers(M, 14.0, 300.0, 300.0, T)); // außerhalb
			CHECK(!MineTriggers(M, 75.0, 0.0, 0.0, T));     // abgelaufen
			CHECK(MineExpired(M, 70.0, T));
			CHECK(!MineExpired(M, 69.0, T));
		} },
	};
	return Cases;
}
