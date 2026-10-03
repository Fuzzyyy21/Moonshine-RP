#pragma once

#include "CoreMinimal.h"
#include "Dom/JsonObject.h"
#include "Dom/JsonValue.h"

/** Ergebnis eines Backend-Aufrufs. Json ist gesetzt, wenn die Antwort ein JSON-Objekt war. */
struct VCNET_API FVCHttpResult
{
	bool bConnected = false;
	int32 Status = 0;
	FString Body;
	TSharedPtr<FJsonValue> JsonValue;
	TSharedPtr<FJsonObject> Json;

	bool IsOk() const { return bConnected && Status >= 200 && Status < 300; }

	/** Titel einer ProblemDetails-Antwort des Backends oder eine generische Meldung. */
	FString ErrorMessage() const;
};

using FVCHttpCallback = TFunction<void(const FVCHttpResult&)>;

/**
 * Schlanker JSON-über-HTTP-Client für die Backend-Dienste.
 * Callbacks laufen auf dem Game Thread (Standard des HTTP-Moduls). Wer Objekte im Callback
 * benutzt, muss sie per TWeakObjectPtr fangen, weil sie inzwischen zerstört sein können.
 */
class VCNET_API FVCHttp
{
public:
	static void Send(const FString& Verb, const FString& Url, const TSharedPtr<FJsonObject>& Body,
		const TMap<FString, FString>& Headers, FVCHttpCallback Callback);

	static FString ToJson(const TSharedRef<FJsonObject>& Object);

	/** Liest eine Ganzzahl-ID (z. B. accountId) aus einem JSON-Objekt. */
	static bool TryGetId(const TSharedPtr<FJsonObject>& Object, const FString& Field, int64& OutId);
};
