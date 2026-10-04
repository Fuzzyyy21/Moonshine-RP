#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "VCAbilityRules.h"
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

	UPROPERTY(config, EditAnywhere, Category = "Daten", meta = (RequiredAssetDataTags = "RowStructure=/Script/VCData.VCAbilityRow"))
	TSoftObjectPtr<UDataTable> AbilitiesTable;

	UPROPERTY(config, EditAnywhere, Category = "Daten", meta = (RequiredAssetDataTags = "RowStructure=/Script/VCData.VCStatusEffectRow"))
	TSoftObjectPtr<UDataTable> StatusEffectsTable;

	/** Waffe ohne Ausrüstung. */
	UPROPERTY(config, EditAnywhere, Category = "Daten")
	FName UnarmedWeapon = TEXT("DEV_UNARMED");
};

/**
 * Zugriff auf die Kampfdaten. Tabellen werden beim ersten Zugriff geladen und bleiben geladen.
 * Fehlen Tabellen oder sind die Parameter ungültig, ist Kampf deaktiviert (IsAvailable() == false) –
 * es wird nie mit Ersatzwerten gekämpft. Fähigkeiten brauchen zusätzlich DT_Abilities und
 * DT_StatusEffects (AreAbilitiesAvailable()); ohne sie gibt es nur den Grundangriff.
 */
class VCABILITIES_API FVCCombatData
{
public:
	static bool IsAvailable();
	static bool AreAbilitiesAvailable();
	static const vc::rules::FCombatTuning& Tuning();
	static const FVCCombatTuningRow* TuningRow();
	static const FVCWeaponRow* FindWeapon(FName Code);
	static const FVCMonsterRow* FindMonster(FName Code);
	static const FVCAbilityRow* FindAbility(FName Code);
	static const FVCStatusEffectRow* FindStatus(FName Code);

	/** Alle Fähigkeiten, nach Code sortiert (für Anzeige und Konsolenbefehle). */
	static TArray<FName> AbilityCodes();

	/** Statuseffekte als Regeldaten; FActiveStatus::DefIndex zeigt in dieses Feld. */
	static const std::vector<vc::rules::FStatusDef>& StatusDefs();
	static int32 StatusIndex(FName Code);
	static FName StatusCode(int32 Index);

	static vc::rules::EWeaponClass ToRules(EVCWeaponClass Class);
	static vc::rules::FWeaponDef ToRules(const FVCWeaponRow& Row);
	static vc::rules::FAbilityDef ToRules(const FVCAbilityRow& Row);
	static vc::rules::FStatusDef ToRules(const FVCStatusEffectRow& Row);
	static vc::rules::FWeaponDef AttackOf(const FVCMonsterRow& Row);
	static vc::rules::FCombatStats StatsOf(const FVCMonsterRow& Row);
};
