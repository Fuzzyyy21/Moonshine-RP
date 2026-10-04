#include "VCAbilityStateComponent.h"
#include "Engine/World.h"
#include "GameFramework/GameStateBase.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PlayerState.h"
#include "Net/UnrealNetwork.h"
#include "VCAbilityRules.h"

static_assert(static_cast<uint8>(vc::rules::EAbilityBlock::OutOfRange) == static_cast<uint8>(EVCAbilityBlock::OutOfRange),
	"EVCAbilityBlock muss vc::rules::EAbilityBlock spiegeln");

UVCAbilityStateComponent::UVCAbilityStateComponent()
{
	PrimaryComponentTick.bCanEverTick = false;
	SetIsReplicatedByDefault(true);
	Hotbar.SetNum(HotbarSlots);
}

UVCAbilityStateComponent* UVCAbilityStateComponent::Find(const AActor* Actor)
{
	if (!Actor)
	{
		return nullptr;
	}
	if (UVCAbilityStateComponent* Own = Actor->FindComponentByClass<UVCAbilityStateComponent>())
	{
		return Own;
	}
	const APawn* Pawn = Cast<APawn>(Actor);
	const APlayerState* PlayerState = Pawn ? Pawn->GetPlayerState() : nullptr;
	return PlayerState ? PlayerState->FindComponentByClass<UVCAbilityStateComponent>() : nullptr;
}

void UVCAbilityStateComponent::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);
	DOREPLIFETIME_CONDITION(UVCAbilityStateComponent, Hotbar, COND_OwnerOnly);
	DOREPLIFETIME_CONDITION(UVCAbilityStateComponent, Cooldowns, COND_OwnerOnly);
}

FName UVCAbilityStateComponent::GetHotbarSlot(int32 Slot) const
{
	return Hotbar.IsValidIndex(Slot) ? Hotbar[Slot] : NAME_None;
}

double UVCAbilityStateComponent::GetRemainingCooldown(FName Code) const
{
	const UWorld* World = GetWorld();
	if (!World)
	{
		return 0.0;
	}
	const AGameStateBase* GameState = World->GetGameState();
	const double Now = GameState ? GameState->GetServerWorldTimeSeconds() : World->GetTimeSeconds();
	for (const FVCCooldownView& Cooldown : Cooldowns)
	{
		if (Cooldown.Code == Code)
		{
			return FMath::Max(0.0, Cooldown.ReadyAt - Now);
		}
	}
	return 0.0;
}

void UVCAbilityStateComponent::ServerSetHotbar(const TArray<FName>& Slots)
{
	if (!GetOwner() || !GetOwner()->HasAuthority())
	{
		return;
	}
	Hotbar = Slots;
	Hotbar.SetNum(HotbarSlots);
	OnHotbarChanged.Broadcast();
}

double UVCAbilityStateComponent::GetLastUse(FName Code) const
{
	const double* Found = LastUse.Find(Code);
	return Found ? *Found : -1.0;
}

void UVCAbilityStateComponent::ServerMarkUsed(FName Code, double Now, double CooldownSeconds)
{
	if (!GetOwner() || !GetOwner()->HasAuthority())
	{
		return;
	}
	LastUse.Add(Code, Now);
	FVCCooldownView* View = Cooldowns.FindByPredicate([Code](const FVCCooldownView& C) { return C.Code == Code; });
	if (!View)
	{
		View = &Cooldowns.AddDefaulted_GetRef();
		View->Code = Code;
	}
	View->ReadyAt = Now + CooldownSeconds;
}

void UVCAbilityStateComponent::ServerReportBlocked(FName Code, EVCAbilityBlock Reason)
{
	if (GetOwner() && GetOwner()->HasAuthority())
	{
		ClientAbilityBlocked(Code, Reason);
	}
}

void UVCAbilityStateComponent::ClientAbilityBlocked_Implementation(FName Code, EVCAbilityBlock Reason)
{
	OnAbilityBlocked.Broadcast(Code, Reason);
}

void UVCAbilityStateComponent::OnRep_Hotbar()
{
	OnHotbarChanged.Broadcast();
}
