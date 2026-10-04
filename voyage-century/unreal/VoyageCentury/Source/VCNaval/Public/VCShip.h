#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "VCShipRules.h"
#include "VCShip.generated.h"

class UBoxComponent;
class UCameraComponent;
class UInputAction;
class UInputMappingContext;
class USpringArmComponent;
class UStaticMeshComponent;
struct FInputActionValue;

/** Was der Server beim Spawnen über das Schiff weiß (aus dem Backend). */
struct FVCShipLoadout
{
	int64 InstanceId = 0;
	FName ShipCode;
	int32 HullHp = 0;
	int32 Crew = 0;
	int32 Injured = 0;
	int32 Provisions = 0;
};

class AVCShip;
/** Treffer an einem Schiff (Clients; für das HUD). */
DECLARE_MULTICAST_DELEGATE_FourParams(FVCShipHitEvent, AVCShip* /*Ship*/, int32 /*Hits*/, int32 /*HullDamage*/, int32 /*CrewLosses*/);

/**
 * Schiff als Spielfigur auf See. Der Server rechnet die Fahrt mit vc::rules (Wind, Kurs zum Wind, Segel, Matrosen,
 * Proviant) und verschiebt das Schiff; Clients senden nur Segelstellung und Ruder und sehen die replizierte Bewegung.
 * Keine Client-Vorhersage: Schiffe reagieren träge, die Latenz fällt dadurch kaum auf (in Iteration 2 messen).
 *
 * Steuerung: W/S Segel setzen/reffen (in Vierteln), A/D Ruder, Q/E Breitseite backbord/steuerbord, R Kanone wechseln,
 * Maus Kamera. Treffer, Matrosenverluste und Sinken entscheidet der Server (vc::rules Seekampf).
 */
UCLASS()
class VCNAVAL_API AVCShip : public APawn
{
	GENERATED_BODY()

public:
	AVCShip();

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
	virtual void Tick(float DeltaSeconds) override;
	virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;
	virtual void PawnClientRestart() override;

	/** Nur Server: Werte aus dem Backend und die Zone (für den Wind) setzen. */
	void ServerInit(const FVCShipLoadout& Loadout, FName InZoneId);

	/** Aktueller Stand für das Speichern (nur Server aussagekräftig). */
	FVCShipLoadout GetLoadout() const;

	// Anzeige (repliziert)
	FName GetShipCode() const { return ShipCode; }
	float GetSpeed() const { return Speed; }
	float GetSailLevel() const { return SailLevel; }
	float GetRudder() const { return Rudder; }
	int32 GetHullHp() const { return HullHp; }
	int32 GetCrew() const { return Crew; }
	int32 GetProvisions() const { return Provisions; }
	/** Wind jetzt, gleich berechnet wie auf dem Server (deterministisch aus Zone und Server-Weltzeit). */
	vc::rules::FWind GetWind() const;

	int32 GetInjured() const { return Injured; }
	FName GetCannonCode() const { return CannonCode; }
	bool IsPirate() const { return bPirate; }
	bool IsSunk() const { return bSunk; }
	/** Restliche Nachladezeit je Seite (Anzeige; Server-Weltzeit). */
	double GetReloadRemaining(bool bStarboard) const;

	/** Nur Server: Breitseite empfangen. Killer = Schiff des Angreifers. */
	void ServerTakeBroadside(const vc::rules::FBroadsideResult& Result, AActor* Attacker);

	static FVCShipHitEvent OnShipHit;

protected:
	/** Piratenschiffe: Gegner, gegen die immer gekämpft werden darf. */
	UPROPERTY(Replicated)
	bool bPirate = false;

	/** Nur Server: Breitseite auf dieser Seite feuern (Nachladen, Ziel im Feuerwinkel und in Reichweite). */
	bool FireBroadside(vc::rules::EBroadside Side);

	/** Gesunken: Server meldet es (Spieler: GameMode, Pirat: Belohnung) und das Schiff bleibt reglos. */
	virtual void HandleSunk(AActor* Killer);

	UPROPERTY(Replicated) FName CannonCode;
	UPROPERTY(Replicated) float SailLevel = 0.f;
	UPROPERTY(Replicated) float Rudder = 0.f;

private:
	UPROPERTY(VisibleAnywhere, Category = "Schiff")
	TObjectPtr<UBoxComponent> Hull;

	UPROPERTY(VisibleAnywhere, Category = "Schiff")
	TObjectPtr<UStaticMeshComponent> PlaceholderBody;

	UPROPERTY(VisibleAnywhere, Category = "Schiff")
	TObjectPtr<UStaticMeshComponent> PlaceholderMast;

	UPROPERTY(VisibleAnywhere, Category = "Kamera")
	TObjectPtr<USpringArmComponent> CameraBoom;

	UPROPERTY(VisibleAnywhere, Category = "Kamera")
	TObjectPtr<UCameraComponent> FollowCamera;

	UPROPERTY(Transient) TObjectPtr<UInputMappingContext> InputContext;
	UPROPERTY(Transient) TObjectPtr<UInputAction> SailAction;
	UPROPERTY(Transient) TObjectPtr<UInputAction> RudderAction;
	UPROPERTY(Transient) TObjectPtr<UInputAction> LookAction;
	UPROPERTY(Transient) TObjectPtr<UInputAction> FirePortAction;
	UPROPERTY(Transient) TObjectPtr<UInputAction> FireStarboardAction;
	UPROPERTY(Transient) TObjectPtr<UInputAction> CannonAction;

	UPROPERTY(Replicated) FName ShipCode;
	UPROPERTY(Replicated) FName ZoneId;
	UPROPERTY(Replicated) float Speed = 0.f;
	UPROPERTY(Replicated) int32 HullHp = 0;
	UPROPERTY(Replicated) int32 Crew = 0;
	UPROPERTY(Replicated) int32 Provisions = 0;
	UPROPERTY(Replicated) int32 Injured = 0;
	UPROPERTY(Replicated) bool bSunk = false;
	/** Server-Weltzeit des letzten Feuers je Seite (Anzeige der Nachladezeit). */
	UPROPERTY(Replicated) double LastFirePort = -1.0;
	UPROPERTY(Replicated) double LastFireStarboard = -1.0;
	int32 Dead = 0;

	int64 InstanceId = 0;
	double ProvisionCarry = 0.0;
	/** Zuletzt gesendete Ruderstellung; vermeidet RPCs ohne Änderung. */
	float SentRudder = 0.f;

	/** Zuverlässig: wird nur bei Änderung gesendet (Segelstufe, Ruderstellung). */
	UFUNCTION(Server, Reliable, WithValidation)
	void ServerSetHelm(float NewSailLevel, float NewRudder);

	UFUNCTION(Server, Reliable)
	void ServerFire(bool bStarboard);

	UFUNCTION(Server, Reliable)
	void ServerToggleCannon();

	UFUNCTION(NetMulticast, Unreliable)
	void MulticastHit(int32 Hits, int32 HullDamage, int32 CrewLosses);

	void FirePort(const FInputActionValue& Value);
	void FireStarboard(const FInputActionValue& Value);
	void ToggleCannon(const FInputActionValue& Value);
	void CreateInputObjects();
	void ChangeSail(const FInputActionValue& Value);
	void Steer(const FInputActionValue& Value);
	void StopSteering(const FInputActionValue& Value);
	void Look(const FInputActionValue& Value);
	void ServerSimulate(float DeltaSeconds);
};
