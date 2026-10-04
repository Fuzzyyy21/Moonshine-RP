#pragma once

// Kleiner eigener Testlauf für die Regeln, damit keine Fremdbibliothek nötig ist.

#include "VCCombatRules.h"

#include <cmath>
#include <functional>
#include <vector>

namespace vctest
{
	struct FCase
	{
		const char* Name;
		std::function<void()> Body;
	};

	void Check(bool Condition, const char* Expression, const char* File, int Line);

	/** Parameter wie in design_data/dev_combat.json, damit die Tests die echten Größenordnungen prüfen. */
	vc::rules::FCombatTuning Tuning();

	/** Mittlere Streuung, kein Ausweichen/Blocken/Krit. */
	vc::rules::FAttackRolls NoLuck();

	const std::vector<FCase>& CombatRulesCases();
	const std::vector<FCase>& AbilityRulesCases();
}

#define CHECK(Expr) ::vctest::Check((Expr), #Expr, __FILE__, __LINE__)
#define CHECK_NEAR(A, B) ::vctest::Check(std::fabs((A) - (B)) < 1e-9, #A " == " #B, __FILE__, __LINE__)
