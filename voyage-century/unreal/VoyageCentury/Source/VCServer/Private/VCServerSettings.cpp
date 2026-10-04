#include "VCServerSettings.h"
#include "Engine/World.h"
#include "HAL/PlatformProcess.h"
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"

FString UVCServerSettings::GetZoneId()
{
	FString Value;
	return FParse::Value(FCommandLine::Get(), TEXT("VCZone="), Value) && !Value.IsEmpty()
		? Value
		: GetDefault<UVCServerSettings>()->ZoneId;
}

FString UVCServerSettings::GetServerId()
{
	FString Value;
	if (FParse::Value(FCommandLine::Get(), TEXT("VCServerId="), Value) && !Value.IsEmpty())
	{
		return Value;
	}
	return FString::Printf(TEXT("%s-%s"), *GetZoneId(), FPlatformProcess::ComputerName()).Left(64);
}

FString UVCServerSettings::GetPublicAddress(const UWorld* World)
{
	FString Value;
	if (FParse::Value(FCommandLine::Get(), TEXT("VCPublicAddress="), Value) && !Value.IsEmpty())
	{
		return Value;
	}
	const int32 Port = World ? World->URL.Port : 7777;
	return FString::Printf(TEXT("%s:%d"), *GetDefault<UVCServerSettings>()->PublicHost, Port);
}
