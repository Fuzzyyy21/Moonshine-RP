#pragma once

#include "CoreMinimal.h"
#include "Widgets/SCompoundWidget.h"
#include "VCSessionSubsystem.h"

class SEditableTextBox;
class SVerticalBox;
class STextBlock;
template <typename OptionType> class SComboBox;

/**
 * Login, Charakterliste und Charaktererstellung (reines Slate, keine Widget-Assets).
 * Alle Auswahlmöglichkeiten kommen vom GameData-Dienst; die Oberfläche prüft nur Bedienfehler,
 * die verbindliche Prüfung macht der Server.
 */
class SVCCharacterScreen : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SVCCharacterScreen) {}
		SLATE_ARGUMENT(TWeakObjectPtr<UVCSessionSubsystem>, Session)
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs);

private:
	TWeakObjectPtr<UVCSessionSubsystem> Session;

	TSharedPtr<SEditableTextBox> LoginBox;
	TSharedPtr<SEditableTextBox> PasswordBox;
	TSharedPtr<SEditableTextBox> ServerBox;
	TSharedPtr<SEditableTextBox> NameBox;
	TSharedPtr<SVerticalBox> CharacterList;
	TSharedPtr<SVerticalBox> AppearanceList;
	TSharedPtr<SComboBox<TSharedPtr<FString>>> ProfessionCombo;
	TSharedPtr<SComboBox<TSharedPtr<FString>>> GenderCombo;

	TArray<TSharedPtr<FString>> ProfessionItems;
	TArray<TSharedPtr<FString>> GenderItems;
	TMap<FString, FString> ProfessionCodeByLabel;
	TSharedPtr<FString> SelectedProfession;
	TSharedPtr<FString> SelectedGender;
	TMap<FString, int32> AppearanceValues;
	FText StatusText;
	bool bLoggedIn = false;

	TSharedRef<SWidget> MakeLoginPanel();
	TSharedRef<SWidget> MakeCharacterPanel();
	TSharedRef<SWidget> MakeCreatePanel();
	static TSharedRef<SWidget> MakeComboRow(TSharedPtr<FString> Item);

	void HandleStatus(bool bSuccess, const FString& Message);
	void HandleLoggedIn();
	void HandleCharacters(const TArray<FVCCharacterSummary>& Characters);
	void HandleOptions(const TArray<FVCProfessionOption>& Professions, const TArray<FString>& Genders,
		const TArray<FVCAppearanceSlotOption>& Slots);

	FReply OnLoginClicked();
	FReply OnCreateClicked();
	FReply OnPlayClicked(int64 CharacterId);
};
