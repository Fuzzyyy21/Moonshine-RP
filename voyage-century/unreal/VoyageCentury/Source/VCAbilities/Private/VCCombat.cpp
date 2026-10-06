#include "VCCombat.h"
#include "AbilitySystemComponent.h"
#include "AbilitySystemGlobals.h"
#include "Engine/World.h"
#include "VCAttributeSet.h"
#include "VCCombatData.h"
#include "VCCombatStateComponent.h"
#include "VCCombatant.h"
#include "VCDamage.h"
#include "VCGameplayTags.h"
#include "VCServerHooks.h"

namespace
{
	void ShowText(const AActor* Target, EVCCombatText Kind, double Amount)
	{
		if (UVCCombatStateComponent* State = UVCCombatStateComponent::Find(Target))
		{
			State->ShowCombatText(Kind, Amount);
		}
	}

	EVCCombatText TextFor(vc::rules::EHitResult Result)
	{
		switch (Result)
		{
		case vc::rules::EHitResult::Dodged: return EVCCombatText::Dodged;
		case vc::rules::EHitResult::Blocked: return EVCCombatText::Blocked;
		case vc::rules::EHitResult::Critical: return EVCCombatText::Critical;
		default: return EVCCombatText::Hit;
		}
	}

	bool IsAliveCombatant(const AActor* Actor)
	{
		const IVCCombatant* Combatant = Cast<IVCCombatant>(Actor);
		return Combatant && Combatant->IsAlive();
	}
}

bool FVCCombat::IsHostile(const AActor* Attacker, const AActor* Defender)
{
	const IVCCombatant* A = Cast<IVCCombatant>(Attacker);
	const IVCCombatant* D = Cast<IVCCombatant>(Defender);
	if (!A || !D || Attacker == Defender)
	{
		return false;
	}
	if (A->IsPlayerCharacter() != D->IsPlayerCharacter())
	{
		return true; // Spieler gegen Gegner
	}
	if (!A->IsPlayerCharacter())
	{
		return false; // Gegner untereinander nicht
	}
	const UWorld* World = Attacker->GetWorld();
	const IVCServerHooks* Hooks = World ? Cast<IVCServerHooks>(World->GetAuthGameMode()) : nullptr;
	return Hooks && Hooks->IsPvPAllowedBetween(Attacker, Defender);
}

bool FVCCombat::IsStunned(const AActor* Actor)
{
	const UVCCombatStateComponent* State = UVCCombatStateComponent::Find(Actor);
	return State && State->IsStunned();
}

vc::rules::FCombatStats FVCCombat::CurrentStats(const AActor* Actor)
{
	vc::rules::FCombatStats Stats;
	const UAbilitySystemComponent* ASC = UAbilitySystemGlobals::GetAbilitySystemComponentFromActor(Actor);
	if (!ASC)
	{
		return Stats;
	}
	auto Get = [ASC](const FGameplayAttribute& Attribute) { return static_cast<double>(ASC->GetNumericAttribute(Attribute)); };
	Stats.MaxHealth = Get(UVCAttributeSet::GetMaxHealthAttribute());
	Stats.MaxStamina = Get(UVCAttributeSet::GetMaxStaminaAttribute());
	Stats.AttackPower = Get(UVCAttributeSet::GetAttackPowerAttribute());
	Stats.Defense = Get(UVCAttributeSet::GetDefenseAttribute());
	Stats.CritChance = Get(UVCAttributeSet::GetCritChanceAttribute());
	Stats.CritMultiplier = Get(UVCAttributeSet::GetCritMultiplierAttribute());
	Stats.BlockChance = Get(UVCAttributeSet::GetBlockChanceAttribute());
	Stats.BlockReduction = Get(UVCAttributeSet::GetBlockReductionAttribute());
	Stats.DodgeChance = Get(UVCAttributeSet::GetDodgeChanceAttribute());
	if (const UVCCombatStateComponent* State = UVCCombatStateComponent::Find(Actor))
	{
		Stats = vc::rules::WithModifiers(Stats, State->GetModifiers());
	}
	return Stats;
}

vc::rules::FAttackOutcome FVCCombat::Strike(AActor* Attacker, AActor* Target, double WeaponDamageValue)
{
	vc::rules::FAttackOutcome Outcome;
	Outcome.Result = vc::rules::EHitResult::Dodged;
	if (!FVCCombatData::IsAvailable() || !Attacker || !IsAliveCombatant(Target))
	{
		return Outcome;
	}
	vc::rules::FAttackRolls Rolls;
	Rolls.Dodge = FMath::FRand();
	Rolls.Block = FMath::FRand();
	Rolls.Crit = FMath::FRand();
	Rolls.Variance = FMath::FRand();
	Outcome = vc::rules::ResolveAttack(CurrentStats(Attacker), CurrentStats(Target), WeaponDamageValue, Rolls, FVCCombatData::Tuning());

	ShowText(Target, TextFor(Outcome.Result), Outcome.Damage);
	ApplyDamage(Target, Outcome.Damage, Attacker, false);
	return Outcome;
}

void FVCCombat::ApplyDamage(AActor* Target, double Amount, AActor* Causer, bool bPeriodic)
{
	UAbilitySystemComponent* ASC = UAbilitySystemGlobals::GetAbilitySystemComponentFromActor(Target);
	if (!ASC || Amount <= 0.0 || !IsAliveCombatant(Target))
	{
		return;
	}
	// Der Verursacher steht im Kontext; UVCAttributeSet meldet ihn beim Tod als Killer.
	FGameplayEffectContextHandle Context = ASC->MakeEffectContext();
	Context.AddInstigator(Causer, Causer);
	const FGameplayEffectSpecHandle Spec = ASC->MakeOutgoingSpec(UVCDamageEffect::StaticClass(), 1.f, Context);
	if (!Spec.IsValid())
	{
		return;
	}
	Spec.Data->SetSetByCallerMagnitude(TAG_VC_Data_Damage, static_cast<float>(Amount));
	if (bPeriodic)
	{
		ShowText(Target, EVCCombatText::Periodic, Amount);
	}
	ASC->ApplyGameplayEffectSpecToSelf(*Spec.Data.Get());
}

void FVCCombat::ApplyHeal(AActor* Target, double Amount)
{
	UAbilitySystemComponent* ASC = UAbilitySystemGlobals::GetAbilitySystemComponentFromActor(Target);
	if (!ASC || Amount <= 0.0 || !IsAliveCombatant(Target))
	{
		return;
	}
	const double Before = ASC->GetNumericAttribute(UVCAttributeSet::GetHealthAttribute());
	UVCAttributeSet::SetVitals(ASC, Before + Amount, ASC->GetNumericAttribute(UVCAttributeSet::GetStaminaAttribute()));
	const double Healed = ASC->GetNumericAttribute(UVCAttributeSet::GetHealthAttribute()) - Before;
	if (Healed > 0.0)
	{
		ShowText(Target, EVCCombatText::Heal, Healed);
	}
}

bool FVCCombat::SpendStamina(AActor* Actor, double Amount)
{
	UAbilitySystemComponent* ASC = UAbilitySystemGlobals::GetAbilitySystemComponentFromActor(Actor);
	if (!ASC)
	{
		return false;
	}
	const double Stamina = ASC->GetNumericAttribute(UVCAttributeSet::GetStaminaAttribute());
	if (Stamina < Amount)
	{
		return false;
	}
	if (Amount > 0.0)
	{
		UVCAttributeSet::SetVitals(ASC, ASC->GetNumericAttribute(UVCAttributeSet::GetHealthAttribute()), Stamina - Amount);
	}
	return true;
}
