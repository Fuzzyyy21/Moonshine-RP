#pragma once

#include "CoreMinimal.h"
#include "AbilitySystemInterface.h"
#include "GameFramework/PlayerState.h"
#include "VCPlayerState.generated.h"

class UAbilitySystemComponent;
class UVCAbilityStateComponent;
class UVCAttributeSet;
class UVCProgressionComponent;

/**
 * PlayerState mit Progression und Ability System. Das Ability System sitzt hier (nicht am Pawn),
 * damit Attribute und Effekte Tod und Respawn überdauern.
 */
UCLASS()
class VOYAGECENTURY_API AVCPlayerState : public APlayerState, public IAbilitySystemInterface
{
	GENERATED_BODY()

public:
	AVCPlayerState();

	virtual UAbilitySystemComponent* GetAbilitySystemComponent() const override;
	virtual void BeginPlay() override;

	UVCProgressionComponent* GetProgression() const { return Progression; }
	UVCAttributeSet* GetAttributes() const { return Attributes; }
	UVCAbilityStateComponent* GetAbilityState() const { return AbilityState; }

private:
	UPROPERTY(VisibleAnywhere, Category = "Progression")
	TObjectPtr<UVCProgressionComponent> Progression;

	UPROPERTY(VisibleAnywhere, Category = "Abilities")
	TObjectPtr<UAbilitySystemComponent> AbilitySystem;

	UPROPERTY()
	TObjectPtr<UVCAttributeSet> Attributes;

	/** Hotbar und Abklingzeiten; überdauern Tod und Respawn wie das Ability System. */
	UPROPERTY(VisibleAnywhere, Category = "Abilities")
	TObjectPtr<UVCAbilityStateComponent> AbilityState;
};
