#include "VCServerBackend.h"
#include "Dom/JsonValue.h"
#include "HAL/PlatformMisc.h"
#include "GenericPlatform/GenericPlatformHttp.h"
#include "VCBackendSettings.h"
#include "VCCore.h"
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
	const FVector& Location, float Yaw, const FIntVector4& Vitals, bool bReleasePresence, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetNumberField(TEXT("accountId"), static_cast<double>(AccountId));
	Body->SetStringField(TEXT("zoneId"), ZoneId);
	Body->SetStringField(TEXT("serverId"), UVCServerSettings::GetServerId());
	Body->SetBoolField(TEXT("releasePresence"), bReleasePresence);
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

namespace
{
	FString ServerUrl()
	{
		return FString::Printf(TEXT("%s/internal/v1/world/servers/%s"), *UVCBackendSettings::GetGameDataBaseUrl(),
			*FGenericPlatformHttp::UrlEncode(UVCServerSettings::GetServerId()));
	}

	TSharedRef<FJsonObject> ServerBody(const FString& Address, int32 Capacity)
	{
		const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
		Body->SetStringField(TEXT("zoneId"), UVCServerSettings::GetZoneId());
		Body->SetStringField(TEXT("address"), Address);
		Body->SetNumberField(TEXT("capacity"), Capacity);
		return Body;
	}

	FString ClaimUrl(int64 CharacterId)
	{
		return FString::Printf(TEXT("%s/internal/v1/world/characters/%lld/claim"), *UVCBackendSettings::GetGameDataBaseUrl(), CharacterId);
	}
}

void FVCServerBackend::StartServer(const FString& Address, int32 Capacity, FVCHttpCallback Callback)
{
	FVCHttp::Send(TEXT("POST"), ServerUrl(), ServerBody(Address, Capacity), Headers(), MoveTemp(Callback));
}

void FVCServerBackend::Heartbeat(const FString& Address, int32 Capacity, FVCHttpCallback Callback)
{
	FVCHttp::Send(TEXT("PUT"), ServerUrl() + TEXT("/heartbeat"), ServerBody(Address, Capacity), Headers(), MoveTemp(Callback));
}

void FVCServerBackend::ClaimCharacter(int64 CharacterId, int64 AccountId, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetNumberField(TEXT("accountId"), static_cast<double>(AccountId));
	Body->SetStringField(TEXT("serverId"), UVCServerSettings::GetServerId());
	FVCHttp::Send(TEXT("POST"), ClaimUrl(CharacterId), Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::ReleaseCharacter(int64 CharacterId)
{
	const FString Url = ClaimUrl(CharacterId) + TEXT("?serverId=") + FGenericPlatformHttp::UrlEncode(UVCServerSettings::GetServerId());
	FVCHttp::Send(TEXT("DELETE"), Url, nullptr, Headers(), [CharacterId](const FVCHttpResult& Result)
	{
		if (!Result.IsOk())
		{
			UE_LOG(LogVC, Warning, TEXT("Freigabe von Charakter %lld fehlgeschlagen: %s"), CharacterId, *Result.ErrorMessage());
		}
	});
}

namespace
{
	FString CharacterUrl(int64 CharacterId)
	{
		return FString::Printf(TEXT("%s/internal/v1/characters/%lld"), *UVCBackendSettings::GetGameDataBaseUrl(), CharacterId);
	}

	TSharedRef<FJsonObject> OwnerBody(int64 AccountId)
	{
		const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
		Body->SetNumberField(TEXT("accountId"), static_cast<double>(AccountId));
		Body->SetStringField(TEXT("serverId"), UVCServerSettings::GetServerId());
		return Body;
	}
}

void FVCServerBackend::BuyShip(int64 CharacterId, int64 AccountId, const FString& NpcCode, const FString& ShipCode,
	const FGuid& PurchaseKey, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = OwnerBody(AccountId);
	Body->SetStringField(TEXT("npcCode"), NpcCode);
	Body->SetStringField(TEXT("shipCode"), ShipCode);
	Body->SetStringField(TEXT("purchaseKey"), PurchaseKey.ToString(EGuidFormats::DigitsWithHyphens));
	FVCHttp::Send(TEXT("POST"), CharacterUrl(CharacterId) + TEXT("/ships"), Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::SetActiveShip(int64 CharacterId, int64 AccountId, int64 InstanceId, FVCHttpCallback Callback)
{
	FVCHttp::Send(TEXT("PUT"), FString::Printf(TEXT("%s/ships/%lld/active"), *CharacterUrl(CharacterId), InstanceId),
		OwnerBody(AccountId), Headers(), MoveTemp(Callback));
}

void FVCServerBackend::ShipService(int64 CharacterId, int64 AccountId, int64 InstanceId, const FString& NpcCode, const FString& Kind,
	int32 Amount, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = OwnerBody(AccountId);
	Body->SetStringField(TEXT("npcCode"), NpcCode);
	Body->SetStringField(TEXT("kind"), Kind);
	Body->SetNumberField(TEXT("amount"), Amount);
	Body->SetStringField(TEXT("key"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	FVCHttp::Send(TEXT("POST"), FString::Printf(TEXT("%s/ships/%lld/services"), *CharacterUrl(CharacterId), InstanceId),
		Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::ViewMarket(int64 CharacterId, int64 AccountId, const FString& NpcCode, FVCHttpCallback Callback)
{
	const FString Url = FString::Printf(TEXT("%s/market?accountId=%lld&serverId=%s&npcCode=%s"), *CharacterUrl(CharacterId), AccountId,
		*FGenericPlatformHttp::UrlEncode(UVCServerSettings::GetServerId()), *FGenericPlatformHttp::UrlEncode(NpcCode));
	FVCHttp::Send(TEXT("GET"), Url, nullptr, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::Trade(int64 CharacterId, int64 AccountId, const FString& NpcCode, const FString& ItemCode, const FString& Side,
	int32 Quantity, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = OwnerBody(AccountId);
	Body->SetStringField(TEXT("npcCode"), NpcCode);
	Body->SetStringField(TEXT("itemCode"), ItemCode);
	Body->SetStringField(TEXT("side"), Side);
	Body->SetNumberField(TEXT("quantity"), Quantity);
	Body->SetStringField(TEXT("key"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	FVCHttp::Send(TEXT("POST"), CharacterUrl(CharacterId) + TEXT("/trade"), Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::LoadInventory(int64 CharacterId, int64 AccountId, FVCHttpCallback Callback)
{
	FVCHttp::Send(TEXT("GET"), FString::Printf(TEXT("%s/inventory?accountId=%lld"), *CharacterUrl(CharacterId), AccountId), nullptr,
		Headers(), MoveTemp(Callback));
}

void FVCServerBackend::InventoryAction(int64 CharacterId, int64 AccountId, const FString& Action, int64 InstanceId, int32 Quantity,
	const FString& NpcCode, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = OwnerBody(AccountId);
	Body->SetNumberField(TEXT("instanceId"), static_cast<double>(InstanceId));
	Body->SetNumberField(TEXT("quantity"), Quantity);
	Body->SetStringField(TEXT("key"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	if (!NpcCode.IsEmpty())
	{
		Body->SetStringField(TEXT("npcCode"), NpcCode);
	}
	FVCHttp::Send(TEXT("POST"), CharacterUrl(CharacterId) + TEXT("/inventory/") + Action, Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::Gather(int64 CharacterId, int64 AccountId, const FString& NodeCode, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = OwnerBody(AccountId);
	Body->SetStringField(TEXT("nodeCode"), NodeCode);
	Body->SetStringField(TEXT("key"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	FVCHttp::Send(TEXT("POST"), CharacterUrl(CharacterId) + TEXT("/gather"), Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::LoadRecipes(int64 CharacterId, int64 AccountId, FVCHttpCallback Callback)
{
	FVCHttp::Send(TEXT("GET"), FString::Printf(TEXT("%s/recipes?accountId=%lld"), *CharacterUrl(CharacterId), AccountId), nullptr,
		Headers(), MoveTemp(Callback));
}

void FVCServerBackend::Craft(int64 CharacterId, int64 AccountId, const FString& RecipeCode, int32 Times, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = OwnerBody(AccountId);
	Body->SetStringField(TEXT("recipeCode"), RecipeCode);
	Body->SetNumberField(TEXT("times"), Times);
	Body->SetStringField(TEXT("key"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	FVCHttp::Send(TEXT("POST"), CharacterUrl(CharacterId) + TEXT("/craft"), Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::Auction(int64 CharacterId, int64 AccountId, const FString& Action, const FString& NpcCode, int64 Id, int32 Quantity,
	int64 Price, const FString& ItemCode, FVCHttpCallback Callback)
{
	if (Action == TEXT("search"))
	{
		FString Url = FString::Printf(TEXT("%s/internal/v1/auction?characterId=%lld&accountId=%lld"), *UVCBackendSettings::GetGameDataBaseUrl(),
			CharacterId, AccountId);
		if (!ItemCode.IsEmpty())
		{
			Url += TEXT("&itemCode=") + FGenericPlatformHttp::UrlEncode(ItemCode);
		}
		FVCHttp::Send(TEXT("GET"), Url, nullptr, Headers(), MoveTemp(Callback));
		return;
	}
	if (Action == TEXT("mine"))
	{
		FVCHttp::Send(TEXT("GET"), FString::Printf(TEXT("%s/auction?accountId=%lld"), *CharacterUrl(CharacterId), AccountId), nullptr,
			Headers(), MoveTemp(Callback));
		return;
	}
	const TSharedRef<FJsonObject> Body = OwnerBody(AccountId);
	Body->SetStringField(TEXT("npcCode"), NpcCode);
	Body->SetStringField(TEXT("key"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	FString Path;
	if (Action == TEXT("list"))
	{
		Body->SetNumberField(TEXT("instanceId"), static_cast<double>(Id));
		Body->SetNumberField(TEXT("quantity"), Quantity);
		Body->SetNumberField(TEXT("price"), static_cast<double>(Price));
		Path = TEXT("/auction/list");
	}
	else if (Action == TEXT("collect"))
	{
		Path = TEXT("/auction/collect");
	}
	else
	{
		Path = FString::Printf(TEXT("/auction/%lld/%s"), Id, *Action); // buy, cancel
	}
	FVCHttp::Send(TEXT("POST"), CharacterUrl(CharacterId) + Path, Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::AdminGrantItem(int64 CharacterId, const FString& ItemCode, int32 Quantity, const TSharedRef<FJsonObject>& AdminContext,
	FVCHttpCallback Callback)
{
	AdminContext->SetStringField(TEXT("itemCode"), ItemCode);
	AdminContext->SetNumberField(TEXT("quantity"), Quantity);
	AdminContext->SetStringField(TEXT("key"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	FVCHttp::Send(TEXT("POST"), CharacterUrl(CharacterId) + TEXT("/inventory/grant"), AdminContext, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::SaveShip(int64 CharacterId, int64 AccountId, int64 InstanceId, int32 HullHp, int32 Crew, int32 Injured,
	int32 Provisions, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = OwnerBody(AccountId);
	Body->SetNumberField(TEXT("hullHp"), HullHp);
	Body->SetNumberField(TEXT("crew"), Crew);
	Body->SetNumberField(TEXT("injured"), Injured);
	Body->SetNumberField(TEXT("provisions"), Provisions);
	FVCHttp::Send(TEXT("PUT"), FString::Printf(TEXT("%s/ships/%lld/state"), *CharacterUrl(CharacterId), InstanceId),
		Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::AdminGrantGold(int64 CharacterId, int64 Amount, const TSharedRef<FJsonObject>& AdminContext, FVCHttpCallback Callback)
{
	AdminContext->SetNumberField(TEXT("amount"), static_cast<double>(Amount));
	AdminContext->SetStringField(TEXT("idempotencyKey"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	FVCHttp::Send(TEXT("POST"), CharacterUrl(CharacterId) + TEXT("/gold"), AdminContext, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::ReportDiscovery(int64 CharacterId, int64 AccountId, const FString& DiscoveryCode, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetNumberField(TEXT("characterId"), static_cast<double>(CharacterId));
	Body->SetNumberField(TEXT("accountId"), static_cast<double>(AccountId));
	Body->SetStringField(TEXT("serverId"), UVCServerSettings::GetServerId());
	Body->SetStringField(TEXT("discoveryCode"), DiscoveryCode);
	FVCHttp::Send(TEXT("POST"), UVCBackendSettings::GetGameDataBaseUrl() + TEXT("/internal/v1/world/discoveries"),
		Body, Headers(), MoveTemp(Callback));
}

void FVCServerBackend::RequestTransfer(int64 CharacterId, int64 AccountId, const FString& ExitCode, FVCHttpCallback Callback)
{
	const TSharedRef<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetNumberField(TEXT("characterId"), static_cast<double>(CharacterId));
	Body->SetNumberField(TEXT("accountId"), static_cast<double>(AccountId));
	Body->SetStringField(TEXT("serverId"), UVCServerSettings::GetServerId());
	Body->SetStringField(TEXT("exitCode"), ExitCode);
	FVCHttp::Send(TEXT("POST"), UVCBackendSettings::GetGameDataBaseUrl() + TEXT("/internal/v1/world/transfers"),
		Body, Headers(), MoveTemp(Callback));
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
void FVCServerBackend::SaveCharacter(int64, int64, const FString&, const FVector&, float, const FIntVector4&, bool, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::StartServer(const FString&, int32, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::Heartbeat(const FString&, int32, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::ClaimCharacter(int64, int64, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::ReleaseCharacter(int64) {}
void FVCServerBackend::RequestTransfer(int64, int64, const FString&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::ReportDiscovery(int64, int64, const FString&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::BuyShip(int64, int64, const FString&, const FString&, const FGuid&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::SetActiveShip(int64, int64, int64, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::SaveShip(int64, int64, int64, int32, int32, int32, int32, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::ShipService(int64, int64, int64, const FString&, const FString&, int32, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::AdminGrantGold(int64, int64, const TSharedRef<FJsonObject>&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::ViewMarket(int64, int64, const FString&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::LoadInventory(int64, int64, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::Gather(int64, int64, const FString&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::Auction(int64, int64, const FString&, const FString&, int64, int32, int64, const FString&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::LoadRecipes(int64, int64, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::Craft(int64, int64, const FString&, int32, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::InventoryAction(int64, int64, const FString&, int64, int32, const FString&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::AdminGrantItem(int64, const FString&, int32, const TSharedRef<FJsonObject>&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::Trade(int64, int64, const FString&, const FString&, const FString&, int32, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::LoadZone(const FString&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::ReportKill(const TSharedRef<FJsonObject>&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::WriteAdminAudit(const TSharedRef<FJsonObject>&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::GrantExperience(int64, int64, const FString&, int64, const FString&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::SaveHotbar(int64, int64, const TArray<FName>&, FVCHttpCallback Callback) { Refuse(Callback); }
void FVCServerBackend::AdminSetLevel(int64, const FString&, int32, const TSharedRef<FJsonObject>&, FVCHttpCallback Callback) { Refuse(Callback); }

#endif // WITH_SERVER_CODE
