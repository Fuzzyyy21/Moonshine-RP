#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "VCDataRows.h"
#include "VCShipRules.h"
#include "VCNavalData.generated.h"

class UDataTable;

/** Schiffsdaten (Projekteinstellungen > Voyage Century Naval). */
UCLASS(config = Game, defaultconfig, meta = (DisplayName = "Voyage Century Naval"))
class VCNAVAL_API UVCNavalSettings : public UDeveloperSettings
{
	GENERATED_BODY()

public:
	UPROPERTY(config, EditAnywhere, Category = "Daten", meta = (RequiredAssetDataTags = "RowStructure=/Script/VCData.VCShipRow"))
	TSoftObjectPtr<UDataTable> ShipsTable;

	UPROPERTY(config, EditAnywhere, Category = "Daten", meta = (RequiredAssetDataTags = "RowStructure=/Script/VCData.VCShipTuningRow"))
	TSoftObjectPtr<UDataTable> ShipTuningTable;

	UPROPERTY(config, EditAnywhere, Category = "Daten", meta = (RequiredAssetDataTags = "RowStructure=/Script/VCData.VCZoneWindRow"))
	TSoftObjectPtr<UDataTable> ZoneWindTable;

	/** Höhe der Wasseroberfläche in den Seekarten (Platzhalter, bis es Wasser-Assets gibt). */
	UPROPERTY(config, EditAnywhere, Category = "See")
	float SeaLevelZ = 0.f;
};

/**
 * Zugriff auf die Schiffsdaten. Fehlen Tabellen oder ist das Segelmodell ungültig, gibt es keine Schiffe
 * (IsAvailable() == false) – nie Ersatzwerte.
 */
class VCNAVAL_API FVCNavalData
{
public:
	static bool IsAvailable();
	static const FVCShipRow* FindShip(FName Code);
	static const vc::rules::FSailTuning& SailTuning();
	/** Wind der Zone; ohne Eintrag Windstille (Stärke 0). */
	static vc::rules::FWindParams WindFor(FName ZoneId);
	static vc::rules::FShipDef ToRules(const FVCShipRow& Row);
};
