#include "VCServerBackend.h"
#include "HAL/PlatformMisc.h"
#include "VCBackendSettings.h"

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
	const FVector& Location, float Yaw, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetNumberField(TEXT("accountId"), static_cast<double>(AccountId));
	Body->SetStringField(TEXT("zoneId"), ZoneId);
	Body->SetNumberField(TEXT("x"), Location.X);
	Body->SetNumberField(TEXT("y"), Location.Y);
	Body->SetNumberField(TEXT("z"), Location.Z);
	Body->SetNumberField(TEXT("yaw"), Yaw);
	const FString Url = FString::Printf(TEXT("%s/internal/v1/characters/%lld/state"),
		*UVCBackendSettings::GetGameDataBaseUrl(), CharacterId);
	FVCHttp::Send(TEXT("PUT"), Url, Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::WriteAdminAudit(const TSharedRef<FJsonObject>& Entry, FVCHttpCallback Callback)
{
	FVCHttp::Send(TEXT("POST"), UVCBackendSettings::GetGameDataBaseUrl() + TEXT("/internal/v1/admin-audit"),
		Entry, Headers(), MoveTemp(Callback));
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
void FVCServerBackend::SaveCharacter(int64, int64, const FString&, const FVector&, float, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::WriteAdminAudit(const TSharedRef<FJsonObject>&, FVCHttpCallback Callback) { Refuse(Callback); }

#endif // WITH_SERVER_CODE
