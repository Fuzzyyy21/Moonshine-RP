#include "VCAbility_UseSkill.h"
#include "AbilitySystemComponent.h"
#include "Engine/World.h"
#include "VCAbilityRules.h"
#include "VCAttributeSet.h"
#include "VCCombat.h"
#include "VCCombatData.h"
#include "VCCombatStateComponent.h"
#include "VCCombatant.h"
#include "VCGameplayTags.h"
#include "VCServerHooks.h"

UVCAbility_UseSkill::UVCAbility_UseSkill()
{
	InstancingPolicy = EGameplayAbilityInstancingPolicy::InstancedPerActor;
	NetExecutionPolicy = EGameplayAbilityNetExecutionPolicy::ServerOnly;
	ActivationBlockedTags.AddTag(TAG_VC_State_Dead);

	FAbilityTriggerData Trigger;
	Trigger.TriggerTag = TAG_VC_Event_UseAbility;
	Trigger.TriggerSource = EGameplayAbilityTriggerSource::GameplayEvent;
	AbilityTriggers.Add(Trigger);
}

FGameplayEventData UVCAbility_UseSkill::MakeRequest(AActor* User, FName AbilityCode, AActor* Target)
{
	FGameplayEventData Payload;
	Payload.Instigator = User;
	Payload.Target = Target;
	FVCAbilityRequest* Request = new FVCAbilityRequest();
	Request->AbilityCode = AbilityCode;
	Payload.TargetData.Add(Request); // Handle übernimmt den Besitz
	return Payload;
}

void UVCAbility_UseSkill::ActivateAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
	const FGameplayAbilityActivationInfo ActivationInfo, const FGameplayEventData* TriggerEventData)
{
	FName Code;
	AActor* Target = nullptr;
	if (TriggerEventData)
	{
		const FGameplayAbilityTargetData* Data = TriggerEventData->TargetData.Get(0);
		if (Data && Data->GetScriptStruct() == FVCAbilityRequest::StaticStruct())
		{
			Code = static_cast<const FVCAbilityRequest*>(Data)->AbilityCode;
		}
		Target = const_cast<AActor*>(TriggerEventData->Target.Get());
	}

	const EVCAbilityBlock Result = Use(ActorInfo, Code, Target);
	if (Result != EVCAbilityBlock::None)
	{
		if (UVCAbilityStateComponent* State = UVCAbilityStateComponent::Find(ActorInfo ? ActorInfo->OwnerActor.Get() : nullptr))
		{
			State->ServerReportBlocked(Code, Result);
		}
	}
	EndAbility(Handle, ActorInfo, ActivationInfo, true, Result != EVCAbilityBlock::None);
}

EVCAbilityBlock UVCAbility_UseSkill::Use(const FGameplayAbilityActorInfo* ActorInfo, FName Code, AActor* Target)
{
	AActor* Avatar = ActorInfo ? ActorInfo->AvatarActor.Get() : nullptr;
	const IVCCombatant* Self = Cast<IVCCombatant>(Avatar);
	UVCAbilityStateComponent* State = UVCAbilityStateComponent::Find(ActorInfo ? ActorInfo->OwnerActor.Get() : nullptr);
	const FVCAbilityRow* Row = FVCCombatData::AreAbilitiesAvailable() ? FVCCombatData::FindAbility(Code) : nullptr;
	UAbilitySystemComponent* ASC = GetAbilitySystemComponentFromActorInfo();
	vc::rules::FWeaponDef Weapon;
	FName WeaponSkill;
	int32 WeaponSkillLevel = 1;
	if (!Avatar || !Self || !State || !Row || !ASC || !Self->GetAttack(Weapon, WeaponSkill, WeaponSkillLevel))
	{
		return EVCAbilityBlock::Unavailable;
	}

	const vc::rules::FAbilityDef Def = FVCCombatData::ToRules(*Row);
	const vc::rules::FCombatTuning& Tuning = FVCCombatData::Tuning();
	const double Now = Avatar->GetWorld()->GetTimeSeconds();
	const IVCCombatant* Other = Cast<IVCCombatant>(Target);

	vc::rules::FAbilityUseContext Context;
	Context.bAlive = Self->IsAlive();
	Context.bStunned = FVCCombat::IsStunned(Avatar);
	Context.EquippedWeaponClass = Weapon.Class;
	Context.SkillLevel = Self->GetSkillLevel(Row->SkillCode);
	Context.Stamina = ASC->GetNumericAttribute(UVCAttributeSet::GetStaminaAttribute());
	Context.LastUseTime = State->GetLastUse(Code);
	Context.Now = Now;
	Context.bHasTarget = Other != nullptr;
	Context.bTargetAlive = Other && Other->IsAlive();
	Context.bTargetHostile = Other && FVCCombat::IsHostile(Avatar, Target);
	Context.DistanceCm = Target ? FVector::Dist(Avatar->GetActorLocation(), Target->GetActorLocation()) : 0.0;
	Context.WeaponRangeCm = Weapon.RangeCm;

	const vc::rules::EAbilityBlock Block = vc::rules::CheckAbilityUse(Def, Context, Tuning);
	if (Block != vc::rules::EAbilityBlock::None)
	{
		return static_cast<EVCAbilityBlock>(static_cast<uint8>(Block));
	}
	if (!FVCCombat::SpendStamina(Avatar, Def.StaminaCost))
	{
		return EVCAbilityBlock::NotEnoughStamina;
	}
	State->ServerMarkUsed(Code, Now, Def.CooldownSeconds);

	const bool bOnSelf = Def.TargetMode == vc::rules::ETargetMode::Self;
	AActor* Affected = bOnSelf ? Avatar : Target;
	bool bLanded = true;
	if (!bOnSelf && Def.DamageMultiplier > 0.0)
	{
		const double Damage = vc::rules::WeaponDamage(Weapon, WeaponSkillLevel, Tuning) * Def.DamageMultiplier;
		bLanded = FVCCombat::Strike(Avatar, Target, Damage).Result != vc::rules::EHitResult::Dodged;
	}
	const IVCCombatant* AffectedCombatant = Cast<IVCCombatant>(Affected);
	UVCCombatStateComponent* AffectedState = UVCCombatStateComponent::Find(Affected);
	if (bLanded && AffectedCombatant && AffectedCombatant->IsAlive() && AffectedState)
	{
		for (const FName& Status : Row->AppliedStatuses)
		{
			AffectedState->ServerApplyStatus(Status, Avatar);
		}
	}
	if (bLanded && !Row->SkillCode.IsNone())
	{
		if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(Avatar->GetWorld()->GetAuthGameMode()))
		{
			Hooks->HandleSkillUse(Avatar, Row->SkillCode);
		}
	}
	return EVCAbilityBlock::None;
}
