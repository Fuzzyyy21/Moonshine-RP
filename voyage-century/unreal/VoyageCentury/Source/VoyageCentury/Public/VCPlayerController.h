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
 *   VCCharacterScreen                                    Login-/Erstellungsoberfläche öffnen (startet offline automatisch)
 *   VCStatus                                             eigenes Level, XP und Skills (Anzeige-Kopie vom Server)
 *   VCAdmin "teleport <x> <y> <z>"                       nur mit Adminrecht, wird protokolliert
 *   VCAdmin "setlevel <stufe>" | "setskill <SKILL> <stufe>"
 *   VCAdmin "givexp <menge>"   | "giveskillxp <SKILL> <menge>"
 *   VCAbilities                                          alle Fähigkeiten mit Voraussetzungen
 *   VCHotbar <platz 1-10> <CODE|leer>                    Hotbar belegen (Server prüft und speichert)
 *
 * Passwörter in der Konsole sind nur für die Entwicklung gedacht; die Login-Oberfläche folgt.
 */
UCLASS()
class VOYAGECENTURY_API AVCPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	UFUNCTION(Exec)
	void VCCharacterScreen();

	UFUNCTION(Exec)
	void VCLogin(const FString& Login, const FString& Password);

	UFUNCTION(Exec)
	void VCCharacters();

	UFUNCTION(Exec)
	void VCCreateCharacter(const FString& Name, const FString& Gender, const FString& Profession);

	UFUNCTION(Exec)
	void VCConnect(const FString& Address, const FString& CharacterId);

	/** Zeigt den replizierten Fortschritt. Ändern kann ihn nur der Server. */
	UFUNCTION(Exec)
	void VCStatus();

	/** Admin-Kommando an den Server senden. Der Server prüft Rechte und protokolliert vor der Ausführung. */
	UFUNCTION(Exec)
	void VCAdmin(const FString& CommandLine);

	/** Listet die Fähigkeiten aus DT_Abilities mit Skill, Stufe, Waffe, Ausdauer und Abklingzeit. */
	UFUNCTION(Exec)
	void VCAbilities();

	/** Hotbar-Platz (1–10) belegen; "leer" oder "-" leert ihn. */
	UFUNCTION(Exec)
	void VCHotbar(const FString& Slot, const FString& AbilityCode);

protected:
	UFUNCTION(Server, Reliable, WithValidation)
	void ServerAdminCommand(const FString& CommandLine);

	UFUNCTION(Server, Reliable, WithValidation)
	void ServerSetHotbarSlot(int32 Slot, FName AbilityCode);

private:
	class UVCSessionSubsystem* Session() const;

	TSharedPtr<class SWidget> CharacterScreen;
	void HideCharacterScreen();
};
