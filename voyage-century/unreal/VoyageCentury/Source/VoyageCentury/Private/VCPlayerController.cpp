#include "VCPlayerController.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "GameFramework/GameModeBase.h"
#include "VCCore.h"
#include "Engine/Engine.h"
#include "Engine/GameViewportClient.h"
#include "SVCCharacterScreen.h"
#include "AbilitySystemComponent.h"
#include "VCAbilityStateComponent.h"
#include "VCAttributeSet.h"
#include "VCCombatData.h"
#include "VCPlayerState.h"
#include "VCProgressionComponent.h"
#include "VCServerHooks.h"
#include "VCSessionSubsystem.h"

namespace
{
	constexpr int32 MaxAdminCommandLength = 256;

	void ShowLine(const FString& Line, const FColor& Color = FColor::Cyan)
	{
		UE_LOG(LogVC, Display, TEXT("%s"), *Line);
		if (GEngine)
		{
			GEngine->AddOnScreenDebugMessage(-1, 8.f, Color, Line);
		}
	}

	const TCHAR* WeaponName(EVCWeaponClass Class)
	{
		switch (Class)
		{
		case EVCWeaponClass::Sword: return TEXT("Schwert");
		case EVCWeaponClass::Blade: return TEXT("Klinge");
		case EVCWeaponClass::Axe: return TEXT("Axt");
		case EVCWeaponClass::Firearm: return TEXT("Schusswaffe");
		default: return TEXT("unbewaffnet");
		}
	}
}

void AVCPlayerController::BeginPlay()
{
	Super::BeginPlay();
	// Offline-Start eines gepackten Clients: noch keine Verbindung, also Login-Oberfläche zeigen.
	const UWorld* World = GetWorld();
	if (IsLocalController() && GetNetMode() == NM_Standalone && World && !World->IsPlayInEditor())
	{
		VCCharacterScreen();
	}
}

void AVCPlayerController::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	// Das Viewport überlebt Map-Wechsel; das Widget muss vor dem Reisen entfernt werden.
	HideCharacterScreen();
	Super::EndPlay(EndPlayReason);
}

void AVCPlayerController::VCCharacterScreen()
{
	if (CharacterScreen.IsValid() || !IsLocalController() || !GEngine || !GEngine->GameViewport)
	{
		return;
	}
	CharacterScreen = SNew(SVCCharacterScreen).Session(Session());
	GEngine->GameViewport->AddViewportWidgetContent(CharacterScreen.ToSharedRef(), 10);
	SetShowMouseCursor(true);
	FInputModeUIOnly Mode;
	Mode.SetWidgetToFocus(CharacterScreen);
	SetInputMode(Mode);
}

void AVCPlayerController::HideCharacterScreen()
{
	if (!CharacterScreen.IsValid())
	{
		return;
	}
	if (GEngine && GEngine->GameViewport)
	{
		GEngine->GameViewport->RemoveViewportWidgetContent(CharacterScreen.ToSharedRef());
	}
	CharacterScreen.Reset();
	if (IsLocalController())
	{
		SetShowMouseCursor(false);
		SetInputMode(FInputModeGameOnly());
	}
}

UVCSessionSubsystem* AVCPlayerController::Session() const
{
	const UGameInstance* GameInstance = GetGameInstance();
	return GameInstance ? GameInstance->GetSubsystem<UVCSessionSubsystem>() : nullptr;
}

void AVCPlayerController::VCLogin(const FString& Login, const FString& Password)
{
	if (UVCSessionSubsystem* S = Session())
	{
		S->Login(Login, Password);
	}
}

void AVCPlayerController::VCCharacters()
{
	if (UVCSessionSubsystem* S = Session())
	{
		S->ListCharacters();
	}
}

void AVCPlayerController::VCCreateCharacter(const FString& Name, const FString& Gender, const FString& Profession)
{
	if (UVCSessionSubsystem* S = Session())
	{
		S->CreateCharacter(Name, Gender, Profession);
	}
}

void AVCPlayerController::VCConnect(const FString& Address, const FString& CharacterId)
{
	if (UVCSessionSubsystem* S = Session())
	{
		S->ConnectToZone(Address, FCString::Atoi64(*CharacterId));
	}
}

void AVCPlayerController::VCPlay(const FString& CharacterId)
{
	if (UVCSessionSubsystem* S = Session())
	{
		S->PlayCharacter(FCString::Atoi64(*CharacterId));
	}
}

void AVCPlayerController::ClientTravelToZone_Implementation(const FString& Address, int64 CharacterId)
{
	// Das Ticket hat nur der Client; der Server nennt nur das Ziel.
	if (UVCSessionSubsystem* S = Session())
	{
		S->ConnectToZone(Address, CharacterId);
	}
}

void AVCPlayerController::VCStatus()
{
	const AVCPlayerState* PS = GetPlayerState<AVCPlayerState>();
	const UVCProgressionComponent* Progression = PS ? PS->GetProgression() : nullptr;
	if (!Progression)
	{
		ClientMessage(TEXT("Noch kein Charakter geladen."));
		return;
	}
	TArray<FString> Lines;
	Lines.Add(FString::Printf(TEXT("Stufe %d, XP %lld"), Progression->GetLevel(), Progression->GetExperience()));
	if (const UAbilitySystemComponent* ASC = PS->GetAbilitySystemComponent())
	{
		Lines.Add(FString::Printf(TEXT("Leben %.0f / %.0f, Ausdauer %.0f / %.0f"),
			ASC->GetNumericAttribute(UVCAttributeSet::GetHealthAttribute()),
			ASC->GetNumericAttribute(UVCAttributeSet::GetMaxHealthAttribute()),
			ASC->GetNumericAttribute(UVCAttributeSet::GetStaminaAttribute()),
			ASC->GetNumericAttribute(UVCAttributeSet::GetMaxStaminaAttribute())));
	}
	for (const FVCSkillState& Skill : Progression->GetSkills())
	{
		Lines.Add(FString::Printf(TEXT("  %s: Stufe %d (Skillstufe %d), XP %lld"),
			*Skill.Code.ToString(), Skill.Level, Skill.Stage, Skill.Experience));
	}
	for (const FString& Line : Lines)
	{
		UE_LOG(LogVC, Display, TEXT("%s"), *Line);
		if (GEngine)
		{
			GEngine->AddOnScreenDebugMessage(-1, 8.f, FColor::Cyan, Line);
		}
	}
}

void AVCPlayerController::VCAdmin(const FString& CommandLine)
{
	ServerAdminCommand(CommandLine);
}

bool AVCPlayerController::ServerAdminCommand_Validate(const FString& CommandLine)
{
	// Überlange Eingaben gelten als Manipulation und trennen die Verbindung.
	return CommandLine.Len() <= MaxAdminCommandLength;
}

void AVCPlayerController::ServerAdminCommand_Implementation(const FString& CommandLine)
{
	UWorld* World = GetWorld();
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(World ? World->GetAuthGameMode() : nullptr))
	{
		Hooks->HandleAdminCommand(this, CommandLine);
	}
	else
	{
		UE_LOG(LogVC, Warning, TEXT("Admin-Kommando ohne Server-GameMode verworfen"));
	}
}

void AVCPlayerController::VCAbilities()
{
	if (!FVCCombatData::AreAbilitiesAvailable())
	{
		ShowLine(TEXT("Keine Fähigkeitsdaten (DT_Abilities/DT_StatusEffects importieren)."), FColor::Red);
		return;
	}
	for (const FName& Code : FVCCombatData::AbilityCodes())
	{
		const FVCAbilityRow* Row = FVCCombatData::FindAbility(Code);
		if (!Row)
		{
			continue;
		}
		ShowLine(FString::Printf(TEXT("%s (%s): %s ab Stufe %d, %s, Ausdauer %.0f, Abklingzeit %.0f s%s"),
			*Code.ToString(), *Row->NameDe, *Row->SkillCode.ToString(), Row->RequiredSkillLevel,
			Row->bRequiresWeaponClass ? WeaponName(Row->RequiredWeaponClass) : TEXT("jede Waffe"),
			Row->StaminaCost, Row->CooldownSeconds, Row->bIsDev ? TEXT(" [DEV]") : TEXT("")));
	}
}

void AVCPlayerController::VCHotbar(const FString& Slot, const FString& AbilityCode)
{
	int32 Number = 0;
	if (!LexTryParseString(Number, *Slot) || Number < 1 || Number > UVCAbilityStateComponent::HotbarSlots)
	{
		ShowLine(TEXT("Aufruf: VCHotbar <1-10> <CODE|leer>"), FColor::Red);
		return;
	}
	const bool bClear = AbilityCode.IsEmpty() || AbilityCode == TEXT("-") || AbilityCode.Equals(TEXT("leer"), ESearchCase::IgnoreCase);
	ServerSetHotbarSlot(Number - 1, bClear ? NAME_None : FName(*AbilityCode.ToUpper()));
}

bool AVCPlayerController::ServerSetHotbarSlot_Validate(int32 Slot, FName AbilityCode)
{
	return Slot >= 0 && Slot < UVCAbilityStateComponent::HotbarSlots && AbilityCode.GetStringLength() <= 64;
}

void AVCPlayerController::ServerSetHotbarSlot_Implementation(int32 Slot, FName AbilityCode)
{
	UWorld* World = GetWorld();
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(World ? World->GetAuthGameMode() : nullptr))
	{
		Hooks->HandleHotbarChange(this, Slot, AbilityCode);
	}
}
