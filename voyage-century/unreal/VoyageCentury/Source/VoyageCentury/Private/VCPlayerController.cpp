#include "VCPlayerController.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "GameFramework/GameModeBase.h"
#include "VCCore.h"
#include "Engine/Engine.h"
#include "VCPlayerState.h"
#include "VCProgressionComponent.h"
#include "VCServerHooks.h"
#include "VCSessionSubsystem.h"

namespace
{
	constexpr int32 MaxAdminCommandLength = 256;
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
