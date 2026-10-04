#include "VCAttributeSet.h"
#include "GameplayEffectExtension.h"
#include "Net/UnrealNetwork.h"
#include "VCCombatant.h"

void UVCAttributeSet::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);
	DOREPLIFETIME_CONDITION_NOTIFY(UVCAttributeSet, Health, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UVCAttributeSet, MaxHealth, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UVCAttributeSet, Stamina, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UVCAttributeSet, MaxStamina, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UVCAttributeSet, AttackPower, COND_OwnerOnly, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UVCAttributeSet, Defense, COND_OwnerOnly, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UVCAttributeSet, CritChance, COND_OwnerOnly, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UVCAttributeSet, CritMultiplier, COND_OwnerOnly, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UVCAttributeSet, BlockChance, COND_OwnerOnly, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UVCAttributeSet, BlockReduction, COND_OwnerOnly, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UVCAttributeSet, DodgeChance, COND_OwnerOnly, REPNOTIFY_Always);
}

void UVCAttributeSet::PreAttributeChange(const FGameplayAttribute& Attribute, float& NewValue)
{
	Super::PreAttributeChange(Attribute, NewValue);
	if (Attribute == GetHealthAttribute())
	{
		NewValue = FMath::Clamp(NewValue, 0.f, GetMaxHealth());
	}
	else if (Attribute == GetStaminaAttribute())
	{
		NewValue = FMath::Clamp(NewValue, 0.f, GetMaxStamina());
	}
}

void UVCAttributeSet::PostGameplayEffectExecute(const FGameplayEffectModCallbackData& Data)
{
	Super::PostGameplayEffectExecute(Data);
	if (Data.EvaluatedData.Attribute != GetIncomingDamageAttribute())
	{
		return;
	}
	const float Damage = GetIncomingDamage();
	SetIncomingDamage(0.f);
	if (Damage <= 0.f)
	{
		return;
	}
	const float Before = GetHealth();
	SetHealth(static_cast<float>(vc::rules::ClampHealth(Before - Damage, GetMaxHealth())));

	if (Before > 0.f && GetHealth() <= 0.f)
	{
		AActor* Victim = Data.Target.AbilityActorInfo.IsValid() ? Data.Target.AbilityActorInfo->AvatarActor.Get() : nullptr;
		if (IVCCombatant* Combatant = Cast<IVCCombatant>(Victim))
		{
			Combatant->HandleOutOfHealth(Data.EffectSpec.GetContext().GetEffectCauser());
		}
	}
}

void UVCAttributeSet::ApplyStats(UAbilitySystemComponent* AbilitySystem, const vc::rules::FCombatStats& Stats)
{
	if (!AbilitySystem || !AbilitySystem->IsOwnerActorAuthoritative())
	{
		return;
	}
	AbilitySystem->SetNumericAttributeBase(GetMaxHealthAttribute(), static_cast<float>(Stats.MaxHealth));
	AbilitySystem->SetNumericAttributeBase(GetMaxStaminaAttribute(), static_cast<float>(Stats.MaxStamina));
	AbilitySystem->SetNumericAttributeBase(GetAttackPowerAttribute(), static_cast<float>(Stats.AttackPower));
	AbilitySystem->SetNumericAttributeBase(GetDefenseAttribute(), static_cast<float>(Stats.Defense));
	AbilitySystem->SetNumericAttributeBase(GetCritChanceAttribute(), static_cast<float>(Stats.CritChance));
	AbilitySystem->SetNumericAttributeBase(GetCritMultiplierAttribute(), static_cast<float>(Stats.CritMultiplier));
	AbilitySystem->SetNumericAttributeBase(GetBlockChanceAttribute(), static_cast<float>(Stats.BlockChance));
	AbilitySystem->SetNumericAttributeBase(GetBlockReductionAttribute(), static_cast<float>(Stats.BlockReduction));
	AbilitySystem->SetNumericAttributeBase(GetDodgeChanceAttribute(), static_cast<float>(Stats.DodgeChance));
	// Bestehende Werte auf die neuen Maxima begrenzen.
	SetVitals(AbilitySystem, AbilitySystem->GetNumericAttribute(GetHealthAttribute()),
		AbilitySystem->GetNumericAttribute(GetStaminaAttribute()));
}

void UVCAttributeSet::SetVitals(UAbilitySystemComponent* AbilitySystem, double InHealth, double InStamina)
{
	if (!AbilitySystem || !AbilitySystem->IsOwnerActorAuthoritative())
	{
		return;
	}
	const double MaxH = AbilitySystem->GetNumericAttribute(GetMaxHealthAttribute());
	const double MaxS = AbilitySystem->GetNumericAttribute(GetMaxStaminaAttribute());
	AbilitySystem->SetNumericAttributeBase(GetHealthAttribute(), static_cast<float>(vc::rules::ClampHealth(InHealth, MaxH)));
	AbilitySystem->SetNumericAttributeBase(GetStaminaAttribute(), static_cast<float>(vc::rules::ClampHealth(InStamina, MaxS)));
}

void UVCAttributeSet::OnRep_Health(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UVCAttributeSet, Health, Old); }
void UVCAttributeSet::OnRep_MaxHealth(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UVCAttributeSet, MaxHealth, Old); }
void UVCAttributeSet::OnRep_Stamina(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UVCAttributeSet, Stamina, Old); }
void UVCAttributeSet::OnRep_MaxStamina(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UVCAttributeSet, MaxStamina, Old); }
void UVCAttributeSet::OnRep_AttackPower(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UVCAttributeSet, AttackPower, Old); }
void UVCAttributeSet::OnRep_Defense(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UVCAttributeSet, Defense, Old); }
void UVCAttributeSet::OnRep_CritChance(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UVCAttributeSet, CritChance, Old); }
void UVCAttributeSet::OnRep_CritMultiplier(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UVCAttributeSet, CritMultiplier, Old); }
void UVCAttributeSet::OnRep_BlockChance(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UVCAttributeSet, BlockChance, Old); }
void UVCAttributeSet::OnRep_BlockReduction(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UVCAttributeSet, BlockReduction, Old); }
void UVCAttributeSet::OnRep_DodgeChance(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UVCAttributeSet, DodgeChance, Old); }
