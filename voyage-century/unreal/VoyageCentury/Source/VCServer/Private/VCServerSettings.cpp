#include "VCServerSettings.h"
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
