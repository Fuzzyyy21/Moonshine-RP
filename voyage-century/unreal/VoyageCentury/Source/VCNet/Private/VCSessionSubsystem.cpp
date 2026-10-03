#include "VCSessionSubsystem.h"
#include "Engine/Engine.h"
#include "Engine/GameInstance.h"
#include "GameFramework/PlayerController.h"
#include "VCBackendSettings.h"
#include "VCCore.h"
#include "VCHttp.h"

void UVCSessionSubsystem::Login(const FString& LoginName, const FString& Password)
{
	const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetStringField(TEXT("login"), LoginName);
	Body->SetStringField(TEXT("password"), Password);

	TWeakObjectPtr<UVCSessionSubsystem> WeakThis(this);
	FVCHttp::Send(TEXT("POST"), UVCBackendSettings::GetAuthBaseUrl() + TEXT("/v1/sessions"), Body, {},
		[WeakThis](const FVCHttpResult& Result)
		{
			UVCSessionSubsystem* Self = WeakThis.Get();
			if (!Self)
			{
				return;
			}
			FString NewTicket;
			int64 NewAccountId = 0;
			if (!Result.IsOk() || !Result.Json.IsValid() || !Result.Json->TryGetStringField(TEXT("ticket"), NewTicket)
				|| !FVCHttp::TryGetId(Result.Json, TEXT("accountId"), NewAccountId))
			{
				Self->Report(false, FString::Printf(TEXT("Login fehlgeschlagen: %s"), *Result.ErrorMessage()));
				return;
			}
			Self->Ticket = NewTicket;
			Self->AccountId = NewAccountId;
			Self->Report(true, FString::Printf(TEXT("Eingeloggt als Konto %lld. Weiter mit VCCharacters."), NewAccountId));
		});
}

void UVCSessionSubsystem::ListCharacters()
{
	if (!HasTicket())
	{
		Report(false, TEXT("Erst VCLogin ausführen."));
		return;
	}
	TWeakObjectPtr<UVCSessionSubsystem> WeakThis(this);
	FVCHttp::Send(TEXT("GET"), UVCBackendSettings::GetGameDataBaseUrl() + TEXT("/v1/characters"), nullptr, AuthHeader(),
		[WeakThis](const FVCHttpResult& Result)
		{
			UVCSessionSubsystem* Self = WeakThis.Get();
			if (!Self)
			{
				return;
			}
			if (!Result.IsOk() || !Result.JsonValue.IsValid() || Result.JsonValue->Type != EJson::Array)
			{
				Self->Report(false, FString::Printf(TEXT("Charakterliste fehlgeschlagen: %s"), *Result.ErrorMessage()));
				return;
			}
			const TArray<TSharedPtr<FJsonValue>>& Entries = Result.JsonValue->AsArray();
			if (Entries.IsEmpty())
			{
				Self->Report(true, TEXT("Keine Charaktere. Anlegen mit: VCCreateCharacter <Name> <MALE|FEMALE> <BERUF>"));
				return;
			}
			for (const TSharedPtr<FJsonValue>& Entry : Entries)
			{
				const TSharedPtr<FJsonObject> Obj = Entry->AsObject();
				int64 Id = 0;
				FVCHttp::TryGetId(Obj, TEXT("characterId"), Id);
				Self->Report(true, FString::Printf(TEXT("[%lld] %s (%s, Stufe %d)"), Id,
					*Obj->GetStringField(TEXT("name")), *Obj->GetStringField(TEXT("professionCode")),
					static_cast<int32>(Obj->GetNumberField(TEXT("level")))));
			}
		});
}

void UVCSessionSubsystem::CreateCharacter(const FString& Name, const FString& Gender, const FString& ProfessionCode)
{
	if (!HasTicket())
	{
		Report(false, TEXT("Erst VCLogin ausführen."));
		return;
	}
	const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetStringField(TEXT("name"), Name);
	Body->SetStringField(TEXT("gender"), Gender.ToUpper());
	Body->SetStringField(TEXT("professionCode"), ProfessionCode.ToUpper());

	TWeakObjectPtr<UVCSessionSubsystem> WeakThis(this);
	FVCHttp::Send(TEXT("POST"), UVCBackendSettings::GetGameDataBaseUrl() + TEXT("/v1/characters"), Body, AuthHeader(),
		[WeakThis](const FVCHttpResult& Result)
		{
			if (UVCSessionSubsystem* Self = WeakThis.Get())
			{
				int64 Id = 0;
				const bool bOk = Result.IsOk() && FVCHttp::TryGetId(Result.Json, TEXT("characterId"), Id);
				Self->Report(bOk, bOk
					? FString::Printf(TEXT("Charakter %lld angelegt. Verbinden mit: VCConnect <host:port> %lld"), Id, Id)
					: FString::Printf(TEXT("Anlegen fehlgeschlagen: %s"), *Result.ErrorMessage()));
			}
		});
}

void UVCSessionSubsystem::ConnectToZone(const FString& ServerAddress, int64 CharacterId)
{
	APlayerController* PC = GetGameInstance()->GetFirstLocalPlayerController();
	if (!HasTicket() || !PC || CharacterId <= 0)
	{
		Report(false, TEXT("Benötigt Login, lokalen Spieler und eine Charakter-ID."));
		return;
	}
	// Das Ticket ist Base64url und damit ohne Escaping als URL-Option zulässig.
	const FString Url = FString::Printf(TEXT("%s?ticket=%s?character=%lld"), *ServerAddress, *Ticket, CharacterId);
	Report(true, FString::Printf(TEXT("Verbinde mit %s ..."), *ServerAddress));
	PC->ClientTravel(Url, TRAVEL_Absolute);
}

TMap<FString, FString> UVCSessionSubsystem::AuthHeader() const
{
	return { { TEXT("Authorization"), TEXT("Bearer ") + Ticket } };
}

void UVCSessionSubsystem::Report(bool bSuccess, const FString& Message)
{
	UE_LOG(LogVC, Display, TEXT("%s"), *Message);
	if (GEngine)
	{
		GEngine->AddOnScreenDebugMessage(-1, 8.f, bSuccess ? FColor::Green : FColor::Red, Message);
	}
	OnStatus.Broadcast(bSuccess, Message);
}
