#pragma once

#include "CoreMinimal.h"
#include "VCCombatRules.h"

class AActor;

/**
 * Kampfablauf auf dem Server – eine Stelle für Grundangriff, Fähigkeiten und Statuseffekte.
 * Formeln kommen aus VCRules (eigenständig getestet), Zufall nur hier, Clients rechnen nie.
 */
class VCABILITIES_API FVCCombat
{
public:
	/** Darf Attacker den Verteidiger angreifen? Spieler ↔ Gegner immer, Spieler ↔ Spieler nur in PvP-Zonen. */
	static bool IsHostile(const AActor* Attacker, const AActor* Defender);

	/** Betäubt (Statuseffekt)? Gilt auf Server und Client (repliziert). */
	static bool IsStunned(const AActor* Actor);

	/** Kampfwerte aus den aktuellen Attributen, inklusive Statusmodifikatoren (nur Server vollständig). */
	static vc::rules::FCombatStats CurrentStats(const AActor* Actor);

	/** Angriff würfeln und Schaden anwenden. Rückgabe: Ergebnis (Ausgewichen = kein Schaden). */
	static vc::rules::FAttackOutcome Strike(AActor* Attacker, AActor* Target, double WeaponDamageValue);

	/** Schaden ohne Würfeln (z. B. Blutung). Causer bekommt den Kill (kann null sein). */
	static void ApplyDamage(AActor* Target, double Amount, AActor* Causer, bool bPeriodic);

	/** Heilen bis zum Maximum. */
	static void ApplyHeal(AActor* Target, double Amount);

	/** Ausdauer abziehen; false, wenn nicht genug da ist (dann ändert sich nichts). */
	static bool SpendStamina(AActor* Actor, double Amount);
};
