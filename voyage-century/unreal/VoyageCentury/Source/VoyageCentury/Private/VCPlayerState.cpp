#include "VCPlayerState.h"
#include "AbilitySystemComponent.h"
#include "VCAbility_BasicAttack.h"
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
	}
}
