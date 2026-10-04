// Tests der Kampfregeln (VCCombatRules).
#include "TestHarness.h"

using namespace vc::rules;
using vctest::NoLuck;
using vctest::Tuning;

const std::vector<vctest::FCase>& vctest::CombatRulesCases()
{
	static const std::vector<FCase> Cases = {
		{ "Tuning wird geprüft", []
		{
			CHECK(IsValidTuning(Tuning()));
			FCombatTuning Bad = Tuning();
			Bad.MaxDodgeChance = 1.5;
			CHECK(!IsValidTuning(Bad));
			Bad = Tuning();
			Bad.DefenseConstant = 0.0;
			CHECK(!IsValidTuning(Bad));
			Bad = Tuning();
			Bad.HealthPerLevel = -1.0;
			CHECK(!IsValidTuning(Bad));
			Bad = Tuning();
			Bad.CritMultiplier = 0.9;
			CHECK(!IsValidTuning(Bad));
		} },
		{ "Stufe 1 hat Grundwerte, jede Stufe +10 HP", []
		{
			const FCombatStats L1 = DeriveCharacterStats(1, Tuning());
			CHECK_NEAR(L1.MaxHealth, 100.0);
			CHECK_NEAR(L1.AttackPower, 0.0);
			const FCombatStats L11 = DeriveCharacterStats(11, Tuning());
			CHECK_NEAR(L11.MaxHealth, 200.0);
			CHECK_NEAR(L11.MaxStamina, 100.0);
			CHECK_NEAR(L11.AttackPower, 20.0);
			CHECK_NEAR(L11.Defense, 10.0);
			CHECK_NEAR(DeriveCharacterStats(0, Tuning()).MaxHealth, 100.0); // Stufe < 1 gilt als 1
		} },
		{ "Waffenskill erhöht den Waffenschaden", []
		{
			FWeaponDef Sword{ EWeaponClass::Sword, 12.0, 1.2, 200.0 };
			CHECK_NEAR(WeaponDamage(Sword, 1, Tuning()), 12.0);
			CHECK_NEAR(WeaponDamage(Sword, 101, Tuning()), 24.0);
			CHECK_NEAR(WeaponDamage(Sword, -3, Tuning()), 12.0);
		} },
		{ "Normaler Treffer mit Verteidigung", []
		{
			FCombatStats A = DeriveCharacterStats(1, Tuning());
			FCombatStats D = DeriveCharacterStats(1, Tuning());
			D.Defense = 100.0; // halbiert den Schaden
			const FAttackOutcome O = ResolveAttack(A, D, 20.0, NoLuck(), Tuning());
			CHECK(O.Result == EHitResult::Hit);
			CHECK_NEAR(O.Damage, 10.0);
		} },
		{ "Streuung bewegt den Schaden um ±10 %", []
		{
			const FCombatStats S = DeriveCharacterStats(1, Tuning());
			FAttackRolls Low = NoLuck();
			Low.Variance = 0.0;
			FAttackRolls High = NoLuck();
			High.Variance = 1.0;
			CHECK_NEAR(ResolveAttack(S, S, 100.0, Low, Tuning()).Damage, 90.0);
			CHECK_NEAR(ResolveAttack(S, S, 100.0, High, Tuning()).Damage, 110.0);
		} },
		{ "Ausweichen verhindert jeden Schaden", []
		{
			const FCombatStats S = DeriveCharacterStats(1, Tuning());
			FAttackRolls Rolls = NoLuck();
			Rolls.Dodge = 0.01;
			const FAttackOutcome O = ResolveAttack(S, S, 100.0, Rolls, Tuning());
			CHECK(O.Result == EHitResult::Dodged);
			CHECK_NEAR(O.Damage, 0.0);
		} },
		{ "Ausweichchance ist gedeckelt", []
		{
			const FCombatStats A = DeriveCharacterStats(1, Tuning());
			FCombatStats D = A;
			D.DodgeChance = 0.95; // über dem Maximum von 0.4
			FAttackRolls Rolls = NoLuck();
			Rolls.Dodge = 0.5;
			CHECK(ResolveAttack(A, D, 10.0, Rolls, Tuning()).Result != EHitResult::Dodged);
		} },
		{ "Block halbiert und schließt Krit aus", []
		{
			const FCombatStats S = DeriveCharacterStats(1, Tuning());
			FAttackRolls Rolls = NoLuck();
			Rolls.Block = 0.01;
			Rolls.Crit = 0.01;
			const FAttackOutcome O = ResolveAttack(S, S, 100.0, Rolls, Tuning());
			CHECK(O.Result == EHitResult::Blocked);
			CHECK_NEAR(O.Damage, 50.0);
		} },
		{ "Kritischer Treffer multipliziert", []
		{
			const FCombatStats S = DeriveCharacterStats(1, Tuning());
			FAttackRolls Rolls = NoLuck();
			Rolls.Crit = 0.01;
			const FAttackOutcome O = ResolveAttack(S, S, 100.0, Rolls, Tuning());
			CHECK(O.Result == EHitResult::Critical);
			CHECK_NEAR(O.Damage, 150.0);
		} },
		{ "Mindestschaden auch gegen hohe Verteidigung", []
		{
			const FCombatStats A = DeriveCharacterStats(1, Tuning());
			FCombatStats D = A;
			D.Defense = 1e9;
			CHECK_NEAR(ResolveAttack(A, D, 5.0, NoLuck(), Tuning()).Damage, 1.0);
		} },
		{ "Negative Eingaben erzeugen keinen negativen Schaden", []
		{
			FCombatStats A = DeriveCharacterStats(1, Tuning());
			A.AttackPower = -500.0;
			FCombatStats D = A;
			D.Defense = -50.0;
			const FAttackOutcome O = ResolveAttack(A, D, 10.0, NoLuck(), Tuning());
			CHECK(O.Damage >= 1.0);
		} },
		{ "Reichweite mit Toleranz", []
		{
			FWeaponDef Sword{ EWeaponClass::Sword, 12.0, 1.2, 200.0 };
			CHECK(IsInRange(200.0, Sword, Tuning()));
			CHECK(IsInRange(249.0, Sword, Tuning()));
			CHECK(!IsInRange(251.0, Sword, Tuning()));
			CHECK(!IsInRange(-1.0, Sword, Tuning()));
		} },
		{ "Angriffsintervall mit Toleranz", []
		{
			FWeaponDef Axe{ EWeaponClass::Axe, 18.0, 2.0, 180.0 };
			CHECK(IsAttackReady(-1.0, 0.0, Axe, Tuning()));
			CHECK(!IsAttackReady(10.0, 11.0, Axe, Tuning()));
			CHECK(IsAttackReady(10.0, 11.8, Axe, Tuning()));  // 10 % Toleranz: ab 1,8 s
			CHECK(!IsAttackReady(10.0, 11.79, Axe, Tuning()));
		} },
		{ "Lebenspunkte bleiben im gültigen Bereich", []
		{
			CHECK_NEAR(ClampHealth(-5.0, 100.0), 0.0);
			CHECK_NEAR(ClampHealth(150.0, 100.0), 100.0);
			CHECK_NEAR(ClampHealth(42.0, 100.0), 42.0);
			CHECK_NEAR(ClampHealth(10.0, -1.0), 0.0);
		} },
	};
	return Cases;
}
