#pragma once

#include "CoreMinimal.h"
#include "Engine/DataTable.h"
#include "VCDataRows.generated.h"

// Row-Structs für die Data Tables unter Content/Data/Generated.
// Die JSON-Quellen erzeugt tools/export_content.py aus der Reconstruction Database.
// Feldnamen müssen mit dem Export übereinstimmen; Änderungen immer an beiden Stellen.

/** Wie gut ein Wert durch Quellen belegt ist (siehe reconstruction_db/README.md). */
UENUM(BlueprintType)
enum class EVCConfidence : uint8
{
	Confirmed,
	Likely,
	Uncertain,
	Unknown
};

/** Originale Skill-Kategorie (战斗系 / 贸易系 / 采集系 / 生产系). */
UENUM(BlueprintType)
enum class EVCSkillCategory : uint8
{
	Unknown,
	Combat,
	Trade,
	Gathering,
	Production
};

/** UI-Gruppierung (Designentscheidung, nicht Original). */
UENUM(BlueprintType)
enum class EVCSkillUiGroup : uint8
{
	Combat,
	Seafaring,
	Profession
};

/** Gemeinsame Felder aller rekonstruierten Einträge. Leere Namen bedeuten UNKNOWN. */
USTRUCT(BlueprintType)
struct VCDATA_API FVCReconRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Recon")
	FString NameZh;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Recon")
	FString NameEn;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Recon")
	FString NameDe;

	/** ID des Datensatzes in reconstruction_db/. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Recon")
	FString ReconId;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Recon")
	EVCConfidence Confidence = EVCConfidence::Unknown;
};

USTRUCT(BlueprintType)
struct VCDATA_API FVCProfessionRow : public FVCReconRow
{
	GENERATED_BODY()
};

USTRUCT(BlueprintType)
struct VCDATA_API FVCSkillRow : public FVCReconRow
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Skill")
	EVCSkillCategory CategoryCn = EVCSkillCategory::Unknown;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Skill")
	EVCSkillUiGroup UiGroup = EVCSkillUiGroup::Combat;
};

USTRUCT(BlueprintType)
struct VCDATA_API FVCSkillStageRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Skill")
	int32 StageNo = 0;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Skill")
	int32 MaxLevel = 0;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Recon")
	FString ReconId;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Recon")
	EVCConfidence Confidence = EVCConfidence::Unknown;
};

USTRUCT(BlueprintType)
struct VCDATA_API FVCShipClassRow : public FVCReconRow
{
	GENERATED_BODY()

	/** Womit die Klasse aufsteigt (laut internationalem Wiki); leer = UNKNOWN. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Ship")
	FString LeveledBy;
};

/** Merkmal der Charaktererstellung (Designdaten, Anzahl Optionen = vorhandene Varianten). */
USTRUCT(BlueprintType)
struct VCDATA_API FVCAppearanceSlotRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Appearance")
	int32 OptionCount = 1;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Appearance")
	int32 SortOrder = 0;
};

/** Waffenarten laut den Kampfskills des Originals. */
UENUM(BlueprintType)
enum class EVCWeaponClass : uint8
{
	Sword,
	Blade,
	Axe,
	Firearm,
	Unarmed
};

/** Parameter der Kampfformeln (eine Zeile "Default"). Herkunft: design_data/dev_combat.json. */
USTRUCT(BlueprintType)
struct VCDATA_API FVCCombatTuningRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Leben") double BaseHealth = 0.0;
	/** Aus der Reconstruction Database (LVL-PER-LEVEL-BONUS, UNCERTAIN). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Leben") double HealthPerLevel = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Leben") double BaseStamina = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Leben") double StaminaPerLevel = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Angriff") double AttackPerLevel = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Angriff") double DefensePerLevel = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Angriff") double SkillDamageBonusPerLevel = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Angriff") double DefenseConstant = 100.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Angriff") double MinDamage = 1.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Angriff") double DamageVariance = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Chancen") double BaseCritChance = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Chancen") double CritMultiplier = 1.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Chancen") double BaseBlockChance = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Chancen") double BlockReduction = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Chancen") double BaseDodgeChance = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Chancen") double MaxCritChance = 1.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Chancen") double MaxBlockChance = 1.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Chancen") double MaxDodgeChance = 1.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Server") double RangeToleranceCm = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Server") double IntervalTolerance = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Server") double PlayerRespawnSeconds = 5.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Server") double SkillXpPerHit = 0.0;
	/** Welche Felder aus der Reconstruction Database stammen. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Recon") FString ReconSources;
};

USTRUCT(BlueprintType)
struct VCDATA_API FVCWeaponRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Waffe") FString NameDe;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Waffe") EVCWeaponClass WeaponClass = EVCWeaponClass::Unarmed;
	/** Skill, der beim Treffen XP erhält (DT_Skills). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Waffe") FName SkillCode;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Waffe") double BaseDamage = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Waffe") double AttackInterval = 1.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Waffe") double RangeCm = 150.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Waffe") int32 DurabilityMax = 0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Recon") bool bIsDev = false;
};

USTRUCT(BlueprintType)
struct VCDATA_API FVCMonsterRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Gegner") FString NameDe;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Gegner") bool bIsPirate = false;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Gegner") int32 Level = 1;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Werte") double MaxHealth = 1.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Werte") double AttackPower = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Werte") double Defense = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Angriff") double BaseDamage = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Angriff") double AttackInterval = 1.0;
	/** 0 = greift nicht an (z. B. Übungspuppe). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Angriff") double RangeCm = 0.0;
	/** 0 = reagiert nicht auf Spieler. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "KI") double AggroRadiusCm = 0.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "KI") double LeashRadiusCm = 0.0;
	/** Nur Anzeige: die verbindliche Belohnung legt das Backend fest. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Belohnung") int64 XpReward = 0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Spawn") double RespawnSeconds = 30.0;
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Recon") bool bIsDev = false;
};
