#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "VCSessionSubsystem.generated.h"

/** Beruf, wie ihn der GameData-Dienst für die Erstellung anbietet. Confidence zeigt, wie gut er belegt ist. */
struct FVCProfessionOption
{
	FString Code;
	FString NameZh;
	FString NameEn;
	FString NameDe;
	FString Confidence;
};

struct FVCAppearanceSlotOption
{
	FString Slot;
	int32 OptionCount = 1;
};

struct FVCCharacterSummary
{
	int64 CharacterId = 0;
	FString Name;
	FString ProfessionCode;
	int32 Level = 1;
};

DECLARE_MULTICAST_DELEGATE(FOnVCLoggedIn);
DECLARE_MULTICAST_DELEGATE_OneParam(FOnVCCharacters, const TArray<FVCCharacterSummary>& /*Characters*/);
DECLARE_MULTICAST_DELEGATE_ThreeParams(FOnVCOptions, const TArray<FVCProfessionOption>& /*Professions*/,
	const TArray<FString>& /*Genders*/, const TArray<FVCAppearanceSlotOption>& /*Slots*/);

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

	FOnVCLoggedIn OnLoggedIn;
	FOnVCCharacters OnCharacters;
	FOnVCOptions OnOptions;

	/** Berufe, Geschlechter und Aussehen-Merkmale für die Erstellung laden (aus dem Backend, nicht fest im Client). */
	void FetchOptions();

	void Login(const FString& LoginName, const FString& Password);
	void ListCharacters();
	void CreateCharacter(const FString& Name, const FString& Gender, const FString& ProfessionCode,
		const TMap<FString, int32>& Appearance = TMap<FString, int32>());

	/** Reist zu "host:port" und übergibt Ticket und Charakter als URL-Optionen. */
	void ConnectToZone(const FString& ServerAddress, int64 CharacterId);

	/** Fragt das World Directory, welcher Server für den Charakter zuständig ist, und verbindet dorthin. */
	void PlayCharacter(int64 CharacterId);

	bool HasTicket() const { return !Ticket.IsEmpty(); }

private:
	FString Ticket;
	int64 AccountId = 0;

	TMap<FString, FString> AuthHeader() const;
	void Report(bool bSuccess, const FString& Message);
};
