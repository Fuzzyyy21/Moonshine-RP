#include "VCDamage.h"
#include "VCAttributeSet.h"
#include "VCGameplayTags.h"

UVCDamageEffect::UVCDamageEffect()
{
	DurationPolicy = EGameplayEffectDurationType::Instant;

	FSetByCallerFloat Damage;
	Damage.DataTag = TAG_VC_Data_Damage;

	FGameplayModifierInfo Modifier;
	Modifier.Attribute = UVCAttributeSet::GetIncomingDamageAttribute();
	Modifier.ModifierOp = EGameplayModOp::Additive;
	Modifier.ModifierMagnitude = FGameplayEffectModifierMagnitude(Damage);
	Modifiers.Add(Modifier);
}
