#include "VCMonsterAIController.h"
#include "AbilitySystemBlueprintLibrary.h"
#include "EngineUtils.h"
#include "TimerManager.h"
#include "VCCombat.h"
#include "VCCombatant.h"
#include "VCDataRows.h"
#include "VCGameplayTags.h"
#include "VCMonster.h"

namespace
{
	/** Wie oft die KI entscheidet. Kein Spielwert, sondern Serverlast gegen Reaktionszeit. */
	constexpr float ThinkInterval = 0.25f;
}

AVCMonsterAIController::AVCMonsterAIController()
{
	bAttachToPawn = true;
}

void AVCMonsterAIController::OnPossess(APawn* InPawn)
{
	Super::OnPossess(InPawn);
	GetWorldTimerManager().SetTimer(ThinkTimer, this, &AVCMonsterAIController::Think, ThinkInterval, true);
}

void AVCMonsterAIController::OnUnPossess()
{
	GetWorldTimerManager().ClearTimer(ThinkTimer);
	Super::OnUnPossess();
}

AActor* AVCMonsterAIController::FindTarget(const AVCMonster& Monster, double AggroRadius) const
{
	AActor* Best = nullptr;
	double BestDistSq = AggroRadius * AggroRadius;
	for (TActorIterator<APawn> It(GetWorld()); It; ++It)
	{
		const IVCCombatant* Other = Cast<IVCCombatant>(*It);
		if (!Other || !Other->IsPlayerCharacter() || !Other->IsAlive())
		{
			continue;
		}
		const double DistSq = FVector::DistSquared(Monster.GetActorLocation(), It->GetActorLocation());
		if (DistSq <= BestDistSq)
		{
			BestDistSq = DistSq;
			Best = *It;
		}
	}
	return Best;
}

void AVCMonsterAIController::Think()
{
	AVCMonster* Monster = Cast<AVCMonster>(GetPawn());
	const FVCMonsterRow* Row = Monster ? Monster->GetRow() : nullptr;
	if (!Monster || !Row || !Monster->IsAlive() || FVCCombat::IsStunned(Monster))
	{
		StopMovement(); // Betäubt: weder laufen noch angreifen; Verlangsamung wirkt über die Laufgeschwindigkeit
		return;
	}

	const double FromHome = FVector::Dist(Monster->GetActorLocation(), Monster->GetHomeLocation());
	switch (State)
	{
	case EState::Idle:
		if (Row->AggroRadiusCm > 0.0 && Row->RangeCm > 0.0)
		{
			if (AActor* Found = FindTarget(*Monster, Row->AggroRadiusCm))
			{
				Target = Found;
				State = EState::Chase;
			}
		}
		break;

	case EState::Chase:
	{
		const IVCCombatant* Other = Cast<IVCCombatant>(Target.Get());
		if (!Other || !Other->IsAlive() || (Row->LeashRadiusCm > 0.0 && FromHome > Row->LeashRadiusCm))
		{
			Target.Reset();
			State = EState::Return;
			MoveToLocation(Monster->GetHomeLocation());
			break;
		}
		const double Distance = FVector::Dist(Monster->GetActorLocation(), Target->GetActorLocation());
		if (Distance <= Row->RangeCm)
		{
			StopMovement();
			SetFocus(Target.Get());
			// Gleiche Fähigkeit und Regeln wie bei Spielern: Reichweite und Intervall prüft der Grundangriff.
			FGameplayEventData Payload;
			Payload.Instigator = Monster;
			Payload.Target = Target.Get();
			UAbilitySystemBlueprintLibrary::SendGameplayEventToActor(Monster, TAG_VC_Event_Attack, Payload);
		}
		else
		{
			ClearFocus(EAIFocusPriority::Gameplay);
			MoveToActor(Target.Get(), static_cast<float>(Row->RangeCm * 0.8));
		}
		break;
	}

	case EState::Return:
		if (FromHome < 100.0)
		{
			Monster->ServerRestoreHealth();
			State = EState::Idle;
		}
		break;
	}
}
