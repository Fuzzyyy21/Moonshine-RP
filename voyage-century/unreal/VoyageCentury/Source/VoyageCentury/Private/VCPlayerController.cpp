#include "VCPlayerController.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "GameFramework/GameModeBase.h"
#include "VCCore.h"
#include "Engine/Engine.h"
#include "Engine/GameViewportClient.h"
#include "SVCCharacterScreen.h"
#include "AbilitySystemComponent.h"
#include "VCAbilityStateComponent.h"
#include "VCAttributeSet.h"
#include "VCCombatData.h"
#include "VCPlayerState.h"
#include "VCProgressionComponent.h"
#include "VCServerHooks.h"
#include "VCSessionSubsystem.h"

namespace
{
	constexpr int32 MaxAdminCommandLength = 256;

	void ShowLine(const FString& Line, const FColor& Color = FColor::Cyan)
	{
		UE_LOG(LogVC, Display, TEXT("%s"), *Line);
		if (GEngine)
		{
			GEngine->AddOnScreenDebugMessage(-1, 8.f, Color, Line);
		}
	}

	const TCHAR* WeaponName(EVCWeaponClass Class)
	{
		switch (Class)
		{
		case EVCWeaponClass::Sword: return TEXT("Schwert");
		case EVCWeaponClass::Blade: return TEXT("Klinge");
		case EVCWeaponClass::Axe: return TEXT("Axt");
		case EVCWeaponClass::Firearm: return TEXT("Schusswaffe");
		default: return TEXT("unbewaffnet");
		}
	}
}

void AVCPlayerController::BeginPlay()
{
	Super::BeginPlay();
	// Offline-Start eines gepackten Clients: noch keine Verbindung, also Login-Oberfläche zeigen.
	const UWorld* World = GetWorld();
	if (IsLocalController() && GetNetMode() == NM_Standalone && World && !World->IsPlayInEditor())
	{
		VCCharacterScreen();
	}
}

void AVCPlayerController::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	// Das Viewport überlebt Map-Wechsel; das Widget muss vor dem Reisen entfernt werden.
	HideCharacterScreen();
	Super::EndPlay(EndPlayReason);
}

void AVCPlayerController::VCCharacterScreen()
{
	if (CharacterScreen.IsValid() || !IsLocalController() || !GEngine || !GEngine->GameViewport)
	{
		return;
	}
	CharacterScreen = SNew(SVCCharacterScreen).Session(Session());
	GEngine->GameViewport->AddViewportWidgetContent(CharacterScreen.ToSharedRef(), 10);
	SetShowMouseCursor(true);
	FInputModeUIOnly Mode;
	Mode.SetWidgetToFocus(CharacterScreen);
	SetInputMode(Mode);
}

void AVCPlayerController::HideCharacterScreen()
{
	if (!CharacterScreen.IsValid())
	{
		return;
	}
	if (GEngine && GEngine->GameViewport)
	{
		GEngine->GameViewport->RemoveViewportWidgetContent(CharacterScreen.ToSharedRef());
	}
	CharacterScreen.Reset();
	if (IsLocalController())
	{
		SetShowMouseCursor(false);
		SetInputMode(FInputModeGameOnly());
	}
}

UVCSessionSubsystem* AVCPlayerController::Session() const
{
	const UGameInstance* GameInstance = GetGameInstance();
	return GameInstance ? GameInstance->GetSubsystem<UVCSessionSubsystem>() : nullptr;
}

void AVCPlayerController::VCLogin(const FString& Login, const FString& Password)
{
	if (UVCSessionSubsystem* S = Session())
	{
		S->Login(Login, Password);
	}
}

void AVCPlayerController::VCCharacters()
{
	if (UVCSessionSubsystem* S = Session())
	{
		S->ListCharacters();
	}
}

void AVCPlayerController::VCCreateCharacter(const FString& Name, const FString& Gender, const FString& Profession)
{
	if (UVCSessionSubsystem* S = Session())
	{
		S->CreateCharacter(Name, Gender, Profession);
	}
}

void AVCPlayerController::VCConnect(const FString& Address, const FString& CharacterId)
{
	if (UVCSessionSubsystem* S = Session())
	{
		S->ConnectToZone(Address, FCString::Atoi64(*CharacterId));
	}
}

void AVCPlayerController::VCPlay(const FString& CharacterId)
{
	if (UVCSessionSubsystem* S = Session())
	{
		S->PlayCharacter(FCString::Atoi64(*CharacterId));
	}
}

void AVCPlayerController::ClientShowNpcDialog_Implementation(FName NpcCode)
{
	OnNpcDialog.Broadcast(NpcCode);
}

void AVCPlayerController::ClientDiscovered_Implementation(FName DiscoveryCode, int64 XpAwarded)
{
	OnDiscovered.Broadcast(DiscoveryCode, XpAwarded);
}

void AVCPlayerController::ClientTravelToZone_Implementation(const FString& Address, int64 CharacterId)
{
	// Das Ticket hat nur der Client; der Server nennt nur das Ziel.
	if (UVCSessionSubsystem* S = Session())
	{
		S->ConnectToZone(Address, CharacterId);
	}
}

void AVCPlayerController::VCStatus()
{
	const AVCPlayerState* PS = GetPlayerState<AVCPlayerState>();
	const UVCProgressionComponent* Progression = PS ? PS->GetProgression() : nullptr;
	if (!Progression)
	{
		ClientMessage(TEXT("Noch kein Charakter geladen."));
		return;
	}
	TArray<FString> Lines;
	Lines.Add(FString::Printf(TEXT("Stufe %d, XP %lld"), Progression->GetLevel(), Progression->GetExperience()));
	if (const UAbilitySystemComponent* ASC = PS->GetAbilitySystemComponent())
	{
		Lines.Add(FString::Printf(TEXT("Leben %.0f / %.0f, Ausdauer %.0f / %.0f"),
			ASC->GetNumericAttribute(UVCAttributeSet::GetHealthAttribute()),
			ASC->GetNumericAttribute(UVCAttributeSet::GetMaxHealthAttribute()),
			ASC->GetNumericAttribute(UVCAttributeSet::GetStaminaAttribute()),
			ASC->GetNumericAttribute(UVCAttributeSet::GetMaxStaminaAttribute())));
	}
	for (const FVCSkillState& Skill : Progression->GetSkills())
	{
		Lines.Add(FString::Printf(TEXT("  %s: Stufe %d (Skillstufe %d), XP %lld"),
			*Skill.Code.ToString(), Skill.Level, Skill.Stage, Skill.Experience));
	}
	for (const FString& Line : Lines)
	{
		UE_LOG(LogVC, Display, TEXT("%s"), *Line);
		if (GEngine)
		{
			GEngine->AddOnScreenDebugMessage(-1, 8.f, FColor::Cyan, Line);
		}
	}
}

void AVCPlayerController::VCAdmin(const FString& CommandLine)
{
	ServerAdminCommand(CommandLine);
}

bool AVCPlayerController::ServerAdminCommand_Validate(const FString& CommandLine)
{
	// Überlange Eingaben gelten als Manipulation und trennen die Verbindung.
	return CommandLine.Len() <= MaxAdminCommandLength;
}

void AVCPlayerController::ServerAdminCommand_Implementation(const FString& CommandLine)
{
	UWorld* World = GetWorld();
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(World ? World->GetAuthGameMode() : nullptr))
	{
		Hooks->HandleAdminCommand(this, CommandLine);
	}
	else
	{
		UE_LOG(LogVC, Warning, TEXT("Admin-Kommando ohne Server-GameMode verworfen"));
	}
}

void AVCPlayerController::VCAbilities()
{
	if (!FVCCombatData::AreAbilitiesAvailable())
	{
		ShowLine(TEXT("Keine Fähigkeitsdaten (DT_Abilities/DT_StatusEffects importieren)."), FColor::Red);
		return;
	}
	for (const FName& Code : FVCCombatData::AbilityCodes())
	{
		const FVCAbilityRow* Row = FVCCombatData::FindAbility(Code);
		if (!Row)
		{
			continue;
		}
		ShowLine(FString::Printf(TEXT("%s (%s): %s ab Stufe %d, %s, Ausdauer %.0f, Abklingzeit %.0f s%s"),
			*Code.ToString(), *Row->NameDe, *Row->SkillCode.ToString(), Row->RequiredSkillLevel,
			Row->bRequiresWeaponClass ? WeaponName(Row->RequiredWeaponClass) : TEXT("jede Waffe"),
			Row->StaminaCost, Row->CooldownSeconds, Row->bIsDev ? TEXT(" [DEV]") : TEXT("")));
	}
}

void AVCPlayerController::VCHotbar(const FString& Slot, const FString& AbilityCode)
{
	int32 Number = 0;
	if (!LexTryParseString(Number, *Slot) || Number < 1 || Number > UVCAbilityStateComponent::HotbarSlots)
	{
		ShowLine(TEXT("Aufruf: VCHotbar <1-10> <CODE|leer>"), FColor::Red);
		return;
	}
	const bool bClear = AbilityCode.IsEmpty() || AbilityCode == TEXT("-") || AbilityCode.Equals(TEXT("leer"), ESearchCase::IgnoreCase);
	ServerSetHotbarSlot(Number - 1, bClear ? NAME_None : FName(*AbilityCode.ToUpper()));
}

bool AVCPlayerController::ServerSetHotbarSlot_Validate(int32 Slot, FName AbilityCode)
{
	return Slot >= 0 && Slot < UVCAbilityStateComponent::HotbarSlots && AbilityCode.GetStringLength() <= 64;
}

void AVCPlayerController::ServerSetHotbarSlot_Implementation(int32 Slot, FName AbilityCode)
{
	UWorld* World = GetWorld();
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(World ? World->GetAuthGameMode() : nullptr))
	{
		Hooks->HandleHotbarChange(this, Slot, AbilityCode);
	}
}

void AVCPlayerController::VCShips()
{
	ServerShipCommand(TEXT("list"), FString());
}

void AVCPlayerController::VCBuyShip(const FString& ShipCode)
{
	ServerShipCommand(TEXT("buy"), ShipCode);
}

void AVCPlayerController::VCSetShip(const FString& InstanceId)
{
	ServerShipCommand(TEXT("activate"), InstanceId);
}

bool AVCPlayerController::ServerShipCommand_Validate(const FString& Command, const FString& Argument)
{
	return Command.Len() <= 16 && Argument.Len() <= 64;
}

void AVCPlayerController::ServerShipCommand_Implementation(const FString& Command, const FString& Argument)
{
	UWorld* World = GetWorld();
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(World ? World->GetAuthGameMode() : nullptr))
	{
		Hooks->HandleShipCommand(this, Command, Argument);
	}
}

void AVCPlayerController::VCShipService(const FString& Kind, const FString& Amount)
{
	ServerShipCommand(TEXT("service"), Amount.IsEmpty() ? Kind : Kind + TEXT(" ") + Amount);
}

void AVCPlayerController::VCInventory()
{
	ServerInventoryCommand(TEXT("list"), FString());
}

void AVCPlayerController::VCEquip(const FString& InstanceId)
{
	ServerInventoryCommand(TEXT("equip"), InstanceId);
}

void AVCPlayerController::VCUnequip(const FString& Slot)
{
	ServerInventoryCommand(TEXT("unequip"), Slot);
}

void AVCPlayerController::VCDiscard(const FString& InstanceId, const FString& Quantity)
{
	ServerInventoryCommand(TEXT("discard"), InstanceId + TEXT(" ") + Quantity);
}

void AVCPlayerController::VCSellItem(const FString& InstanceId, const FString& Quantity)
{
	ServerInventoryCommand(TEXT("sell"), InstanceId + TEXT(" ") + Quantity);
}

bool AVCPlayerController::ServerInventoryCommand_Validate(const FString& Command, const FString& Argument)
{
	return Command.Len() <= 16 && Argument.Len() <= 64;
}

void AVCPlayerController::ServerInventoryCommand_Implementation(const FString& Command, const FString& Argument)
{
	// Nur bekannte Befehle weiterreichen; Besitz, Art und Menge prüft das Backend.
	static const TSet<FString> Allowed = { TEXT("list"), TEXT("equip"), TEXT("unequip"), TEXT("discard"), TEXT("sell"), TEXT("recipes"),
		TEXT("craft"), TEXT("auction") };
	UWorld* World = GetWorld();
	IVCServerHooks* Hooks = Cast<IVCServerHooks>(World ? World->GetAuthGameMode() : nullptr);
	if (Hooks && Allowed.Contains(Command))
	{
		Hooks->HandleInventoryCommand(this, Command, Argument);
	}
}

void AVCPlayerController::VCRecipes()
{
	ServerInventoryCommand(TEXT("recipes"), FString());
}

void AVCPlayerController::VCCraft(const FString& RecipeCode, const FString& Times)
{
	ServerInventoryCommand(TEXT("craft"), Times.IsEmpty() ? RecipeCode : RecipeCode + TEXT(" ") + Times);
}

void AVCPlayerController::VCSay(const FString& Message)
{
	ServerChat(TEXT("LOCAL"), FString(), Message);
}

void AVCPlayerController::VCWorld(const FString& Message)
{
	ServerChat(TEXT("WORLD"), FString(), Message);
}

void AVCPlayerController::VCTradeChat(const FString& Message)
{
	ServerChat(TEXT("TRADE"), FString(), Message);
}

void AVCPlayerController::VCWhisper(const FString& Name, const FString& Message)
{
	ServerChat(TEXT("WHISPER"), Name, Message);
}

void AVCPlayerController::VCFriends()
{
	ServerSocialCommand(TEXT("friends"), FString());
}

void AVCPlayerController::VCFriendAdd(const FString& Name)
{
	ServerSocialCommand(TEXT("friendadd"), Name);
}

void AVCPlayerController::VCFriendRemove(const FString& Name)
{
	ServerSocialCommand(TEXT("friendremove"), Name);
}

void AVCPlayerController::VCIgnores()
{
	ServerSocialCommand(TEXT("ignores"), FString());
}

void AVCPlayerController::VCIgnore(const FString& Name)
{
	ServerSocialCommand(TEXT("ignore"), Name);
}

void AVCPlayerController::VCUnignore(const FString& Name)
{
	ServerSocialCommand(TEXT("unignore"), Name);
}

void AVCPlayerController::VCReport(const FString& Name, const FString& Reason)
{
	ServerSocialCommand(TEXT("report"), Name + TEXT(" ") + Reason);
}

void AVCPlayerController::VCGuild()
{
	ServerSocialCommand(TEXT("guild"), FString());
}

void AVCPlayerController::VCGuildCreate(const FString& Name, const FString& Tag)
{
	ServerSocialCommand(TEXT("guildcreate"), (Tag.IsEmpty() ? FString(TEXT("-")) : Tag) + TEXT(" ") + Name);
}

void AVCPlayerController::VCGuildInvite(const FString& Name)
{
	ServerSocialCommand(TEXT("guildinvite"), Name);
}

void AVCPlayerController::VCGuildInvites()
{
	ServerSocialCommand(TEXT("guildinvites"), FString());
}

void AVCPlayerController::VCGuildAccept(const FString& GuildId)
{
	ServerSocialCommand(TEXT("guildaccept"), GuildId);
}

void AVCPlayerController::VCGuildDecline(const FString& GuildId)
{
	ServerSocialCommand(TEXT("guilddecline"), GuildId);
}

void AVCPlayerController::VCGuildKick(const FString& Name)
{
	ServerSocialCommand(TEXT("guildkick"), Name);
}

void AVCPlayerController::VCGuildRank(const FString& Name, const FString& Rank)
{
	ServerSocialCommand(TEXT("guildrank"), Name + TEXT(" ") + Rank);
}

void AVCPlayerController::VCGuildLeave()
{
	ServerSocialCommand(TEXT("guildleave"), FString());
}

void AVCPlayerController::VCGuildDisband()
{
	ServerSocialCommand(TEXT("guilddisband"), FString());
}

void AVCPlayerController::VCGuildChat(const FString& Message)
{
	ServerChat(TEXT("GUILD"), FString(), Message);
}

void AVCPlayerController::VCGuildDeposit(const FString& Gold)
{
	ServerSocialCommand(TEXT("guilddeposit"), Gold);
}

void AVCPlayerController::VCGuildWithdraw(const FString& Gold)
{
	ServerSocialCommand(TEXT("guildwithdraw"), Gold);
}

void AVCPlayerController::VCCities()
{
	ServerSocialCommand(TEXT("guildcities"), FString());
}

void AVCPlayerController::VCGuildBuyCity(const FString& City)
{
	ServerSocialCommand(TEXT("guildbuycity"), City);
}

void AVCPlayerController::VCGuildCityTax(const FString& City, const FString& Permille)
{
	ServerSocialCommand(TEXT("guildcitytax"), City + TEXT(" ") + Permille);
}

void AVCPlayerController::VCSieges()
{
	ServerSocialCommand(TEXT("guildsieges"), FString());
}

void AVCPlayerController::VCGuildSiege(const FString& City)
{
	ServerSocialCommand(TEXT("guildsiege"), City);
}

bool AVCPlayerController::ServerChat_Validate(const FString& Channel, const FString& Target, const FString& Message)
{
	return Channel.Len() <= 16 && Target.Len() <= 24 && Message.Len() <= 1000;
}

void AVCPlayerController::ServerChat_Implementation(const FString& Channel, const FString& Target, const FString& Message)
{
	UWorld* World = GetWorld();
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(World ? World->GetAuthGameMode() : nullptr))
	{
		Hooks->HandleChat(this, Channel, Target, Message);
	}
}

bool AVCPlayerController::ServerSocialCommand_Validate(const FString& Command, const FString& Argument)
{
	return Command.Len() <= 16 && Argument.Len() <= 600;
}

void AVCPlayerController::ServerSocialCommand_Implementation(const FString& Command, const FString& Argument)
{
	UWorld* World = GetWorld();
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(World ? World->GetAuthGameMode() : nullptr))
	{
		Hooks->HandleSocialCommand(this, Command, Argument);
	}
}

void AVCPlayerController::VCAuction(const FString& ItemCode)
{
	ServerInventoryCommand(TEXT("auction"), ItemCode.IsEmpty() ? FString(TEXT("search")) : TEXT("search ") + ItemCode);
}

void AVCPlayerController::VCAuctionMine()
{
	ServerInventoryCommand(TEXT("auction"), TEXT("mine"));
}

void AVCPlayerController::VCAuctionSell(const FString& InstanceId, const FString& Quantity, const FString& Price)
{
	ServerInventoryCommand(TEXT("auction"), FString::Printf(TEXT("list %s %s %s"), *InstanceId, *Quantity, *Price));
}

void AVCPlayerController::VCAuctionBuy(const FString& ListingId)
{
	ServerInventoryCommand(TEXT("auction"), TEXT("buy ") + ListingId);
}

void AVCPlayerController::VCAuctionCancel(const FString& ListingId)
{
	ServerInventoryCommand(TEXT("auction"), TEXT("cancel ") + ListingId);
}

void AVCPlayerController::VCAuctionCollect()
{
	ServerInventoryCommand(TEXT("auction"), TEXT("collect"));
}

void AVCPlayerController::VCMarket()
{
	ServerShipCommand(TEXT("market"), FString());
}

void AVCPlayerController::VCTrade(const FString& Side, const FString& ItemCode, const FString& Quantity)
{
	ServerShipCommand(TEXT("trade"), FString::Printf(TEXT("%s %s %s"), *Side, *ItemCode, *Quantity));
}
