#pragma once

// Seekampf-Fähigkeiten: Rammen, Enterhaken, Entern, Minen – ohne Unreal-Typen, eigenständig testbar.
// Belegt sind nur die Fähigkeiten selbst (SHIP-SPECIAL-ABILITIES) und dass das Erkundungsschiff stark beim Entern ist
// (SHIPCLASS-RAIDER). Mechanik und Zahlen sind Designentscheidungen (Priorität 6), die Zahlen kommen als Daten herein.

#include "VCCombatRules.h"

#include <vector>

namespace vc::rules
{
	struct FRamTuning
	{
		/** Schaden je m/s Aufprallgeschwindigkeit und je 1000 Punkte Rumpf des Rammenden (schwere Schiffe rammen härter). */
		double DamagePerMps = 0.0;
		/** Anteil des Schadens, den der Rammende selbst nimmt. */
		double SelfDamageShare = 0.0;
		/** Ziel muss innerhalb dieses halben Winkels vor dem Bug liegen. */
		double FrontArcDeg = 30.0;
		/** Unter dieser Geschwindigkeit ist es nur ein Anstoßen. */
		double MinSpeedMps = 0.0;
	};

	struct FRamResult
	{
		bool bRammed = false;
		double TargetDamage = 0.0;
		double SelfDamage = 0.0;
	};

	/** Liegt das Ziel vor dem Bug (Ebene, Unreal-Yaw)? */
	VCRULES_API bool IsAhead(double HeadingDeg, double X, double Y, double TargetX, double TargetY, double HalfArcDeg);

	VCRULES_API FRamResult ResolveRam(double SpeedMps, double AttackerHullMax, bool bTargetAhead, const FRamTuning& Tuning);

	struct FGrappleTuning
	{
		double RangeCm = 0.0;
		/** Höchstgeschwindigkeit beider Schiffe, damit der Haken hält. */
		double MaxSpeedMps = 0.0;
		double DurationSeconds = 0.0;
		double CooldownSeconds = 0.0;
	};

	VCRULES_API bool CanGrapple(double DistanceCm, double OwnSpeedMps, double TargetSpeedMps, const FGrappleTuning& Tuning);

	struct FBoardingTuning
	{
		/** Verluste je Runde = Gegner × Stärke × LossFactor × Wurf(0,5 … 1,5). */
		double LossFactor = 0.0;
		/** Stärke des Erkundungsschiffs (belegt: stark beim Entern); andere Klassen 1. */
		double RaiderStrength = 1.0;
		double RoundSeconds = 0.0;
	};

	struct FBoardingRound
	{
		int AttackerLosses = 0;
		int DefenderLosses = 0;
	};

	/** Eine Kampfrunde an Deck. Beide Seiten verlieren gleichzeitig; nie mehr, als da sind. */
	VCRULES_API FBoardingRound ResolveBoardingRound(int Attackers, int Defenders, double AttackerStrength, double DefenderStrength,
		double AttackerRoll, double DefenderRoll, const FBoardingTuning& Tuning);

	enum class EBoardingOutcome : uint8_t
	{
		Ongoing,
		AttackerWins,  // Verteidiger ohne kampffähige Matrosen: Schiff genommen
		DefenderWins   // Angreifer ohne Matrosen: Entern abgewehrt
	};

	VCRULES_API EBoardingOutcome BoardingOutcome(int Attackers, int Defenders);

	struct FMineTuning
	{
		double Damage = 0.0;
		double CrewHits = 0.0;
		double TriggerRadiusCm = 0.0;
		double LifetimeSeconds = 0.0;
		double CooldownSeconds = 0.0;
		/** Wie weit hinter dem Heck die Mine liegt. */
		double DropDistanceCm = 0.0;
		/** Eigene Minen lösen erst nach dieser Zeit aus (sonst trifft man sich selbst beim Legen). */
		double ArmSeconds = 0.0;
	};

	struct FMine
	{
		double X = 0.0;
		double Y = 0.0;
		double PlacedAt = 0.0;
	};

	VCRULES_API bool MineTriggers(const FMine& Mine, double Now, double ShipX, double ShipY, const FMineTuning& Tuning);
	VCRULES_API bool MineExpired(const FMine& Mine, double Now, const FMineTuning& Tuning);
}
