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
