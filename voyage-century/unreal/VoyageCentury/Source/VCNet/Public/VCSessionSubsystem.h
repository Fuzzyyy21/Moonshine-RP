#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "VCSessionSubsystem.generated.h"

/**
 * Clientseitiger Login-Ablauf: Login beim Auth-Dienst, Charaktere anlegen/auflisten,
 * mit Ticket zu einem Zonen-Server verbinden. Überlebt Map-Wechsel (GameInstance).
 *
 * Phase 1: Bedienung über Konsolenbefehle des PlayerControllers (VCLogin, VCCharacters, ...).
 * Eine Login-Oberfläche folgt in Phase 2 und nutzt dieselben Funktionen.
 */
UCLASS()
class VCNET_API UVCSessionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	DECLARE_MULTICAST_DELEGATE_TwoParams(FOnVCStatus, bool /*bSuccess*/, const FString& /*Message*/);

	/** Meldet jedes Ergebnis (Erfolg/Fehler + lesbarer Text) an UI oder Konsole. */
	FOnVCStatus OnStatus;

	void Login(const FString& LoginName, const FString& Password);
	void ListCharacters();
	void CreateCharacter(const FString& Name, const FString& Gender, const FString& ProfessionCode);

	/** Reist zu "host:port" und übergibt Ticket und Charakter als URL-Optionen. */
	void ConnectToZone(const FString& ServerAddress, int64 CharacterId);

	bool HasTicket() const { return !Ticket.IsEmpty(); }

private:
	FString Ticket;
	int64 AccountId = 0;

	TMap<FString, FString> AuthHeader() const;
	void Report(bool bSuccess, const FString& Message);
};
