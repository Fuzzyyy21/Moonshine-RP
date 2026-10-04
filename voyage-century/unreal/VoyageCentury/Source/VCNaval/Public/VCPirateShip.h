#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VCShip.h"
#include "VCPirateShip.generated.h"

/**
 * Piratenschiff als Gegner (DT_PirateShips → Schiffswerte aus DT_Ships). Gleiche Fahrt- und Kampfregeln wie Spielerschiffe;
 * die KI stellt nur Segel und Ruder und feuert: Ziel im Aggro-Radius suchen, quer zum Ziel auf etwa 70 % der Kanonenreichweite
 * gehen, feuern, sobald das Ziel im Feuerwinkel liegt; mit mehr Matrosen als das Ziel heranfahren, Haken werfen und entern;
 * zu weit vom Startpunkt (Leine) → zurück. Läuft nur auf dem Server.
 */
UCLASS()
class VCNAVAL_API AVCPirateShip : public AVCShip
{
	GENERATED_BODY()

public:
	AVCPirateShip();

	/** Code aus DT_PirateShips (= monsters.code im Backend). */
	UPROPERTY(EditAnywhere, Category = "Pirat")
	FName PirateCode;

	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

protected:
	virtual void HandleSunk(AActor* Killer) override;

private:
	FVector Home = FVector::ZeroVector;
	TWeakObjectPtr<AVCShip> Target;
	FTimerHandle ThinkTimer;

	void Think();
	void SteerTowards(double DesiredHeadingDeg, float Sail);
};

/** Setzt ein Piratenschiff ein und nach dem Versenken nach RespawnSeconds neu. */
UCLASS()
class VCNAVAL_API AVCPirateSpawner : public AActor
{
	GENERATED_BODY()

public:
	AVCPirateSpawner();

	UPROPERTY(EditAnywhere, Category = "Pirat")
	FName PirateCode;

	virtual void BeginPlay() override;

private:
	TWeakObjectPtr<AVCPirateShip> Spawned;
	FTimerHandle CheckTimer;
	double GoneSince = -1.0;

	void Check();
	void SpawnPirate();
};
