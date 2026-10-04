#include "TestHarness.h"

#include <cstdio>

namespace vctest
{
	namespace
	{
		int Failures = 0;
		int Checks = 0;
	}

	void Check(bool Condition, const char* Expression, const char* File, int Line)
	{
		++Checks;
		if (!Condition)
		{
			++Failures;
			std::printf("  FEHLER %s:%d: %s\n", File, Line, Expression);
		}
	}

	vc::rules::FCombatTuning Tuning()
	{
		vc::rules::FCombatTuning T;
		T.BaseHealth = 100.0;
		T.HealthPerLevel = 10.0;
		T.BaseStamina = 50.0;
		T.StaminaPerLevel = 5.0;
		T.AttackPerLevel = 2.0;
		T.DefensePerLevel = 1.0;
		T.SkillDamageBonusPerLevel = 0.01;
		T.DefenseConstant = 100.0;
		T.MinDamage = 1.0;
		T.DamageVariance = 0.1;
		T.BaseCritChance = 0.05;
		T.CritMultiplier = 1.5;
		T.BaseBlockChance = 0.05;
		T.BlockReduction = 0.5;
		T.BaseDodgeChance = 0.05;
		T.MaxCritChance = 0.5;
		T.MaxBlockChance = 0.4;
		T.MaxDodgeChance = 0.4;
		T.RangeToleranceCm = 50.0;
		T.IntervalTolerance = 0.1;
		return T;
	}

	vc::rules::FAttackRolls NoLuck()
	{
		return vc::rules::FAttackRolls{ 0.99, 0.99, 0.99, 0.5 };
	}

	namespace
	{
		void Run(const std::vector<FCase>& Cases)
		{
			for (const FCase& Case : Cases)
			{
				const int Before = Failures;
				Case.Body();
				std::printf("%s %s\n", Failures == Before ? "ok  " : "FAIL", Case.Name);
			}
		}
	}
}

int main()
{
	std::printf("== Kampfregeln\n");
	vctest::Run(vctest::CombatRulesCases());
	std::printf("== Fähigkeiten und Statuseffekte\n");
	vctest::Run(vctest::AbilityRulesCases());
	std::printf("%d Prüfungen, %d Fehler\n", vctest::Checks, vctest::Failures);
	return vctest::Failures == 0 ? 0 : 1;
}
