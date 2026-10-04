#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "VCNavalAbilityRules.h"
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
 * F Enterhaken, B Entern (nur festgehakt), M Mine legen, Maus Kamera. Treffer, Matrosenverluste, Rammen, Entern und Sinken
 * entscheidet der Server (vc::rules Seekampf und Seekampf-Fähigkeiten).
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
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

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

	/** Nur Server: Schaden aus beliebiger Quelle (Breitseite, Rammen, Mine). Hits nur für die Anzeige. */
	void ServerTakeDamage(double HullDamage, int32 CrewLosses, int32 Hits, AActor* Attacker);

	/** Darf dieses Schiff Other angreifen? Spieler gegen Piraten immer, Piraten untereinander nie, Spieler gegen Spieler nur in PvP-Zonen. */
	bool IsHostileTo(const AVCShip* Other) const;

	/** Festgehakt an (repliziert, beide Schiffe); nullptr, wenn frei. */
	AVCShip* GetGrappledTo() const { return GrappledTo; }
	/** Entern läuft (als Angreifer oder Verteidiger). */
	bool IsBoarding() const { return bBoarding; }
	/** Restliche Abklingzeit (Anzeige; Server-Weltzeit). */
	double GetGrappleCooldown() const;
	double GetMineCooldown() const;

	static FVCShipHitEvent OnShipHit;

protected:
	/** Piratenschiffe: Gegner, gegen die immer gekämpft werden darf. */
	UPROPERTY(Replicated)
	bool bPirate = false;

	/** Nur Server: Breitseite auf dieser Seite feuern (Nachladen, Ziel im Feuerwinkel und in Reichweite). */
	bool FireBroadside(vc::rules::EBroadside Side);

	/** Gesunken: Server meldet es (Spieler: GameMode, Pirat: Belohnung) und das Schiff bleibt reglos. */
	virtual void HandleSunk(AActor* Killer);

	/** Nur Server: nächstes feindliches Schiff festhaken (Reichweite, beide langsam genug, Abklingzeit). */
	bool TryGrapple();
	/** Nur Server: das festgehakte Schiff entern (Runden-Timer bis eine Seite keine Matrosen mehr hat). */
	bool TryBoard();
	/** Nur Server: Mine hinter dem Heck legen. */
	bool TryDropMine();

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
	UPROPERTY(Transient) TObjectPtr<UInputAction> GrappleAction;
	UPROPERTY(Transient) TObjectPtr<UInputAction> BoardAction;
	UPROPERTY(Transient) TObjectPtr<UInputAction> MineAction;

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

	UPROPERTY(Replicated) TObjectPtr<AVCShip> GrappledTo;
	UPROPERTY(Replicated) bool bBoarding = false;
	/** Server-Weltzeit des letzten Enterhakens / der letzten Mine (Anzeige der Abklingzeit). */
	UPROPERTY(Replicated) double LastGrapple = -1.0;
	UPROPERTY(Replicated) double LastMine = -1.0;
	double GrappleUntil = 0.0;
	/** Nur beim Angreifer: wen er entert. */
	TWeakObjectPtr<AVCShip> BoardingDefender;
	FTimerHandle BoardingTimer;

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

	UFUNCTION(Server, Reliable)
	void ServerGrapple();

	UFUNCTION(Server, Reliable)
	void ServerBoard();

	UFUNCTION(Server, Reliable)
	void ServerDropMine();

	UFUNCTION(NetMulticast, Unreliable)
	void MulticastHit(int32 Hits, int32 HullDamage, int32 CrewLosses);

	/** Nur Server: an Ziel festhaken (beide Seiten). */
	void Grapple(AVCShip* Other, double Now);
	/** Nur Server: Haken lösen (beide Seiten); beendet auch ein laufendes Entern. */
	void ReleaseGrapple();
	void BoardingRound();
	void EndBoarding();
	/** Nur Server: Schiff verloren (versenkt oder genommen). */
	void Sink(AActor* Killer);
	void TryRam(const FHitResult& Hit, double SpeedCmPerSecond);
	double ServerNow() const;
	double BoardingStrength() const;

	void FirePort(const FInputActionValue& Value);
	void FireStarboard(const FInputActionValue& Value);
	void ToggleCannon(const FInputActionValue& Value);
	void GrappleInput(const FInputActionValue& Value);
	void BoardInput(const FInputActionValue& Value);
	void MineInput(const FInputActionValue& Value);
	void CreateInputObjects();
	void ChangeSail(const FInputActionValue& Value);
	void Steer(const FInputActionValue& Value);
	void StopSteering(const FInputActionValue& Value);
	void Look(const FInputActionValue& Value);
	void ServerSimulate(float DeltaSeconds);
};
