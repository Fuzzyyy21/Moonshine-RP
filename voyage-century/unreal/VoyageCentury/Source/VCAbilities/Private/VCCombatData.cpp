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

	vc::rules::EWeaponClass ToRulesClass(EVCWeaponClass Class)
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

	struct FCache
	{
		bool bLoaded = false;
		UDataTable* Tuning = nullptr;
		UDataTable* Weapons = nullptr;
		UDataTable* Monsters = nullptr;
		vc::rules::FCombatTuning Rules;
		bool bValid = false;
	};

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
		}
		return Instance;
	}
}

bool FVCCombatData::IsAvailable()
{
	return Cache().bValid;
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

vc::rules::FWeaponDef FVCCombatData::ToRules(const FVCWeaponRow& Row)
{
	vc::rules::FWeaponDef Def;
	Def.Class = ToRulesClass(Row.WeaponClass);
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
