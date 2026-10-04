#include "VCCombatStateComponent.h"
#include "AbilitySystemComponent.h"
#include "AbilitySystemGlobals.h"
#include "Engine/World.h"
#include "GameFramework/Character.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Net/UnrealNetwork.h"
#include "TimerManager.h"
#include "VCAttributeSet.h"
#include "VCCombat.h"
#include "VCCombatData.h"
#include "VCCombatant.h"

namespace
{
	/** Wie oft der Server Ticks, Ablauf und Regeneration prüft. Kein Spielwert, sondern Last gegen Genauigkeit. */
	constexpr float ServerTickInterval = 0.25f;
}

FVCCombatTextEvent UVCCombatStateComponent::OnCombatText;

UVCCombatStateComponent::UVCCombatStateComponent()
{
	PrimaryComponentTick.bCanEverTick = false;
	SetIsReplicatedByDefault(true);
}

UVCCombatStateComponent* UVCCombatStateComponent::Find(const AActor* Actor)
{
	return Actor ? Actor->FindComponentByClass<UVCCombatStateComponent>() : nullptr;
}

void UVCCombatStateComponent::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);
	DOREPLIFETIME(UVCCombatStateComponent, Statuses);
	DOREPLIFETIME(UVCCombatStateComponent, MoveSpeedFactor);
	DOREPLIFETIME(UVCCombatStateComponent, bStunned);
}

void UVCCombatStateComponent::BeginPlay()
{
	Super::BeginPlay();
	if (const ACharacter* Character = Cast<ACharacter>(GetOwner()))
	{
		BaseWalkSpeed = Character->GetCharacterMovement()->MaxWalkSpeed;
	}
	if (GetOwner() && GetOwner()->HasAuthority())
	{
		GetWorld()->GetTimerManager().SetTimer(TickTimer, this, &UVCCombatStateComponent::ServerTick, ServerTickInterval, true);
	}
}

void UVCCombatStateComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (UWorld* World = GetWorld())
	{
		World->GetTimerManager().ClearTimer(TickTimer);
	}
	Super::EndPlay(EndPlayReason);
}

void UVCCombatStateComponent::ServerApplyStatus(FName Code, AActor* Instigator)
{
	const std::vector<vc::rules::FStatusDef>& Defs = FVCCombatData::StatusDefs();
	const int32 Index = FVCCombatData::StatusIndex(Code);
	if (!GetOwner() || !GetOwner()->HasAuthority() || Index < 0 || static_cast<size_t>(Index) >= Defs.size())
	{
		return;
	}
	vc::rules::ApplyStatus(Active, Index, Defs[static_cast<size_t>(Index)], GetWorld()->GetTimeSeconds());
	Instigators.Add(Index, Instigator);
	Refresh();
}

void UVCCombatStateComponent::ServerClearAll()
{
	if (!GetOwner() || !GetOwner()->HasAuthority() || Active.empty())
	{
		return;
	}
	Active.clear();
	Instigators.Reset();
	Refresh();
}

void UVCCombatStateComponent::ServerTick()
{
	AActor* Owner = GetOwner();
	const IVCCombatant* Self = Cast<IVCCombatant>(Owner);
	if (!Self || !FVCCombatData::IsAvailable())
	{
		return;
	}
	if (!Self->IsAlive())
	{
		ServerClearAll();
		return;
	}

	// Erst alles einsammeln, dann anwenden: Schaden kann zum Tod führen, und der Tod leert Active.
	struct FPending
	{
		double Damage = 0.0;
		double Heal = 0.0;
		TWeakObjectPtr<AActor> Causer;
	};
	TArray<FPending, TInlineAllocator<4>> Pending;
	const double Now = GetWorld()->GetTimeSeconds();
	const std::vector<vc::rules::FStatusDef>& Defs = FVCCombatData::StatusDefs();
	for (vc::rules::FActiveStatus& Status : Active)
	{
		if (Status.DefIndex < 0 || static_cast<size_t>(Status.DefIndex) >= Defs.size())
		{
			continue;
		}
		const vc::rules::FTickResult Due = vc::rules::CollectStatusTicks(Status, Defs[static_cast<size_t>(Status.DefIndex)], Now);
		if (Due.Damage > 0.0 || Due.Heal > 0.0)
		{
			FPending& Entry = Pending.AddDefaulted_GetRef();
			Entry.Damage = Due.Damage;
			Entry.Heal = Due.Heal;
			Entry.Causer = Instigators.FindRef(Status.DefIndex);
		}
	}
	if (vc::rules::RemoveExpired(Active, Now))
	{
		Refresh();
	}
	for (const FPending& Entry : Pending)
	{
		if (Entry.Heal > 0.0)
		{
			FVCCombat::ApplyHeal(Owner, Entry.Heal);
		}
		if (Entry.Damage > 0.0)
		{
			FVCCombat::ApplyDamage(Owner, Entry.Damage, Entry.Causer.Get(), true);
		}
	}

	const FVCCombatTuningRow* Tuning = FVCCombatData::TuningRow();
	UAbilitySystemComponent* ASC = UAbilitySystemGlobals::GetAbilitySystemComponentFromActor(Owner);
	if (bRegenerateStamina && Tuning && Tuning->StaminaRegenPerSecond > 0.0 && ASC && Self->IsAlive())
	{
		const double Stamina = ASC->GetNumericAttribute(UVCAttributeSet::GetStaminaAttribute());
		if (Stamina < ASC->GetNumericAttribute(UVCAttributeSet::GetMaxStaminaAttribute()))
		{
			UVCAttributeSet::SetVitals(ASC, ASC->GetNumericAttribute(UVCAttributeSet::GetHealthAttribute()),
				Stamina + Tuning->StaminaRegenPerSecond * ServerTickInterval);
		}
	}
}

void UVCCombatStateComponent::Refresh()
{
	Modifiers = vc::rules::Aggregate(Active, FVCCombatData::StatusDefs());
	bStunned = Modifiers.bStunned;
	MoveSpeedFactor = static_cast<float>(vc::rules::MoveSpeedFactor(Modifiers));
	Statuses.Reset();
	for (const vc::rules::FActiveStatus& Status : Active)
	{
		FVCStatusView& View = Statuses.AddDefaulted_GetRef();
		View.Code = FVCCombatData::StatusCode(Status.DefIndex);
		View.Stacks = Status.Stacks;
		View.ExpiresAt = Status.ExpiresAt;
	}
	ApplyWalkSpeed();
}

void UVCCombatStateComponent::OnRep_MoveSpeedFactor()
{
	// Auch auf dem Client setzen, damit die Bewegungsvorhersage nicht ständig korrigiert wird.
	ApplyWalkSpeed();
}

void UVCCombatStateComponent::ApplyWalkSpeed()
{
	const ACharacter* Character = Cast<ACharacter>(GetOwner());
	UCharacterMovementComponent* Movement = Character ? Character->GetCharacterMovement() : nullptr;
	if (!Movement)
	{
		return;
	}
	if (BaseWalkSpeed < 0.f)
	{
		BaseWalkSpeed = Movement->MaxWalkSpeed;
	}
	Movement->MaxWalkSpeed = BaseWalkSpeed * MoveSpeedFactor;
}

void UVCCombatStateComponent::ShowCombatText(EVCCombatText Kind, double Amount)
{
	if (GetOwner() && GetOwner()->HasAuthority())
	{
		MulticastCombatText(Kind, FMath::RoundToInt(Amount));
	}
}

void UVCCombatStateComponent::MulticastCombatText_Implementation(EVCCombatText Kind, int32 Amount)
{
	if (GetNetMode() != NM_DedicatedServer)
	{
		OnCombatText.Broadcast(GetOwner(), Kind, Amount);
	}
}
