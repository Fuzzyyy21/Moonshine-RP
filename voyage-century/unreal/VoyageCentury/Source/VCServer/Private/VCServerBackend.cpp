#include "VCServerBackend.h"
#include "Dom/JsonValue.h"
#include "HAL/PlatformMisc.h"
#include "GenericPlatform/GenericPlatformHttp.h"
#include "VCBackendSettings.h"
#include "VCServerSettings.h"

#if WITH_SERVER_CODE

namespace
{
	const FString& ServiceKey()
	{
		// Einmal lesen; Umgebungsvariablen erscheinen nicht in der Prozessliste wie Kommandozeilen.
		static const FString Key = FPlatformMisc::GetEnvironmentVariable(TEXT("VC_SERVICE_KEY"));
		return Key;
	}

	TMap<FString, FString> Headers()
	{
		return { { TEXT("X-Service-Key"), ServiceKey() } };
	}
}

bool FVCServerBackend::IsConfigured()
{
	return ServiceKey().Len() >= 32;
}

void FVCServerBackend::ValidateTicket(const FString& Ticket, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetStringField(TEXT("ticket"), Ticket);
	FVCHttp::Send(TEXT("POST"), UVCBackendSettings::GetAuthBaseUrl() + TEXT("/internal/v1/sessions/validate"),
		Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::LoadCharacter(int64 CharacterId, int64 AccountId, FVCHttpCallback Callback)
{
	const FString Url = FString::Printf(TEXT("%s/internal/v1/characters/%lld/state?accountId=%lld"),
		*UVCBackendSettings::GetGameDataBaseUrl(), CharacterId, AccountId);
	FVCHttp::Send(TEXT("GET"), Url, nullptr, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::SaveCharacter(int64 CharacterId, int64 AccountId, const FString& ZoneId,
	const FVector& Location, float Yaw, const FIntVector4& Vitals, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetNumberField(TEXT("accountId"), static_cast<double>(AccountId));
	Body->SetStringField(TEXT("zoneId"), ZoneId);
	Body->SetNumberField(TEXT("x"), Location.X);
	Body->SetNumberField(TEXT("y"), Location.Y);
	Body->SetNumberField(TEXT("z"), Location.Z);
	Body->SetNumberField(TEXT("yaw"), Yaw);
	if (Vitals.Y > 0 && Vitals.W > 0) // (Health, MaxHealth, Stamina, MaxStamina)
	{
		Body->SetNumberField(TEXT("health"), Vitals.X);
		Body->SetNumberField(TEXT("maxHealth"), Vitals.Y);
		Body->SetNumberField(TEXT("stamina"), Vitals.Z);
		Body->SetNumberField(TEXT("maxStamina"), Vitals.W);
	}
	const FString Url = FString::Printf(TEXT("%s/internal/v1/characters/%lld/state"),
		*UVCBackendSettings::GetGameDataBaseUrl(), CharacterId);
	FVCHttp::Send(TEXT("PUT"), Url, Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::WriteAdminAudit(const TSharedRef<FJsonObject>& Entry, FVCHttpCallback Callback)
{
	FVCHttp::Send(TEXT("POST"), UVCBackendSettings::GetGameDataBaseUrl() + TEXT("/internal/v1/admin-audit"),
		Entry, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::GrantExperience(int64 CharacterId, int64 AccountId, const FString& SkillCode, int64 Amount,
	const FString& Source, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetNumberField(TEXT("accountId"), static_cast<double>(AccountId));
	Body->SetNumberField(TEXT("amount"), static_cast<double>(Amount));
	Body->SetStringField(TEXT("source"), Source);
	Body->SetStringField(TEXT("idempotencyKey"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	Body->SetStringField(TEXT("serverId"), UVCServerSettings::GetServerId());
	const FString Base = FString::Printf(TEXT("%s/internal/v1/characters/%lld"), *UVCBackendSettings::GetGameDataBaseUrl(), CharacterId);
	const FString Url = SkillCode.IsEmpty()
		? Base + TEXT("/experience")
		: FString::Printf(TEXT("%s/skills/%s/experience"), *Base, *FGenericPlatformHttp::UrlEncode(SkillCode));
	FVCHttp::Send(TEXT("POST"), Url, Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::LoadZone(const FString& ZoneId, FVCHttpCallback Callback)
{
	FVCHttp::Send(TEXT("GET"), FString::Printf(TEXT("%s/internal/v1/zones/%s"), *UVCBackendSettings::GetGameDataBaseUrl(),
		*FGenericPlatformHttp::UrlEncode(ZoneId)), nullptr, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::ReportKill(const TSharedRef<FJsonObject>& Kill, FVCHttpCallback Callback)
{
	Kill->SetStringField(TEXT("idempotencyKey"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	Kill->SetStringField(TEXT("serverId"), UVCServerSettings::GetServerId());
	Kill->SetStringField(TEXT("zoneId"), UVCServerSettings::GetZoneId());
	FVCHttp::Send(TEXT("POST"), UVCBackendSettings::GetGameDataBaseUrl() + TEXT("/internal/v1/combat/kills"),
		Kill, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::SaveHotbar(int64 CharacterId, int64 AccountId, const TArray<FName>& Slots, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetNumberField(TEXT("accountId"), static_cast<double>(AccountId));
	TArray<TSharedPtr<FJsonValue>> Entries;
	for (int32 Slot = 0; Slot < Slots.Num(); ++Slot)
	{
		if (Slots[Slot].IsNone())
		{
			continue;
		}
		const TSharedRef<FJsonObject> Entry = MakeShared<FJsonObject>();
		Entry->SetNumberField(TEXT("slot"), Slot);
		Entry->SetStringField(TEXT("abilityCode"), Slots[Slot].ToString());
		Entries.Add(MakeShared<FJsonValueObject>(Entry));
	}
	Body->SetArrayField(TEXT("slots"), Entries);
	const FString Url = FString::Printf(TEXT("%s/internal/v1/characters/%lld/hotbar"),
		*UVCBackendSettings::GetGameDataBaseUrl(), CharacterId);
	FVCHttp::Send(TEXT("PUT"), Url, Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::AdminSetLevel(int64 CharacterId, const FString& SkillCode, int32 Level,
	const TSharedRef<FJsonObject>& AdminContext, FVCHttpCallback Callback)
{
	AdminContext->SetNumberField(TEXT("level"), Level);
	const FString Base = FString::Printf(TEXT("%s/internal/v1/characters/%lld"), *UVCBackendSettings::GetGameDataBaseUrl(), CharacterId);
	const FString Url = SkillCode.IsEmpty()
		? Base + TEXT("/level")
		: FString::Printf(TEXT("%s/skills/%s/level"), *Base, *FGenericPlatformHttp::UrlEncode(SkillCode));
	FVCHttp::Send(TEXT("PUT"), Url, AdminContext, Headers(), MoveTemp(Callback));
}

#else // !WITH_SERVER_CODE

namespace
{
	void Refuse(const FVCHttpCallback& Callback)
	{
		Callback(FVCHttpResult());
	}
}

bool FVCServerBackend::IsConfigured() { return false; }
void FVCServerBackend::ValidateTicket(const FString&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::LoadCharacter(int64, int64, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::SaveCharacter(int64, int64, const FString&, const FVector&, float, const FIntVector4&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::LoadZone(const FString&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::ReportKill(const TSharedRef<FJsonObject>&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::WriteAdminAudit(const TSharedRef<FJsonObject>&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::GrantExperience(int64, int64, const FString&, int64, const FString&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::SaveHotbar(int64, int64, const TArray<FName>&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::AdminSetLevel(int64, const FString&, int32, const TSharedRef<FJsonObject>&, FVCHttpCallback Callback) { Refuse(Callback); }

#endif // WITH_SERVER_CODE
