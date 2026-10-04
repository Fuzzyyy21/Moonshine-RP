#pragma once

#include "CoreMinimal.h"
#include "AbilitySystemInterface.h"
#include "GameFramework/Character.h"
#include "VCCombatant.h"
#include "VCMonster.generated.h"

class UAbilitySystemComponent;
class UStaticMeshComponent;
class UVCAttributeSet;
struct FVCMonsterRow;

/**
 * Gegner an Land. Werte kommen ausschließlich aus DT_Monsters (MonsterCode).
 * Fehlt der Eintrag, entfernt sich der Gegner selbst – es wird nie mit Ersatzwerten gekämpft.
 */
UCLASS()
class VCAI_API AVCMonster : public ACharacter, public IAbilitySystemInterface, public IVCCombatant
{
	GENERATED_BODY()

public:
	AVCMonster();

	virtual void BeginPlay() override;
	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
	virtual UAbilitySystemComponent* GetAbilitySystemComponent() const override;

	// IVCCombatant
	virtual bool IsAlive() const override;
	virtual bool IsPlayerCharacter() const override { return false; }
	virtual bool GetAttack(vc::rules::FWeaponDef& OutWeapon, FName& OutSkillCode, int32& OutSkillLevel) const override;
	virtual FName GetMonsterCode() const override { return MonsterCode; }
	virtual void HandleOutOfHealth(AActor* Killer) override;

	/** Vor dem Spawnen (SpawnActorDeferred) oder im Level setzen. */
	UPROPERTY(EditAnywhere, Replicated, Category = "Gegner")
	FName MonsterCode;

	const FVCMonsterRow* GetRow() const;
	FVector GetHomeLocation() const { return HomeLocation; }

	/** Nur Server: Leben voll auffüllen (z. B. nach dem Zurückkehren). */
	void ServerRestoreHealth();

private:
	UPROPERTY(VisibleAnywhere, Category = "Abilities")
	TObjectPtr<UAbilitySystemComponent> AbilitySystem;

	UPROPERTY()
	TObjectPtr<UVCAttributeSet> Attributes;

	UPROPERTY(VisibleAnywhere, Category = "Visual")
	TObjectPtr<UStaticMeshComponent> PlaceholderBody;

	FVector HomeLocation = FVector::ZeroVector;
};
