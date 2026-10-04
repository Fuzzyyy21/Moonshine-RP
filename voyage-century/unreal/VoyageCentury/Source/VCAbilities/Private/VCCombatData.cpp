#include "VCCombatData.h"
#include "Engine/DataTable.h"
#include "VCCore.h"

namespace
{
	UDataTable* Load(const TSoftObjectPtr<UDataTable>& Ref)
	{
		UDataTable* Table = Ref.IsNull() ? nullptr : Ref.LoadSynchronous();
		if (Table && !Table->IsRooted())
		{
			Table->AddToRoot(); // Konfigurationsdaten: für die Laufzeit des Prozesses geladen halten
		}
		return Table;
	}

	struct FCache
	{
		bool bLoaded = false;
		UDataTable* Tuning = nullptr;
		UDataTable* Weapons = nullptr;
		UDataTable* Monsters = nullptr;
		UDataTable* Abilities = nullptr;
		UDataTable* StatusEffects = nullptr;
		vc::rules::FCombatTuning Rules;
		bool bValid = false;
		bool bAbilitiesValid = false;
		TArray<FName> StatusCodes;
		std::vector<vc::rules::FStatusDef> StatusDefs;
	};

	/** Prüft, dass jede Fähigkeit auf vorhandene Statuseffekte verweist. */
	bool AbilitiesConsistent(const UDataTable& Abilities, const TArray<FName>& StatusCodes)
	{
		bool bOk = true;
		Abilities.ForeachRow<FVCAbilityRow>(TEXT("VCCombatData"), [&bOk, &StatusCodes](const FName& Code, const FVCAbilityRow& Row)
		{
			for (const FName& Status : Row.AppliedStatuses)
			{
				if (!StatusCodes.Contains(Status))
				{
					UE_LOG(LogVC, Error, TEXT("Fähigkeit %s verweist auf unbekannten Statuseffekt %s"), *Code.ToString(), *Status.ToString());
					bOk = false;
				}
			}
		});
		return bOk;
	}

	FCache& Cache()
	{
		static FCache Instance;
		if (!Instance.bLoaded)
		{
			Instance.bLoaded = true;
			const UVCCombatSettings* Settings = GetDefault<UVCCombatSettings>();
			Instance.Tuning = Load(Settings->TuningTable);
			Instance.Weapons = Load(Settings->WeaponsTable);
			Instance.Monsters = Load(Settings->MonstersTable);
			Instance.Abilities = Load(Settings->AbilitiesTable);
			Instance.StatusEffects = Load(Settings->StatusEffectsTable);

			const FVCCombatTuningRow* Row = Instance.Tuning
				? Instance.Tuning->FindRow<FVCCombatTuningRow>(TEXT("Default"), TEXT("VCCombatData")) : nullptr;
			if (Row)
			{
				vc::rules::FCombatTuning& T = Instance.Rules;
				T.BaseHealth = Row->BaseHealth;
				T.HealthPerLevel = Row->HealthPerLevel;
				T.BaseStamina = Row->BaseStamina;
				T.StaminaPerLevel = Row->StaminaPerLevel;
				T.AttackPerLevel = Row->AttackPerLevel;
				T.DefensePerLevel = Row->DefensePerLevel;
				T.SkillDamageBonusPerLevel = Row->SkillDamageBonusPerLevel;
				T.DefenseConstant = Row->DefenseConstant;
				T.MinDamage = Row->MinDamage;
				T.DamageVariance = Row->DamageVariance;
				T.BaseCritChance = Row->BaseCritChance;
				T.CritMultiplier = Row->CritMultiplier;
				T.BaseBlockChance = Row->BaseBlockChance;
				T.BlockReduction = Row->BlockReduction;
				T.BaseDodgeChance = Row->BaseDodgeChance;
				T.MaxCritChance = Row->MaxCritChance;
				T.MaxBlockChance = Row->MaxBlockChance;
				T.MaxDodgeChance = Row->MaxDodgeChance;
				T.RangeToleranceCm = Row->RangeToleranceCm;
				T.IntervalTolerance = Row->IntervalTolerance;
				Instance.bValid = vc::rules::IsValidTuning(T) && Instance.Weapons && Instance.Monsters;
			}
			if (!Instance.bValid)
			{
				UE_LOG(LogVC, Error, TEXT("Kampfdaten fehlen oder sind ungültig – Kampf ist deaktiviert (Projekteinstellungen > Voyage Century Combat)"));
			}

			if (Instance.StatusEffects)
			{
				// Feste Reihenfolge (nach Code), damit Indizes in einem Serverprozess stabil sind.
				Instance.StatusCodes = Instance.StatusEffects->GetRowNames();
				Instance.StatusCodes.Sort(FNameLexicalLess());
				for (const FName& Code : Instance.StatusCodes)
				{
					const FVCStatusEffectRow* Row = Instance.StatusEffects->FindRow<FVCStatusEffectRow>(Code, TEXT("VCCombatData"));
					Instance.StatusDefs.push_back(Row ? FVCCombatData::ToRules(*Row) : vc::rules::FStatusDef());
				}
			}
			Instance.bAbilitiesValid = Instance.bValid && Instance.Abilities && Instance.StatusEffects
				&& AbilitiesConsistent(*Instance.Abilities, Instance.StatusCodes);
			if (Instance.bValid && !Instance.bAbilitiesValid)
			{
				UE_LOG(LogVC, Warning, TEXT("DT_Abilities/DT_StatusEffects fehlen oder passen nicht zusammen – nur Grundangriff verfügbar"));
			}
		}
		return Instance;
	}
}

bool FVCCombatData::IsAvailable()
{
	return Cache().bValid;
}

bool FVCCombatData::AreAbilitiesAvailable()
{
	return Cache().bAbilitiesValid;
}

const vc::rules::FCombatTuning& FVCCombatData::Tuning()
{
	return Cache().Rules;
}

const FVCCombatTuningRow* FVCCombatData::TuningRow()
{
	UDataTable* Table = Cache().Tuning;
	return Table ? Table->FindRow<FVCCombatTuningRow>(TEXT("Default"), TEXT("VCCombatData")) : nullptr;
}

const FVCWeaponRow* FVCCombatData::FindWeapon(FName Code)
{
	UDataTable* Table = Cache().Weapons;
	return Table && !Code.IsNone() ? Table->FindRow<FVCWeaponRow>(Code, TEXT("VCCombatData"), false) : nullptr;
}

const FVCMonsterRow* FVCCombatData::FindMonster(FName Code)
{
	UDataTable* Table = Cache().Monsters;
	return Table && !Code.IsNone() ? Table->FindRow<FVCMonsterRow>(Code, TEXT("VCCombatData"), false) : nullptr;
}

const FVCAbilityRow* FVCCombatData::FindAbility(FName Code)
{
	UDataTable* Table = Cache().Abilities;
	return Table && !Code.IsNone() ? Table->FindRow<FVCAbilityRow>(Code, TEXT("VCCombatData"), false) : nullptr;
}

const FVCStatusEffectRow* FVCCombatData::FindStatus(FName Code)
{
	UDataTable* Table = Cache().StatusEffects;
	return Table && !Code.IsNone() ? Table->FindRow<FVCStatusEffectRow>(Code, TEXT("VCCombatData"), false) : nullptr;
}

TArray<FName> FVCCombatData::AbilityCodes()
{
	UDataTable* Table = Cache().Abilities;
	TArray<FName> Codes = Table ? Table->GetRowNames() : TArray<FName>();
	Codes.Sort(FNameLexicalLess());
	return Codes;
}

const std::vector<vc::rules::FStatusDef>& FVCCombatData::StatusDefs()
{
	return Cache().StatusDefs;
}

int32 FVCCombatData::StatusIndex(FName Code)
{
	return Cache().StatusCodes.IndexOfByKey(Code);
}

FName FVCCombatData::StatusCode(int32 Index)
{
	const TArray<FName>& Codes = Cache().StatusCodes;
	return Codes.IsValidIndex(Index) ? Codes[Index] : NAME_None;
}

vc::rules::EWeaponClass FVCCombatData::ToRules(EVCWeaponClass Class)
{
	switch (Class)
	{
	case EVCWeaponClass::Sword: return vc::rules::EWeaponClass::Sword;
	case EVCWeaponClass::Blade: return vc::rules::EWeaponClass::Blade;
	case EVCWeaponClass::Axe: return vc::rules::EWeaponClass::Axe;
	case EVCWeaponClass::Firearm: return vc::rules::EWeaponClass::Firearm;
	default: return vc::rules::EWeaponClass::Unarmed;
	}
}

vc::rules::FAbilityDef FVCCombatData::ToRules(const FVCAbilityRow& Row)
{
	vc::rules::FAbilityDef Def;
	Def.RequiredSkillLevel = Row.RequiredSkillLevel;
	Def.StaminaCost = Row.StaminaCost;
	Def.CooldownSeconds = Row.CooldownSeconds;
	Def.DamageMultiplier = Row.DamageMultiplier;
	Def.RangeCm = Row.RangeCm;
	Def.TargetMode = Row.TargetMode == EVCAbilityTarget::Caster ? vc::rules::ETargetMode::Self : vc::rules::ETargetMode::Enemy;
	Def.bRequiresWeaponClass = Row.bRequiresWeaponClass;
	Def.RequiredWeaponClass = ToRules(Row.RequiredWeaponClass);
	return Def;
}

vc::rules::FStatusDef FVCCombatData::ToRules(const FVCStatusEffectRow& Row)
{
	vc::rules::FStatusDef Def;
	Def.DurationSeconds = Row.DurationSeconds;
	Def.MaxStacks = Row.MaxStacks;
	Def.PerStack.AttackPower = Row.AttackPower;
	Def.PerStack.Defense = Row.Defense;
	Def.PerStack.CritChance = Row.CritChance;
	Def.PerStack.BlockChance = Row.BlockChance;
	Def.PerStack.DodgeChance = Row.DodgeChance;
	Def.PerStack.MoveSpeedMultiplier = Row.MoveSpeedMultiplier;
	Def.PerStack.bStunned = Row.bStunned;
	Def.TickIntervalSeconds = Row.TickIntervalSeconds;
	Def.DamagePerTick = Row.DamagePerTick;
	Def.HealPerTick = Row.HealPerTick;
	return Def;
}

vc::rules::FWeaponDef FVCCombatData::ToRules(const FVCWeaponRow& Row)
{
	vc::rules::FWeaponDef Def;
	Def.Class = ToRules(Row.WeaponClass);
	Def.BaseDamage = Row.BaseDamage;
	Def.AttackInterval = Row.AttackInterval;
	Def.RangeCm = Row.RangeCm;
	return Def;
}

vc::rules::FWeaponDef FVCCombatData::AttackOf(const FVCMonsterRow& Row)
{
	vc::rules::FWeaponDef Def;
	Def.Class = vc::rules::EWeaponClass::Unarmed;
	Def.BaseDamage = Row.BaseDamage;
	Def.AttackInterval = Row.AttackInterval;
	Def.RangeCm = Row.RangeCm;
	return Def;
}

vc::rules::FCombatStats FVCCombatData::StatsOf(const FVCMonsterRow& Row)
{
	const vc::rules::FCombatTuning& T = Tuning();
	vc::rules::FCombatStats Stats;
	Stats.MaxHealth = Row.MaxHealth;
	Stats.AttackPower = Row.AttackPower;
	Stats.Defense = Row.Defense;
	// Gegner nutzen die allgemeinen Grundchancen, bis eigene Werte belegt sind.
	Stats.CritChance = T.BaseCritChance;
	Stats.CritMultiplier = T.CritMultiplier;
	Stats.BlockChance = T.BaseBlockChance;
	Stats.BlockReduction = T.BlockReduction;
	Stats.DodgeChance = T.BaseDodgeChance;
	return Stats;
}
