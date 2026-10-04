// Tests der Fähigkeits- und Statusregeln (VCAbilityRules).
#include "TestHarness.h"
#include "VCAbilityRules.h"

using namespace vc::rules;
using vctest::Tuning;

namespace
{
	FAbilityDef Strike()
	{
		FAbilityDef A;
		A.RequiredSkillLevel = 5;
		A.StaminaCost = 10.0;
		A.CooldownSeconds = 6.0;
		A.DamageMultiplier = 1.5;
		A.bRequiresWeaponClass = true;
		A.RequiredWeaponClass = EWeaponClass::Sword;
		return A;
	}

	/** Alles erfüllt: lebendig, Schwert in der Hand, Skill hoch genug, Ausdauer da, feindliches Ziel in Reichweite. */
	FAbilityUseContext Ready()
	{
		FAbilityUseContext C;
		C.EquippedWeaponClass = EWeaponClass::Sword;
		C.SkillLevel = 10;
		C.Stamina = 50.0;
		C.Now = 100.0;
		C.bHasTarget = true;
		C.bTargetAlive = true;
		C.bTargetHostile = true;
		C.DistanceCm = 150.0;
		C.WeaponRangeCm = 200.0;
		return C;
	}

	FStatusDef Slow()
	{
		FStatusDef D;
		D.DurationSeconds = 4.0;
		D.PerStack.MoveSpeedMultiplier = 0.5;
		return D;
	}

	FStatusDef ArmorBreak()
	{
		FStatusDef D;
		D.DurationSeconds = 8.0;
		D.MaxStacks = 3;
		D.PerStack.Defense = -5.0;
		return D;
	}

	FStatusDef Bleed()
	{
		FStatusDef D;
		D.DurationSeconds = 5.0;
		D.MaxStacks = 2;
		D.TickIntervalSeconds = 1.0;
		D.DamagePerTick = 3.0;
		return D;
	}

	FStatusDef Stun()
	{
		FStatusDef D;
		D.DurationSeconds = 2.0;
		D.PerStack.bStunned = true;
		return D;
	}
}

const std::vector<vctest::FCase>& vctest::AbilityRulesCases()
{
	static const std::vector<FCase> Cases = {
		{ "Fähigkeit erlaubt, wenn alles erfüllt ist", []
		{
			CHECK(CheckAbilityUse(Strike(), Ready(), Tuning()) == EAbilityBlock::None);
		} },
		{ "Prüfreihenfolge: der erste Grund gewinnt", []
		{
			FAbilityUseContext C = Ready();
			C.bAlive = false;
			C.bStunned = true;
			C.EquippedWeaponClass = EWeaponClass::Axe;
			C.SkillLevel = 1;
			C.Stamina = 0.0;
			C.bHasTarget = false;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::Dead);
			C.bAlive = true;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::Stunned);
			C.bStunned = false;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::WrongWeapon);
			C.EquippedWeaponClass = EWeaponClass::Sword;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::SkillTooLow);
			C.SkillLevel = 5;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::NotEnoughStamina);
			C.Stamina = 10.0;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::NoTarget);
		} },
		{ "Abklingzeit mit Toleranz", []
		{
			FAbilityUseContext C = Ready();
			C.LastUseTime = 100.0;
			C.Now = 101.0;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::OnCooldown);
			C.Now = 105.39;  // 6 s, 10 % Toleranz: frei ab 5,4 s
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::OnCooldown);
			C.Now = 105.4;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::None);
			C.LastUseTime = -1.0;
			C.Now = 0.0;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::None);
		} },
		{ "Ziel muss leben und feindlich sein", []
		{
			FAbilityUseContext C = Ready();
			C.bTargetAlive = false;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::NoTarget);
			C.bTargetAlive = true;
			C.bTargetHostile = false;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::TargetNotHostile);
		} },
		{ "Reichweite: Waffe oder eigene, plus Toleranz", []
		{
			FAbilityUseContext C = Ready();
			C.DistanceCm = 250.0;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::None);
			C.DistanceCm = 251.0;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::OutOfRange);
			C.DistanceCm = -1.0;
			CHECK(CheckAbilityUse(Strike(), C, Tuning()) == EAbilityBlock::OutOfRange);

			FAbilityDef Shot = Strike();
			Shot.RangeCm = 1500.0;
			CHECK_NEAR(EffectiveRange(Shot, 200.0), 1500.0);
			CHECK_NEAR(EffectiveRange(Strike(), 200.0), 200.0);
			C.DistanceCm = 1540.0;
			CHECK(CheckAbilityUse(Shot, C, Tuning()) == EAbilityBlock::None);
		} },
		{ "Selbstziel braucht kein Ziel", []
		{
			FAbilityDef Heal = Strike();
			Heal.TargetMode = ETargetMode::Self;
			Heal.bRequiresWeaponClass = false;
			FAbilityUseContext C = Ready();
			C.bHasTarget = false;
			C.EquippedWeaponClass = EWeaponClass::Firearm;
			C.DistanceCm = 99999.0;
			CHECK(CheckAbilityUse(Heal, C, Tuning()) == EAbilityBlock::None);
			C.Stamina = 0.0;
			CHECK(CheckAbilityUse(Heal, C, Tuning()) == EAbilityBlock::NotEnoughStamina);
		} },
		{ "Status: neu, auffrischen, stapeln bis zur Grenze", []
		{
			std::vector<FActiveStatus> Active;
			ApplyStatus(Active, 1, ArmorBreak(), 10.0);
			CHECK(Active.size() == 1);
			CHECK(Active[0].Stacks == 1);
			CHECK_NEAR(Active[0].ExpiresAt, 18.0);
			ApplyStatus(Active, 1, ArmorBreak(), 12.0);
			ApplyStatus(Active, 1, ArmorBreak(), 13.0);
			ApplyStatus(Active, 1, ArmorBreak(), 14.0);
			CHECK(Active.size() == 1);
			CHECK(Active[0].Stacks == 3);
			CHECK_NEAR(Active[0].ExpiresAt, 22.0);
			ApplyStatus(Active, 0, Slow(), 14.0);
			CHECK(Active.size() == 2);
		} },
		{ "Status läuft ab", []
		{
			std::vector<FActiveStatus> Active;
			ApplyStatus(Active, 0, Slow(), 0.0);
			ApplyStatus(Active, 1, ArmorBreak(), 0.0);
			CHECK(!RemoveExpired(Active, 3.9));
			CHECK(RemoveExpired(Active, 4.0));
			CHECK(Active.size() == 1);
			CHECK(Active[0].DefIndex == 1);
			CHECK(RemoveExpired(Active, 8.0));
			CHECK(Active.empty());
		} },
		{ "Modifikatoren: additiv je Stapel, Tempo multiplikativ, Betäubung", []
		{
			const std::vector<FStatusDef> Defs = { Slow(), ArmorBreak(), Bleed(), Stun() };
			std::vector<FActiveStatus> Active;
			CHECK_NEAR(Aggregate(Active, Defs).MoveSpeedMultiplier, 1.0);
			ApplyStatus(Active, 1, Defs[1], 0.0);
			ApplyStatus(Active, 1, Defs[1], 0.0);
			ApplyStatus(Active, 0, Defs[0], 0.0);
			FStatModifiers M = Aggregate(Active, Defs);
			CHECK_NEAR(M.Defense, -10.0);
			CHECK_NEAR(M.MoveSpeedMultiplier, 0.5);
			CHECK(!M.bStunned);
			CHECK_NEAR(MoveSpeedFactor(M), 0.5);
			ApplyStatus(Active, 3, Defs[3], 0.0);
			M = Aggregate(Active, Defs);
			CHECK(M.bStunned);
			CHECK_NEAR(MoveSpeedFactor(M), 0.0);

			// Ungültiger Index wird ignoriert statt abzustürzen.
			Active.push_back(FActiveStatus{ 99, 1, 100.0, 100.0 });
			CHECK_NEAR(Aggregate(Active, Defs).Defense, -10.0);
		} },
		{ "Gestapelte Verlangsamung multipliziert sich", []
		{
			FStatusDef Def = Slow();
			Def.MaxStacks = 2;
			const std::vector<FStatusDef> Defs = { Def };
			std::vector<FActiveStatus> Active;
			ApplyStatus(Active, 0, Def, 0.0);
			ApplyStatus(Active, 0, Def, 0.0);
			CHECK_NEAR(Aggregate(Active, Defs).MoveSpeedMultiplier, 0.25);
		} },
		{ "Schaden über Zeit: Ticks bis zum Ablauf, je Stapel", []
		{
			const std::vector<FStatusDef> Defs = { Bleed() };
			std::vector<FActiveStatus> Active;
			ApplyStatus(Active, 0, Defs[0], 0.0);
			CHECK_NEAR(CollectTicks(Active, Defs, 0.5).Damage, 0.0);
			CHECK_NEAR(CollectTicks(Active, Defs, 1.0).Damage, 3.0);
			CHECK_NEAR(CollectTicks(Active, Defs, 1.5).Damage, 0.0);
			// Server hing: drei fällige Ticks auf einmal.
			CHECK_NEAR(CollectTicks(Active, Defs, 4.0).Damage, 9.0);
			// Zweiter Stapel frischt die Dauer auf (läuft bis 9 s) und verdoppelt jeden Tick.
			ApplyStatus(Active, 0, Defs[0], 4.0);
			CHECK_NEAR(CollectTicks(Active, Defs, 5.0).Damage, 6.0);
			// Nach dem Ablauf keine Ticks mehr, auch wenn lange nicht abgefragt wurde.
			CHECK_NEAR(CollectTicks(Active, Defs, 100.0).Damage, 24.0);
			CHECK_NEAR(CollectTicks(Active, Defs, 200.0).Damage, 0.0);
		} },
		{ "Ticks eines einzelnen Effekts", []
		{
			std::vector<FActiveStatus> Active;
			ApplyStatus(Active, 0, Bleed(), 0.0);
			ApplyStatus(Active, 0, Bleed(), 0.0);
			CHECK_NEAR(CollectStatusTicks(Active[0], Bleed(), 2.0).Damage, 12.0);
			CHECK_NEAR(CollectStatusTicks(Active[0], Bleed(), 2.0).Damage, 0.0);
			CHECK_NEAR(CollectStatusTicks(Active[0], Slow(), 9.0).Damage, 0.0);
		} },
		{ "Heilung über Zeit", []
		{
			FStatusDef Regen;
			Regen.DurationSeconds = 3.0;
			Regen.TickIntervalSeconds = 1.0;
			Regen.HealPerTick = 4.0;
			const std::vector<FStatusDef> Defs = { Regen };
			std::vector<FActiveStatus> Active;
			ApplyStatus(Active, 0, Regen, 0.0);
			const FTickResult R = CollectTicks(Active, Defs, 10.0);
			CHECK_NEAR(R.Heal, 12.0);
			CHECK_NEAR(R.Damage, 0.0);
		} },
		{ "Effekte ohne Intervall ticken nie", []
		{
			const std::vector<FStatusDef> Defs = { Slow() };
			std::vector<FActiveStatus> Active;
			ApplyStatus(Active, 0, Defs[0], 0.0);
			const FTickResult R = CollectTicks(Active, Defs, 3.0);
			CHECK_NEAR(R.Damage, 0.0);
			CHECK_NEAR(R.Heal, 0.0);
		} },
		{ "Kampfwerte mit Modifikatoren bleiben gültig", []
		{
			const FCombatStats Base = DeriveCharacterStats(1, Tuning());
			FStatModifiers M;
			M.Defense = -1000.0;
			M.AttackPower = 5.0;
			M.DodgeChance = 2.0;
			M.CritChance = -1.0;
			const FCombatStats S = WithModifiers(Base, M);
			CHECK_NEAR(S.Defense, 0.0);
			CHECK_NEAR(S.AttackPower, Base.AttackPower + 5.0);
			CHECK_NEAR(S.DodgeChance, 1.0);
			CHECK_NEAR(S.CritChance, 0.0);
			CHECK_NEAR(S.MaxHealth, Base.MaxHealth);
			CHECK_NEAR(MoveSpeedFactor(FStatModifiers{}), 1.0);
		} },
		{ "Rüstungsbruch erhöht den Schaden", []
		{
			const FCombatStats A = DeriveCharacterStats(10, Tuning());
			const FCombatStats D = DeriveCharacterStats(10, Tuning());
			std::vector<FActiveStatus> Active;
			const std::vector<FStatusDef> Defs = { ArmorBreak() };
			ApplyStatus(Active, 0, Defs[0], 0.0);
			const FCombatStats Broken = WithModifiers(D, Aggregate(Active, Defs));
			const double Normal = ResolveAttack(A, D, 100.0, vctest::NoLuck(), Tuning()).Damage;
			const double More = ResolveAttack(A, Broken, 100.0, vctest::NoLuck(), Tuning()).Damage;
			CHECK(More > Normal);
		} },
	};
	return Cases;
}
