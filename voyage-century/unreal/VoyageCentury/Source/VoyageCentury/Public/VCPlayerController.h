#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "VCPlayerController.generated.h"

/**
 * PlayerController für Client und Server.
 *
 * Phase-1-Konsolenbefehle (Client):
 *   VCLogin <login> <passwort>
 *   VCCharacters
 *   VCCreateCharacter <name> <MALE|FEMALE> <BERUF>      z. B. ROYAL_OFFICER
 *   VCConnect <host:port> <characterId>
 *   VCAdmin "teleport <x> <y> <z>"                       nur mit Adminrecht, wird protokolliert
 *
 * Passwörter in der Konsole sind nur für die Entwicklung gedacht; die Login-Oberfläche folgt.
 */
UCLASS()
class VOYAGECENTURY_API AVCPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	UFUNCTION(Exec)
	void VCLogin(const FString& Login, const FString& Password);

	UFUNCTION(Exec)
	void VCCharacters();

	UFUNCTION(Exec)
	void VCCreateCharacter(const FString& Name, const FString& Gender, const FString& Profession);

	UFUNCTION(Exec)
	void VCConnect(const FString& Address, const FString& CharacterId);

	/** Admin-Kommando an den Server senden. Der Server prüft Rechte und protokolliert vor der Ausführung. */
	UFUNCTION(Exec)
	void VCAdmin(const FString& CommandLine);

protected:
	UFUNCTION(Server, Reliable, WithValidation)
	void ServerAdminCommand(const FString& CommandLine);

private:
	class UVCSessionSubsystem* Session() const;
};
