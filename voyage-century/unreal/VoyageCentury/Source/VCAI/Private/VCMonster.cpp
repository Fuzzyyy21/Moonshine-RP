#include "VCMonster.h"
#include "AbilitySystemComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Net/UnrealNetwork.h"
#include "UObject/ConstructorHelpers.h"
#include "VCAbility_BasicAttack.h"
#include "VCAttributeSet.h"
#include "VCCombatData.h"
#include "VCCore.h"
#include "VCGameplayTags.h"
#include "VCMonsterAIController.h"
#include "VCServerHooks.h"

AVCMonster::AVCMonster()
{
	bReplicates = true;
	AIControllerClass = AVCMonsterAIController::StaticClass();
	AutoPossessAI = EAutoPossessAI::PlacedInWorldOrSpawned;

	AbilitySystem = CreateDefaultSubobject<UAbilitySystemComponent>(TEXT("AbilitySystem"));
	AbilitySystem->SetIsReplicated(true);
	// Minimal: Gegner brauchen keine Effektreplikation, nur Attribute und Tags.
	AbilitySystem->SetReplicationMode(EGameplayEffectReplicationMode::Minimal);
	Attributes = CreateDefaultSubobject<UVCAttributeSet>(TEXT("Attributes"));

	PlaceholderBody = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("PlaceholderBody"));
	PlaceholderBody->SetupAttachment(GetCapsuleComponent());
	PlaceholderBody->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	PlaceholderBody->SetRelativeScale3D(FVector(0.8f, 0.8f, 1.76f));
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(TEXT("/Engine/BasicShapes/Cube.Cube"));
	if (Cube.Succeeded())
	{
		PlaceholderBody->SetStaticMesh(Cube.Object); // Würfel = Gegner, Zylinder = Spieler
	}
	GetCharacterMovement()->bOrientRotationToMovement = true;
}

void AVCMonster::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);
	DOREPLIFETIME(AVCMonster, MonsterCode);
}

UAbilitySystemComponent* AVCMonster::GetAbilitySystemComponent() const
{
	return AbilitySystem;
}

const FVCMonsterRow* AVCMonster::GetRow() const
{
	return FVCCombatData::FindMonster(MonsterCode);
}

void AVCMonster::BeginPlay()
{
	Super::BeginPlay();
	AbilitySystem->InitAbilityActorInfo(this, this);
	HomeLocation = GetActorLocation();
	if (!HasAuthority())
	{
		return;
	}
	const FVCMonsterRow* Row = GetRow();
	if (!FVCCombatData::IsAvailable() || !Row)
	{
		UE_LOG(LogVC, Error, TEXT("Gegner %s ohne Daten in DT_Monsters – entfernt"), *MonsterCode.ToString());
		Destroy();
		return;
	}
	AbilitySystem->GiveAbility(FGameplayAbilitySpec(UVCAbility_BasicAttack::StaticClass(), 1));
	const vc::rules::FCombatStats Stats = FVCCombatData::StatsOf(*Row);
	UVCAttributeSet::ApplyStats(AbilitySystem, Stats);
	UVCAttributeSet::SetVitals(AbilitySystem, Stats.MaxHealth, Stats.MaxStamina);
}

bool AVCMonster::IsAlive() const
{
	return !AbilitySystem->HasMatchingGameplayTag(TAG_VC_State_Dead)
		&& AbilitySystem->GetNumericAttribute(UVCAttributeSet::GetHealthAttribute()) > 0.f;
}

bool AVCMonster::GetAttack(vc::rules::FWeaponDef& OutWeapon, FName& OutSkillCode, int32& OutSkillLevel) const
{
	const FVCMonsterRow* Row = GetRow();
	if (!Row)
	{
		return false;
	}
	OutWeapon = FVCCombatData::AttackOf(*Row);
	OutSkillCode = NAME_None;
	OutSkillLevel = 1;
	return true;
}

void AVCMonster::HandleOutOfHealth(AActor* Killer)
{
	if (!HasAuthority())
	{
		return;
	}
	AbilitySystem->AddLooseGameplayTag(TAG_VC_State_Dead);
	GetCharacterMovement()->DisableMovement();
	SetActorEnableCollision(false);
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(GetWorld()->GetAuthGameMode()))
	{
		Hooks->HandleKill(Killer, this);
	}
	SetLifeSpan(3.f); // kurz liegen lassen, dann entfernen; der Spawner setzt neu ein
}

void AVCMonster::ServerRestoreHealth()
{
	if (const FVCMonsterRow* Row = HasAuthority() ? GetRow() : nullptr)
	{
		UVCAttributeSet::SetVitals(AbilitySystem, Row->MaxHealth, 0.0);
	}
}
