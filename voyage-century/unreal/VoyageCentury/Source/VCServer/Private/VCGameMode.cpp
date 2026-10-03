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

	const TSharedRef<FJsonObject> Entry = MakeShared<FJsonObject>();
	Entry->SetNumberField(TEXT("adminAccountId"), static_cast<double>(Session.AccountId));
	Entry->SetStringField(TEXT("command"), TEXT("/teleport"));
	Entry->SetStringField(TEXT("targetType"), TEXT("CHARACTER"));
	Entry->SetStringField(TEXT("targetId"), FString::Printf(TEXT("%lld"), Session.CharacterId));
	Entry->SetObjectField(TEXT("args"), VectorJson(Target));
	Entry->SetObjectField(TEXT("oldValue"), VectorJson(Old));
	Entry->SetObjectField(TEXT("newValue"), VectorJson(Target));
	Entry->SetStringField(TEXT("sessionId"), Session.SessionId);
	Entry->SetStringField(TEXT("serverId"), UVCServerSettings::GetServerId());
	const FString Ip = RemoteAddress(Issuer);
	if (!Ip.IsEmpty())
	{
		Entry->SetStringField(TEXT("ip"), Ip);
	}

	// Erst protokollieren, dann ausführen: ohne Audit-Eintrag keine Admin-Aktion.
	TWeakObjectPtr<AVCGameMode> WeakThis(this);
	TWeakObjectPtr<APlayerController> WeakPC(Issuer);
	FVCServerBackend::WriteAdminAudit(Entry, [WeakThis, WeakPC, Target](const FVCHttpResult& Result)
	{
		APlayerController* PC = WeakPC.Get();
		if (!WeakThis.IsValid() || !PC)
		{
			return;
		}
		if (!Result.IsOk())
		{
			PC->ClientMessage(FString::Printf(TEXT("Teleport abgelehnt: %s"), *Result.ErrorMessage()));
			return;
		}
		APawn* P = PC->GetPawn();
		if (!P || !P->TeleportTo(Target, P->GetActorRotation()))
		{
			UE_LOG(LogVC, Warning, TEXT("Teleport nach %s nicht möglich (blockiert)"), *Target.ToString());
			PC->ClientMessage(TEXT("Zielort blockiert."));
			return;
		}
		if (const FPlayerSession* S = WeakThis->Sessions.Find(PC))
		{
			WeakThis->SaveSession(*S, *P);
		}
	});
}
