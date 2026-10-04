#pragma once

#include "CoreMinimal.h"
#include "AbilitySystemInterface.h"
#include "GameFramework/Character.h"
#include "VCAppearance.h"
#include "VCCombatant.h"
#include "VCCharacter.generated.h"

class UCameraComponent;
class UInputAction;
class UVCCombatStateComponent;
class AVCNpc;
class UInputMappingContext;
class USpringArmComponent;
class UStaticMeshComponent;
struct FInputActionValue;

/**
 * Spielfigur an Land. Bewegung über die Character Movement Component: der Client sagt voraus,
 * der Server rechnet nach und korrigiert. Der Client sendet nur Eingaben, keine Positionen.
 *
 * Steuerung (Enhanced Input, zur Laufzeit erzeugt, damit keine Binär-Assets nötig sind):
 *   WASD bewegen, Maus umsehen, Leertaste springen, Tab Ziel wechseln, linke Maustaste angreifen,
 *   1–0 Hotbar-Fähigkeiten, E NPC ansprechen.
 * Laufgeschwindigkeit und Sprunghöhe des Originals sind UNKNOWN; es gelten die Engine-Standardwerte.
 */
UCLASS()
class VOYAGECENTURY_API AVCCharacter : public ACharacter, public IAbilitySystemInterface, public IVCCombatant
{
	GENERATED_BODY()

public:
	AVCCharacter();

	virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;
	virtual void PawnClientRestart() override;
	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
	virtual void BeginPlay() override;

	/** Nur Server: geprüftes Erscheinungsbild aus dem GameData-Dienst setzen. */
	void ServerSetAppearance(const FVCAppearance& InAppearance);

	// Ability System liegt am PlayerState.
	virtual UAbilitySystemComponent* GetAbilitySystemComponent() const override;
	virtual void PossessedBy(AController* NewController) override;
	virtual void OnRep_PlayerState() override;

	// IVCCombatant
	virtual bool IsAlive() const override;
	virtual bool IsPlayerCharacter() const override { return true; }
	virtual bool GetAttack(vc::rules::FWeaponDef& OutWeapon, FName& OutSkillCode, int32& OutSkillLevel) const override;
	virtual int32 GetSkillLevel(FName SkillCode) const override;
	virtual FText GetCombatName() const override;
	virtual void HandleOutOfHealth(AActor* Killer) override;

	/** Nur Server: ausgerüstete Waffe (Code aus DT_Weapons). Ausrüstung über das Inventar folgt. */
	void ServerSetEquippedWeapon(FName WeaponCode);
	FName GetEquippedWeapon() const { return EquippedWeapon; }

	/** Clientseitig gewähltes Ziel (nur Anzeige und Angriffsziel; der Server prüft alles neu). */
	AActor* GetCurrentTarget() const { return CurrentTarget.Get(); }

private:
	UPROPERTY(VisibleAnywhere, Category = "Visual")
	TObjectPtr<UStaticMeshComponent> PlaceholderBody;

	/** Platzhalter für Haare; Form je "hair"-Index, Farbe je "hairColor". */
	UPROPERTY(VisibleAnywhere, Category = "Visual")
	TObjectPtr<UStaticMeshComponent> PlaceholderHair;

	UPROPERTY(ReplicatedUsing = OnRep_Appearance)
	FVCAppearance Appearance;

	UPROPERTY(VisibleAnywhere, Category = "Kampf")
	TObjectPtr<UVCCombatStateComponent> CombatState;

	UPROPERTY(VisibleAnywhere, Category = "Camera")
	TObjectPtr<USpringArmComponent> CameraBoom;

	UPROPERTY(VisibleAnywhere, Category = "Camera")
	TObjectPtr<UCameraComponent> FollowCamera;

	UPROPERTY(Transient)
	TObjectPtr<UInputMappingContext> InputContext;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> MoveAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> LookAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> JumpAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> TargetAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> AttackAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> InteractAction;

	/** Eine Aktion für alle Hotbar-Tasten; der Wert (1–10) sagt, welche Taste gedrückt wurde. */
	UPROPERTY(Transient)
	TObjectPtr<UInputAction> HotbarAction;

	/** Code aus DT_Weapons; leer = unbewaffnet (UVCCombatSettings::UnarmedWeapon). */
	UPROPERTY(Replicated)
	FName EquippedWeapon;

	TWeakObjectPtr<AActor> CurrentTarget;

	void InitAbilityActorInfo();
	void CycleTarget();
	void Attack();
	void UseHotbar(const FInputActionValue& Value);
	void Interact();

	/** Der Client nennt den NPC; Abstand und Zustand prüft der Server. */
	UFUNCTION(Server, Reliable)
	void ServerInteract(AVCNpc* Npc);

	/** Der Client nennt den Sammelpunkt; Abstand, Verfügbarkeit, Sammelzeit prüft der Server, Skill und Ausbeute das Backend. */
	UFUNCTION(Server, Reliable)
	void ServerGather(class AVCGatherNode* Node);

	UFUNCTION(Server, Reliable)
	void ServerRequestAttack(AActor* Target);

	/** Der Client nennt nur Platz und Ziel; welche Fähigkeit dort liegt und ob sie geht, entscheidet der Server. */
	UFUNCTION(Server, Reliable, WithValidation)
	void ServerUseHotbarSlot(int32 Slot, AActor* Target);

	UFUNCTION()
	void OnRep_Appearance();

	void ApplyAppearance();
	void UseCharacterModelIfConfigured();
	void CreateInputObjects();
	void Move(const FInputActionValue& Value);
	void Look(const FInputActionValue& Value);
};
