#pragma once

// Segelregeln – ohne Unreal-Typen, eigenständig testbar.
// Segelmodell, Windverhalten und alle Schiffswerte des Originals sind UNKNOWN. Belegt ist nur, dass mehr Matrosen
// schneller machen und mehr Proviant verbrauchen (SAILOR-SYSTEM). Die Mechanik ist eine Designentscheidung
// (Priorität 6), die Zahlen kommen als Daten herein.
//
// Winkel in Grad wie Unreal-Yaw (0 = +X, 90 = +Y). Windrichtung = Richtung, in die der Wind weht.

#include "VCCombatRules.h"

#include <cstdint>
#include <vector>

namespace vc::rules
{
	/** Wind einer Zone: pendelt langsam um eine Grundrichtung. Deterministisch, damit Server und Client ihn gleich berechnen. */
	struct FWindParams
	{
		double BaseDirectionDeg = 0.0;
		/** 1 = Bezugsstärke (volle Wirkung der Segelpolare). */
		double BaseStrength = 1.0;
		double DirectionSwingDeg = 0.0;
		/** Anteil, um den die Stärke schwankt (0.2 = ±20 %). */
		double StrengthSwing = 0.0;
		double PeriodSeconds = 600.0;
	};

	struct FWind
	{
		double DirectionDeg = 0.0;
		double Strength = 0.0;
	};

	struct FPolarPoint
	{
		/** Winkel zwischen Kurs und Windrichtung: 0 = Wind genau von achtern, 180 = genau von vorn. */
		double AngleDeg = 0.0;
		double Efficiency = 0.0;
	};

	struct FShipDef
	{
		/** cm/s bei vollen Segeln, idealem Wind und voller Besatzung. */
		double MaxSpeed = 0.0;
		/** cm/s² beim Beschleunigen bzw. Abbremsen. */
		double Acceleration = 0.0;
		double Deceleration = 0.0;
		/** Grad/s bei voller Fahrt und vollem Ruder. */
		double TurnRateDeg = 0.0;
		int CrewMin = 0;
		int CrewMax = 0;
		/** 0 = Wind egal (z. B. Ruder), 1 = Geschwindigkeit hängt ganz vom Wind ab. */
		double WindEfficiency = 1.0;
	};

	struct FSailTuning
	{
		/** Nach Winkel sortiert. Dazwischen wird linear interpoliert. */
		std::vector<FPolarPoint> Polar;
		/** Faktor bei Mindestbesatzung; volle Besatzung = 1. */
		double CrewMinFactor = 0.5;
		/** Lenkwirkung im Stand (Anteil der vollen Wendigkeit). */
		double MinSteerageFactor = 0.2;
		double ProvisionsPerSailorPerMinute = 0.0;
		/** Geschwindigkeitsfaktor ohne Proviant (Wirkung im Original UNKNOWN, SYS-PROVISIONS). */
		double NoProvisionsFactor = 0.5;
	};

	struct FHelm
	{
		/** 0 = Segel eingeholt, 1 = volle Segel. */
		double SailLevel = 0.0;
		/** -1 = hart backbord, 1 = hart steuerbord. */
		double Rudder = 0.0;
	};

	struct FShipMotion
	{
		double Speed = 0.0;
		double HeadingDeg = 0.0;
	};

	VCRULES_API double NormalizeDeg(double Deg);
	VCRULES_API FWind WindAt(const FWindParams& Params, double TimeSeconds);
	/** 0 … 180: 0 = Wind von achtern, 180 = Wind von vorn. */
	VCRULES_API double AngleOffWindDeg(double HeadingDeg, double WindDirectionDeg);
	VCRULES_API double PolarEfficiency(const std::vector<FPolarPoint>& Polar, double AngleDeg);
	/** 0 unter Mindestbesatzung; sonst von CrewMinFactor bis 1 bei voller Besatzung. */
	VCRULES_API double CrewFactor(int Crew, const FShipDef& Ship, const FSailTuning& Tuning);
	VCRULES_API double TargetSpeed(const FShipDef& Ship, const FSailTuning& Tuning, double SailLevel, double HeadingDeg,
		const FWind& Wind, int Crew, bool bHasProvisions);
	VCRULES_API FShipMotion StepShip(const FShipMotion& Motion, const FHelm& Helm, double TargetSpeedValue,
		const FShipDef& Ship, const FSailTuning& Tuning, double DeltaSeconds);

	/** Proviant mit Bruchteil-Übertrag, damit kurze Ticks nichts verschlucken. Nie unter 0. */
	struct FProvisions
	{
		int Amount = 0;
		double Carry = 0.0;
	};
	VCRULES_API FProvisions ConsumeProvisions(const FProvisions& State, int Crew, double Seconds, const FSailTuning& Tuning);

	/** Prüft Polare (sortiert, Werte in [0, 1]) und Faktoren. */
	VCRULES_API bool IsValidSailTuning(const FSailTuning& Tuning);
}
