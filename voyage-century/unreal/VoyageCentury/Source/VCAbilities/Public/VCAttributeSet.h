#pragma once

#include "CoreMinimal.h"
#include "AbilitySystemComponent.h"
#include "AttributeSet.h"
#include "VCCombatRules.h"
#include "VCAttributeSet.generated.h"

#define VC_ATTRIBUTE_ACCESSORS(ClassName, PropertyName) \
	GAMEPLAYATTRIBUTE_PROPERTY_GETTER(ClassName, PropertyName) \
	GAMEPLAYATTRIBUTE_VALUE_GETTER(PropertyName) \
	GAMEPLAYATTRIBUTE_VALUE_SETTER(PropertyName) \
	GAMEPLAYATTRIBUTE_VALUE_INITTER(PropertyName)

/**
 * Kampfattribute. Leben und Ausdauer sehen alle (Zielanzeige), die übrigen nur der Besitzer.
 * Basiswerte setzt ausschließlich der Server (ApplyStats) aus den Kampfregeln und Daten.
 * IncomingDamage ist ein Meta-Attribut: Schaden läuft darüber, damit Tod an einer Stelle erkannt wird.
 */
UCLASS()
class VCABILITIES_API UVCAttributeSet : public UAttributeSet
{
	GENERATED_BODY()

public:
	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
	virtual void PreAttributeChange(const FGameplayAttribute& Attribute, float& NewValue) override;
	virtual void PostGameplayEffectExecute(const FGameplayEffectModCallbackData& Data) override;

	/** Nur Server: Basiswerte aus abgeleiteten Kampfwerten setzen. Health wird auf das neue Maximum begrenzt. */
	static void ApplyStats(UAbilitySystemComponent* AbilitySystem, const vc::rules::FCombatStats& Stats);

	/** Nur Server: Leben und Ausdauer setzen (begrenzt auf die Maxima). */
	static void SetVitals(UAbilitySystemComponent* AbilitySystem, double Health, double Stamina);

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_Health, Category = "Vitals") FGameplayAttributeData Health;
	VC_ATTRIBUTE_ACCESSORS(UVCAttributeSet, Health)
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_MaxHealth, Category = "Vitals") FGameplayAttributeData MaxHealth;
	VC_ATTRIBUTE_ACCESSORS(UVCAttributeSet, MaxHealth)
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_Stamina, Category = "Vitals") FGameplayAttributeData Stamina;
	VC_ATTRIBUTE_ACCESSORS(UVCAttributeSet, Stamina)
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_MaxStamina, Category = "Vitals") FGameplayAttributeData MaxStamina;
	VC_ATTRIBUTE_ACCESSORS(UVCAttributeSet, MaxStamina)

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_AttackPower, Category = "Kampf") FGameplayAttributeData AttackPower;
	VC_ATTRIBUTE_ACCESSORS(UVCAttributeSet, AttackPower)
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_Defense, Category = "Kampf") FGameplayAttributeData Defense;
	VC_ATTRIBUTE_ACCESSORS(UVCAttributeSet, Defense)
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_CritChance, Category = "Kampf") FGameplayAttributeData CritChance;
	VC_ATTRIBUTE_ACCESSORS(UVCAttributeSet, CritChance)
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_CritMultiplier, Category = "Kampf") FGameplayAttributeData CritMultiplier;
	VC_ATTRIBUTE_ACCESSORS(UVCAttributeSet, CritMultiplier)
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_BlockChance, Category = "Kampf") FGameplayAttributeData BlockChance;
	VC_ATTRIBUTE_ACCESSORS(UVCAttributeSet, BlockChance)
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_BlockReduction, Category = "Kampf") FGameplayAttributeData BlockReduction;
	VC_ATTRIBUTE_ACCESSORS(UVCAttributeSet, BlockReduction)
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_DodgeChance, Category = "Kampf") FGameplayAttributeData DodgeChance;
	VC_ATTRIBUTE_ACCESSORS(UVCAttributeSet, DodgeChance)

	/** Meta-Attribut, nicht repliziert. */
	UPROPERTY(BlueprintReadOnly, Category = "Meta") FGameplayAttributeData IncomingDamage;
	VC_ATTRIBUTE_ACCESSORS(UVCAttributeSet, IncomingDamage)

protected:
	UFUNCTION() void OnRep_Health(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_MaxHealth(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_Stamina(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_MaxStamina(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_AttackPower(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_Defense(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_CritChance(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_CritMultiplier(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_BlockChance(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_BlockReduction(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_DodgeChance(const FGameplayAttributeData& Old);
};
