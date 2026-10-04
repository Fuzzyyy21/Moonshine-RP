#include "SVCCharacterScreen.h"
#include "Widgets/Input/SButton.h"
#include "Widgets/Input/SComboBox.h"
#include "Widgets/Input/SEditableTextBox.h"
#include "Widgets/Input/SSpinBox.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/Layout/SScrollBox.h"
#include "Widgets/SBoxPanel.h"
#include "Widgets/Text/STextBlock.h"

#define LOCTEXT_NAMESPACE "VCCharacterScreen"

namespace
{
	FText ProfessionLabel(const FVCProfessionOption& P)
	{
		// Deutsch (Chinesisch) und ein Hinweis, wenn der Beruf nur unsicher belegt ist.
		FString Label = P.NameDe.IsEmpty() ? P.Code : P.NameDe;
		if (!P.NameZh.IsEmpty())
		{
			Label += FString::Printf(TEXT(" (%s)"), *P.NameZh);
		}
		if (P.Confidence == TEXT("UNCERTAIN") || P.Confidence == TEXT("UNKNOWN"))
		{
			Label += TEXT(" – Quellenlage unsicher");
		}
		return FText::FromString(Label);
	}

	FText SlotLabel(const FString& Slot)
	{
		static const TMap<FString, FText> Labels = {
			{ TEXT("face"), LOCTEXT("Face", "Gesicht") },
			{ TEXT("hair"), LOCTEXT("Hair", "Frisur") },
			{ TEXT("hairColor"), LOCTEXT("HairColor", "Haarfarbe") },
			{ TEXT("skin"), LOCTEXT("Skin", "Haut") },
			{ TEXT("body"), LOCTEXT("Body", "Körperbau") },
			{ TEXT("outfit"), LOCTEXT("Outfit", "Kleidung") },
		};
		const FText* Found = Labels.Find(Slot);
		return Found ? *Found : FText::FromString(Slot);
	}
}

void SVCCharacterScreen::Construct(const FArguments& InArgs)
{
	Session = InArgs._Session;
	if (UVCSessionSubsystem* S = Session.Get())
	{
		S->OnStatus.AddSP(this, &SVCCharacterScreen::HandleStatus);
		S->OnLoggedIn.AddSP(this, &SVCCharacterScreen::HandleLoggedIn);
		S->OnCharacters.AddSP(this, &SVCCharacterScreen::HandleCharacters);
		S->OnOptions.AddSP(this, &SVCCharacterScreen::HandleOptions);
	}

	ChildSlot
	[
		SNew(SBox).HAlign(HAlign_Center).VAlign(VAlign_Center).WidthOverride(720.f)
		[
			SNew(SBorder).Padding(16.f)
			[
				SNew(SVerticalBox)
				+ SVerticalBox::Slot().AutoHeight().Padding(0, 0, 0, 12)
				[
					SNew(STextBlock).Text(LOCTEXT("Title", "Voyage Century – 航海世纪"))
				]
				+ SVerticalBox::Slot().AutoHeight()[ MakeLoginPanel() ]
				+ SVerticalBox::Slot().AutoHeight().Padding(0, 12)[ MakeCharacterPanel() ]
				+ SVerticalBox::Slot().AutoHeight()[ MakeCreatePanel() ]
				+ SVerticalBox::Slot().AutoHeight().Padding(0, 12, 0, 0)
				[
					SNew(STextBlock).AutoWrapText(true).Text_Lambda([this] { return StatusText; })
				]
			]
		]
	];
}

TSharedRef<SWidget> SVCCharacterScreen::MakeLoginPanel()
{
	return SNew(SHorizontalBox)
		.Visibility_Lambda([this] { return bLoggedIn ? EVisibility::Collapsed : EVisibility::Visible; })
		+ SHorizontalBox::Slot().FillWidth(1.f).Padding(0, 0, 8, 0)
		[
			SAssignNew(LoginBox, SEditableTextBox).HintText(LOCTEXT("Login", "Login"))
		]
		+ SHorizontalBox::Slot().FillWidth(1.f).Padding(0, 0, 8, 0)
		[
			SAssignNew(PasswordBox, SEditableTextBox).IsPassword(true).HintText(LOCTEXT("Password", "Passwort"))
		]
		+ SHorizontalBox::Slot().AutoWidth()
		[
			SNew(SButton).Text(LOCTEXT("DoLogin", "Anmelden")).OnClicked(this, &SVCCharacterScreen::OnLoginClicked)
		];
}

TSharedRef<SWidget> SVCCharacterScreen::MakeCharacterPanel()
{
	return SNew(SVerticalBox)
		.Visibility_Lambda([this] { return bLoggedIn ? EVisibility::Visible : EVisibility::Collapsed; })
		+ SVerticalBox::Slot().AutoHeight().Padding(0, 0, 0, 4)
		[
			SNew(SHorizontalBox)
			+ SHorizontalBox::Slot().AutoWidth().VAlign(VAlign_Center).Padding(0, 0, 8, 0)
			[
				SNew(STextBlock).Text(LOCTEXT("Server", "Server"))
			]
			+ SHorizontalBox::Slot().FillWidth(1.f)
			[
				SAssignNew(ServerBox, SEditableTextBox).Text(FText::FromString(TEXT("127.0.0.1:7777")))
			]
		]
		+ SVerticalBox::Slot().AutoHeight().MaxHeight(220.f)
		[
			SNew(SScrollBox) + SScrollBox::Slot()[ SAssignNew(CharacterList, SVerticalBox) ]
		];
}

TSharedRef<SWidget> SVCCharacterScreen::MakeCreatePanel()
{
	return SNew(SVerticalBox)
		.Visibility_Lambda([this] { return bLoggedIn ? EVisibility::Visible : EVisibility::Collapsed; })
		+ SVerticalBox::Slot().AutoHeight().Padding(0, 0, 0, 4)
		[
			SNew(STextBlock).Text(LOCTEXT("Create", "Neuer Charakter"))
		]
		+ SVerticalBox::Slot().AutoHeight().Padding(0, 2)
		[
			SAssignNew(NameBox, SEditableTextBox).HintText(LOCTEXT("Name", "Name (2–24 Buchstaben oder Ziffern)"))
		]
		+ SVerticalBox::Slot().AutoHeight().Padding(0, 2)
		[
			SAssignNew(GenderCombo, SComboBox<TSharedPtr<FString>>)
			.OptionsSource(&GenderItems)
			.OnGenerateWidget_Static(&SVCCharacterScreen::MakeComboRow)
			.OnSelectionChanged_Lambda([this](TSharedPtr<FString> Item, ESelectInfo::Type) { SelectedGender = Item; })
			[
				SNew(STextBlock).Text_Lambda([this]
				{
					return SelectedGender.IsValid() ? FText::FromString(*SelectedGender) : LOCTEXT("Gender", "Geschlecht wählen");
				})
			]
		]
		+ SVerticalBox::Slot().AutoHeight().Padding(0, 2)
		[
			SAssignNew(ProfessionCombo, SComboBox<TSharedPtr<FString>>)
			.OptionsSource(&ProfessionItems)
			.OnGenerateWidget_Static(&SVCCharacterScreen::MakeComboRow)
			.OnSelectionChanged_Lambda([this](TSharedPtr<FString> Item, ESelectInfo::Type) { SelectedProfession = Item; })
			[
				SNew(STextBlock).Text_Lambda([this]
				{
					return SelectedProfession.IsValid() ? FText::FromString(*SelectedProfession) : LOCTEXT("Profession", "Beruf wählen");
				})
			]
		]
		+ SVerticalBox::Slot().AutoHeight().Padding(0, 4)
		[
			SAssignNew(AppearanceList, SVerticalBox)
		]
		+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Right)
		[
			SNew(SButton).Text(LOCTEXT("DoCreate", "Anlegen")).OnClicked(this, &SVCCharacterScreen::OnCreateClicked)
		];
}

TSharedRef<SWidget> SVCCharacterScreen::MakeComboRow(TSharedPtr<FString> Item)
{
	return SNew(STextBlock).Text(FText::FromString(Item.IsValid() ? *Item : FString()));
}

void SVCCharacterScreen::HandleStatus(bool, const FString& Message)
{
	StatusText = FText::FromString(Message);
}

void SVCCharacterScreen::HandleLoggedIn()
{
	bLoggedIn = true;
	if (UVCSessionSubsystem* S = Session.Get())
	{
		S->FetchOptions();
		S->ListCharacters();
	}
}

void SVCCharacterScreen::HandleCharacters(const TArray<FVCCharacterSummary>& Characters)
{
	CharacterList->ClearChildren();
	for (const FVCCharacterSummary& C : Characters)
	{
		const int64 Id = C.CharacterId;
		CharacterList->AddSlot().AutoHeight().Padding(0, 2)
		[
			SNew(SHorizontalBox)
			+ SHorizontalBox::Slot().FillWidth(1.f).VAlign(VAlign_Center)
			[
				SNew(STextBlock).Text(FText::FromString(
					FString::Printf(TEXT("%s – %s, Stufe %d"), *C.Name, *C.ProfessionCode, C.Level)))
			]
			+ SHorizontalBox::Slot().AutoWidth()
			[
				SNew(SButton).Text(LOCTEXT("Play", "Spielen"))
				.OnClicked(this, &SVCCharacterScreen::OnPlayClicked, Id)
			]
		];
	}
}

void SVCCharacterScreen::HandleOptions(const TArray<FVCProfessionOption>& Professions, const TArray<FString>& Genders,
	const TArray<FVCAppearanceSlotOption>& Slots)
{
	ProfessionItems.Reset();
	ProfessionCodeByLabel.Reset();
	for (const FVCProfessionOption& P : Professions)
	{
		const FString Label = ProfessionLabel(P).ToString();
		ProfessionItems.Add(MakeShared<FString>(Label));
		ProfessionCodeByLabel.Add(Label, P.Code);
	}
	GenderItems.Reset();
	for (const FString& G : Genders)
	{
		GenderItems.Add(MakeShared<FString>(G));
	}
	ProfessionCombo->RefreshOptions();
	GenderCombo->RefreshOptions();

	AppearanceValues.Reset();
	AppearanceList->ClearChildren();
	for (const FVCAppearanceSlotOption& Slot : Slots)
	{
		const FString Key = Slot.Slot;
		AppearanceValues.Add(Key, 0);
		AppearanceList->AddSlot().AutoHeight().Padding(0, 1)
		[
			SNew(SHorizontalBox)
			+ SHorizontalBox::Slot().FillWidth(0.4f).VAlign(VAlign_Center)
			[
				SNew(STextBlock).Text(SlotLabel(Key))
			]
			+ SHorizontalBox::Slot().FillWidth(0.6f)
			[
				SNew(SSpinBox<int32>)
				.MinValue(0).MaxValue(Slot.OptionCount - 1).MinSliderValue(0).MaxSliderValue(Slot.OptionCount - 1)
				.Value_Lambda([this, Key] { return AppearanceValues.FindRef(Key); })
				.OnValueChanged_Lambda([this, Key](int32 V) { AppearanceValues.Add(Key, V); })
			]
		];
	}
}

FReply SVCCharacterScreen::OnLoginClicked()
{
	if (UVCSessionSubsystem* S = Session.Get())
	{
		S->Login(LoginBox->GetText().ToString(), PasswordBox->GetText().ToString());
		PasswordBox->SetText(FText::GetEmpty());
	}
	return FReply::Handled();
}

FReply SVCCharacterScreen::OnCreateClicked()
{
	UVCSessionSubsystem* S = Session.Get();
	const FString* Code = SelectedProfession.IsValid() ? ProfessionCodeByLabel.Find(*SelectedProfession) : nullptr;
	if (!S || !Code || !SelectedGender.IsValid() || NameBox->GetText().IsEmpty())
	{
		StatusText = LOCTEXT("Missing", "Bitte Name, Geschlecht und Beruf wählen.");
		return FReply::Handled();
	}
	S->CreateCharacter(NameBox->GetText().ToString(), *SelectedGender, *Code, AppearanceValues);
	return FReply::Handled();
}

FReply SVCCharacterScreen::OnPlayClicked(int64 CharacterId)
{
	if (UVCSessionSubsystem* S = Session.Get())
	{
		S->ConnectToZone(ServerBox->GetText().ToString(), CharacterId);
	}
	return FReply::Handled();
}

#undef LOCTEXT_NAMESPACE
