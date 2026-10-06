#include "VCCombatRules.h"

#include <algorithm>
#include <cmath>

namespace vc::rules
{
	namespace
	{
		bool IsChance(double Value)
		{
			return Value >= 0.0 && Value <= 1.0;
		}

		double Clamp01(double Value)
		{
			return std::clamp(Value, 0.0, 1.0);
		}
	}

	bool IsValidTuning(const FCombatTuning& T)
	{
		const double NonNegative[] = {
			T.BaseHealth, T.HealthPerLevel, T.BaseStamina, T.StaminaPerLevel, T.AttackPerLevel, T.DefensePerLevel,
			T.SkillDamageBonusPerLevel, T.MinDamage, T.RangeToleranceCm,
		};
		for (const double Value : NonNegative)
		{
			if (!(Value >= 0.0))
			{
				return false;
			}
		}
		const double Chances[] = {
			T.DamageVariance, T.BaseCritChance, T.BaseBlockChance, T.BlockReduction, T.BaseDodgeChance,
			T.MaxCritChance, T.MaxBlockChance, T.MaxDodgeChance, T.IntervalTolerance,
		};
		for (const double Value : Chances)
		{
			if (!IsChance(Value))
			{
				return false;
			}
		}
		return T.BaseHealth > 0.0 && T.DefenseConstant > 0.0 && T.CritMultiplier >= 1.0;
	}

	FCombatStats DeriveCharacterStats(int Level, const FCombatTuning& T)
	{
		const double Steps = static_cast<double>(std::max(Level, 1) - 1);
		FCombatStats Stats;
		Stats.MaxHealth = T.BaseHealth + T.HealthPerLevel * Steps;
		Stats.MaxStamina = T.BaseStamina + T.StaminaPerLevel * Steps;
		Stats.AttackPower = T.AttackPerLevel * Steps;
		Stats.Defense = T.DefensePerLevel * Steps;
		Stats.CritChance = T.BaseCritChance;
		Stats.CritMultiplier = T.CritMultiplier;
		Stats.BlockChance = T.BaseBlockChance;
		Stats.BlockReduction = T.BlockReduction;
		Stats.DodgeChance = T.BaseDodgeChance;
		return Stats;
	}

	FCombatStats WithBonus(const FCombatStats& Stats, const FStatBonus& Bonus)
	{
		FCombatStats Result = Stats;
		Result.MaxHealth = std::max(1.0, Stats.MaxHealth + Bonus.MaxHealth);
		Result.AttackPower = std::max(0.0, Stats.AttackPower + Bonus.AttackPower);
		Result.Defense = std::max(0.0, Stats.Defense + Bonus.Defense);
		return Result;
	}

	double WeaponDamage(const FWeaponDef& Weapon, int WeaponSkillLevel, const FCombatTuning& T)
	{
		const double Steps = static_cast<double>(std::max(WeaponSkillLevel, 1) - 1);
		return std::max(0.0, Weapon.BaseDamage) * (1.0 + T.SkillDamageBonusPerLevel * Steps);
	}

	FAttackOutcome ResolveAttack(const FCombatStats& Attacker, const FCombatStats& Defender,
		double WeaponDamageValue, const FAttackRolls& Rolls, const FCombatTuning& T)
	{
		FAttackOutcome Outcome;

		if (Rolls.Dodge < std::min(Clamp01(Defender.DodgeChance), T.MaxDodgeChance))
		{
			Outcome.Result = EHitResult::Dodged;
			Outcome.Damage = 0.0;
			return Outcome;
		}

		const double Spread = 1.0 + T.DamageVariance * (2.0 * Clamp01(Rolls.Variance) - 1.0);
		const double Raw = std::max(0.0, WeaponDamageValue + Attacker.AttackPower) * Spread;
		const double Defense = std::max(0.0, Defender.Defense);
		double Damage = Raw * (1.0 - Defense / (Defense + T.DefenseConstant));

		if (Rolls.Block < std::min(Clamp01(Defender.BlockChance), T.MaxBlockChance))
		{
			Outcome.Result = EHitResult::Blocked;
			Damage *= 1.0 - Clamp01(Defender.BlockReduction);
		}
		else if (Rolls.Crit < std::min(Clamp01(Attacker.CritChance), T.MaxCritChance))
		{
			Outcome.Result = EHitResult::Critical;
			Damage *= std::max(1.0, Attacker.CritMultiplier);
		}
		else
		{
			Outcome.Result = EHitResult::Hit;
		}

		Outcome.Damage = std::max(T.MinDamage, std::round(Damage));
		return Outcome;
	}

	bool IsInRange(double DistanceCm, const FWeaponDef& Weapon, const FCombatTuning& T)
	{
		return DistanceCm >= 0.0 && DistanceCm <= Weapon.RangeCm + T.RangeToleranceCm;
	}

	bool IsAttackReady(double LastAttackTime, double Now, const FWeaponDef& Weapon, const FCombatTuning& T)
	{
		if (LastAttackTime < 0.0)
		{
			return true;
		}
		return Now - LastAttackTime >= Weapon.AttackInterval * (1.0 - T.IntervalTolerance);
	}

	double ClampHealth(double Health, double MaxHealth)
	{
		return std::clamp(Health, 0.0, std::max(0.0, MaxHealth));
	}
}
