#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "VCCombatRules.h"
#include "VCDataRows.h"
#include "VCCombatData.generated.h"

class UDataTable;

/** Verweise auf die importierten Kampftabellen (Projekteinstellungen > Voyage Century Combat). */
UCLASS(config = Game, defaultconfig, meta = (DisplayName = "Voyage Century Combat"))
class VCABILITIES_API UVCCombatSettings : public UDeveloperSettings
{
	GENERATED_BODY()

public:
	UPROPERTY(config, EditAnywhere, Category = "Daten", meta = (RequiredAssetDataTags = "RowStructure=/Script/VCData.VCCombatTuningRow"))
	TSoftObjectPtr<UDataTable> TuningTable;

	UPROPERTY(config, EditAnywhere, Category = "Daten", meta = (RequiredAssetDataTags = "RowStructure=/Script/VCData.VCWeaponRow"))
	TSoftObjectPtr<UDataTable> WeaponsTable;

	UPROPERTY(config, EditAnywhere, Category = "Daten", meta = (RequiredAssetDataTags = "RowStructure=/Script/VCData.VCMonsterRow"))
	TSoftObjectPtr<UDataTable> MonstersTable;

	/** Waffe ohne Ausrüstung. */
	UPROPERTY(config, EditAnywhere, Category = "Daten")
	FName UnarmedWeapon = TEXT("DEV_UNARMED");
};

/**
 * Zugriff auf die Kampfdaten. Tabellen werden beim ersten Zugriff geladen und bleiben geladen.
 * Fehlen Tabellen oder sind die Parameter ungültig, ist Kampf deaktiviert (IsAvailable() == false) –
 * es wird nie mit Ersatzwerten gekämpft.
 */
class VCABILITIES_API FVCCombatData
{
public:
	static bool IsAvailable();
	static const vc::rules::FCombatTuning& Tuning();
	static const FVCCombatTuningRow* TuningRow();
	static const FVCWeaponRow* FindWeapon(FName Code);
	static const FVCMonsterRow* FindMonster(FName Code);

	static vc::rules::FWeaponDef ToRules(const FVCWeaponRow& Row);
	static vc::rules::FWeaponDef AttackOf(const FVCMonsterRow& Row);
	static vc::rules::FCombatStats StatsOf(const FVCMonsterRow& Row);
};
