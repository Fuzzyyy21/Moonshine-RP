#include "VCGameMode.h"
#include "Engine/NetConnection.h"
#include "Engine/World.h"
#include "GameFramework/Character.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/GameSession.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PlayerStart.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"
#include "VCCharacter.h"
#include "VCCore.h"
#include "VCHUD.h"
#include "VCHttp.h"
#include "VCPlayerController.h"
#include "VCPlayerState.h"
#include "VCProgressionComponent.h"
#include "AbilitySystemComponent.h"
#include "VCAbilityStateComponent.h"
#include "VCAttributeSet.h"
#include "VCCombatData.h"
#include "VCCombatRules.h"
#include "VCCombatant.h"
#include "VCGameplayTags.h"
#include "EngineUtils.h"
#include "VCNavalData.h"
#include "VCNpc.h"
#include "VCServerBackend.h"
#include "VCShip.h"
#include "VCWorldData.h"
#include "VCServerSettings.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"

namespace
{
	TSharedRef<FJsonObject> VectorJson(const FVector& V)
	{
		const TSharedRef<FJsonObject> Obj = MakeShared<FJsonObject>();
		Obj->SetNumberField(TEXT("x"), V.X);
		Obj->SetNumberField(TEXT("y"), V.Y);
		Obj->SetNumberField(TEXT("z"), V.Z);
		return Obj;
	}

	UVCProgressionComponent* ProgressionOf(const APlayerController* PC)
	{
		const AVCPlayerState* PS = PC ? PC->GetPlayerState<AVCPlayerState>() : nullptr;
		return PS ? PS->GetProgression() : nullptr;
	}

	UAbilitySystemComponent* AbilitySystemOf(const APlayerController* PC)
	{
		const AVCPlayerState* PS = PC ? PC->GetPlayerState<AVCPlayerState>() : nullptr;
		return PS ? PS->GetAbilitySystemComponent() : nullptr;
	}

	UVCAbilityStateComponent* AbilityStateOf(const APlayerController* PC)
	{
		const AVCPlayerState* PS = PC ? PC->GetPlayerState<AVCPlayerState>() : nullptr;
		return PS ? PS->GetAbilityState() : nullptr;
	}

	/** Hotbar aus der Backend-Antwort [{slot, abilityCode}]; unbekannte Codes (nicht in DT_Abilities) bleiben leer. */
	TArray<FName> ParseHotbar(const TSharedPtr<FJsonObject>& Json)
	{
		TArray<FName> Slots;
		Slots.SetNum(UVCAbilityStateComponent::HotbarSlots);
		const TArray<TSharedPtr<FJsonValue>>* Values = nullptr;
		if (!Json.IsValid() || !Json->TryGetArrayField(TEXT("hotbar"), Values) || !Values)
		{
			return Slots;
		}
		for (const TSharedPtr<FJsonValue>& Value : *Values)
		{
			const TSharedPtr<FJsonObject> Entry = Value.IsValid() ? Value->AsObject() : nullptr;
			double Slot = -1.0;
			FString Code;
			if (Entry.IsValid() && Entry->TryGetNumberField(TEXT("slot"), Slot) && Entry->TryGetStringField(TEXT("abilityCode"), Code)
				&& Slots.IsValidIndex(static_cast<int32>(Slot)) && FVCCombatData::FindAbility(FName(*Code)))
			{
				Slots[static_cast<int32>(Slot)] = FName(*Code);
			}
		}
		return Slots;
	}

	/** Kampfwerte aus Stufe und Kampfregeln neu setzen (nach Laden und Stufenaufstieg). */
	void ApplyCharacterStats(const APlayerController* PC)
	{
		const UVCProgressionComponent* Progression = ProgressionOf(PC);
		if (Progression && FVCCombatData::IsAvailable())
		{
			UVCAttributeSet::ApplyStats(AbilitySystemOf(PC),
				vc::rules::DeriveCharacterStats(Progression->GetLevel(), FVCCombatData::Tuning()));
		}
	}

	FIntVector4 CurrentVitals(const APlayerController* PC)
	{
		const UAbilitySystemComponent* ASC = AbilitySystemOf(PC);
		if (!ASC)
		{
			return FIntVector4(0, 0, 0, 0);
		}
		return FIntVector4(
			FMath::RoundToInt(ASC->GetNumericAttribute(UVCAttributeSet::GetHealthAttribute())),
			FMath::RoundToInt(ASC->GetNumericAttribute(UVCAttributeSet::GetMaxHealthAttribute())),
			FMath::RoundToInt(ASC->GetNumericAttribute(UVCAttributeSet::GetStaminaAttribute())),
			FMath::RoundToInt(ASC->GetNumericAttribute(UVCAttributeSet::GetMaxStaminaAttribute())));
	}

	/** Übernimmt {level, experience, levelCap?} aus einer Backend-Antwort und passt die Kampfwerte an. */
	void ApplyCharacterProgress(const APlayerController* PC, const TSharedPtr<FJsonObject>& Json)
	{
		UVCProgressionComponent* Progression = ProgressionOf(PC);
		double Level = 1.0, Experience = 0.0, Cap = 1.0;
		if (Progression && Json.IsValid() && Json->TryGetNumberField(TEXT("level"), Level)
			&& Json->TryGetNumberField(TEXT("experience"), Experience))
		{
			Json->TryGetNumberField(TEXT("levelCap"), Cap);
			Progression->ServerApplyCharacter(static_cast<int32>(Level), static_cast<int64>(Experience), static_cast<int32>(Cap));
			ApplyCharacterStats(PC);
		}
	}

	bool ParseSkill(const TSharedPtr<FJsonObject>& Json, FVCSkillState& Out)
	{
		FString Code;
		double Level = 0.0, Stage = 0.0, Experience = 0.0;
		if (!Json.IsValid() || !Json->TryGetStringField(TEXT("code"), Code) || !Json->TryGetNumberField(TEXT("level"), Level)
			|| !Json->TryGetNumberField(TEXT("stage"), Stage) || !Json->TryGetNumberField(TEXT("experience"), Experience))
		{
			return false;
		}
		Out.Code = FName(*Code);
		Out.Level = static_cast<int32>(Level);
		Out.Stage = static_cast<int32>(Stage);
		Out.Experience = static_cast<int64>(Experience);
		return true;
	}

	FString RemoteAddress(const APlayerController* PC)
	{
		// LowLevelGetRemoteAddress ist nicht const, daher nicht-konstanter Zeiger.
		UNetConnection* Conn = PC ? PC->GetNetConnection() : nullptr;
		return Conn ? Conn->LowLevelGetRemoteAddress(false) : FString();
	}
}

AVCGameMode::AVCGameMode()
{
	PlayerControllerClass = AVCPlayerController::StaticClass();
	PlayerStateClass = AVCPlayerState::StaticClass();
	DefaultPawnClass = AVCCharacter::StaticClass();
	HUDClass = AVCHUD::StaticClass();
}

void AVCGameMode::BeginPlay()
{
	Super::BeginPlay();

	if (IsAuthRequired() && !FVCServerBackend::IsConfigured() && GetNetMode() == NM_DedicatedServer)
	{
		UE_LOG(LogVC, Error, TEXT("VC_SERVICE_KEY fehlt oder ist zu kurz: Spieler können sich nicht anmelden."));
	}
	const UVCServerSettings* Settings = GetDefault<UVCServerSettings>();
	GetWorldTimerManager().SetTimer(SaveTimer, this, &AVCGameMode::SaveAllPlayers, Settings->SaveIntervalSeconds, true);
	GetWorldTimerManager().SetTimer(AuthTimeoutTimer, this, &AVCGameMode::DisconnectTimedOutPlayers, 1.f, true);
	UE_LOG(LogVC, Display, TEXT("Zone %s gestartet als %s"), *UVCServerSettings::GetZoneId(), *UVCServerSettings::GetServerId());

	if (IsAuthRequired() && GetNetMode() == NM_DedicatedServer)
	{
		RegisterWithDirectory();
	}

	if (IsAuthRequired())
	{
		TWeakObjectPtr<AVCGameMode> WeakThis(this);
		FVCServerBackend::LoadZone(UVCServerSettings::GetZoneId(), [WeakThis](const FVCHttpResult& Result)
		{
			FString Mode;
			if (WeakThis.IsValid() && Result.IsOk() && Result.Json.IsValid() && Result.Json->TryGetStringField(TEXT("pvpMode"), Mode))
			{
				Result.Json->TryGetStringField(TEXT("zoneKind"), WeakThis->ZoneKind);
				WeakThis->bPvPAllowed = Mode == TEXT("FREE");
				UE_LOG(LogVC, Display, TEXT("PvP in dieser Zone: %s"), WeakThis->bPvPAllowed ? TEXT("erlaubt") : TEXT("aus"));
			}
			else
			{
				UE_LOG(LogVC, Error, TEXT("Zonendaten nicht geladen (%s) – PvP bleibt aus"), *Result.ErrorMessage());
			}
		});
	}
}

bool AVCGameMode::IsAuthRequired() const
{
#if WITH_EDITOR
	const UWorld* World = GetWorld();
	if (World && World->IsPlayInEditor() && GetDefault<UVCServerSettings>()->bAllowUnauthenticatedInEditor)
	{
		return false;
	}
#endif
	return true;
}

void AVCGameMode::PreLogin(const FString& Options, const FString& Address, const FUniqueNetIdRepl& UniqueId,
	FString& ErrorMessage)
{
	Super::PreLogin(Options, Address, UniqueId, ErrorMessage);
	if (!ErrorMessage.IsEmpty() || !IsAuthRequired())
	{
		return;
	}
	if (!FVCServerBackend::IsConfigured())
	{
		ErrorMessage = TEXT("Server ist nicht mit dem Backend verbunden.");
	}
	else if (UGameplayStatics::ParseOption(Options, TEXT("ticket")).IsEmpty()
		|| FCString::Atoi64(*UGameplayStatics::ParseOption(Options, TEXT("character"))) <= 0)
	{
		ErrorMessage = TEXT("Ticket und Charakter fehlen. Bitte über den Login verbinden.");
	}
}

FString AVCGameMode::InitNewPlayer(APlayerController* NewPlayerController, const FUniqueNetIdRepl& UniqueId,
	const FString& Options, const FString& Portal)
{
	FPlayerSession Session;
	Session.Ticket = UGameplayStatics::ParseOption(Options, TEXT("ticket"));
	Session.CharacterId = FCString::Atoi64(*UGameplayStatics::ParseOption(Options, TEXT("character")));
	Session.ConnectedAt = GetWorld()->GetTimeSeconds();
	Sessions.Add(NewPlayerController, MoveTemp(Session));
	return Super::InitNewPlayer(NewPlayerController, UniqueId, Options, Portal);
}

void AVCGameMode::HandleStartingNewPlayer_Implementation(APlayerController* NewPlayer)
{
	if (!IsAuthRequired())
	{
		Super::HandleStartingNewPlayer_Implementation(NewPlayer);
		return;
	}
	if (GetNetMode() == NM_Standalone)
	{
		// Offline-Start des Clients: kein Pawn, nur Konsole für VCLogin / VCConnect.
		UE_LOG(LogVC, Display, TEXT("Offline. Anmelden mit: VCLogin <login> <passwort>"));
		return;
	}
	if (NewPlayer->IsLocalController())
	{
		Reject(NewPlayer, TEXT("Listen-Server werden nicht unterstützt; bitte Dedicated Server starten."));
		return;
	}
	BeginAuthentication(NewPlayer);
}

void AVCGameMode::BeginAuthentication(APlayerController* PC)
{
	const FPlayerSession* Session = Sessions.Find(PC);
	if (!Session)
	{
		Reject(PC, TEXT("Keine Sitzung"));
		return;
	}
	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	TWeakObjectPtr<APlayerController> WeakPC(PC);
	FVCServerBackend::ValidateTicket(Session->Ticket, [WeakThis, WeakPC](const FVCHttpResult& Result)
	{
		if (WeakThis.IsValid() && WeakPC.IsValid())
		{
			WeakThis->OnTicketValidated(WeakPC.Get(), Result);
		}
	});
}

void AVCGameMode::OnTicketValidated(APlayerController* PC, const FVCHttpResult& Result)
{
	FPlayerSession* Session = Sessions.Find(PC);
	if (!Session)
	{
		return;
	}
	double AdminLevel = 0.0;
	if (!Result.IsOk() || !FVCHttp::TryGetId(Result.Json, TEXT("accountId"), Session->AccountId)
		|| !Result.Json->TryGetStringField(TEXT("sessionId"), Session->SessionId)
		|| !Result.Json->TryGetNumberField(TEXT("adminLevel"), AdminLevel))
	{
		Reject(PC, Result.Status == 401 ? TEXT("Ticket ungültig oder abgelaufen") : *Result.ErrorMessage());
		return;
	}
	Session->AdminLevel = static_cast<int32>(AdminLevel);
	// Das Ticket wird nach der Prüfung nicht mehr gebraucht und nicht im Speicher gehalten.
	Session->Ticket.Empty();

	// Erst die Anwesenheit sichern (ein Charakter, eine Zone), dann laden.
	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	TWeakObjectPtr<APlayerController> WeakPC(PC);
	const int64 CharacterId = Session->CharacterId;
	FVCServerBackend::ClaimCharacter(CharacterId, Session->AccountId, [WeakThis, WeakPC, CharacterId](const FVCHttpResult& R)
	{
		if (WeakThis.IsValid() && WeakPC.IsValid())
		{
			WeakThis->OnCharacterClaimed(WeakPC.Get(), R);
		}
		else if (R.IsOk())
		{
			FVCServerBackend::ReleaseCharacter(CharacterId); // Spieler ist inzwischen weg
		}
	});
}

void AVCGameMode::OnCharacterClaimed(APlayerController* PC, const FVCHttpResult& Result)
{
	FPlayerSession* Session = Sessions.Find(PC);
	if (!Session)
	{
		return;
	}
	if (!Result.IsOk())
	{
		Reject(PC, Result.ErrorMessage()); // z. B. "Charakter ist bereits online" oder falsche Zone
		return;
	}
	Session->bClaimed = true;
	if (Result.Json.IsValid())
	{
		Result.Json->TryGetStringField(TEXT("arrivalTag"), Session->ArrivalTag);
	}

	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	TWeakObjectPtr<APlayerController> WeakPC(PC);
	FVCServerBackend::LoadCharacter(Session->CharacterId, Session->AccountId, [WeakThis, WeakPC](const FVCHttpResult& R)
	{
		if (WeakThis.IsValid() && WeakPC.IsValid())
		{
			WeakThis->OnCharacterLoaded(WeakPC.Get(), R);
		}
	});
}

void AVCGameMode::OnCharacterLoaded(APlayerController* PC, const FVCHttpResult& Result)
{
	if (!Result.IsOk() || !Result.Json.IsValid())
	{
		Reject(PC, Result.Status == 404 ? TEXT("Charakter gehört nicht zu diesem Konto") : *Result.ErrorMessage());
		return;
	}

	FString Name;
	Result.Json->TryGetStringField(TEXT("name"), Name);
	ChangeName(PC, Name, false);

	// Erscheinungsbild: vom Backend bei der Erstellung geprüft, hier nur übernommen.
	if (FPlayerSession* Session = Sessions.Find(PC))
	{
		FString Gender;
		Result.Json->TryGetStringField(TEXT("gender"), Gender);
		Session->Appearance.bFemale = Gender == TEXT("FEMALE");
		Session->Appearance.Entries.Reset();
		const TSharedPtr<FJsonObject>* Appearance = nullptr;
		if (Result.Json->TryGetObjectField(TEXT("appearance"), Appearance) && Appearance && Appearance->IsValid())
		{
			for (const TPair<FString, TSharedPtr<FJsonValue>>& Field : (*Appearance)->Values)
			{
				double Index = 0.0;
				if (Field.Value.IsValid() && Field.Value->TryGetNumber(Index))
				{
					FVCAppearanceEntry& Entry = Session->Appearance.Entries.AddDefaulted_GetRef();
					Entry.Slot = FName(*Field.Key);
					Entry.Index = static_cast<int32>(Index);
				}
			}
		}
	}

	// Progression aus der Datenbank übernehmen; der Client erhält sie per Replikation.
	ApplyCharacterProgress(PC, Result.Json);
	if (UVCProgressionComponent* Progression = ProgressionOf(PC))
	{
		TArray<FVCSkillState> Skills;
		const TArray<TSharedPtr<FJsonValue>>* SkillValues = nullptr;
		if (Result.Json->TryGetArrayField(TEXT("skills"), SkillValues) && SkillValues)
		{
			for (const TSharedPtr<FJsonValue>& Value : *SkillValues)
			{
				FVCSkillState Skill;
				if (ParseSkill(Value->AsObject(), Skill))
				{
					Skills.Add(Skill);
				}
			}
		}
		Progression->ServerSetSkills(Skills);
	}

	if (UVCAbilityStateComponent* AbilityState = AbilityStateOf(PC))
	{
		AbilityState->ServerSetHotbar(ParseHotbar(Result.Json));
	}
	if (FPlayerSession* Session = Sessions.Find(PC))
	{
		const TArray<TSharedPtr<FJsonValue>>* ShipValues = nullptr;
		if (Result.Json->TryGetArrayField(TEXT("ships"), ShipValues) && ShipValues)
		{
			for (const TSharedPtr<FJsonValue>& Value : *ShipValues)
			{
				FPlayerSession::FShip Ship;
				if (Value.IsValid() && FPlayerSession::FShip::FromJson(Value->AsObject(), Ship))
				{
					Session->Ships.Add(Ship);
				}
			}
		}
		double Gold = 0.0;
		Result.Json->TryGetNumberField(TEXT("gold"), Gold);
		Session->Gold = static_cast<int64>(Gold);
		// Ausgerüstete Waffe kommt aus dem Inventar des Backends (EQUIPMENT/WEAPON); ohne Eintrag unbewaffnet.
		FString Weapon;
		Session->EquippedWeapon = Result.Json->TryGetStringField(TEXT("equippedWeapon"), Weapon) ? FName(*Weapon) : NAME_None;

		const TArray<TSharedPtr<FJsonValue>>* Found = nullptr;
		if (Result.Json->TryGetArrayField(TEXT("discoveries"), Found) && Found)
		{
			for (const TSharedPtr<FJsonValue>& Value : *Found)
			{
				FString Code;
				if (Value.IsValid() && Value->TryGetString(Code))
				{
					Session->Discoveries.Add(FName(*Code));
				}
			}
		}
	}

	// Leben/Ausdauer: gespeicherten Stand übernehmen, sonst (oder nach Tod) voll.
	if (FPlayerSession* Session = Sessions.Find(PC))
	{
		const TSharedPtr<FJsonObject>* Vitals = nullptr;
		double Health = 0.0, Stamina = 0.0;
		if (Result.Json->TryGetObjectField(TEXT("vitals"), Vitals) && Vitals && Vitals->IsValid()
			&& (*Vitals)->TryGetNumberField(TEXT("health"), Health) && (*Vitals)->TryGetNumberField(TEXT("stamina"), Stamina))
		{
			Session->SavedVitals = FIntVector4(FMath::RoundToInt(Health), 1, FMath::RoundToInt(Stamina), 1);
		}
		UAbilitySystemComponent* ASC = AbilitySystemOf(PC);
		const bool bHasSaved = Session->SavedVitals.Y > 0 && Session->SavedVitals.X > 0;
		if (ASC)
		{
			UVCAttributeSet::SetVitals(ASC,
				bHasSaved ? Session->SavedVitals.X : ASC->GetNumericAttribute(UVCAttributeSet::GetMaxHealthAttribute()),
				bHasSaved ? Session->SavedVitals.Z : ASC->GetNumericAttribute(UVCAttributeSet::GetMaxStaminaAttribute()));
		}
	}

	// Gespeicherte Position nur verwenden, wenn sie zu dieser Zone gehört.
	TOptional<FTransform> Saved;
	FString SavedZone;
	const TSharedPtr<FJsonObject>* Position = nullptr;
	if (Result.Json->TryGetStringField(TEXT("zoneId"), SavedZone) && SavedZone == UVCServerSettings::GetZoneId()
		&& Result.Json->TryGetObjectField(TEXT("position"), Position) && Position && Position->IsValid())
	{
		const FVector Location((*Position)->GetNumberField(TEXT("x")), (*Position)->GetNumberField(TEXT("y")),
			(*Position)->GetNumberField(TEXT("z")));
		const FRotator Rotation(0.f, static_cast<float>((*Position)->GetNumberField(TEXT("yaw"))), 0.f);
		Saved = FTransform(Rotation, Location);
	}
	SpawnAuthenticatedPlayer(PC, Saved);
}

void AVCGameMode::SpawnAuthenticatedPlayer(APlayerController* PC, const TOptional<FTransform>& SavedTransform)
{
	FPlayerSession* Session = Sessions.Find(PC);
	if (!Session)
	{
		return;
	}
	Session->bAuthenticated = true;

	if (SavedTransform.IsSet())
	{
		RestartPlayerAtTransform(PC, SavedTransform.GetValue());
	}
	if (!PC->GetPawn() && !Session->ArrivalTag.IsEmpty())
	{
		// Ankunft nach einem Zonenwechsel: PlayerStart mit passendem Tag in dieser Karte.
		AActor* Start = FindPlayerStart(PC, Session->ArrivalTag);
		const APlayerStart* Tagged = Cast<APlayerStart>(Start);
		if (!Tagged || Tagged->PlayerStartTag != FName(*Session->ArrivalTag))
		{
			UE_LOG(LogVC, Warning, TEXT("Kein PlayerStart mit Tag %s in Zone %s – Standard-Startpunkt"),
				*Session->ArrivalTag, *UVCServerSettings::GetZoneId());
		}
		if (Start)
		{
			RestartPlayerAtPlayerStart(PC, Start);
		}
	}
	Session->ArrivalTag.Empty();
	if (!PC->GetPawn())
	{
		// Keine gespeicherte Position oder Spawn dort blockiert: PlayerStart der Zone.
		RestartPlayer(PC);
	}
	if (APawn* Pawn = PC->GetPawn())
	{
		Session->Pawn = Pawn;
		if (AVCCharacter* Character = Cast<AVCCharacter>(Pawn))
		{
			Character->ServerSetAppearance(Session->Appearance);
			Character->ServerSetEquippedWeapon(Session->EquippedWeapon);
		}
		if (AVCShip* Ship = Cast<AVCShip>(Pawn))
		{
			for (const FPlayerSession::FShip& Owned : Session->Ships)
			{
				if (Owned.bActive)
				{
					FVCShipLoadout Loadout;
					Loadout.InstanceId = Owned.InstanceId;
					Loadout.ShipCode = Owned.Code;
					Loadout.HullHp = Owned.HullHp;
					Loadout.Crew = Owned.Crew;
					Loadout.Injured = Owned.Injured;
					Loadout.Provisions = Owned.Provisions;
					Ship->ServerInit(Loadout, FName(*UVCServerSettings::GetZoneId()));
				}
			}
		}
		Pawn->OnDestroyed.AddDynamic(this, &AVCGameMode::OnPlayerPawnDestroyed);
	}
	UE_LOG(LogVC, Display, TEXT("Charakter %lld (Konto %lld) betritt Zone %s"),
		Session->CharacterId, Session->AccountId, *UVCServerSettings::GetZoneId());
}

void AVCGameMode::Reject(APlayerController* PC, const FString& Reason)
{
	UE_LOG(LogVC, Warning, TEXT("Spieler getrennt (%s): %s"), *RemoteAddress(PC), *Reason);
	if (const FPlayerSession* Session = Sessions.Find(PC); Session && Session->bClaimed && !Session->bFinalSaveSent)
	{
		FVCServerBackend::ReleaseCharacter(Session->CharacterId); // wirkt nur, solange er hier ONLINE ist
	}
	Sessions.Remove(PC);
	if (GameSession)
	{
		GameSession->KickPlayer(PC, FText::FromString(Reason));
	}
}

void AVCGameMode::Logout(AController* Exiting)
{
	// Die Position wurde bereits in OnPlayerPawnDestroyed gespeichert (der Pawn ist hier schon weg); dieser letzte
	// Stand gibt die Anwesenheit frei. Ohne ihn (kein Pawn, abgebrochener Wechsel) hier freigeben.
	if (APlayerController* PC = Cast<APlayerController>(Exiting))
	{
		if (const FPlayerSession* Session = Sessions.Find(PC); Session && Session->bClaimed && !Session->bFinalSaveSent)
		{
			FVCServerBackend::ReleaseCharacter(Session->CharacterId);
		}
		Sessions.Remove(PC);
	}
	Super::Logout(Exiting);
}

void AVCGameMode::OnPlayerPawnDestroyed(AActor* DestroyedActor)
{
	for (TPair<TObjectKey<APlayerController>, FPlayerSession>& Entry : Sessions)
	{
		if (Entry.Value.bAuthenticated && Entry.Value.Pawn.Get() == DestroyedActor)
		{
			// Beim Verlassen des Spiels wird der Pawn zusammen mit dem Controller zerstört; beim Respawn nicht.
			const APlayerController* PC = Entry.Key.ResolveObjectPtr();
			const bool bLeaving = !PC || PC->IsActorBeingDestroyed();
			if (bLeaving && !Entry.Value.bTransferring)
			{
				Entry.Value.bFinalSaveSent = true;
			}
			SaveSession(PC, Entry.Value, *CastChecked<APawn>(DestroyedActor), bLeaving);
			return;
		}
	}
}

void AVCGameMode::SaveSession(const APlayerController* PC, const FPlayerSession& Session, const APawn& Pawn, bool bFinal) const
{
	if (Session.bTransferring)
	{
		return; // Anwesenheit liegt beim Zielserver; das Backend würde ohnehin ablehnen
	}
	const int64 CharacterId = Session.CharacterId;
	SaveShipThenCharacter(PC, CharacterId, Session.AccountId, Pawn, bFinal, [CharacterId](const FVCHttpResult& Result)
	{
		if (!Result.IsOk())
		{
			UE_LOG(LogVC, Error, TEXT("Speichern von Charakter %lld fehlgeschlagen: %s"), CharacterId, *Result.ErrorMessage());
		}
	});
}

void AVCGameMode::SaveShipThenCharacter(const APlayerController* PC, int64 CharacterId, int64 AccountId, const APawn& Pawn, bool bFinal,
	TFunction<void(const FVCHttpResult&)> Done)
{
	// Werte jetzt festhalten: der Pawn kann bis zur Antwort verschwunden sein.
	const FVector Location = Pawn.GetActorLocation();
	const float Yaw = Pawn.GetActorRotation().Yaw;
	const FIntVector4 Vitals = CurrentVitals(PC);
	auto SaveCharacter = [CharacterId, AccountId, Location, Yaw, Vitals, bFinal](TFunction<void(const FVCHttpResult&)> Then)
	{
		FVCServerBackend::SaveCharacter(CharacterId, AccountId, UVCServerSettings::GetZoneId(), Location, Yaw, Vitals, bFinal, MoveTemp(Then));
	};
	const AVCShip* Ship = Cast<AVCShip>(&Pawn);
	if (!Ship)
	{
		SaveCharacter(MoveTemp(Done));
		return;
	}
	const FVCShipLoadout Loadout = Ship->GetLoadout();
	FVCServerBackend::SaveShip(CharacterId, AccountId, Loadout.InstanceId, Loadout.HullHp, Loadout.Crew, Loadout.Injured, Loadout.Provisions,
		[SaveCharacter, Done = MoveTemp(Done), CharacterId](const FVCHttpResult& ShipResult) mutable
		{
			if (!ShipResult.IsOk())
			{
				UE_LOG(LogVC, Error, TEXT("Schiff von Charakter %lld nicht gespeichert: %s"), CharacterId, *ShipResult.ErrorMessage());
			}
			SaveCharacter(MoveTemp(Done)); // Charakter trotzdem speichern (und beim Ausloggen freigeben)
		});
}

void AVCGameMode::SaveAllPlayers()
{
	for (const TPair<TObjectKey<APlayerController>, FPlayerSession>& Entry : Sessions)
	{
		if (Entry.Value.bAuthenticated && Entry.Value.Pawn.IsValid())
		{
			SaveSession(Entry.Key.ResolveObjectPtr(), Entry.Value, *Entry.Value.Pawn.Get(), false);
		}
	}
}

void AVCGameMode::DisconnectTimedOutPlayers()
{
	if (!IsAuthRequired())
	{
		// PIE ohne Backend: niemand wird authentifiziert, also auch niemand wegen Zeitüberschreitung getrennt.
		return;
	}
	const double Now = GetWorld()->GetTimeSeconds();
	const double Timeout = GetDefault<UVCServerSettings>()->AuthTimeoutSeconds;
	TArray<APlayerController*> Expired;
	for (const TPair<TObjectKey<APlayerController>, FPlayerSession>& Entry : Sessions)
	{
		APlayerController* PC = Entry.Key.ResolveObjectPtr();
		if (PC && !Entry.Value.bAuthenticated && !PC->IsLocalController() && Now - Entry.Value.ConnectedAt > Timeout)
		{
			Expired.Add(PC);
		}
	}
	for (APlayerController* PC : Expired)
	{
		Reject(PC, TEXT("Anmeldung hat zu lange gedauert"));
	}
}

void AVCGameMode::HandleAdminCommand(APlayerController* Issuer, const FString& CommandLine)
{
	const FPlayerSession* Session = Sessions.Find(Issuer);
	if (!Session || !Session->bAuthenticated)
	{
		return;
	}
	TArray<FString> Args;
	CommandLine.ParseIntoArrayWS(Args);
	if (Args.IsEmpty())
	{
		return;
	}
	const FString Command = Args[0].ToLower();
	Args.RemoveAt(0);

	if (Command == TEXT("teleport"))
	{
		AdminTeleport(Issuer, *Session, Args);
	}
	else if (Command == TEXT("setlevel") && Args.Num() == 1)
	{
		AdminSetLevel(Issuer, *Session, FString(), Args[0]);
	}
	else if (Command == TEXT("setskill") && Args.Num() == 2)
	{
		AdminSetLevel(Issuer, *Session, Args[0].ToUpper(), Args[1]);
	}
	else if (Command == TEXT("givexp") && Args.Num() == 1)
	{
		AdminGiveXp(Issuer, *Session, FString(), Args[0]);
	}
	else if (Command == TEXT("giveskillxp") && Args.Num() == 2)
	{
		AdminGiveXp(Issuer, *Session, Args[0].ToUpper(), Args[1]);
	}
	else if (Command == TEXT("givegold") && Args.Num() == 1)
	{
		int64 Amount = 0;
		if (!LexTryParseString(Amount, *Args[0]) || Amount <= 0)
		{
			Issuer->ClientMessage(TEXT("Aufruf: VCAdmin \"givegold <menge>\""));
			return;
		}
		// Rechteprüfung, Ledger-Buchung und Audit erledigt das Backend in einer Transaktion.
		TWeakObjectPtr<AVCGameMode> WeakThis(this);
		TWeakObjectPtr<APlayerController> WeakPC(Issuer);
		FVCServerBackend::AdminGrantGold(Session->CharacterId, Amount, AdminContext(Issuer, *Session), [WeakThis, WeakPC](const FVCHttpResult& Result)
		{
			APlayerController* PC = WeakPC.Get();
			double Gold = 0.0;
			if (!PC || !WeakThis.IsValid())
			{
				return;
			}
			if (!Result.IsOk() || !Result.Json.IsValid() || !Result.Json->TryGetNumberField(TEXT("gold"), Gold))
			{
				PC->ClientMessage(FString::Printf(TEXT("Abgelehnt: %s"), *Result.ErrorMessage()));
				return;
			}
			if (FPlayerSession* S = WeakThis->Sessions.Find(PC))
			{
				S->Gold = static_cast<int64>(Gold);
			}
			PC->ClientMessage(FString::Printf(TEXT("Gold: %lld"), static_cast<int64>(Gold)));
		});
	}
	else if (Command == TEXT("giveitem") && (Args.Num() == 1 || Args.Num() == 2))
	{
		// Waffen und Items kommen jetzt aus dem Inventar; zum Testen legt ein Admin Items hinein (Rechte und Audit im Backend).
		int32 Quantity = 1;
		if (Args.Num() == 2 && (!LexTryParseString(Quantity, *Args[1]) || Quantity <= 0))
		{
			Issuer->ClientMessage(TEXT("Aufruf: VCAdmin \"giveitem <ITEM> [menge]\""));
			return;
		}
		TWeakObjectPtr<AVCGameMode> WeakThis(this);
		TWeakObjectPtr<APlayerController> WeakPC(Issuer);
		FVCServerBackend::AdminGrantItem(Session->CharacterId, Args[0].ToUpper(), Quantity, AdminContext(Issuer, *Session),
			[WeakThis, WeakPC](const FVCHttpResult& Result)
			{
				APlayerController* PC = WeakPC.Get();
				double Placed = 0.0, Lost = 0.0;
				if (!PC || !WeakThis.IsValid())
				{
					return;
				}
				if (!Result.IsOk() || !Result.Json.IsValid() || !Result.Json->TryGetNumberField(TEXT("placed"), Placed))
				{
					PC->ClientMessage(FString::Printf(TEXT("Abgelehnt: %s"), *Result.ErrorMessage()));
					return;
				}
				Result.Json->TryGetNumberField(TEXT("lost"), Lost);
				PC->ClientMessage(FString::Printf(TEXT("Ins Inventar: %d%s"), static_cast<int32>(Placed),
					Lost > 0.0 ? *FString::Printf(TEXT(" (%d passten nicht)"), static_cast<int32>(Lost)) : TEXT("")));
			});
	}
	else
	{
		Issuer->ClientMessage(FString::Printf(TEXT("Unbekanntes Admin-Kommando: %s"), *Command));
	}
}

void AVCGameMode::AdminTeleport(APlayerController* Issuer, const FPlayerSession& Session, const TArray<FString>& Args)
{
	if (Session.AdminLevel < GetDefault<UVCServerSettings>()->TeleportAdminLevel)
	{
		UE_LOG(LogVC, Warning, TEXT("Konto %lld ohne Recht versuchte /teleport"), Session.AccountId);
		Issuer->ClientMessage(TEXT("Keine Berechtigung."));
		return;
	}
	FVector Target;
	if (Args.Num() != 3 || !LexTryParseString(Target.X, *Args[0]) || !LexTryParseString(Target.Y, *Args[1])
		|| !LexTryParseString(Target.Z, *Args[2]) || Target.ContainsNaN())
	{
		Issuer->ClientMessage(TEXT("Aufruf: VCAdmin \"teleport <x> <y> <z>\""));
		return;
	}
	APawn* Pawn = Issuer->GetPawn();
	if (!Pawn)
	{
		return;
	}
	const FVector Old = Pawn->GetActorLocation();

	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	AuditThenRun(Issuer, Session, TEXT("/teleport"), VectorJson(Target), VectorJson(Old), VectorJson(Target),
		[WeakThis, Target](APlayerController* PC)
		{
			APawn* P = PC->GetPawn();
			if (!P || !P->TeleportTo(Target, P->GetActorRotation()))
			{
				UE_LOG(LogVC, Warning, TEXT("Teleport nach %s nicht möglich (blockiert)"), *Target.ToString());
				PC->ClientMessage(TEXT("Zielort blockiert."));
				return;
			}
			if (const FPlayerSession* S = WeakThis.IsValid() ? WeakThis->Sessions.Find(PC) : nullptr)
			{
				WeakThis->SaveSession(PC, *S, *P, false);
			}
		});
}

TSharedRef<FJsonObject> AVCGameMode::AdminContext(const APlayerController* Issuer, const FPlayerSession& Session) const
{
	const TSharedRef<FJsonObject> Ctx = MakeShared<FJsonObject>();
	Ctx->SetNumberField(TEXT("adminAccountId"), static_cast<double>(Session.AccountId));
	Ctx->SetStringField(TEXT("sessionId"), Session.SessionId);
	Ctx->SetStringField(TEXT("serverId"), UVCServerSettings::GetServerId());
	const FString Ip = RemoteAddress(Issuer);
	if (!Ip.IsEmpty())
	{
		Ctx->SetStringField(TEXT("ip"), Ip);
	}
	return Ctx;
}

void AVCGameMode::AuditThenRun(APlayerController* Issuer, const FPlayerSession& Session, const FString& Command,
	const TSharedRef<FJsonObject>& Args, const TSharedRef<FJsonObject>& OldValue, const TSharedRef<FJsonObject>& NewValue,
	TFunction<void(APlayerController*)> Action)
{
	const TSharedRef<FJsonObject> Entry = AdminContext(Issuer, Session);
	Entry->SetStringField(TEXT("command"), Command);
	Entry->SetStringField(TEXT("targetType"), TEXT("CHARACTER"));
	Entry->SetStringField(TEXT("targetId"), FString::Printf(TEXT("%lld"), Session.CharacterId));
	Entry->SetObjectField(TEXT("args"), Args);
	Entry->SetObjectField(TEXT("oldValue"), OldValue);
	Entry->SetObjectField(TEXT("newValue"), NewValue);

	// Erst protokollieren, dann ausführen: ohne Audit-Eintrag keine Admin-Aktion.
	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	TWeakObjectPtr<APlayerController> WeakPC(Issuer);
	FVCServerBackend::WriteAdminAudit(Entry, [WeakThis, WeakPC, Command, Action = MoveTemp(Action)](const FVCHttpResult& Result)
	{
		APlayerController* PC = WeakPC.Get();
		if (!WeakThis.IsValid() || !PC)
		{
			return;
		}
		if (!Result.IsOk())
		{
			PC->ClientMessage(FString::Printf(TEXT("%s abgelehnt: %s"), *Command, *Result.ErrorMessage()));
			return;
		}
		Action(PC);
	});
}

void AVCGameMode::AdminSetLevel(APlayerController* Issuer, const FPlayerSession& Session, const FString& SkillCode,
	const FString& LevelArg)
{
	int32 Level = 0;
	if (!LexTryParseString(Level, *LevelArg) || Level < 1)
	{
		Issuer->ClientMessage(TEXT("Aufruf: VCAdmin \"setlevel <stufe>\" oder VCAdmin \"setskill <SKILL> <stufe>\""));
		return;
	}
	// Rechteprüfung, Grenzen (bekannte XP-Schwellen, Skillstufen, Gesamtcap) und Audit erledigt das Backend atomar.
	TWeakObjectPtr<APlayerController> WeakPC(Issuer);
	FVCServerBackend::AdminSetLevel(Session.CharacterId, SkillCode, Level, AdminContext(Issuer, Session),
		[WeakPC, SkillCode](const FVCHttpResult& Result)
		{
			APlayerController* PC = WeakPC.Get();
			if (!PC)
			{
				return;
			}
			const TSharedPtr<FJsonObject>* Progress = nullptr;
			if (!Result.IsOk() || !Result.Json.IsValid() || !Result.Json->TryGetObjectField(TEXT("progress"), Progress) || !Progress)
			{
				PC->ClientMessage(FString::Printf(TEXT("Abgelehnt: %s"), *Result.ErrorMessage()));
				return;
			}
			if (SkillCode.IsEmpty())
			{
				ApplyCharacterProgress(PC, *Progress);
			}
			else if (UVCProgressionComponent* Progression = ProgressionOf(PC))
			{
				FVCSkillState Skill;
				if (ParseSkill(*Progress, Skill))
				{
					Progression->ServerApplySkill(Skill);
				}
			}
		});
}

void AVCGameMode::AdminGiveXp(APlayerController* Issuer, const FPlayerSession& Session, const FString& SkillCode,
	const FString& AmountArg)
{
	int64 Amount = 0;
	if (!LexTryParseString(Amount, *AmountArg) || Amount <= 0)
	{
		Issuer->ClientMessage(TEXT("Aufruf: VCAdmin \"givexp <menge>\" oder VCAdmin \"giveskillxp <SKILL> <menge>\""));
		return;
	}
	if (Session.AdminLevel < GetDefault<UVCServerSettings>()->TeleportAdminLevel)
	{
		Issuer->ClientMessage(TEXT("Keine Berechtigung."));
		return;
	}
	const TSharedRef<FJsonObject> Args = MakeShared<FJsonObject>();
	Args->SetStringField(TEXT("skill"), SkillCode);
	Args->SetNumberField(TEXT("amount"), static_cast<double>(Amount));
	const FString Source = FString::Printf(TEXT("admin:%lld"), Session.AccountId);

	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	AuditThenRun(Issuer, Session, SkillCode.IsEmpty() ? TEXT("/givexp") : TEXT("/giveskillxp"), Args,
		MakeShared<FJsonObject>(), Args, [WeakThis, SkillCode, Amount, Source](APlayerController* PC)
		{
			if (WeakThis.IsValid())
			{
				WeakThis->RequestGrant(PC, SkillCode, Amount, Source);
			}
		});
}

void AVCGameMode::GrantExperience(APlayerController* PC, int64 Amount, const FString& Source)
{
	RequestGrant(PC, FString(), Amount, Source);
}

void AVCGameMode::GrantSkillExperience(APlayerController* PC, FName SkillCode, int64 Amount, const FString& Source)
{
	RequestGrant(PC, SkillCode.ToString(), Amount, Source);
}

void AVCGameMode::RequestGrant(APlayerController* PC, const FString& SkillCode, int64 Amount, const FString& Source)
{
	const FPlayerSession* Session = Sessions.Find(PC);
	if (!Session || !Session->bAuthenticated || Amount <= 0)
	{
		return;
	}
	TWeakObjectPtr<APlayerController> WeakPC(PC);
	const int64 CharacterId = Session->CharacterId;
	FVCServerBackend::GrantExperience(CharacterId, Session->AccountId, SkillCode, Amount, Source,
		[WeakPC, SkillCode, CharacterId](const FVCHttpResult& Result)
		{
			if (!Result.IsOk())
			{
				// Keine lokale Schätzung: ohne Bestätigung des Backends bleibt der angezeigte Stand unverändert.
				UE_LOG(LogVC, Error, TEXT("XP-Vergabe für Charakter %lld fehlgeschlagen: %s"), CharacterId, *Result.ErrorMessage());
				return;
			}
			APlayerController* PC = WeakPC.Get();
			if (!PC)
			{
				return;
			}
			if (SkillCode.IsEmpty())
			{
				ApplyCharacterProgress(PC, Result.Json);
			}
			else if (UVCProgressionComponent* Progression = ProgressionOf(PC))
			{
				FVCSkillState Skill;
				if (ParseSkill(Result.Json, Skill))
				{
					Progression->ServerApplySkill(Skill);
				}
			}
		});
}

void AVCGameMode::HandleSkillUse(AActor* User, FName SkillCode)
{
	const FVCCombatTuningRow* Tuning = FVCCombatData::TuningRow();
	const APawn* Pawn = Cast<APawn>(User);
	APlayerController* PC = Pawn ? Cast<APlayerController>(Pawn->GetController()) : nullptr;
	if (PC && Tuning && Tuning->SkillXpPerHit >= 1.0)
	{
		GrantSkillExperience(PC, SkillCode, static_cast<int64>(Tuning->SkillXpPerHit), TEXT("hit"));
	}
}

void AVCGameMode::HandleHotbarChange(APlayerController* Player, int32 Slot, FName AbilityCode)
{
	UVCAbilityStateComponent* AbilityState = AbilityStateOf(Player);
	if (!AbilityState || Slot < 0 || Slot >= UVCAbilityStateComponent::HotbarSlots)
	{
		return;
	}
	if (!AbilityCode.IsNone() && !FVCCombatData::FindAbility(AbilityCode))
	{
		Player->ClientMessage(TEXT("Unbekannte Fähigkeit (VCAbilities zeigt alle)"));
		return;
	}
	// Eine Fähigkeit liegt höchstens auf einem Platz (wie im Backend): vom alten Platz entfernen.
	TArray<FName> Slots = AbilityState->GetHotbar();
	Slots.SetNum(UVCAbilityStateComponent::HotbarSlots);
	for (FName& Existing : Slots)
	{
		Existing = Existing == AbilityCode ? NAME_None : Existing;
	}
	Slots[Slot] = AbilityCode;

	if (!IsAuthRequired())
	{
		AbilityState->ServerSetHotbar(Slots); // PIE ohne Backend: nur für diese Sitzung
		return;
	}
	FPlayerSession* Session = Sessions.Find(Player);
	if (!Session || !Session->bAuthenticated)
	{
		return;
	}
	if (Session->bHotbarSaveInFlight)
	{
		Player->ClientMessage(TEXT("Hotbar wird noch gespeichert, bitte kurz warten."));
		return;
	}
	Session->bHotbarSaveInFlight = true;
	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	TWeakObjectPtr<APlayerController> WeakPC(Player);
	FVCServerBackend::SaveHotbar(Session->CharacterId, Session->AccountId, Slots, [WeakThis, WeakPC, Slots](const FVCHttpResult& Result)
	{
		APlayerController* PC = WeakPC.Get();
		FPlayerSession* S = WeakThis.IsValid() && PC ? WeakThis->Sessions.Find(PC) : nullptr;
		if (!S)
		{
			return;
		}
		S->bHotbarSaveInFlight = false;
		if (!Result.IsOk())
		{
			PC->ClientMessage(FString::Printf(TEXT("Hotbar nicht gespeichert: %s"), *Result.ErrorMessage()));
			return;
		}
		// Erst nach Bestätigung übernehmen: Anzeige und Datenbank stimmen immer überein.
		if (UVCAbilityStateComponent* State = AbilityStateOf(PC))
		{
			State->ServerSetHotbar(Slots);
		}
	});
}

void AVCGameMode::HandleKill(AActor* Killer, AActor* Victim)
{
	const IVCCombatant* VictimCombatant = Cast<IVCCombatant>(Victim);
	if (!VictimCombatant)
	{
		return;
	}
	const APawn* KillerPawn = Cast<APawn>(Killer);
	APlayerController* KillerPC = KillerPawn ? Cast<APlayerController>(KillerPawn->GetController()) : nullptr;
	const FPlayerSession* KillerSession = KillerPC ? Sessions.Find(KillerPC) : nullptr;
	const bool bKillerKnown = KillerSession && KillerSession->bAuthenticated;

	if (!VictimCombatant->IsPlayerCharacter())
	{
		HandleMonsterKill(Killer, VictimCombatant->GetMonsterCode());
		return;
	}

	const APawn* VictimPawn = Cast<APawn>(Victim);
	APlayerController* VictimPC = VictimPawn ? Cast<APlayerController>(VictimPawn->GetController()) : nullptr;
	const FPlayerSession* VictimSession = VictimPC ? Sessions.Find(VictimPC) : nullptr;
	if (bKillerKnown && VictimSession && VictimSession->bAuthenticated && KillerPC != VictimPC)
	{
		const TSharedRef<FJsonObject> Kill = MakeShared<FJsonObject>();
		Kill->SetStringField(TEXT("victimType"), TEXT("CHARACTER"));
		Kill->SetNumberField(TEXT("victimCharacterId"), static_cast<double>(VictimSession->CharacterId));
		Kill->SetNumberField(TEXT("victimAccountId"), static_cast<double>(VictimSession->AccountId));
		ReportKill(KillerPC, *KillerSession, Kill);
	}
	if (VictimPC)
	{
		ScheduleRespawn(VictimPC);
	}
}

void AVCGameMode::ReportKill(APlayerController* KillerPC, const FPlayerSession& Killer, const TSharedRef<FJsonObject>& Kill)
{
	Kill->SetNumberField(TEXT("killerCharacterId"), static_cast<double>(Killer.CharacterId));
	Kill->SetNumberField(TEXT("killerAccountId"), static_cast<double>(Killer.AccountId));
	TWeakObjectPtr<APlayerController> WeakPC(KillerPC);
	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	FVCServerBackend::ReportKill(Kill, [WeakPC, WeakThis](const FVCHttpResult& Result)
	{
		if (!Result.IsOk())
		{
			UE_LOG(LogVC, Error, TEXT("Kill-Meldung abgelehnt: %s"), *Result.ErrorMessage());
			return;
		}
		// Belohnung legt das Backend fest; übernommen wird nur, was es bestätigt.
		const TSharedPtr<FJsonObject>* Progress = nullptr;
		if (WeakPC.IsValid() && Result.Json.IsValid() && Result.Json->TryGetObjectField(TEXT("progress"), Progress) && Progress)
		{
			ApplyCharacterProgress(WeakPC.Get(), *Progress);
		}
		// Beute: was im Inventar landete und was nicht passte; Gold aus dem Ledger.
		APlayerController* PC = WeakPC.Get();
		const TArray<TSharedPtr<FJsonValue>>* Loot = nullptr;
		if (!PC || !Result.Json.IsValid())
		{
			return;
		}
		double LootGold = 0.0;
		if (Result.Json->TryGetNumberField(TEXT("lootGold"), LootGold) && LootGold > 0.0)
		{
			if (FPlayerSession* S = WeakThis.IsValid() ? WeakThis->Sessions.Find(PC) : nullptr)
			{
				S->Gold += static_cast<int64>(LootGold);
			}
			PC->ClientMessage(FString::Printf(TEXT("Beute: %lld Gold"), static_cast<int64>(LootGold)));
		}
		if (Result.Json->TryGetArrayField(TEXT("loot"), Loot) && Loot)
		{
			for (const TSharedPtr<FJsonValue>& Value : *Loot)
			{
				const TSharedPtr<FJsonObject> Drop = Value.IsValid() ? Value->AsObject() : nullptr;
				if (!Drop.IsValid())
				{
					continue;
				}
				FString Name;
				if (!Drop->TryGetStringField(TEXT("nameDe"), Name) || Name.IsEmpty())
				{
					Name = Drop->GetStringField(TEXT("code"));
				}
				const int32 Quantity = static_cast<int32>(Drop->GetNumberField(TEXT("quantity")));
				const int32 Lost = static_cast<int32>(Drop->GetNumberField(TEXT("lost")));
				PC->ClientMessage(Lost > 0
					? FString::Printf(TEXT("Beute: %d × %s – %d passten nicht ins Inventar"), Quantity, *Name, Lost)
					: FString::Printf(TEXT("Beute: %d × %s"), Quantity, *Name));
			}
		}
	});
}

void AVCGameMode::ScheduleRespawn(APlayerController* PC)
{
	const FVCCombatTuningRow* Tuning = FVCCombatData::TuningRow();
	const float Delay = FMath::Max(0.5f, Tuning ? static_cast<float>(Tuning->PlayerRespawnSeconds) : 5.f);
	TWeakObjectPtr<APlayerController> WeakPC(PC);
	FTimerHandle Handle;
	GetWorldTimerManager().SetTimer(Handle, FTimerDelegate::CreateWeakLambda(this, [this, WeakPC]()
	{
		if (APlayerController* P = WeakPC.Get())
		{
			RespawnPlayer(P);
		}
	}), Delay, false);
}

void AVCGameMode::RespawnPlayer(APlayerController* PC)
{
	const FPlayerSession* Session = Sessions.Find(PC);
	if (!Session || !Session->bAuthenticated)
	{
		return;
	}
	// Todesstrafen des Originals sind UNKNOWN: Respawn am PlayerStart mit vollem Leben, ohne Verlust. [DESIGN]
	if (APawn* Old = PC->GetPawn())
	{
		PC->UnPossess();
		Old->Destroy();
	}
	if (UAbilitySystemComponent* ASC = AbilitySystemOf(PC))
	{
		ASC->RemoveLooseGameplayTag(TAG_VC_State_Dead);
		UVCAttributeSet::SetVitals(ASC, ASC->GetNumericAttribute(UVCAttributeSet::GetMaxHealthAttribute()),
			ASC->GetNumericAttribute(UVCAttributeSet::GetMaxStaminaAttribute()));
	}
	SpawnAuthenticatedPlayer(PC, TOptional<FTransform>());
}

void AVCGameMode::RegisterWithDirectory()
{
	const FString Address = UVCServerSettings::GetPublicAddress(GetWorld());
	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	FVCServerBackend::StartServer(Address, GetDefault<UVCServerSettings>()->Capacity, [WeakThis, Address](const FVCHttpResult& Result)
	{
		AVCGameMode* Self = WeakThis.Get();
		if (!Self)
		{
			return;
		}
		double Interval = 0.0;
		if (!Result.IsOk() || !Result.Json.IsValid() || !Result.Json->TryGetNumberField(TEXT("heartbeatSeconds"), Interval))
		{
			// Ohne Anmeldung lehnt das Backend jeden Spieler ab; also weiter versuchen.
			UE_LOG(LogVC, Error, TEXT("Anmeldung beim World Directory fehlgeschlagen (%s) – neuer Versuch in 10 s"), *Result.ErrorMessage());
			Self->GetWorldTimerManager().SetTimer(Self->DirectoryTimer, Self, &AVCGameMode::RegisterWithDirectory, 10.f, false);
			return;
		}
		UE_LOG(LogVC, Display, TEXT("Im World Directory angemeldet: %s unter %s"), *UVCServerSettings::GetServerId(), *Address);
		Self->GetWorldTimerManager().SetTimer(Self->DirectoryTimer, Self, &AVCGameMode::SendHeartbeat,
			static_cast<float>(FMath::Max(1.0, Interval)), true);
	});
}

void AVCGameMode::SendHeartbeat()
{
	FVCServerBackend::Heartbeat(UVCServerSettings::GetPublicAddress(GetWorld()), GetDefault<UVCServerSettings>()->Capacity,
		[](const FVCHttpResult& Result)
		{
			if (!Result.IsOk())
			{
				UE_LOG(LogVC, Warning, TEXT("Lebenszeichen an das World Directory fehlgeschlagen: %s"), *Result.ErrorMessage());
			}
		});
}

void AVCGameMode::HandleZoneExit(APawn* Pawn, FName ExitCode)
{
	APlayerController* PC = Pawn ? Cast<APlayerController>(Pawn->GetController()) : nullptr;
	if (!PC)
	{
		return;
	}
	if (!IsAuthRequired())
	{
		PC->ClientMessage(FString::Printf(TEXT("Ausgang %s: Zonenwechsel braucht Backend und Dedicated Server"), *ExitCode.ToString()));
		return;
	}
	FPlayerSession* Session = Sessions.Find(PC);
	const IVCCombatant* Combatant = Cast<IVCCombatant>(Pawn);
	if (!Session || !Session->bAuthenticated || !Session->bClaimed || Session->bTransferring || (Combatant && !Combatant->IsAlive()))
	{
		return;
	}
	// Schutz gegen Pendeln: wer gerade erst erschienen ist (z. B. Ankunftspunkt zu nah am Ausgang), wechselt nicht sofort zurück.
	if (Pawn->GetGameTimeSinceCreation() < 2.f)
	{
		return;
	}
	// Ab hier keine periodischen Speicherungen und keine weiteren Ausgänge für diesen Spieler.
	Session->bTransferring = true;

	const int64 CharacterId = Session->CharacterId;
	const int64 AccountId = Session->AccountId;
	const FString Exit = ExitCode.ToString();
	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	TWeakObjectPtr<APlayerController> WeakPC(PC);

	// 1. Letzten Stand dieser Zone speichern (Leben, Ausdauer), solange die Anwesenheit noch hier liegt.
	SaveShipThenCharacter(PC, CharacterId, AccountId, *Pawn, false,
		[WeakThis, WeakPC, CharacterId, AccountId, Exit](const FVCHttpResult& Saved)
		{
			AVCGameMode* Self = WeakThis.Get();
			APlayerController* Player = WeakPC.Get();
			if (!Self || !Player)
			{
				return;
			}
			if (!Saved.IsOk())
			{
				Self->CancelTransfer(Player, Saved.ErrorMessage());
				return;
			}
			// 2. Wechsel anfordern: das Backend kennt den Übergang, wählt den Zielserver und reserviert den Platz.
			FVCServerBackend::RequestTransfer(CharacterId, AccountId, Exit, [WeakThis, WeakPC, CharacterId](const FVCHttpResult& Result)
			{
				AVCGameMode* GameMode = WeakThis.Get();
				APlayerController* Traveller = WeakPC.Get();
				if (!GameMode || !Traveller)
				{
					return; // Spieler ist weg; eine Reservierung läuft von selbst ab
				}
				FString Address;
				if (!Result.IsOk() || !Result.Json.IsValid() || !Result.Json->TryGetStringField(TEXT("address"), Address))
				{
					GameMode->CancelTransfer(Traveller, Result.ErrorMessage());
					return;
				}
				GameMode->CompleteTransfer(Traveller, CharacterId, Address);
			});
		});
}

void AVCGameMode::CompleteTransfer(APlayerController* PC, int64 CharacterId, const FString& Address)
{
	UE_LOG(LogVC, Display, TEXT("Charakter %lld wechselt zu %s"), CharacterId, *Address);
	if (ACharacter* Character = Cast<ACharacter>(PC->GetPawn()))
	{
		Character->GetCharacterMovement()->DisableMovement(); // gehört schon zur Zielzone
	}
	if (AVCPlayerController* VCPC = Cast<AVCPlayerController>(PC))
	{
		VCPC->ClientTravelToZone(Address, CharacterId);
	}
	// Reist der Client nicht (alter Client, Fehler), wird er getrennt; sein Platz liegt bereits auf dem Zielserver.
	TWeakObjectPtr<APlayerController> WeakPC(PC);
	FTimerHandle KickTimer;
	GetWorldTimerManager().SetTimer(KickTimer, FTimerDelegate::CreateWeakLambda(this, [this, WeakPC]()
	{
		if (APlayerController* Stuck = WeakPC.Get())
		{
			Reject(Stuck, TEXT("Zonenwechsel nicht abgeschlossen"));
		}
	}), GetDefault<UVCServerSettings>()->TransferKickSeconds, false);
}

void AVCGameMode::CancelTransfer(APlayerController* PC, const FString& Reason)
{
	if (FPlayerSession* Session = Sessions.Find(PC))
	{
		Session->bTransferring = false;
	}
	PC->ClientMessage(FString::Printf(TEXT("Zonenwechsel nicht möglich: %s"), *Reason));
}

void AVCGameMode::HandleDiscovery(APawn* Pawn, FName DiscoveryCode)
{
	APlayerController* PC = Pawn ? Cast<APlayerController>(Pawn->GetController()) : nullptr;
	FPlayerSession* Session = PC ? Sessions.Find(PC) : nullptr;
	if (!Session || !Session->bAuthenticated || !Session->bClaimed || Session->bTransferring || Session->Discoveries.Contains(DiscoveryCode))
	{
		return;
	}
	// Vorab als bekannt markieren: ein zweites Betreten während der Meldung schickt nichts doppelt.
	Session->Discoveries.Add(DiscoveryCode);
	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	TWeakObjectPtr<APlayerController> WeakPC(PC);
	FVCServerBackend::ReportDiscovery(Session->CharacterId, Session->AccountId, DiscoveryCode.ToString(),
		[WeakThis, WeakPC, DiscoveryCode](const FVCHttpResult& Result)
		{
			AVCGameMode* Self = WeakThis.Get();
			APlayerController* Player = WeakPC.Get();
			if (!Self || !Player)
			{
				return;
			}
			bool bFirstTime = false;
			if (!Result.IsOk() || !Result.Json.IsValid() || !Result.Json->TryGetBoolField(TEXT("firstTime"), bFirstTime))
			{
				// Nicht gezählt (z. B. Punkt gehört zu einer anderen Zone): beim nächsten Betreten erneut versuchen.
				UE_LOG(LogVC, Warning, TEXT("Entdeckung %s abgelehnt: %s"), *DiscoveryCode.ToString(), *Result.ErrorMessage());
				if (FPlayerSession* S = Self->Sessions.Find(Player))
				{
					S->Discoveries.Remove(DiscoveryCode);
				}
				return;
			}
			if (!bFirstTime)
			{
				return;
			}
			double Xp = 0.0;
			Result.Json->TryGetNumberField(TEXT("xpAwarded"), Xp);
			const TSharedPtr<FJsonObject>* Progress = nullptr;
			if (Result.Json->TryGetObjectField(TEXT("progress"), Progress) && Progress)
			{
				ApplyCharacterProgress(Player, *Progress);
			}
			if (AVCPlayerController* VCPC = Cast<AVCPlayerController>(Player))
			{
				VCPC->ClientDiscovered(DiscoveryCode, static_cast<int64>(Xp));
			}
		});
}

bool AVCGameMode::FPlayerSession::FShip::FromJson(const TSharedPtr<FJsonObject>& Json, FShip& Out)
{
	FString Code;
	double Hull = 0.0, HullMax = 0.0, Crew = 0.0, Provisions = 0.0;
	if (!Json.IsValid() || !FVCHttp::TryGetId(Json, TEXT("instanceId"), Out.InstanceId) || !Json->TryGetStringField(TEXT("shipCode"), Code)
		|| !Json->TryGetBoolField(TEXT("active"), Out.bActive) || !Json->TryGetNumberField(TEXT("hullHp"), Hull)
		|| !Json->TryGetNumberField(TEXT("crew"), Crew) || !Json->TryGetNumberField(TEXT("provisions"), Provisions))
	{
		return false;
	}
	Json->TryGetNumberField(TEXT("hullMax"), HullMax);
	double Injured = 0.0;
	Json->TryGetNumberField(TEXT("injured"), Injured);
	Out.Injured = static_cast<int32>(Injured);
	Out.Code = FName(*Code);
	Out.HullHp = static_cast<int32>(Hull);
	Out.HullMax = static_cast<int32>(HullMax);
	Out.Crew = static_cast<int32>(Crew);
	Out.Provisions = static_cast<int32>(Provisions);
	return true;
}

UClass* AVCGameMode::GetDefaultPawnClassForController_Implementation(AController* InController)
{
	const FPlayerSession* Session = Sessions.Find(Cast<APlayerController>(InController));
	if (Session && ZoneKind == TEXT("SEA") && FVCNavalData::IsAvailable())
	{
		for (const FPlayerSession::FShip& Ship : Session->Ships)
		{
			if (Ship.bActive && Ship.HullHp > 0 && FVCNavalData::FindShip(Ship.Code)) // gesunkene Schiffe erst reparieren
			{
				return AVCShip::StaticClass();
			}
		}
	}
	return Super::GetDefaultPawnClassForController_Implementation(InController);
}

void AVCGameMode::HandleInventoryCommand(APlayerController* Player, const FString& Command, const FString& Argument)
{
	FPlayerSession* Session = Player ? Sessions.Find(Player) : nullptr;
	if (!Session || !Session->bAuthenticated || !Session->bClaimed)
	{
		return;
	}
	if (Session->bShipRequestInFlight)
	{
		Player->ClientMessage(TEXT("Bitte warten, die letzte Anfrage läuft noch."));
		return;
	}
	TArray<FString> Parts;
	Argument.ParseIntoArrayWS(Parts);
	int64 InstanceId = 0;
	int32 Quantity = 0;
	const bool bHasId = Parts.Num() >= 1 && LexTryParseString(InstanceId, *Parts[0]) && InstanceId > 0;
	const bool bHasAmount = Parts.Num() == 2 && LexTryParseString(Quantity, *Parts[1]) && Quantity > 0;
	FString NpcCode;
	if (Command == TEXT("sell"))
	{
		const FName Merchant = FindNpcInRange(Player, EVCNpcRole::Merchant);
		if (Merchant.IsNone())
		{
			Player->ClientMessage(TEXT("Verkaufen geht beim Händler (in Reichweite stehen)."));
			return;
		}
		NpcCode = Merchant.ToString();
	}
	if (Command != TEXT("list") && Command != TEXT("unequip") && Command != TEXT("recipes") && Command != TEXT("craft") && (!bHasId || ((Command == TEXT("sell") || Command == TEXT("discard")) && !bHasAmount)))
	{
		Player->ClientMessage(TEXT("VCInventory | VCEquip <nr> | VCUnequip | VCDiscard <nr> <menge> | VCSellItem <nr> <menge>"));
		return;
	}
	if (Command == TEXT("equip") && Cast<AVCShip>(Player->GetPawn()))
	{
		Player->ClientMessage(TEXT("Waffen wechseln nur an Land."));
		return;
	}
	TWeakObjectPtr<AVCGameMode> WeakSelf(this);
	TWeakObjectPtr<APlayerController> WeakPlayer(Player);
	if (Command == TEXT("recipes"))
	{
		Session->bShipRequestInFlight = true;
		FVCServerBackend::LoadRecipes(Session->CharacterId, Session->AccountId, [WeakSelf, WeakPlayer](const FVCHttpResult& Result)
		{
			APlayerController* PC = WeakPlayer.Get();
			FPlayerSession* S = WeakSelf.IsValid() && PC ? WeakSelf->Sessions.Find(PC) : nullptr;
			if (!S)
			{
				return;
			}
			S->bShipRequestInFlight = false;
			TArray<TSharedPtr<FJsonValue>> Recipes;
			if (!Result.IsOk() || !FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Result.Body), Recipes))
			{
				PC->ClientMessage(FString::Printf(TEXT("Rezepte nicht verfügbar: %s"), *Result.ErrorMessage()));
				return;
			}
			for (const TSharedPtr<FJsonValue>& Value : Recipes)
			{
				const TSharedPtr<FJsonObject> R = Value.IsValid() ? Value->AsObject() : nullptr;
				if (!R.IsValid())
				{
					continue;
				}
				FString Materials;
				for (const TSharedPtr<FJsonValue>& M : R->GetArrayField(TEXT("materials")))
				{
					const TSharedPtr<FJsonObject> Mat = M->AsObject();
					FString Name;
					if (!Mat->TryGetStringField(TEXT("nameDe"), Name) || Name.IsEmpty())
					{
						Name = Mat->GetStringField(TEXT("code"));
					}
					Materials += FString::Printf(TEXT("%s%d × %s (%d)"), Materials.IsEmpty() ? TEXT("") : TEXT(", "),
						static_cast<int32>(Mat->GetNumberField(TEXT("quantity"))), *Name, static_cast<int32>(Mat->GetNumberField(TEXT("have"))));
				}
				PC->ClientMessage(FString::Printf(TEXT("%s %s – %s %d/%d, %s, Gebühr %lld"),
					R->GetBoolField(TEXT("canCraft")) ? TEXT("✔") : TEXT("✘"), *R->GetStringField(TEXT("code")),
					*R->GetStringField(TEXT("skill")), static_cast<int32>(R->GetNumberField(TEXT("skillLevel"))),
					static_cast<int32>(R->GetNumberField(TEXT("requiredLevel"))), *Materials,
					static_cast<int64>(R->GetNumberField(TEXT("goldCost")))));
			}
		});
		return;
	}
	if (Command == TEXT("craft"))
	{
		// "DEV_RECIPE_SWORD 2" – Rezept und Anzahl; nur an Land [DESIGN].
		int32 Times = 1;
		if (Parts.Num() < 1 || Parts.Num() > 2 || (Parts.Num() == 2 && (!LexTryParseString(Times, *Parts[1]) || Times < 1)))
		{
			Player->ClientMessage(TEXT("VCCraft <REZEPT> [anzahl] (VCRecipes zeigt die Rezepte)"));
			return;
		}
		if (Cast<AVCShip>(Player->GetPawn()))
		{
			Player->ClientMessage(TEXT("Herstellen geht nur an Land."));
			return;
		}
		Session->bShipRequestInFlight = true;
		FVCServerBackend::Craft(Session->CharacterId, Session->AccountId, Parts[0].ToUpper(), Times,
			[WeakSelf, WeakPlayer](const FVCHttpResult& Result)
			{
				APlayerController* PC = WeakPlayer.Get();
				FPlayerSession* S = WeakSelf.IsValid() && PC ? WeakSelf->Sessions.Find(PC) : nullptr;
				if (S)
				{
					S->bShipRequestInFlight = false;
					WeakSelf->ApplyCraftResult(PC, Result, true);
				}
			});
		return;
	}

	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	TWeakObjectPtr<APlayerController> WeakPC(Player);
	Session->bShipRequestInFlight = true;
	auto Done = [WeakThis, WeakPC, Command](const FVCHttpResult& Result)
	{
		APlayerController* PC = WeakPC.Get();
		FPlayerSession* S = WeakThis.IsValid() && PC ? WeakThis->Sessions.Find(PC) : nullptr;
		if (!S)
		{
			return;
		}
		S->bShipRequestInFlight = false;
		if (!Result.IsOk() || !Result.Json.IsValid())
		{
			PC->ClientMessage(FString::Printf(TEXT("Abgelehnt: %s"), *Result.ErrorMessage()));
			return;
		}
		// equip/unequip/list antworten mit dem Inventar, sell/discard mit gold, total und inventory.
		const TSharedPtr<FJsonObject>* Nested = nullptr;
		const TSharedPtr<FJsonObject> Inventory = Result.Json->TryGetObjectField(TEXT("inventory"), Nested) && Nested ? *Nested : Result.Json;
		double Gold = 0.0, Total = 0.0;
		if (Result.Json->TryGetNumberField(TEXT("gold"), Gold))
		{
			S->Gold = static_cast<int64>(Gold);
			Result.Json->TryGetNumberField(TEXT("total"), Total);
			PC->ClientMessage(Command == TEXT("sell")
				? FString::Printf(TEXT("Verkauft für %lld Gold. Gold: %lld"), static_cast<int64>(Total), S->Gold)
				: FString(TEXT("Weggeworfen.")));
		}
		WeakThis->ApplyInventory(PC, Inventory, Command == TEXT("list"));
	};
	if (Command == TEXT("list"))
	{
		FVCServerBackend::LoadInventory(Session->CharacterId, Session->AccountId, MoveTemp(Done));
	}
	else
	{
		FVCServerBackend::InventoryAction(Session->CharacterId, Session->AccountId, Command, InstanceId, Quantity, NpcCode, MoveTemp(Done));
	}
}

void AVCGameMode::HandleGather(APawn* Pawn, FName NodeCode, TFunction<void(bool)> Done)
{
	APlayerController* PC = Pawn ? Cast<APlayerController>(Pawn->GetController()) : nullptr;
	FPlayerSession* Session = PC ? Sessions.Find(PC) : nullptr;
	if (!Session || !Session->bAuthenticated || !Session->bClaimed || Session->bTransferring)
	{
		Done(false);
		return;
	}
	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	TWeakObjectPtr<APlayerController> WeakPC(PC);
	FVCServerBackend::Gather(Session->CharacterId, Session->AccountId, NodeCode.ToString(),
		[WeakThis, WeakPC, Done = MoveTemp(Done)](const FVCHttpResult& Result)
		{
			Done(Result.IsOk()); // Punkt erschöpfen nur, wenn das Backend die Ausbeute bestätigt
			if (WeakThis.IsValid() && WeakPC.IsValid())
			{
				WeakThis->ApplyCraftResult(WeakPC.Get(), Result, false);
			}
		});
}

void AVCGameMode::ApplyCraftResult(APlayerController* PC, const FVCHttpResult& Result, bool bCrafted)
{
	FPlayerSession* Session = PC ? Sessions.Find(PC) : nullptr;
	if (!Session)
	{
		return;
	}
	if (!Result.IsOk() || !Result.Json.IsValid())
	{
		PC->ClientMessage(FString::Printf(TEXT("%s: %s"), bCrafted ? TEXT("Herstellen abgelehnt") : TEXT("Sammeln ohne Ertrag"),
			*Result.ErrorMessage()));
		return;
	}
	FString Name;
	if (!Result.Json->TryGetStringField(TEXT("nameDe"), Name) || Name.IsEmpty())
	{
		Name = Result.Json->GetStringField(TEXT("itemCode"));
	}
	const int32 Quantity = static_cast<int32>(Result.Json->GetNumberField(TEXT("quantity")));
	const int32 Lost = static_cast<int32>(Result.Json->GetNumberField(TEXT("lost")));
	const int64 Fee = static_cast<int64>(Result.Json->GetNumberField(TEXT("goldCost")));
	Session->Gold = static_cast<int64>(Result.Json->GetNumberField(TEXT("gold")));
	FString Text = FString::Printf(TEXT("%s: %d × %s"), bCrafted ? TEXT("Hergestellt") : TEXT("Gesammelt"), Quantity, *Name);
	if (Lost > 0)
	{
		Text += FString::Printf(TEXT(" (%d passten nicht ins Inventar)"), Lost);
	}
	if (Fee > 0)
	{
		Text += FString::Printf(TEXT(", Gebühr %lld Gold"), Fee);
	}
	PC->ClientMessage(Text);
	const TSharedPtr<FJsonObject>* Skill = nullptr;
	if (Result.Json->TryGetObjectField(TEXT("skill"), Skill) && Skill)
	{
		FVCSkillState State;
		if (UVCProgressionComponent* Progression = ProgressionOf(PC); Progression && ParseSkill(*Skill, State))
		{
			Progression->ServerApplySkill(State);
		}
	}
	const TSharedPtr<FJsonObject>* Inventory = nullptr;
	if (Result.Json->TryGetObjectField(TEXT("inventory"), Inventory) && Inventory)
	{
		ApplyInventory(PC, *Inventory, false);
	}
}

void AVCGameMode::ApplyInventory(APlayerController* PC, const TSharedPtr<FJsonObject>& Inventory, bool bPrint)
{
	FPlayerSession* Session = PC ? Sessions.Find(PC) : nullptr;
	const TArray<TSharedPtr<FJsonValue>>* Items = nullptr;
	if (!Session || !Inventory.IsValid() || !Inventory->TryGetArrayField(TEXT("items"), Items) || !Items)
	{
		return;
	}
	FName Weapon;
	int32 Used = 0;
	TArray<FString> Lines;
	for (const TSharedPtr<FJsonValue>& Value : *Items)
	{
		const TSharedPtr<FJsonObject> Item = Value.IsValid() ? Value->AsObject() : nullptr;
		if (!Item.IsValid())
		{
			continue;
		}
		const FString Location = Item->GetStringField(TEXT("location"));
		FString Slot, Name;
		Item->TryGetStringField(TEXT("slot"), Slot);
		if (!Item->TryGetStringField(TEXT("nameDe"), Name) || Name.IsEmpty())
		{
			Name = Item->GetStringField(TEXT("code"));
		}
		const bool bEquipped = Location == TEXT("EQUIPMENT");
		if (bEquipped && Slot == TEXT("WEAPON"))
		{
			Weapon = FName(*Item->GetStringField(TEXT("code")));
		}
		Used += bEquipped ? 0 : 1;
		Lines.Add(FString::Printf(TEXT("  [%s] Nr. %lld %s × %d"), bEquipped ? *Slot : *FString::Printf(TEXT("Platz %s"), *Slot),
			static_cast<int64>(Item->GetNumberField(TEXT("instanceId"))), *Name, static_cast<int32>(Item->GetNumberField(TEXT("quantity")))));
	}
	if (bPrint)
	{
		PC->ClientMessage(FString::Printf(TEXT("Inventar %d/%d, Gold %lld"), Used,
			static_cast<int32>(Inventory->GetNumberField(TEXT("capacity"))), Session->Gold));
		for (const FString& Line : Lines)
		{
			PC->ClientMessage(Line);
		}
	}
	if (Weapon != Session->EquippedWeapon)
	{
		Session->EquippedWeapon = Weapon;
		if (AVCCharacter* Character = Cast<AVCCharacter>(PC->GetPawn()))
		{
			Character->ServerSetEquippedWeapon(Weapon);
		}
		PC->ClientMessage(Weapon.IsNone() ? FString(TEXT("Unbewaffnet.")) : FString::Printf(TEXT("Ausgerüstet: %s"), *Weapon.ToString()));
	}
}

FName AVCGameMode::FindNpcInRange(const APlayerController* Player, EVCNpcRole Role) const
{
	const APawn* Pawn = Player ? Player->GetPawn() : nullptr;
	const float Range = GetDefault<UVCWorldSettings>()->InteractRangeCm + 50.f;
	for (TActorIterator<AVCNpc> It(GetWorld()); It && Pawn; ++It)
	{
		const FVCNpcRow* Row = FVCWorldData::FindNpc(It->NpcCode);
		if (Row && Row->Role == Role && FVector::Dist(Pawn->GetActorLocation(), It->GetActorLocation()) <= Range)
		{
			return It->NpcCode;
		}
	}
	return NAME_None;
}

void AVCGameMode::HandleShipCommand(APlayerController* Player, const FString& Command, const FString& Argument)
{
	FPlayerSession* Session = Player ? Sessions.Find(Player) : nullptr;
	if (!Session || !Session->bAuthenticated || !Session->bClaimed)
	{
		return;
	}
	if (Command == TEXT("list"))
	{
		Player->ClientMessage(FString::Printf(TEXT("Gold: %lld"), Session->Gold));
		for (const FPlayerSession::FShip& Ship : Session->Ships)
		{
			const FVCShipRow* Row = FVCNavalData::FindShip(Ship.Code);
			Player->ClientMessage(FString::Printf(TEXT("%s#%lld %s – Rumpf %d/%d, Matrosen %d (+%d verletzt), Proviant %d"),
				Ship.bActive ? TEXT("* ") : TEXT("  "), Ship.InstanceId, Row ? *Row->NameDe : *Ship.Code.ToString(),
				Ship.HullHp, Ship.HullMax, Ship.Crew, Ship.Injured, Ship.Provisions));
		}
		return;
	}
	if (Session->bShipRequestInFlight)
	{
		Player->ClientMessage(TEXT("Bitte warten, die letzte Anfrage läuft noch."));
		return;
	}

	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	TWeakObjectPtr<APlayerController> WeakPC(Player);
	if (Command == TEXT("buy"))
	{
		// Nur beim Werftmeister in Reichweite (SHIP-ACQUISITION); welches Schiff er verkauft, prüft das Backend.
		const FName Shipyard = FindNpcInRange(Player, EVCNpcRole::Shipyard);
		if (Shipyard.IsNone())
		{
			Player->ClientMessage(TEXT("Schiffe gibt es nur beim Werftmeister – näher herangehen."));
			return;
		}
		Session->bShipRequestInFlight = true;
		FVCServerBackend::BuyShip(Session->CharacterId, Session->AccountId, Shipyard.ToString(), Argument.ToUpper(), FGuid::NewGuid(),
			[WeakThis, WeakPC](const FVCHttpResult& Result)
			{
				APlayerController* PC = WeakPC.Get();
				FPlayerSession* S = WeakThis.IsValid() && PC ? WeakThis->Sessions.Find(PC) : nullptr;
				if (!S)
				{
					return;
				}
				S->bShipRequestInFlight = false;
				const TSharedPtr<FJsonObject>* ShipJson = nullptr;
				FPlayerSession::FShip Ship;
				double Gold = 0.0;
				if (!Result.IsOk() || !Result.Json.IsValid() || !Result.Json->TryGetObjectField(TEXT("ship"), ShipJson) || !ShipJson
					|| !FPlayerSession::FShip::FromJson(*ShipJson, Ship) || !Result.Json->TryGetNumberField(TEXT("gold"), Gold))
				{
					PC->ClientMessage(FString::Printf(TEXT("Kauf abgelehnt: %s"), *Result.ErrorMessage()));
					return;
				}
				S->Gold = static_cast<int64>(Gold);
				if (!S->Ships.ContainsByPredicate([&Ship](const FPlayerSession::FShip& Owned) { return Owned.InstanceId == Ship.InstanceId; }))
				{
					S->Ships.Add(Ship);
				}
				PC->ClientMessage(FString::Printf(TEXT("Schiff #%lld gekauft%s. Gold: %lld"), Ship.InstanceId,
					Ship.bActive ? TEXT(" (aktiv)") : TEXT(""), S->Gold));
			});
		return;
	}
	if (Command == TEXT("service"))
	{
		// "REPAIR", "HEAL", "HIRE 5", "PROVISIONS 100" – beim Werftmeister in Reichweite, für das aktive Schiff.
		FString Kind, AmountText;
		if (!Argument.Split(TEXT(" "), &Kind, &AmountText))
		{
			Kind = Argument;
		}
		int32 Amount = 0;
		LexTryParseString(Amount, *AmountText);
		const FPlayerSession::FShip* Active = Session->Ships.FindByPredicate([](const FPlayerSession::FShip& Ship) { return Ship.bActive; });
		const FName Shipyard = FindNpcInRange(Player, EVCNpcRole::Shipyard);
		if (!Active || Shipyard.IsNone())
		{
			Player->ClientMessage(TEXT("Dienste gibt es beim Werftmeister, und nur für das aktive Schiff."));
			return;
		}
		Session->bShipRequestInFlight = true;
		const int64 InstanceId = Active->InstanceId;
		FVCServerBackend::ShipService(Session->CharacterId, Session->AccountId, InstanceId, Shipyard.ToString(), Kind.ToUpper(), Amount,
			[WeakThis, WeakPC](const FVCHttpResult& Result)
			{
				APlayerController* PC = WeakPC.Get();
				FPlayerSession* S = WeakThis.IsValid() && PC ? WeakThis->Sessions.Find(PC) : nullptr;
				if (!S)
				{
					return;
				}
				S->bShipRequestInFlight = false;
				const TSharedPtr<FJsonObject>* ShipJson = nullptr;
				FPlayerSession::FShip Ship;
				double Gold = 0.0, Cost = 0.0;
				if (!Result.IsOk() || !Result.Json.IsValid() || !Result.Json->TryGetObjectField(TEXT("ship"), ShipJson) || !ShipJson
					|| !FPlayerSession::FShip::FromJson(*ShipJson, Ship) || !Result.Json->TryGetNumberField(TEXT("gold"), Gold))
				{
					PC->ClientMessage(FString::Printf(TEXT("Abgelehnt: %s"), *Result.ErrorMessage()));
					return;
				}
				Result.Json->TryGetNumberField(TEXT("cost"), Cost);
				S->Gold = static_cast<int64>(Gold);
				for (FPlayerSession::FShip& Owned : S->Ships)
				{
					Owned = Owned.InstanceId == Ship.InstanceId ? Ship : Owned;
				}
				PC->ClientMessage(FString::Printf(TEXT("Erledigt für %lld Gold – Rumpf %d/%d, Matrosen %d (+%d verletzt), Proviant %d. Gold: %lld"),
					static_cast<int64>(Cost), Ship.HullHp, Ship.HullMax, Ship.Crew, Ship.Injured, Ship.Provisions, S->Gold));
			});
		return;
	}
	if (Command == TEXT("market") || Command == TEXT("trade"))
	{
		// Hafenhandel beim Händler in Reichweite; Preise, Bestand und Laderaum entscheidet das Backend.
		const FName Merchant = FindNpcInRange(Player, EVCNpcRole::Merchant);
		if (Merchant.IsNone())
		{
			Player->ClientMessage(TEXT("Handel gibt es beim Händler (in Reichweite stehen)."));
			return;
		}
		if (Command == TEXT("market"))
		{
			Session->bShipRequestInFlight = true;
			FVCServerBackend::ViewMarket(Session->CharacterId, Session->AccountId, Merchant.ToString(),
				[WeakThis, WeakPC](const FVCHttpResult& Result)
				{
					APlayerController* PC = WeakPC.Get();
					FPlayerSession* S = WeakThis.IsValid() && PC ? WeakThis->Sessions.Find(PC) : nullptr;
					if (!S)
					{
						return;
					}
					S->bShipRequestInFlight = false;
					const TArray<TSharedPtr<FJsonValue>>* Goods = nullptr;
					if (!Result.IsOk() || !Result.Json.IsValid() || !Result.Json->TryGetArrayField(TEXT("goods"), Goods) || !Goods)
					{
						PC->ClientMessage(FString::Printf(TEXT("Markt nicht verfügbar: %s"), *Result.ErrorMessage()));
						return;
					}
					double Gold = 0.0, Used = 0.0, Capacity = 0.0;
					Result.Json->TryGetNumberField(TEXT("gold"), Gold);
					Result.Json->TryGetNumberField(TEXT("cargoUsed"), Used);
					Result.Json->TryGetNumberField(TEXT("cargoCapacity"), Capacity);
					S->Gold = static_cast<int64>(Gold);
					PC->ClientMessage(FString::Printf(TEXT("Markt – Gold %lld, Laderaum %d/%d"), S->Gold,
						static_cast<int32>(Used), static_cast<int32>(Capacity)));
					for (const TSharedPtr<FJsonValue>& Value : *Goods)
					{
						const TSharedPtr<FJsonObject> Good = Value.IsValid() ? Value->AsObject() : nullptr;
						if (!Good.IsValid())
						{
							continue;
						}
						double Stock = 0.0, Buy = 0.0, Sell = 0.0, InCargo = 0.0;
						Good->TryGetNumberField(TEXT("stock"), Stock);
						const bool bCanBuy = Good->TryGetNumberField(TEXT("buyPrice"), Buy); // null = ausverkauft
						Good->TryGetNumberField(TEXT("sellPrice"), Sell);
						Good->TryGetNumberField(TEXT("inCargo"), InCargo);
						FString NameDe;
						Good->TryGetStringField(TEXT("nameDe"), NameDe);
						PC->ClientMessage(FString::Printf(TEXT("  %s %s – kaufen %s, verkaufen %lld, Vorrat %d, an Bord %d"),
							*Good->GetStringField(TEXT("code")), *NameDe,
							bCanBuy ? *FString::Printf(TEXT("%lld"), static_cast<int64>(Buy)) : TEXT("ausverkauft"),
							static_cast<int64>(Sell), static_cast<int32>(Stock), static_cast<int32>(InCargo)));
					}
				});
			return;
		}
		// "BUY DEV_GOOD_OIL 10"
		TArray<FString> Parts;
		Argument.ParseIntoArrayWS(Parts);
		int32 Quantity = 0;
		if (Parts.Num() != 3 || !LexTryParseString(Quantity, *Parts[2]) || Quantity < 1)
		{
			Player->ClientMessage(TEXT("VCTrade <BUY|SELL> <WARE> <menge>"));
			return;
		}
		Session->bShipRequestInFlight = true;
		FVCServerBackend::Trade(Session->CharacterId, Session->AccountId, Merchant.ToString(), Parts[1].ToUpper(), Parts[0].ToUpper(),
			Quantity, [WeakThis, WeakPC](const FVCHttpResult& Result)
			{
				APlayerController* PC = WeakPC.Get();
				FPlayerSession* S = WeakThis.IsValid() && PC ? WeakThis->Sessions.Find(PC) : nullptr;
				if (!S)
				{
					return;
				}
				S->bShipRequestInFlight = false;
				double Gold = 0.0, Total = 0.0, InCargo = 0.0, Used = 0.0, Capacity = 0.0;
				if (!Result.IsOk() || !Result.Json.IsValid() || !Result.Json->TryGetNumberField(TEXT("gold"), Gold))
				{
					PC->ClientMessage(FString::Printf(TEXT("Handel abgelehnt: %s"), *Result.ErrorMessage()));
					return;
				}
				Result.Json->TryGetNumberField(TEXT("total"), Total);
				Result.Json->TryGetNumberField(TEXT("inCargo"), InCargo);
				Result.Json->TryGetNumberField(TEXT("cargoUsed"), Used);
				Result.Json->TryGetNumberField(TEXT("cargoCapacity"), Capacity);
				S->Gold = static_cast<int64>(Gold);
				const bool bBought = Result.Json->GetStringField(TEXT("side")) == TEXT("BUY");
				PC->ClientMessage(FString::Printf(TEXT("%s %d × %s für %lld Gold. An Bord %d, Laderaum %d/%d, Gold %lld"),
					bBought ? TEXT("Gekauft") : TEXT("Verkauft"), static_cast<int32>(Result.Json->GetNumberField(TEXT("quantity"))),
					*Result.Json->GetStringField(TEXT("itemCode")), static_cast<int64>(Total), static_cast<int32>(InCargo),
					static_cast<int32>(Used), static_cast<int32>(Capacity), S->Gold));
			});
		return;
	}
	if (Command == TEXT("activate"))
	{
		int64 InstanceId = 0;
		if (!LexTryParseString(InstanceId, *Argument) || !Session->Ships.ContainsByPredicate(
			[InstanceId](const FPlayerSession::FShip& Ship) { return Ship.InstanceId == InstanceId; }))
		{
			Player->ClientMessage(TEXT("Unbekanntes Schiff (VCShips zeigt deine Schiffe)"));
			return;
		}
		if (Cast<AVCShip>(Player->GetPawn()))
		{
			Player->ClientMessage(TEXT("Das aktive Schiff wechselt man im Hafen, nicht auf See."));
			return;
		}
		Session->bShipRequestInFlight = true;
		FVCServerBackend::SetActiveShip(Session->CharacterId, Session->AccountId, InstanceId, [WeakThis, WeakPC, InstanceId](const FVCHttpResult& Result)
		{
			APlayerController* PC = WeakPC.Get();
			FPlayerSession* S = WeakThis.IsValid() && PC ? WeakThis->Sessions.Find(PC) : nullptr;
			if (!S)
			{
				return;
			}
			S->bShipRequestInFlight = false;
			if (!Result.IsOk())
			{
				PC->ClientMessage(FString::Printf(TEXT("Abgelehnt: %s"), *Result.ErrorMessage()));
				return;
			}
			for (FPlayerSession::FShip& Ship : S->Ships)
			{
				Ship.bActive = Ship.InstanceId == InstanceId;
			}
			PC->ClientMessage(FString::Printf(TEXT("Schiff #%lld ist jetzt aktiv."), InstanceId));
		});
		return;
	}
	Player->ClientMessage(TEXT("Schiffsbefehle: VCShips, VCBuyShip <SCHIFF>, VCSetShip <nummer>"));
}

FString AVCGameMode::GetZoneId() const
{
	return UVCServerSettings::GetZoneId();
}

void AVCGameMode::HandleMonsterKill(AActor* Killer, FName MonsterCode)
{
	// Killer kann ein Charakter oder ein Schiff sein; gemeldet wird für den Spieler, der ihn steuert.
	const APawn* KillerPawn = Cast<APawn>(Killer);
	APlayerController* KillerPC = KillerPawn ? Cast<APlayerController>(KillerPawn->GetController()) : nullptr;
	const FPlayerSession* KillerSession = KillerPC ? Sessions.Find(KillerPC) : nullptr;
	if (!KillerSession || !KillerSession->bAuthenticated || MonsterCode.IsNone())
	{
		return;
	}
	const TSharedRef<FJsonObject> Kill = MakeShared<FJsonObject>();
	Kill->SetStringField(TEXT("victimType"), TEXT("MONSTER"));
	Kill->SetStringField(TEXT("monsterCode"), MonsterCode.ToString());
	ReportKill(KillerPC, *KillerSession, Kill);
}

void AVCGameMode::HandleShipSunk(APawn* Ship, AActor* Killer)
{
	APlayerController* PC = Ship ? Cast<APlayerController>(Ship->GetController()) : nullptr;
	FPlayerSession* Session = PC ? Sessions.Find(PC) : nullptr;
	const AVCShip* Sunk = Cast<AVCShip>(Ship);
	if (!Session || !Sunk)
	{
		return;
	}
	// Strafe fürs Sinken im Original UNKNOWN [DESIGN]: Schiff bleibt im Besitz mit Rumpf 0 (Reparatur beim Werftmeister),
	// der Spieler kommt nach kurzer Zeit an Land der Zone (Anleger) zurück. Kein Gold- oder XP-Verlust.
	const FVCShipLoadout Loadout = Sunk->GetLoadout();
	for (FPlayerSession::FShip& Owned : Session->Ships)
	{
		if (Owned.InstanceId == Loadout.InstanceId)
		{
			Owned.HullHp = 0;
			Owned.Crew = Loadout.Crew;
			Owned.Injured = Loadout.Injured;
			Owned.Provisions = Loadout.Provisions;
		}
	}
	SaveSession(PC, *Session, *Ship, false);
	PC->ClientMessage(TEXT("Dein Schiff ist gesunken. Reparatur beim Werftmeister (VCShipService REPAIR)."));
	ScheduleRespawn(PC);
}
