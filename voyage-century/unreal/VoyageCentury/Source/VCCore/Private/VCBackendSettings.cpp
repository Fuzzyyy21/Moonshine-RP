#include "VCBackendSettings.h"
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"

namespace
{
	FString WithOverride(const TCHAR* Switch, const FString& Configured)
	{
		FString Value;
		return FParse::Value(FCommandLine::Get(), Switch, Value) && !Value.IsEmpty() ? Value : Configured;
	}
}

FString UVCBackendSettings::GetAuthBaseUrl()
{
	return WithOverride(TEXT("VCAuthUrl="), GetDefault<UVCBackendSettings>()->AuthBaseUrl);
}

FString UVCBackendSettings::GetGameDataBaseUrl()
{
	return WithOverride(TEXT("VCGameDataUrl="), GetDefault<UVCBackendSettings>()->GameDataBaseUrl);
}
