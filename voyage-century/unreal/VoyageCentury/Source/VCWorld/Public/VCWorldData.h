#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "VCDataRows.h"
#include "VCWorldData.generated.h"

class UDataTable;

/** Weltdaten (Projekteinstellungen > Voyage Century World). */
UCLASS(config = Game, defaultconfig, meta = (DisplayName = "Voyage Century World"))
class VCWORLD_API UVCWorldSettings : public UDeveloperSettings
{
	GENERATED_BODY()

public:
	UPROPERTY(config, EditAnywhere, Category = "Daten", meta = (RequiredAssetDataTags = "RowStructure=/Script/VCData.VCNpcRow"))
	TSoftObjectPtr<UDataTable> NpcsTable;

	UPROPERTY(config, EditAnywhere, Category = "Daten", meta = (RequiredAssetDataTags = "RowStructure=/Script/VCData.VCDiscoveryRow"))
	TSoftObjectPtr<UDataTable> DiscoveriesTable;

	/** Höchstabstand für das Ansprechen eines NPCs (Server prüft). Designwert, Original UNKNOWN. */
	UPROPERTY(config, EditAnywhere, Category = "NPC", meta = (ClampMin = "50"))
	float InteractRangeCm = 300.f;
};

/** Zugriff auf die Weltdaten; Tabellen werden beim ersten Zugriff geladen und bleiben geladen. */
class VCWORLD_API FVCWorldData
{
public:
	static const FVCNpcRow* FindNpc(FName Code);
	static const FVCDiscoveryRow* FindDiscovery(FName Code);
	/** Anzeigename: deutsch, sonst chinesisch, sonst Code. */
	static FString NpcDisplayName(FName Code);
};
