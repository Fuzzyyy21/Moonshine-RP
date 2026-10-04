#pragma once

// Seekampf-Regeln – ohne Unreal-Typen, eigenständig testbar.
// Belegt: Kanonen für Nah- und Fernkampf (SHIP-SPECIAL-ABILITIES), Matrosen gesund/verletzt/tot (SAILOR-SYSTEM).
// Schadensmodell, Reichweiten und Nachladezeiten des Originals sind UNKNOWN; Mechanik = Designentscheidung (Priorität 6),
// Zahlen kommen als Daten herein. Zufall wird übergeben (reproduzierbar).

#include "VCCombatRules.h"

#include <cstdint>
#include <vector>

namespace vc::rules
{
	enum class EBroadside : uint8_t
	{
		None,
		Port,      // backbord (links)
		Starboard  // steuerbord (rechts)
	};

	struct FCannonDef
	{
		double RangeCm = 0.0;
		/** Rumpfschaden je Treffer. */
		double DamagePerHit = 0.0;
		/** Matrosenverluste je Treffer (Erwartungswert, wird gerundet). */
		double CrewHitsPerHit = 0.0;
		double ReloadSeconds = 0.0;
		/** Trefferchance auf kürzeste und auf größte Entfernung (linear dazwischen). */
		double HitChanceNear = 0.0;
		double HitChanceFar = 0.0;
	};

	struct FBroadsideTuning
	{
		/** Halber Öffnungswinkel um die Querachse, in dem eine Breitseite trifft (z. B. 45 = 45°–135° vom Bug). */
		double ArcHalfWidthDeg = 45.0;
		/** Anteil der Verluste, die tot statt verletzt sind. */
		double DeathShare = 0.3;
	};

	/** Auf welcher Seite liegt das Ziel (Ebene, Unreal-Yaw)? None, wenn außerhalb beider Feuerwinkel. */
	VCRULES_API EBroadside SideFacing(double ShipHeadingDeg, double ShipX, double ShipY, double TargetX, double TargetY,
		const FBroadsideTuning& Tuning);

	VCRULES_API double HitChance(const FCannonDef& Cannon, double DistanceCm);

	struct FBroadsideResult
	{
		int Hits = 0;
		double HullDamage = 0.0;
		int CrewLosses = 0;
	};

	/** Eine Breitseite: je Kanone ein Wurf in Rolls (0 … 1). Außer Reichweite: nichts. */
	VCRULES_API FBroadsideResult ResolveBroadside(int Cannons, const FCannonDef& Cannon, double DistanceCm, const std::vector<double>& Rolls);

	/** Kanonen je Seite: die Hälfte der Plätze (ungerade: abgerundet). */
	VCRULES_API int CannonsPerSide(int CannonSlots);

	struct FCrew
	{
		int Healthy = 0;
		int Injured = 0;
		int Dead = 0;
	};

	/** Verluste treffen erst Gesunde; DeathShare davon sterben, der Rest wird verletzt. Verletzte segeln nicht mit. */
	VCRULES_API FCrew ApplyCrewLosses(const FCrew& Crew, int Losses, const FBroadsideTuning& Tuning);

	/** Rumpf nach Schaden, nie unter 0. Bei 0 sinkt das Schiff. */
	VCRULES_API double ApplyHullDamage(double Hull, double Damage);

	VCRULES_API bool IsReloaded(double LastFireTime, double Now, const FCannonDef& Cannon, const FCombatTuning& Tuning);
}
