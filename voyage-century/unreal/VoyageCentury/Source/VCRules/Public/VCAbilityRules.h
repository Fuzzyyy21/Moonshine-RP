#pragma once

// Regeln für Fähigkeiten und Statuseffekte – ohne Unreal-Typen, eigenständig testbar.
// Fähigkeiten und Statuseffekte des Originals sind UNKNOWN; die Mechanik hier ist eine
// Designentscheidung (Priorität 6), die Zahlen kommen als Daten herein.

#include "VCCombatRules.h"

#include <cstdint>
#include <vector>

namespace vc::rules
{
	enum class ETargetMode : uint8_t
	{
		Enemy, // feindliches Ziel nötig
		Self   // wirkt auf den Anwender
	};

	struct FAbilityDef
	{
		int RequiredSkillLevel = 1;
		double StaminaCost = 0.0;
		double CooldownSeconds = 0.0;
		/** Vielfaches des Waffenschadens; 0 = kein Schaden. */
		double DamageMultiplier = 0.0;
		/** Eigene Reichweite; 0 = Reichweite der Waffe. */
		double RangeCm = 0.0;
		ETargetMode TargetMode = ETargetMode::Enemy;
		/** Nur mit einer bestimmten Waffenart einsetzbar (z. B. Schwerthieb nur mit Schwert). */
		bool bRequiresWeaponClass = false;
		EWeaponClass RequiredWeaponClass = EWeaponClass::Unarmed;
	};

	/** Warum eine Fähigkeit nicht eingesetzt werden kann (None = erlaubt). Reihenfolge = Prüfreihenfolge. */
	enum class EAbilityBlock : uint8_t
	{
		None,
		Dead,
		Stunned,
		WrongWeapon,
		SkillTooLow,
		OnCooldown,
		NotEnoughStamina,
		NoTarget,
		TargetNotHostile,
		OutOfRange
	};

	struct FAbilityUseContext
	{
		bool bAlive = true;
		bool bStunned = false;
		EWeaponClass EquippedWeaponClass = EWeaponClass::Unarmed;
		/** Stufe des Skills, zu dem die Fähigkeit gehört. */
		int SkillLevel = 1;
		double Stamina = 0.0;
		/** < 0: noch nie eingesetzt. */
		double LastUseTime = -1.0;
		double Now = 0.0;
		bool bHasTarget = false;
		bool bTargetAlive = false;
		bool bTargetHostile = false;
		double DistanceCm = 0.0;
		double WeaponRangeCm = 0.0;
	};

	VCRULES_API double EffectiveRange(const FAbilityDef& Ability, double WeaponRangeCm);
	VCRULES_API EAbilityBlock CheckAbilityUse(const FAbilityDef& Ability, const FAbilityUseContext& Context, const FCombatTuning& Tuning);

	/** Veränderungen der Kampfwerte durch aktive Statuseffekte. */
	struct FStatModifiers
	{
		double AttackPower = 0.0;
		double Defense = 0.0;
		double CritChance = 0.0;
		double BlockChance = 0.0;
		double DodgeChance = 0.0;
		/** Multiplikativ über alle Effekte und Stapel. */
		double MoveSpeedMultiplier = 1.0;
		bool bStunned = false;
	};

	struct FStatusDef
	{
		double DurationSeconds = 0.0;
		int MaxStacks = 1;
		/** Wirkung je Stapel (additiv; MoveSpeedMultiplier wird je Stapel multipliziert). */
		FStatModifiers PerStack;
		/** 0 = keine periodische Wirkung. */
		double TickIntervalSeconds = 0.0;
		/** Je Tick und Stapel. */
		double DamagePerTick = 0.0;
		double HealPerTick = 0.0;
	};

	struct FActiveStatus
	{
		int DefIndex = -1;
		int Stacks = 0;
		double ExpiresAt = 0.0;
		double NextTickAt = 0.0;
	};

	/** Neu anwenden oder auffrischen: Dauer beginnt neu, Stapel steigen bis MaxStacks, Tick-Rhythmus bleibt. */
	VCRULES_API void ApplyStatus(std::vector<FActiveStatus>& Active, int DefIndex, const FStatusDef& Def, double Now);

	/** Entfernt abgelaufene Effekte. Gibt zurück, ob sich etwas geändert hat. */
	VCRULES_API bool RemoveExpired(std::vector<FActiveStatus>& Active, double Now);

	/** Summe aller aktiven Effekte. Defs wird über FActiveStatus::DefIndex adressiert. */
	VCRULES_API FStatModifiers Aggregate(const std::vector<FActiveStatus>& Active, const std::vector<FStatusDef>& Defs);

	struct FTickResult
	{
		double Damage = 0.0;
		double Heal = 0.0;
	};

	/** Fällige Ticks eines einzelnen Effekts (z. B. um Schaden dem Verursacher zuzuordnen). */
	VCRULES_API FTickResult CollectStatusTicks(FActiveStatus& Status, const FStatusDef& Def, double Now);

	/** Alle fälligen Ticks bis Now (höchstens bis zum Ablauf des Effekts) einsammeln und weiterschalten. */
	VCRULES_API FTickResult CollectTicks(std::vector<FActiveStatus>& Active, const std::vector<FStatusDef>& Defs, double Now);

	/** Kampfwerte mit Statusmodifikatoren. Chancen bleiben in [0, 1], Angriff/Verteidigung ≥ 0. */
	VCRULES_API FCombatStats WithModifiers(const FCombatStats& Base, const FStatModifiers& Mods);

	/** Faktor für die Laufgeschwindigkeit: 0 bei Betäubung, sonst Multiplikator (≥ 0). */
	VCRULES_API double MoveSpeedFactor(const FStatModifiers& Mods);
}
