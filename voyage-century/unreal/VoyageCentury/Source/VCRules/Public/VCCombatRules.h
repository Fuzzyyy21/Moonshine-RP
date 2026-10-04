#pragma once

// Kampfregeln von Voyage Century – ohne Unreal-Typen, damit sie eigenständig testbar sind.
//
// Alle Zahlen kommen als Daten herein (FCombatTuning, FWeaponDef). Die Formeln selbst sind eine
// Designentscheidung (Quellen-Priorität 6): Das Kampfsystem des Originals ist UNKNOWN.
// Zufall wird von außen übergeben (FAttackRolls), damit Ergebnisse reproduzierbar sind.

#include <cstdint>

#ifndef VCRULES_API
#define VCRULES_API
#endif

namespace vc::rules
{
	/** Waffenarten laut den Kampfskills des Originals (Schwert, Klinge, Axt, Schusswaffe, unbewaffnet). */
	enum class EWeaponClass : uint8_t
	{
		Sword,
		Blade,
		Axe,
		Firearm,
		Unarmed
	};

	/** Abgeleitete Kampfwerte. Wahrscheinlichkeiten und Anteile liegen zwischen 0 und 1. */
	struct FCombatStats
	{
		double MaxHealth = 0.0;
		double MaxStamina = 0.0;
		double AttackPower = 0.0;
		double Defense = 0.0;
		double CritChance = 0.0;
		double CritMultiplier = 1.0;
		double BlockChance = 0.0;
		double BlockReduction = 0.0;
		double DodgeChance = 0.0;
	};

	struct FWeaponDef
	{
		EWeaponClass Class = EWeaponClass::Unarmed;
		double BaseDamage = 0.0;
		/** Sekunden zwischen zwei Angriffen. */
		double AttackInterval = 1.0;
		double RangeCm = 150.0;
	};

	/** Parameter der Formeln. Herkunft je Feld siehe design_data/dev_combat.json. */
	struct FCombatTuning
	{
		double BaseHealth = 0.0;
		double HealthPerLevel = 0.0;
		double BaseStamina = 0.0;
		double StaminaPerLevel = 0.0;
		double AttackPerLevel = 0.0;
		double DefensePerLevel = 0.0;
		/** Schadensbonus je Waffenskillstufe über 1 (0.01 = +1 % je Stufe). */
		double SkillDamageBonusPerLevel = 0.0;
		/** Schadensminderung = Verteidigung / (Verteidigung + DefenseConstant). */
		double DefenseConstant = 100.0;
		double MinDamage = 1.0;
		/** Streuung des Rohschadens, ± Anteil. */
		double DamageVariance = 0.0;
		double BaseCritChance = 0.0;
		double CritMultiplier = 1.0;
		double BaseBlockChance = 0.0;
		double BlockReduction = 0.0;
		double BaseDodgeChance = 0.0;
		double MaxCritChance = 1.0;
		double MaxBlockChance = 1.0;
		double MaxDodgeChance = 1.0;
		/** Zusätzliche Reichweite für Netzwerklatenz. */
		double RangeToleranceCm = 0.0;
		/** Erlaubtes Unterschreiten des Angriffsintervalls als Anteil (0.1 = 10 %). */
		double IntervalTolerance = 0.0;
	};

	/** Zufallswerte je Angriff, jeweils im Bereich [0, 1). */
	struct FAttackRolls
	{
		double Dodge = 1.0;
		double Block = 1.0;
		double Crit = 1.0;
		double Variance = 0.5;
	};

	enum class EHitResult : uint8_t
	{
		Dodged,
		Blocked,
		Hit,
		Critical
	};

	struct FAttackOutcome
	{
		EHitResult Result = EHitResult::Hit;
		double Damage = 0.0;
	};

	/** Prüft, ob die Parameter in sich stimmig sind (keine negativen Werte, Chancen ≤ 1, Konstante > 0). */
	VCRULES_API bool IsValidTuning(const FCombatTuning& Tuning);

	/** Kampfwerte eines Spielercharakters aus Stufe und Parametern. Stufen < 1 gelten als 1. */
	VCRULES_API FCombatStats DeriveCharacterStats(int Level, const FCombatTuning& Tuning);

	/** Waffenschaden inklusive Skillbonus. Skillstufen < 1 gelten als 1. */
	VCRULES_API double WeaponDamage(const FWeaponDef& Weapon, int WeaponSkillLevel, const FCombatTuning& Tuning);

	/**
	 * Ein Angriff: erst Ausweichen, dann Blocken, dann kritischer Treffer.
	 * Ein geblockter Treffer kann nicht kritisch sein. Ausgewichen = 0 Schaden,
	 * sonst mindestens MinDamage. Schaden wird auf ganze Punkte gerundet.
	 */
	VCRULES_API FAttackOutcome ResolveAttack(const FCombatStats& Attacker, const FCombatStats& Defender,
		double WeaponDamageValue, const FAttackRolls& Rolls, const FCombatTuning& Tuning);

	/** Serverprüfung: Ziel in Waffenreichweite (inklusive Latenztoleranz)? */
	VCRULES_API bool IsInRange(double DistanceCm, const FWeaponDef& Weapon, const FCombatTuning& Tuning);

	/** Serverprüfung: Angriffsintervall abgelaufen? LastAttackTime < 0 bedeutet "noch nie angegriffen". */
	VCRULES_API bool IsAttackReady(double LastAttackTime, double Now, const FWeaponDef& Weapon, const FCombatTuning& Tuning);

	/** Begrenzt Lebenspunkte auf [0, MaxHealth]. */
	VCRULES_API double ClampHealth(double Health, double MaxHealth);
}
