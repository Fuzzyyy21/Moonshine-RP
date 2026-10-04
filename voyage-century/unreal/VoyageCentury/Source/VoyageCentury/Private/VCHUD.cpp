#include "VCHUD.h"
#include "AbilitySystemComponent.h"
#include "AbilitySystemGlobals.h"
#include "Engine/Canvas.h"
#include "Engine/Engine.h"
#include "Engine/Font.h"
#include "Engine/World.h"
#include "GameFramework/GameStateBase.h"
#include "GameFramework/PlayerController.h"
#include "VCAttributeSet.h"
#include "VCCharacter.h"
#include "VCCombatData.h"
#include "VCCombatant.h"
#include "VCPlayerController.h"
#include "VCNavalData.h"
#include "VCPlayerState.h"
#include "VCShip.h"
#include "VCWorldData.h"
#include "VCProgressionComponent.h"

namespace
{
	constexpr double FloatingTextSeconds = 1.5;
	constexpr double NoticeSeconds = 2.0;
	constexpr double DialogSeconds = 10.0;
	constexpr float SlotSize = 58.f;
	constexpr float SlotGap = 6.f;

	const FLinearColor Panel(0.f, 0.f, 0.f, 0.55f);
	const FLinearColor HealthColor(0.75f, 0.12f, 0.10f, 1.f);
	const FLinearColor StaminaColor(0.85f, 0.70f, 0.15f, 1.f);
	const FLinearColor BuffColor(0.45f, 0.95f, 0.45f, 1.f);
	const FLinearColor DebuffColor(1.f, 0.45f, 0.40f, 1.f);

	UFont* SmallFont()
	{
		return GEngine ? GEngine->GetSmallFont() : nullptr;
	}

	const TCHAR* BlockText(EVCAbilityBlock Reason)
	{
		switch (Reason)
		{
		case EVCAbilityBlock::Dead: return TEXT("Du bist besiegt");
		case EVCAbilityBlock::Stunned: return TEXT("Betäubt");
		case EVCAbilityBlock::WrongWeapon: return TEXT("Falsche Waffe");
		case EVCAbilityBlock::SkillTooLow: return TEXT("Skillstufe zu niedrig");
		case EVCAbilityBlock::OnCooldown: return TEXT("Noch nicht bereit");
		case EVCAbilityBlock::NotEnoughStamina: return TEXT("Nicht genug Ausdauer");
		case EVCAbilityBlock::NoTarget: return TEXT("Kein Ziel");
		case EVCAbilityBlock::TargetNotHostile: return TEXT("Kein feindliches Ziel");
		case EVCAbilityBlock::OutOfRange: return TEXT("Zu weit entfernt");
		default: return TEXT("Fähigkeit nicht verfügbar");
		}
	}

	double Attribute(const AActor* Actor, const FGameplayAttribute& Which)
	{
		const UAbilitySystemComponent* ASC = UAbilitySystemGlobals::GetAbilitySystemComponentFromActor(Actor);
		return ASC ? ASC->GetNumericAttribute(Which) : 0.0;
	}
}

void AVCHUD::BeginPlay()
{
	Super::BeginPlay();
	CombatTextHandle = UVCCombatStateComponent::OnCombatText.AddUObject(this, &AVCHUD::OnCombatText);
	ShipHitHandle = AVCShip::OnShipHit.AddUObject(this, &AVCHUD::OnShipHit);
}

void AVCHUD::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	UVCCombatStateComponent::OnCombatText.Remove(CombatTextHandle);
	AVCShip::OnShipHit.Remove(ShipHitHandle);
	if (UVCAbilityStateComponent* State = BoundAbilityState.Get())
	{
		State->OnAbilityBlocked.Remove(BlockedHandle);
	}
	Super::EndPlay(EndPlayReason);
}

double AVCHUD::LocalNow() const
{
	return GetWorld() ? GetWorld()->GetTimeSeconds() : 0.0;
}

double AVCHUD::ServerNow() const
{
	const AGameStateBase* GameState = GetWorld() ? GetWorld()->GetGameState() : nullptr;
	return GameState ? GameState->GetServerWorldTimeSeconds() : LocalNow();
}

void AVCHUD::OnCombatText(AActor* Target, EVCCombatText Kind, int32 Amount)
{
	FFloatingText& Entry = FloatingTexts.AddDefaulted_GetRef();
	Entry.Actor = Target;
	Entry.StartTime = LocalNow();
	switch (Kind)
	{
	case EVCCombatText::Critical: Entry.Text = FString::Printf(TEXT("%d!"), Amount); Entry.Color = FLinearColor::Yellow; break;
	case EVCCombatText::Blocked: Entry.Text = FString::Printf(TEXT("Block %d"), Amount); Entry.Color = FLinearColor::Gray; break;
	case EVCCombatText::Dodged: Entry.Text = TEXT("Ausgewichen"); Entry.Color = FLinearColor(0.6f, 0.8f, 1.f); break;
	case EVCCombatText::Periodic: Entry.Text = FString::Printf(TEXT("%d"), Amount); Entry.Color = FLinearColor(1.f, 0.6f, 0.2f); break;
	case EVCCombatText::Heal: Entry.Text = FString::Printf(TEXT("+%d"), Amount); Entry.Color = BuffColor; break;
	default: Entry.Text = FString::Printf(TEXT("%d"), Amount); Entry.Color = FLinearColor::White; break;
	}
}

void AVCHUD::OnAbilityBlocked(FName Code, EVCAbilityBlock Reason)
{
	const FVCAbilityRow* Row = FVCCombatData::FindAbility(Code);
	Notice = FString::Printf(TEXT("%s: %s"), Row ? *Row->NameDe : *Code.ToString(), BlockText(Reason));
	NoticeUntil = LocalNow() + NoticeSeconds;
}

void AVCHUD::DrawHUD()
{
	Super::DrawHUD();
	if (!Canvas || !PlayerOwner)
	{
		return;
	}
	// Die Hotbar-Komponente kommt mit dem PlayerState, also erst nach einigen Frames.
	if (!BoundAbilityState.IsValid())
	{
		if (UVCAbilityStateComponent* State = UVCAbilityStateComponent::Find(PlayerOwner->PlayerState))
		{
			BoundAbilityState = State;
			BlockedHandle = State->OnAbilityBlocked.AddUObject(this, &AVCHUD::OnAbilityBlocked);
		}
	}
	if (!bBoundController)
	{
		if (AVCPlayerController* VCPC = Cast<AVCPlayerController>(PlayerOwner))
		{
			VCPC->OnNpcDialog.AddUObject(this, &AVCHUD::OnNpcDialog);
			VCPC->OnDiscovered.AddUObject(this, &AVCHUD::OnDiscovered);
			bBoundController = true;
		}
	}
	DrawOwnFrame();
	DrawTargetFrame();
	DrawHotbar();
	DrawFloatingTexts();
	DrawNotice();
	DrawNpcDialog();
	DrawShipPanel();
}

void AVCHUD::DrawBar(float X, float Y, float Width, float Height, double Value, double Max, const FLinearColor& Color, const FString& Label)
{
	DrawRect(Panel, X, Y, Width, Height);
	const double Fraction = Max > 0.0 ? FMath::Clamp(Value / Max, 0.0, 1.0) : 0.0;
	DrawRect(Color, X + 1.f, Y + 1.f, static_cast<float>((Width - 2.f) * Fraction), Height - 2.f);
	DrawText(FString::Printf(TEXT("%s %.0f / %.0f"), *Label, Value, Max), FLinearColor::White, X + 6.f, Y + 2.f, SmallFont());
}

void AVCHUD::DrawStatuses(float X, float Y, const UVCCombatStateComponent* State)
{
	if (!State)
	{
		return;
	}
	const double Now = ServerNow();
	for (const FVCStatusView& Status : State->GetStatuses())
	{
		const FVCStatusEffectRow* Row = FVCCombatData::FindStatus(Status.Code);
		const FString Name = Row ? Row->NameDe : Status.Code.ToString();
		const FString Stacks = Status.Stacks > 1 ? FString::Printf(TEXT(" x%d"), Status.Stacks) : FString();
		const bool bBuff = Row && Row->Kind == EVCStatusKind::Buff;
		DrawText(FString::Printf(TEXT("%s%s (%.0f s)"), *Name, *Stacks, FMath::Max(0.0, Status.ExpiresAt - Now)),
			bBuff ? BuffColor : DebuffColor, X, Y, SmallFont());
		Y += 16.f;
	}
}

void AVCHUD::DrawOwnFrame()
{
	const APlayerState* PlayerState = PlayerOwner->PlayerState;
	if (!PlayerState)
	{
		return;
	}
	const float X = 20.f;
	const float Y = Canvas->ClipY - 150.f;
	DrawBar(X, Y, 260.f, 20.f, Attribute(PlayerState, UVCAttributeSet::GetHealthAttribute()),
		Attribute(PlayerState, UVCAttributeSet::GetMaxHealthAttribute()), HealthColor, TEXT("Leben"));
	DrawBar(X, Y + 24.f, 260.f, 20.f, Attribute(PlayerState, UVCAttributeSet::GetStaminaAttribute()),
		Attribute(PlayerState, UVCAttributeSet::GetMaxStaminaAttribute()), StaminaColor, TEXT("Ausdauer"));
	DrawStatuses(X, Y + 50.f, UVCCombatStateComponent::Find(PlayerOwner->GetPawn()));
}

void AVCHUD::DrawTargetFrame()
{
	const AVCCharacter* Me = Cast<AVCCharacter>(PlayerOwner->GetPawn());
	const AActor* Target = Me ? Me->GetCurrentTarget() : nullptr;
	const IVCCombatant* Combatant = Cast<IVCCombatant>(Target);
	if (!Combatant)
	{
		return;
	}
	const float Width = 300.f;
	const float X = (Canvas->ClipX - Width) * 0.5f;
	const float Y = 20.f;
	const FString Name = Combatant->IsAlive() ? Combatant->GetCombatName().ToString()
		: FString::Printf(TEXT("%s (besiegt)"), *Combatant->GetCombatName().ToString());
	DrawText(Name, FLinearColor::White, X, Y, SmallFont());
	DrawBar(X, Y + 18.f, Width, 20.f, Attribute(Target, UVCAttributeSet::GetHealthAttribute()),
		Attribute(Target, UVCAttributeSet::GetMaxHealthAttribute()), HealthColor, TEXT("Leben"));
	if (Me)
	{
		DrawText(FString::Printf(TEXT("%.1f m"), FVector::Dist(Me->GetActorLocation(), Target->GetActorLocation()) / 100.0),
			FLinearColor::Gray, X + Width + 8.f, Y + 20.f, SmallFont());
	}
	DrawStatuses(X, Y + 42.f, UVCCombatStateComponent::Find(Target));
}

void AVCHUD::DrawHotbar()
{
	const UVCAbilityStateComponent* State = BoundAbilityState.Get();
	if (!State)
	{
		return;
	}
	const AVCPlayerState* PlayerState = Cast<AVCPlayerState>(PlayerOwner->PlayerState);
	const AVCCharacter* Me = Cast<AVCCharacter>(PlayerOwner->GetPawn());
	const FName WeaponCode = Me && !Me->GetEquippedWeapon().IsNone() ? Me->GetEquippedWeapon() : GetDefault<UVCCombatSettings>()->UnarmedWeapon;
	const FVCWeaponRow* Weapon = FVCCombatData::FindWeapon(WeaponCode);

	const int32 Count = UVCAbilityStateComponent::HotbarSlots;
	const float Total = Count * SlotSize + (Count - 1) * SlotGap;
	float X = (Canvas->ClipX - Total) * 0.5f;
	const float Y = Canvas->ClipY - SlotSize - 20.f;
	for (int32 Slot = 0; Slot < Count; ++Slot, X += SlotSize + SlotGap)
	{
		DrawRect(Panel, X, Y, SlotSize, SlotSize);
		DrawText(FString::FromInt((Slot + 1) % 10), FLinearColor::Gray, X + 3.f, Y + 2.f, SmallFont());
		const FName Code = State->GetHotbarSlot(Slot);
		const FVCAbilityRow* Row = FVCCombatData::FindAbility(Code);
		if (!Row)
		{
			continue;
		}
		// Nur Hinweise für die Anzeige; ob es geht, entscheidet der Server.
		int32 SkillLevel = 1;
		if (PlayerState)
		{
			for (const FVCSkillState& Skill : PlayerState->GetProgression()->GetSkills())
			{
				SkillLevel = Skill.Code == Row->SkillCode ? Skill.Level : SkillLevel;
			}
		}
		const bool bSkillOk = SkillLevel >= Row->RequiredSkillLevel;
		const bool bWeaponOk = !Row->bRequiresWeaponClass || (Weapon && Weapon->WeaponClass == Row->RequiredWeaponClass);
		const FLinearColor NameColor = !bSkillOk ? DebuffColor : !bWeaponOk ? FLinearColor(1.f, 0.7f, 0.3f) : FLinearColor::White;
		DrawText(Row->NameDe.Left(9), NameColor, X + 3.f, Y + 20.f, SmallFont());
		if (!bSkillOk)
		{
			DrawText(FString::Printf(TEXT("Stufe %d"), Row->RequiredSkillLevel), DebuffColor, X + 3.f, Y + 36.f, SmallFont());
		}

		const double Remaining = State->GetRemainingCooldown(Code);
		if (Remaining > 0.0 && Row->CooldownSeconds > 0.0)
		{
			const float Covered = static_cast<float>(SlotSize * FMath::Clamp(Remaining / Row->CooldownSeconds, 0.0, 1.0));
			DrawRect(FLinearColor(0.f, 0.f, 0.f, 0.6f), X, Y + SlotSize - Covered, SlotSize, Covered);
			DrawText(FString::Printf(TEXT("%.0f"), FMath::CeilToDouble(Remaining)), FLinearColor::White, X + SlotSize - 22.f, Y + 2.f, SmallFont());
		}
	}
}

void AVCHUD::DrawFloatingTexts()
{
	const double Now = LocalNow();
	FloatingTexts.RemoveAll([Now](const FFloatingText& Entry)
	{
		return !Entry.Actor.IsValid() || Now - Entry.StartTime > FloatingTextSeconds;
	});
	for (const FFloatingText& Entry : FloatingTexts)
	{
		const double Age = (Now - Entry.StartTime) / FloatingTextSeconds;
		const FVector Above = Entry.Actor->GetActorLocation() + FVector(0.0, 0.0, 120.0 + 60.0 * Age);
		const FVector Screen = Project(Above, true);
		if (Screen.Z <= 0.0)
		{
			continue; // hinter der Kamera
		}
		FLinearColor Color = Entry.Color;
		Color.A = static_cast<float>(1.0 - Age);
		float W = 0.f, H = 0.f;
		GetTextSize(Entry.Text, W, H, SmallFont(), 1.4f);
		DrawText(Entry.Text, Color, static_cast<float>(Screen.X) - W * 0.5f, static_cast<float>(Screen.Y), SmallFont(), 1.4f);
	}
}

void AVCHUD::DrawNotice()
{
	if (Notice.IsEmpty() || LocalNow() > NoticeUntil)
	{
		return;
	}
	float W = 0.f, H = 0.f;
	GetTextSize(Notice, W, H, SmallFont(), 1.2f);
	DrawText(Notice, DebuffColor, (Canvas->ClipX - W) * 0.5f, Canvas->ClipY - SlotSize - 50.f, SmallFont(), 1.2f);
}

void AVCHUD::OnNpcDialog(FName NpcCode)
{
	DialogNpc = NpcCode;
	DialogUntil = LocalNow() + DialogSeconds;
}

void AVCHUD::OnDiscovered(FName DiscoveryCode, int64 XpAwarded)
{
	const FVCDiscoveryRow* Row = FVCWorldData::FindDiscovery(DiscoveryCode);
	const FString Name = Row ? Row->NameDe : DiscoveryCode.ToString();
	Notice = XpAwarded > 0 ? FString::Printf(TEXT("Entdeckt: %s (+%lld XP)"), *Name, XpAwarded) : FString::Printf(TEXT("Entdeckt: %s"), *Name);
	NoticeUntil = LocalNow() + NoticeSeconds * 2.0;
}

void AVCHUD::DrawNpcDialog()
{
	if (DialogNpc.IsNone() || LocalNow() > DialogUntil)
	{
		return;
	}
	const FVCNpcRow* Row = FVCWorldData::FindNpc(DialogNpc);
	TArray<FString> Lines;
	Lines.Add(FVCWorldData::NpcDisplayName(DialogNpc));
	if (Row && !Row->NameZh.IsEmpty())
	{
		Lines.Add(Row->NameZh);
	}
	// Was der NPC im Original tut (belegt), und was davon hier schon geht.
	if (Row && Row->Role == EVCNpcRole::Shipyard)
	{
		Lines.Add(TEXT("Baut und verkauft Schiffe, übernimmt den Schiffsumbau."));
		Lines.Add(TEXT("Dienst folgt mit Phase 5 (Schiffe)."));
	}
	else if (Row && Row->Role == EVCNpcRole::OfficerExchange)
	{
		Lines.Add(TEXT("Tauscht Offizierskarten."));
		Lines.Add(TEXT("Offiziere und ihre Werte sind noch UNKNOWN; Dienst folgt später."));
	}
	if (Row)
	{
		Lines.Add(FString::Printf(TEXT("Beleg: %s"), *Row->ReconId));
	}

	const float Width = 420.f;
	const float LineHeight = 18.f;
	const float Height = 16.f + LineHeight * Lines.Num();
	const float X = (Canvas->ClipX - Width) * 0.5f;
	const float Y = Canvas->ClipY * 0.35f;
	DrawRect(Panel, X, Y, Width, Height);
	for (int32 Index = 0; Index < Lines.Num(); ++Index)
	{
		DrawText(Lines[Index], Index == 0 ? FLinearColor::Yellow : FLinearColor::White, X + 10.f, Y + 8.f + Index * LineHeight, SmallFont());
	}
}

void AVCHUD::DrawShipPanel()
{
	const AVCShip* Ship = Cast<AVCShip>(PlayerOwner->GetPawn());
	if (!Ship)
	{
		return;
	}
	const FVCShipRow* Row = FVCNavalData::FindShip(Ship->GetShipCode());
	const vc::rules::FWind Wind = Ship->GetWind();
	const double Heading = vc::rules::NormalizeDeg(Ship->GetActorRotation().Yaw);
	const double OffWind = vc::rules::AngleOffWindDeg(Heading, Wind.DirectionDeg);
	const double MetersPerSecond = Ship->GetSpeed() / 100.0;

	TArray<FString> Lines;
	Lines.Add(Row ? Row->NameDe : Ship->GetShipCode().ToString());
	Lines.Add(FString::Printf(TEXT("Fahrt %.1f m/s (%.1f kn)   Kurs %.0f°"), MetersPerSecond, MetersPerSecond * 1.94384, Heading));
	Lines.Add(FString::Printf(TEXT("Segel %.0f %%   Ruder %+.0f %%"), Ship->GetSailLevel() * 100.0, Ship->GetRudder() * 100.0));
	Lines.Add(FString::Printf(TEXT("Wind nach %.0f°, Stärke %.2f – %.0f° zum Wind"), Wind.DirectionDeg, Wind.Strength, OffWind));
	Lines.Add(FString::Printf(TEXT("Rumpf %d / %d"), Ship->GetHullHp(), Row ? Row->HullHp : 0));
	Lines.Add(FString::Printf(TEXT("Matrosen %d (+%d verletzt; min. %d, max. %d)   Proviant %d"), Ship->GetCrew(), Ship->GetInjured(),
		Row ? Row->CrewMin : 0, Row ? Row->CrewMax : 0, Ship->GetProvisions()));
	const FVCCannonRow* Cannon = FVCNavalData::FindCannon(Ship->GetCannonCode());
	const double PortReload = Ship->GetReloadRemaining(false);
	const double StarboardReload = Ship->GetReloadRemaining(true);
	Lines.Add(FString::Printf(TEXT("%s (%.0f m)   Q backbord %s   E steuerbord %s"),
		Cannon ? *Cannon->NameDe : TEXT("keine Kanone"), Cannon ? Cannon->RangeCm / 100.0 : 0.0,
		PortReload > 0.0 ? *FString::Printf(TEXT("%.0f s"), FMath::CeilToDouble(PortReload)) : TEXT("bereit"),
		StarboardReload > 0.0 ? *FString::Printf(TEXT("%.0f s"), FMath::CeilToDouble(StarboardReload)) : TEXT("bereit")));
	const double GrappleCooldown = Ship->GetGrappleCooldown();
	const double MineCooldown = Ship->GetMineCooldown();
	const FString GrappleText = GrappleCooldown > 0.0 ? FString::Printf(TEXT("%.0f s"), FMath::CeilToDouble(GrappleCooldown)) : FString(TEXT("bereit"));
	const FString MineText = MineCooldown > 0.0 ? FString::Printf(TEXT("%.0f s"), FMath::CeilToDouble(MineCooldown)) : FString(TEXT("bereit"));
	Lines.Add(FString::Printf(TEXT("F Haken %s   M Mine %s"), *GrappleText, *MineText));
	if (Ship->IsBoarding())
	{
		Lines.Add(TEXT("ENTERN – Kampf an Deck"));
	}
	else if (Ship->GetGrappledTo())
	{
		Lines.Add(TEXT("Festgehakt – B zum Entern"));
	}
	if (Ship->IsSunk())
	{
		Lines.Add(TEXT("GESUNKEN"));
	}

	const float X = Canvas->ClipX - 360.f;
	const float Y = Canvas->ClipY - 170.f;
	DrawRect(Panel, X - 8.f, Y - 6.f - 36.f, 350.f, 18.f * Lines.Num() + 12.f);
	for (int32 Index = 0; Index < Lines.Num(); ++Index)
	{
		DrawText(Lines[Index], Index == 0 ? FLinearColor::Yellow : FLinearColor::White, X, Y - 36.f + Index * 18.f, SmallFont());
	}
}

void AVCHUD::OnShipHit(AVCShip* Ship, int32 Hits, int32 HullDamage, int32 CrewLosses)
{
	FFloatingText& Entry = FloatingTexts.AddDefaulted_GetRef();
	Entry.Actor = Ship;
	Entry.StartTime = LocalNow();
	Entry.Color = Hits > 0 ? FLinearColor(1.f, 0.6f, 0.2f) : FLinearColor::Gray;
	Entry.Text = Hits > 0
		? FString::Printf(TEXT("-%d Rumpf (%d Treffer)%s"), HullDamage, Hits,
			CrewLosses > 0 ? *FString::Printf(TEXT(", %d Matrosen"), CrewLosses) : TEXT(""))
		: TEXT("verfehlt");
}
