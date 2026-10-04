#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VCZoneExit.generated.h"

class UBoxComponent;
class UTextRenderComponent;

/**
 * Ausgang in eine andere Zone (z. B. Hafen → See). Wohin er führt, steht nicht hier, sondern in den
 * Weltdaten (zone_links: Zone + ExitCode → Zielzone + Ankunftspunkt); das Backend löst ihn auf.
 * So lassen sich Übergänge ändern, ohne Karten anzufassen.
 *
 * Ankunftspunkte sind PlayerStarts mit passendem PlayerStartTag in der Zielkarte.
 * Betritt eine Spielfigur das Volumen, meldet der Server den Wunsch an den GameMode; nur er entscheidet.
 */
UCLASS()
class VCWORLD_API AVCZoneExit : public AActor
{
	GENERATED_BODY()

public:
	AVCZoneExit();

	/** Code des Ausgangs in dieser Zone, z. B. HARBOR (A-Z, 0-9, _), siehe design_data/world_layout.json. */
	UPROPERTY(EditAnywhere, Category = "Zone")
	FName ExitCode;

	virtual void OnConstruction(const FTransform& Transform) override;

protected:
	virtual void NotifyActorBeginOverlap(AActor* OtherActor) override;

private:
	UPROPERTY(VisibleAnywhere, Category = "Zone")
	TObjectPtr<UBoxComponent> Volume;

	/** Nur im Editor sichtbar, damit Ausgänge in der Karte auffallen. */
	UPROPERTY(VisibleAnywhere, Category = "Zone")
	TObjectPtr<UTextRenderComponent> Label;
};
