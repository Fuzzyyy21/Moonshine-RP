#include "VCGameMode.h"
#include "Engine/NetConnection.h"
#include "Engine/World.h"
#include "GameFramework/GameSession.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"
#include "VCCharacter.h"
#include "VCCore.h"
#include "VCHttp.h"
#include "VCPlayerController.h"
#include "VCPlayerState.h"
#include "VCProgressionComponent.h"
#include "VCServerBackend.h"
#include "VCServerSettings.h"

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

	/** Übernimmt {level, experience, levelCap?} aus einer Backend-Antwort. */
	void ApplyCharacterProgress(const APlayerController* PC, const TSharedPtr<FJsonObject>& Json)
	{
		UVCProgressionComponent* Progression = ProgressionOf(PC);
		double Level = 1.0, Experience = 0.0, Cap = 1.0;
		if (Progression && Json.IsValid() && Json->TryGetNumberField(TEXT("level"), Level)
			&& Json->TryGetNumberField(TEXT("experience"), Experience))
		{
			Json->TryGetNumberField(TEXT("levelCap"), Cap);
			Progression->ServerApplyCharacter(static_cast<int32>(Level), static_cast<int64>(Experience), static_cast<int32>(Cap));
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
		}
		Pawn->OnDestroyed.AddDynamic(this, &AVCGameMode::OnPlayerPawnDestroyed);
	}
	UE_LOG(LogVC, Display, TEXT("Charakter %lld (Konto %lld) betritt Zone %s"),
		Session->CharacterId, Session->AccountId, *UVCServerSettings::GetZoneId());
}

void AVCGameMode::Reject(APlayerController* PC, const FString& Reason)
{
	UE_LOG(LogVC, Warning, TEXT("Spieler getrennt (%s): %s"), *RemoteAddress(PC), *Reason);
	Sessions.Remove(PC);
	if (GameSession)
	{
		GameSession->KickPlayer(PC, FText::FromString(Reason));
	}
}

void AVCGameMode::Logout(AController* Exiting)
{
	// Die Position wurde bereits in OnPlayerPawnDestroyed gespeichert (der Pawn ist hier schon weg).
	if (APlayerController* PC = Cast<APlayerController>(Exiting))
	{
		Sessions.Remove(PC);
	}
	Super::Logout(Exiting);
}

void AVCGameMode::OnPlayerPawnDestroyed(AActor* DestroyedActor)
{
	for (const TPair<TObjectKey<APlayerController>, FPlayerSession>& Entry : Sessions)
	{
		if (Entry.Value.bAuthenticated && Entry.Value.Pawn.Get() == DestroyedActor)
		{
			SaveSession(Entry.Value, *CastChecked<APawn>(DestroyedActor));
			return;
		}
	}
}

void AVCGameMode::SaveSession(const FPlayerSession& Session, const APawn& Pawn) const
{
	const int64 CharacterId = Session.CharacterId;
	FVCServerBackend::SaveCharacter(CharacterId, Session.AccountId, UVCServerSettings::GetZoneId(),
		Pawn.GetActorLocation(), Pawn.GetActorRotation().Yaw, [CharacterId](const FVCHttpResult& Result)
		{
			if (!Result.IsOk())
			{
				UE_LOG(LogVC, Error, TEXT("Speichern von Charakter %lld fehlgeschlagen: %s"),
					CharacterId, *Result.ErrorMessage());
			}
		});
}

void AVCGameMode::SaveAllPlayers()
{
	for (const TPair<TObjectKey<APlayerController>, FPlayerSession>& Entry : Sessions)
	{
		if (Entry.Value.bAuthenticated && Entry.Value.Pawn.IsValid())
		{
			SaveSession(Entry.Value, *Entry.Value.Pawn.Get());
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
				WeakThis->SaveSession(*S, *P);
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
