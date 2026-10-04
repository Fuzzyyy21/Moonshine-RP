#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "VCAppearance.generated.h"

class UAnimInstance;
class USkeletalMesh;

/** Ein gewähltes Merkmal (z. B. hairColor = 3). */
USTRUCT(BlueprintType)
struct VOYAGECENTURY_API FVCAppearanceEntry
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "Appearance")
	FName Slot;

	UPROPERTY(BlueprintReadOnly, Category = "Appearance")
	int32 Index = 0;
};

/** Erscheinungsbild eines Charakters, wie es der GameData-Dienst gespeichert und geprüft hat. */
USTRUCT(BlueprintType)
struct VOYAGECENTURY_API FVCAppearance
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "Appearance")
	bool bFemale = false;

	UPROPERTY(BlueprintReadOnly, Category = "Appearance")
	TArray<FVCAppearanceEntry> Entries;

	int32 Get(FName Slot) const
	{
		const FVCAppearanceEntry* Found = Entries.FindByPredicate([Slot](const FVCAppearanceEntry& E) { return E.Slot == Slot; });
		return Found ? Found->Index : 0;
	}
};

/**
 * Darstellung des Erscheinungsbilds (Projekteinstellungen > Voyage Century Appearance).
 * Solange keine Modelle existieren, färbt und skaliert der Code die Platzhalterfigur.
 * Sobald ein Charaktermodell vorliegt, CharacterMesh und AnimClass setzen – der Platzhalter
 * wird dann ausgeblendet. Alle Werte sind Darstellungsparameter, keine Spielwerte.
 */
UCLASS(config = Game, defaultconfig, meta = (DisplayName = "Voyage Century Appearance"))
class VOYAGECENTURY_API UVCAppearanceSettings : public UDeveloperSettings
{
	GENERATED_BODY()

public:
	/** Hautfarben je Index von "skin". */
	UPROPERTY(config, EditAnywhere, Category = "Platzhalter")
	TArray<FLinearColor> SkinColors;

	/** Haarfarben je Index von "hairColor". */
	UPROPERTY(config, EditAnywhere, Category = "Platzhalter")
	TArray<FLinearColor> HairColors;

	/** Skalierung (Breite, Breite, Höhe) je Index von "body". */
	UPROPERTY(config, EditAnywhere, Category = "Platzhalter")
	TArray<FVector> BodyScales;

	/** Echtes Charaktermodell (optional). */
	UPROPERTY(config, EditAnywhere, Category = "Modell")
	TSoftObjectPtr<USkeletalMesh> CharacterMesh;

	/** Animation Blueprint auf Basis von UVCAnimInstance (optional). */
	UPROPERTY(config, EditAnywhere, Category = "Modell")
	TSoftClassPtr<UAnimInstance> AnimClass;
};
