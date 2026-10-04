#include "VCAbility_BasicAttack.h"
#include "AbilitySystemBlueprintLibrary.h"
#include "AbilitySystemComponent.h"
#include "Engine/World.h"
#include "VCCombatData.h"
#include "VCCombatant.h"
#include "VCDamage.h"
#include "VCGameplayTags.h"
#include "VCServerHooks.h"

UVCAbility_BasicAttack::UVCAbility_BasicAttack()
{
	InstancingPolicy = EGameplayAbilityInstancingPolicy::InstancedPerActor;
	NetExecutionPolicy = EGameplayAbilityNetExecutionPolicy::ServerOnly;
	ActivationBlockedTags.AddTag(TAG_VC_State_Dead);

	FAbilityTriggerData Trigger;
	Trigger.TriggerTag = TAG_VC_Event_Attack;
	Trigger.TriggerSource = EGameplayAbilityTriggerSource::GameplayEvent;
	AbilityTriggers.Add(Trigger);
}

void UVCAbility_BasicAttack::ActivateAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
	const FGameplayAbilityActivationInfo ActivationInfo, const FGameplayEventData* TriggerEventData)
{
	AActor* Target = TriggerEventData ? const_cast<AActor*>(TriggerEventData->Target.Get()) : nullptr;
	const bool bHit = Target && PerformAttack(ActorInfo, Target);
	EndAbility(Handle, ActorInfo, ActivationInfo, true, !bHit);
}

bool UVCAbility_BasicAttack::IsHostile(const AActor* Attacker, const AActor* Defender)
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
	return Hooks && Hooks->IsPvPAllowed();
}

bool UVCAbility_BasicAttack::PerformAttack(const FGameplayAbilityActorInfo* ActorInfo, AActor* Target)
{
	AActor* Avatar = ActorInfo ? ActorInfo->AvatarActor.Get() : nullptr;
	const IVCCombatant* Self = Cast<IVCCombatant>(Avatar);
	const IVCCombatant* Other = Cast<IVCCombatant>(Target);
	if (!FVCCombatData::IsAvailable() || !Self || !Other || !Self->IsAlive() || !Other->IsAlive() || !IsHostile(Avatar, Target))
	{
		return false;
	}

	vc::rules::FWeaponDef Weapon;
	FName SkillCode;
	int32 SkillLevel = 1;
	if (!Self->GetAttack(Weapon, SkillCode, SkillLevel) || Weapon.RangeCm <= 0.0)
	{
		return false;
	}
	const vc::rules::FCombatTuning& Tuning = FVCCombatData::Tuning();
	const double Distance = FVector::Dist(Avatar->GetActorLocation(), Target->GetActorLocation());
	const double Now = Avatar->GetWorld()->GetTimeSeconds();
	if (!vc::rules::IsInRange(Distance, Weapon, Tuning) || !vc::rules::IsAttackReady(LastAttackTime, Now, Weapon, Tuning))
	{
		return false;
	}
	LastAttackTime = Now;

	UAbilitySystemComponent* TargetASC = UAbilitySystemBlueprintLibrary::GetAbilitySystemComponent(Target);
	UAbilitySystemComponent* SourceASC = GetAbilitySystemComponentFromActorInfo();
	if (!TargetASC || !SourceASC)
	{
		return false;
	}
	const FGameplayEffectSpecHandle Spec = MakeOutgoingGameplayEffectSpec(UVCDamageEffect::StaticClass(), 1.f);
	if (!Spec.IsValid())
	{
		return false;
	}
	Spec.Data->SetSetByCallerMagnitude(TAG_VC_Data_WeaponDamage,
		static_cast<float>(vc::rules::WeaponDamage(Weapon, SkillLevel, Tuning)));
	SourceASC->ApplyGameplayEffectSpecToTarget(*Spec.Data.Get(), TargetASC);

	if (!SkillCode.IsNone())
	{
		if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(Avatar->GetWorld()->GetAuthGameMode()))
		{
			Hooks->HandleWeaponHit(Avatar, SkillCode);
		}
	}
	return true;
}
