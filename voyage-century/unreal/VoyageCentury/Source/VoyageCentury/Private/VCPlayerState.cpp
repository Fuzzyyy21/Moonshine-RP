#include "VCPlayerState.h"
#include "AbilitySystemComponent.h"
#include "VCAbilityStateComponent.h"
#include "VCAbility_BasicAttack.h"
#include "VCAbility_UseSkill.h"
#include "VCAttributeSet.h"
#include "VCProgressionComponent.h"

AVCPlayerState::AVCPlayerState()
{
	Progression = CreateDefaultSubobject<UVCProgressionComponent>(TEXT("Progression"));

	AbilitySystem = CreateDefaultSubobject<UAbilitySystemComponent>(TEXT("AbilitySystem"));
	AbilitySystem->SetIsReplicated(true);
	// Mixed: Effekte nur an den Besitzer, Tags und Cues an alle.
	AbilitySystem->SetReplicationMode(EGameplayEffectReplicationMode::Mixed);
	Attributes = CreateDefaultSubobject<UVCAttributeSet>(TEXT("Attributes"));
	AbilityState = CreateDefaultSubobject<UVCAbilityStateComponent>(TEXT("AbilityState"));

	// Kampfwerte sollen zügig ankommen; Standard-PlayerState repliziert nur selten.
	SetNetUpdateFrequency(100.f);
}

UAbilitySystemComponent* AVCPlayerState::GetAbilitySystemComponent() const
{
	return AbilitySystem;
}

void AVCPlayerState::BeginPlay()
{
	Super::BeginPlay();
	if (HasAuthority())
	{
		AbilitySystem->GiveAbility(FGameplayAbilitySpec(UVCAbility_BasicAttack::StaticClass(), 1));
		AbilitySystem->GiveAbility(FGameplayAbilitySpec(UVCAbility_UseSkill::StaticClass(), 1));
	}
}
