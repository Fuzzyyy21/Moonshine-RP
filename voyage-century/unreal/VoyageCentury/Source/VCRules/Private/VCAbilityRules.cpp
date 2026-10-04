#include "VCAbilityRules.h"

#include <algorithm>

namespace vc::rules
{
	double EffectiveRange(const FAbilityDef& Ability, double WeaponRangeCm)
	{
		return Ability.RangeCm > 0.0 ? Ability.RangeCm : WeaponRangeCm;
	}

	EAbilityBlock CheckAbilityUse(const FAbilityDef& A, const FAbilityUseContext& C, const FCombatTuning& T)
	{
		if (!C.bAlive)
		{
			return EAbilityBlock::Dead;
		}
		if (C.bStunned)
		{
			return EAbilityBlock::Stunned;
		}
		if (A.bRequiresWeaponClass && C.EquippedWeaponClass != A.RequiredWeaponClass)
		{
			return EAbilityBlock::WrongWeapon;
		}
		if (C.SkillLevel < A.RequiredSkillLevel)
		{
			return EAbilityBlock::SkillTooLow;
		}
		if (C.LastUseTime >= 0.0 && C.Now - C.LastUseTime < A.CooldownSeconds * (1.0 - T.IntervalTolerance))
		{
			return EAbilityBlock::OnCooldown;
		}
		if (C.Stamina < A.StaminaCost)
		{
			return EAbilityBlock::NotEnoughStamina;
		}
		if (A.TargetMode == ETargetMode::Self)
		{
			return EAbilityBlock::None;
		}
		if (!C.bHasTarget || !C.bTargetAlive)
		{
			return EAbilityBlock::NoTarget;
		}
		if (!C.bTargetHostile)
		{
			return EAbilityBlock::TargetNotHostile;
		}
		if (C.DistanceCm < 0.0 || C.DistanceCm > EffectiveRange(A, C.WeaponRangeCm) + T.RangeToleranceCm)
		{
			return EAbilityBlock::OutOfRange;
		}
		return EAbilityBlock::None;
	}

	void ApplyStatus(std::vector<FActiveStatus>& Active, int DefIndex, const FStatusDef& Def, double Now)
	{
		const int MaxStacks = std::max(1, Def.MaxStacks);
		for (FActiveStatus& Status : Active)
		{
			if (Status.DefIndex == DefIndex)
			{
				Status.Stacks = std::min(Status.Stacks + 1, MaxStacks);
				Status.ExpiresAt = Now + Def.DurationSeconds;
				return;
			}
		}
		FActiveStatus Status;
		Status.DefIndex = DefIndex;
		Status.Stacks = 1;
		Status.ExpiresAt = Now + Def.DurationSeconds;
		Status.NextTickAt = Def.TickIntervalSeconds > 0.0 ? Now + Def.TickIntervalSeconds : Status.ExpiresAt + 1.0;
		Active.push_back(Status);
	}

	bool RemoveExpired(std::vector<FActiveStatus>& Active, double Now)
	{
		const auto Before = Active.size();
		Active.erase(std::remove_if(Active.begin(), Active.end(),
			[Now](const FActiveStatus& S) { return S.ExpiresAt <= Now; }), Active.end());
		return Active.size() != Before;
	}

	FStatModifiers Aggregate(const std::vector<FActiveStatus>& Active, const std::vector<FStatusDef>& Defs)
	{
		FStatModifiers Sum;
		for (const FActiveStatus& Status : Active)
		{
			if (Status.DefIndex < 0 || static_cast<size_t>(Status.DefIndex) >= Defs.size() || Status.Stacks <= 0)
			{
				continue;
			}
			const FStatModifiers& Per = Defs[static_cast<size_t>(Status.DefIndex)].PerStack;
			const double Stacks = static_cast<double>(Status.Stacks);
			Sum.AttackPower += Per.AttackPower * Stacks;
			Sum.Defense += Per.Defense * Stacks;
			Sum.CritChance += Per.CritChance * Stacks;
			Sum.BlockChance += Per.BlockChance * Stacks;
			Sum.DodgeChance += Per.DodgeChance * Stacks;
			for (int i = 0; i < Status.Stacks; ++i)
			{
				Sum.MoveSpeedMultiplier *= std::max(0.0, Per.MoveSpeedMultiplier);
			}
			Sum.bStunned = Sum.bStunned || Per.bStunned;
		}
		return Sum;
	}

	FTickResult CollectStatusTicks(FActiveStatus& Status, const FStatusDef& Def, double Now)
	{
		FTickResult Result;
		if (Def.TickIntervalSeconds <= 0.0)
		{
			return Result;
		}
		while (Status.NextTickAt <= Now && Status.NextTickAt <= Status.ExpiresAt)
		{
			Result.Damage += Def.DamagePerTick * Status.Stacks;
			Result.Heal += Def.HealPerTick * Status.Stacks;
			Status.NextTickAt += Def.TickIntervalSeconds;
		}
		return Result;
	}

	FTickResult CollectTicks(std::vector<FActiveStatus>& Active, const std::vector<FStatusDef>& Defs, double Now)
	{
		FTickResult Result;
		for (FActiveStatus& Status : Active)
		{
			if (Status.DefIndex < 0 || static_cast<size_t>(Status.DefIndex) >= Defs.size())
			{
				continue;
			}
			const FTickResult One = CollectStatusTicks(Status, Defs[static_cast<size_t>(Status.DefIndex)], Now);
			Result.Damage += One.Damage;
			Result.Heal += One.Heal;
		}
		return Result;
	}

	FCombatStats WithModifiers(const FCombatStats& Base, const FStatModifiers& Mods)
	{
		FCombatStats Stats = Base;
		Stats.AttackPower = std::max(0.0, Base.AttackPower + Mods.AttackPower);
		Stats.Defense = std::max(0.0, Base.Defense + Mods.Defense);
		Stats.CritChance = std::clamp(Base.CritChance + Mods.CritChance, 0.0, 1.0);
		Stats.BlockChance = std::clamp(Base.BlockChance + Mods.BlockChance, 0.0, 1.0);
		Stats.DodgeChance = std::clamp(Base.DodgeChance + Mods.DodgeChance, 0.0, 1.0);
		return Stats;
	}

	double MoveSpeedFactor(const FStatModifiers& Mods)
	{
		return Mods.bStunned ? 0.0 : std::max(0.0, Mods.MoveSpeedMultiplier);
	}
}
