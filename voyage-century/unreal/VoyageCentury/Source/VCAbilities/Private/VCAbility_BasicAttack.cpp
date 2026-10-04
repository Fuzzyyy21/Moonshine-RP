#include "VCAbility_BasicAttack.h"
#include "Engine/World.h"
#include "VCCombat.h"
#include "VCCombatData.h"
#include "VCCombatant.h"
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

bool UVCAbility_BasicAttack::PerformAttack(const FGameplayAbilityActorInfo* ActorInfo, AActor* Target)
{
	AActor* Avatar = ActorInfo ? ActorInfo->AvatarActor.Get() : nullptr;
	const IVCCombatant* Self = Cast<IVCCombatant>(Avatar);
	const IVCCombatant* Other = Cast<IVCCombatant>(Target);
	if (!FVCCombatData::IsAvailable() || !Self || !Other || !Self->IsAlive() || !Other->IsAlive()
		|| FVCCombat::IsStunned(Avatar) || !FVCCombat::IsHostile(Avatar, Target))
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

	const vc::rules::FAttackOutcome Outcome =
		FVCCombat::Strike(Avatar, Target, vc::rules::WeaponDamage(Weapon, SkillLevel, Tuning));

	// Skill-XP nur für Treffer (auch geblockte), nicht für Ausweichen.
	if (!SkillCode.IsNone() && Outcome.Result != vc::rules::EHitResult::Dodged)
	{
		if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(Avatar->GetWorld()->GetAuthGameMode()))
		{
			Hooks->HandleSkillUse(Avatar, SkillCode);
		}
	}
	return true;
}
