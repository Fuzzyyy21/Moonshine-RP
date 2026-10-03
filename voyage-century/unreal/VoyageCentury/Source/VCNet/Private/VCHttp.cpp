#include "VCHttp.h"
#include "HttpModule.h"
#include "Interfaces/IHttpRequest.h"
#include "Interfaces/IHttpResponse.h"
#include "Policies/CondensedJsonPrintPolicy.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"
#include "VCBackendSettings.h"

FString FVCHttpResult::ErrorMessage() const
{
	FString Title;
	if (Json.IsValid() && Json->TryGetStringField(TEXT("title"), Title))
	{
		return Title;
	}
	return bConnected ? FString::Printf(TEXT("HTTP %d"), Status) : TEXT("Backend nicht erreichbar");
}

void FVCHttp::Send(const FString& Verb, const FString& Url, const TSharedPtr<FJsonObject>& Body,
	const TMap<FString, FString>& Headers, FVCHttpCallback Callback)
{
	const TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Request = FHttpModule::Get().CreateRequest();
	Request->SetURL(Url);
	Request->SetVerb(Verb);
	Request->SetHeader(TEXT("Accept"), TEXT("application/json"));
	for (const TPair<FString, FString>& Header : Headers)
	{
		Request->SetHeader(Header.Key, Header.Value);
	}
	if (Body.IsValid())
	{
		Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
		Request->SetContentAsString(ToJson(Body.ToSharedRef()));
	}
	Request->SetTimeout(GetDefault<UVCBackendSettings>()->RequestTimeoutSeconds);

	Request->OnProcessRequestComplete().BindLambda(
		[Callback = MoveTemp(Callback)](FHttpRequestPtr, FHttpResponsePtr Response, bool bConnectedSuccessfully)
		{
			FVCHttpResult Result;
			Result.bConnected = bConnectedSuccessfully && Response.IsValid();
			if (Response.IsValid())
			{
				Result.Status = Response->GetResponseCode();
				Result.Body = Response->GetContentAsString();
				const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Result.Body);
				if (FJsonSerializer::Deserialize(Reader, Result.JsonValue) && Result.JsonValue.IsValid()
					&& Result.JsonValue->Type == EJson::Object)
				{
					Result.Json = Result.JsonValue->AsObject();
				}
			}
			Callback(Result);
		});
	Request->ProcessRequest();
}

FString FVCHttp::ToJson(const TSharedRef<FJsonObject>& Object)
{
	FString Out;
	using FCondensedWriter = TJsonWriter<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>;
	const TSharedRef<FCondensedWriter> Writer = TJsonWriterFactory<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>::Create(&Out);
	FJsonSerializer::Serialize(Object, Writer);
	return Out;
}

bool FVCHttp::TryGetId(const TSharedPtr<FJsonObject>& Object, const FString& Field, int64& OutId)
{
	double Number = 0.0;
	if (!Object.IsValid() || !Object->TryGetNumberField(Field, Number) || Number < 1.0)
	{
		return false;
	}
	// IDs kommen als JSON-Zahl; bis 2^53 exakt darstellbar, weit über jedem realistischen Bestand.
	OutId = static_cast<int64>(Number);
	return true;
}
