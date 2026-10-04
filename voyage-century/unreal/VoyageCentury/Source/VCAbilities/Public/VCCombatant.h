#pragma once

#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "VCCombatRules.h"
#include "VCCombatant.generated.h"

UINTERFACE(MinimalAPI)
class UVCCombatant : public UInterface
{
	GENERATED_BODY()
};

/** Alles, was kämpfen kann: Spielfiguren und Gegner. */
class VCABILITIES_API IVCCombatant
{
	GENERATED_BODY()

public:
	virtual bool IsAlive() const = 0;

	/** Spieler (true) oder Gegner (false). Bestimmt, wer wen angreifen darf. */
	virtual bool IsPlayerCharacter() const = 0;

	/** Aktuelle Angriffswerte. SkillCode leer = kein Skill-XP (z. B. Gegner). */
	virtual bool GetAttack(vc::rules::FWeaponDef& OutWeapon, FName& OutSkillCode, int32& OutSkillLevel) const = 0;

	/** Stufe eines Skills (DT_Skills); Kämpfer ohne Skills haben überall Stufe 1. */
	virtual int32 GetSkillLevel(FName SkillCode) const { return 1; }

	/** Code aus DT_Monsters; None für Spieler. */
	virtual FName GetMonsterCode() const { return NAME_None; }

	/** Anzeigename für Zielrahmen und Kampftexte. */
	virtual FText GetCombatName() const = 0;

	/** Nur Server: Lebenspunkte auf 0 gefallen. Killer ist die verursachende Spielfigur (kann null sein). */
	virtual void HandleOutOfHealth(AActor* Killer) = 0;
};
