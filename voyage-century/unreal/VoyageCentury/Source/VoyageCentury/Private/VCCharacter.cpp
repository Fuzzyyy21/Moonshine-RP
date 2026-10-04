#include "VCCharacter.h"
#include "Camera/CameraComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/LocalPlayer.h"
#include "Engine/StaticMesh.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/SpringArmComponent.h"
#include "InputAction.h"
#include "InputMappingContext.h"
#include "InputModifiers.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Net/UnrealNetwork.h"
#include "Components/SkeletalMeshComponent.h"
#include "Engine/SkeletalMesh.h"
#include "UObject/ConstructorHelpers.h"
#include "VCCore.h"
#include "AbilitySystemBlueprintLibrary.h"
#include "AbilitySystemComponent.h"
#include "EngineUtils.h"
#include "VCAbilityStateComponent.h"
#include "VCAbility_UseSkill.h"
#include "VCAttributeSet.h"
#include "VCCombatData.h"
#include "VCCombatStateComponent.h"
#include "VCGameplayTags.h"
#include "VCPlayerState.h"
#include "VCProgressionComponent.h"
#include "VCServerHooks.h"

AVCCharacter::AVCCharacter()
{
	PlaceholderBody = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("PlaceholderBody"));
	PlaceholderBody->SetupAttachment(GetCapsuleComponent());
	PlaceholderBody->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	PlaceholderBody->SetRelativeScale3D(FVector(0.8f, 0.8f, 1.76f));

	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cylinder(TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));
	if (Cylinder.Succeeded())
	{
		PlaceholderBody->SetStaticMesh(Cylinder.Object);
	}

	// Figur dreht sich in Laufrichtung, Kamera folgt der Maus.
	bUseControllerRotationYaw = false;
	bUseControllerRotationPitch = false;
	bUseControllerRotationRoll = false;
	GetCharacterMovement()->bOrientRotationToMovement = true;

	PlaceholderHair = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("PlaceholderHair"));
	PlaceholderHair->SetupAttachment(PlaceholderBody);
	PlaceholderHair->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	PlaceholderHair->SetRelativeLocation(FVector(0.f, 0.f, 55.f));
	PlaceholderHair->SetRelativeScale3D(FVector(0.9f, 0.9f, 0.25f));
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Sphere(TEXT("/Engine/BasicShapes/Sphere.Sphere"));
	if (Sphere.Succeeded())
	{
		PlaceholderHair->SetStaticMesh(Sphere.Object);
	}

	CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
	CameraBoom->SetupAttachment(GetCapsuleComponent());
	CameraBoom->TargetArmLength = 600.f;
	CameraBoom->bUsePawnControlRotation = true;

	FollowCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FollowCamera"));
	FollowCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
	FollowCamera->bUsePawnControlRotation = false;

	CombatState = CreateDefaultSubobject<UVCCombatStateComponent>(TEXT("CombatState"));
	CombatState->bRegenerateStamina = true;
}

void AVCCharacter::CreateInputObjects()
{
	if (InputContext)
	{
		return;
	}
	MoveAction = NewObject<UInputAction>(this, TEXT("IA_Move"));
	MoveAction->ValueType = EInputActionValueType::Axis2D;
	LookAction = NewObject<UInputAction>(this, TEXT("IA_Look"));
	LookAction->ValueType = EInputActionValueType::Axis2D;
	JumpAction = NewObject<UInputAction>(this, TEXT("IA_Jump"));
	JumpAction->ValueType = EInputActionValueType::Boolean;

	InputContext = NewObject<UInputMappingContext>(this, TEXT("IMC_Land"));

	// Move: X = rechts, Y = vorwärts. W/S liegen auf Y (Swizzle), S und A negiert.
	InputContext->MapKey(MoveAction, EKeys::W).Modifiers.Add(NewObject<UInputModifierSwizzleAxis>(this));
	{
		FEnhancedActionKeyMapping& S = InputContext->MapKey(MoveAction, EKeys::S);
		S.Modifiers.Add(NewObject<UInputModifierSwizzleAxis>(this));
		S.Modifiers.Add(NewObject<UInputModifierNegate>(this));
	}
	InputContext->MapKey(MoveAction, EKeys::A).Modifiers.Add(NewObject<UInputModifierNegate>(this));
	InputContext->MapKey(MoveAction, EKeys::D);

	// Look: Maus; Y negiert, damit "Maus hoch" nach oben schaut.
	{
		UInputModifierNegate* InvertY = NewObject<UInputModifierNegate>(this);
		InvertY->bX = false;
		InvertY->bZ = false;
		InputContext->MapKey(LookAction, EKeys::Mouse2D).Modifiers.Add(InvertY);
	}

	InputContext->MapKey(JumpAction, EKeys::SpaceBar);

	TargetAction = NewObject<UInputAction>(this, TEXT("IA_Target"));
	TargetAction->ValueType = EInputActionValueType::Boolean;
	InputContext->MapKey(TargetAction, EKeys::Tab);
	AttackAction = NewObject<UInputAction>(this, TEXT("IA_Attack"));
	AttackAction->ValueType = EInputActionValueType::Boolean;
	InputContext->MapKey(AttackAction, EKeys::LeftMouseButton);

	// Tasten 1–9 und 0 → Plätze 1–10. Der Scalar-Modifier macht aus "gedrückt" (1.0) die Platznummer.
	HotbarAction = NewObject<UInputAction>(this, TEXT("IA_Hotbar"));
	HotbarAction->ValueType = EInputActionValueType::Axis1D;
	const TArray<FKey> HotbarKeys = { EKeys::One, EKeys::Two, EKeys::Three, EKeys::Four, EKeys::Five,
		EKeys::Six, EKeys::Seven, EKeys::Eight, EKeys::Nine, EKeys::Zero };
	for (int32 Index = 0; Index < HotbarKeys.Num(); ++Index)
	{
		UInputModifierScalar* SlotNumber = NewObject<UInputModifierScalar>(this);
		SlotNumber->Scalar = FVector(static_cast<double>(Index + 1), 1.0, 1.0);
		InputContext->MapKey(HotbarAction, HotbarKeys[Index]).Modifiers.Add(SlotNumber);
	}
}

void AVCCharacter::PawnClientRestart()
{
	Super::PawnClientRestart();
	CreateInputObjects();

	const APlayerController* PC = Cast<APlayerController>(GetController());
	const ULocalPlayer* LocalPlayer = PC ? PC->GetLocalPlayer() : nullptr;
	if (UEnhancedInputLocalPlayerSubsystem* Input = LocalPlayer
		? LocalPlayer->GetSubsystem<UEnhancedInputLocalPlayerSubsystem>() : nullptr)
	{
		Input->AddMappingContext(InputContext, 0);
	}
}

void AVCCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);
	CreateInputObjects();

	UEnhancedInputComponent* Input = Cast<UEnhancedInputComponent>(PlayerInputComponent);
	if (!Input)
	{
		UE_LOG(LogVC, Error, TEXT("Enhanced Input ist nicht aktiv (Config/DefaultInput.ini prüfen)"));
		return;
	}
	Input->BindAction(MoveAction, ETriggerEvent::Triggered, this, &AVCCharacter::Move);
	Input->BindAction(LookAction, ETriggerEvent::Triggered, this, &AVCCharacter::Look);
	Input->BindAction(JumpAction, ETriggerEvent::Started, this, &ACharacter::Jump);
	Input->BindAction(JumpAction, ETriggerEvent::Completed, this, &ACharacter::StopJumping);
	Input->BindAction(TargetAction, ETriggerEvent::Started, this, &AVCCharacter::CycleTarget);
	Input->BindAction(AttackAction, ETriggerEvent::Started, this, &AVCCharacter::Attack);
	Input->BindAction(HotbarAction, ETriggerEvent::Started, this, &AVCCharacter::UseHotbar);
}

void AVCCharacter::Move(const FInputActionValue& Value)
{
	const FVector2D Axis = Value.Get<FVector2D>();
	if (!Controller || Axis.IsNearlyZero())
	{
		return;
	}
	const FRotator Yaw(0.f, Controller->GetControlRotation().Yaw, 0.f);
	AddMovementInput(FRotationMatrix(Yaw).GetUnitAxis(EAxis::X), Axis.Y);
	AddMovementInput(FRotationMatrix(Yaw).GetUnitAxis(EAxis::Y), Axis.X);
}

void AVCCharacter::Look(const FInputActionValue& Value)
{
	const FVector2D Axis = Value.Get<FVector2D>();
	AddControllerYawInput(Axis.X);
	AddControllerPitchInput(Axis.Y);
}

void AVCCharacter::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);
	DOREPLIFETIME(AVCCharacter, Appearance);
	DOREPLIFETIME(AVCCharacter, EquippedWeapon);
}

void AVCCharacter::BeginPlay()
{
	Super::BeginPlay();
	UseCharacterModelIfConfigured();
	ApplyAppearance();
}

void AVCCharacter::ServerSetAppearance(const FVCAppearance& InAppearance)
{
	if (!HasAuthority())
	{
		return;
	}
	Appearance = InAppearance;
	ApplyAppearance(); // Server und Listen-Host sehen die Änderung sofort, Clients per OnRep
}

void AVCCharacter::OnRep_Appearance()
{
	ApplyAppearance();
}

void AVCCharacter::UseCharacterModelIfConfigured()
{
	// Andockstelle für echte Modelle: ist ein Mesh konfiguriert, ersetzt es den Platzhalter.
	const UVCAppearanceSettings* Settings = GetDefault<UVCAppearanceSettings>();
	USkeletalMesh* Mesh = Settings->CharacterMesh.IsNull() ? nullptr : Settings->CharacterMesh.LoadSynchronous();
	if (!Mesh)
	{
		return;
	}
	GetMesh()->SetSkeletalMeshAsset(Mesh);
	if (UClass* AnimClass = Settings->AnimClass.IsNull() ? nullptr : Settings->AnimClass.LoadSynchronous())
	{
		GetMesh()->SetAnimInstanceClass(AnimClass);
	}
	PlaceholderBody->SetVisibility(false, true);
}

void AVCCharacter::ApplyAppearance()
{
	if (GetNetMode() == NM_DedicatedServer || !PlaceholderBody->IsVisible())
	{
		return; // Keine Darstellung auf dem Server; echte Modelle bekommen später eigene Logik
	}
	const UVCAppearanceSettings* Settings = GetDefault<UVCAppearanceSettings>();
	auto Pick = [](const auto& Array, int32 Index, const auto& Fallback)
	{
		return Array.IsValidIndex(Index) ? Array[Index] : Fallback;
	};

	PlaceholderBody->SetRelativeScale3D(Pick(Settings->BodyScales, Appearance.Get(TEXT("body")), FVector(0.8f, 0.8f, 1.76f)));
	if (UMaterialInstanceDynamic* Skin = PlaceholderBody->CreateDynamicMaterialInstance(0))
	{
		// BasicShapeMaterial der Engine hat den Farbparameter "Color".
		Skin->SetVectorParameterValue(TEXT("Color"), Pick(Settings->SkinColors, Appearance.Get(TEXT("skin")), FLinearColor::White));
	}
	if (UMaterialInstanceDynamic* Hair = PlaceholderHair->CreateDynamicMaterialInstance(0))
	{
		Hair->SetVectorParameterValue(TEXT("Color"), Pick(Settings->HairColors, Appearance.Get(TEXT("hairColor")), FLinearColor::Black));
	}
	// Haarform: Index 0 = kurz, höhere Indizes = höher aufgebaut (Platzhalter für echte Frisuren).
	const int32 HairStyle = Appearance.Get(TEXT("hair"));
	PlaceholderHair->SetRelativeScale3D(FVector(0.9f, 0.9f, 0.25f + 0.15f * HairStyle));
}

UAbilitySystemComponent* AVCCharacter::GetAbilitySystemComponent() const
{
	const AVCPlayerState* PS = GetPlayerState<AVCPlayerState>();
	return PS ? PS->GetAbilitySystemComponent() : nullptr;
}

void AVCCharacter::PossessedBy(AController* NewController)
{
	Super::PossessedBy(NewController);
	InitAbilityActorInfo(); // Server
}

void AVCCharacter::OnRep_PlayerState()
{
	Super::OnRep_PlayerState();
	InitAbilityActorInfo(); // Client
}

void AVCCharacter::InitAbilityActorInfo()
{
	if (AVCPlayerState* PS = GetPlayerState<AVCPlayerState>())
	{
		PS->GetAbilitySystemComponent()->InitAbilityActorInfo(PS, this);
	}
}

bool AVCCharacter::IsAlive() const
{
	const UAbilitySystemComponent* ASC = GetAbilitySystemComponent();
	return ASC && !ASC->HasMatchingGameplayTag(TAG_VC_State_Dead)
		&& ASC->GetNumericAttribute(UVCAttributeSet::GetHealthAttribute()) > 0.f;
}

bool AVCCharacter::GetAttack(vc::rules::FWeaponDef& OutWeapon, FName& OutSkillCode, int32& OutSkillLevel) const
{
	const FName Code = EquippedWeapon.IsNone() ? GetDefault<UVCCombatSettings>()->UnarmedWeapon : EquippedWeapon;
	const FVCWeaponRow* Row = FVCCombatData::FindWeapon(Code);
	if (!Row)
	{
		return false;
	}
	OutWeapon = FVCCombatData::ToRules(*Row);
	OutSkillCode = Row->SkillCode;
	OutSkillLevel = GetSkillLevel(Row->SkillCode);
	return true;
}

int32 AVCCharacter::GetSkillLevel(FName SkillCode) const
{
	if (const AVCPlayerState* PS = GetPlayerState<AVCPlayerState>())
	{
		for (const FVCSkillState& Skill : PS->GetProgression()->GetSkills())
		{
			if (Skill.Code == SkillCode)
			{
				return Skill.Level;
			}
		}
	}
	return 1;
}

FText AVCCharacter::GetCombatName() const
{
	const APlayerState* PS = GetPlayerState();
	return FText::FromString(PS ? PS->GetPlayerName() : GetName());
}

void AVCCharacter::HandleOutOfHealth(AActor* Killer)
{
	if (!HasAuthority())
	{
		return;
	}
	CombatState->ServerClearAll();
	if (UAbilitySystemComponent* ASC = GetAbilitySystemComponent())
	{
		ASC->AddLooseGameplayTag(TAG_VC_State_Dead);
	}
	GetCharacterMovement()->DisableMovement();
	if (IVCServerHooks* Hooks = Cast<IVCServerHooks>(GetWorld()->GetAuthGameMode()))
	{
		Hooks->HandleKill(Killer, this); // Meldung ans Backend und Respawn übernimmt der Server-GameMode
	}
}

void AVCCharacter::ServerSetEquippedWeapon(FName WeaponCode)
{
	if (HasAuthority() && (WeaponCode.IsNone() || FVCCombatData::FindWeapon(WeaponCode)))
	{
		EquippedWeapon = WeaponCode;
	}
}

void AVCCharacter::CycleTarget()
{
	// Nächstes lebendes, feindliches Ziel im Umkreis, nach Entfernung sortiert; wiederholtes Drücken wechselt weiter.
	constexpr double SearchRadius = 2500.0;
	TArray<AActor*> Candidates;
	for (TActorIterator<AActor> It(GetWorld()); It; ++It)
	{
		const IVCCombatant* Other = Cast<IVCCombatant>(*It);
		if (*It != this && Other && Other->IsAlive()
			&& FVector::DistSquared(GetActorLocation(), It->GetActorLocation()) <= SearchRadius * SearchRadius)
		{
			Candidates.Add(*It);
		}
	}
	if (Candidates.IsEmpty())
	{
		CurrentTarget.Reset();
		return;
	}
	const FVector Here = GetActorLocation();
	Candidates.Sort([Here](const AActor& A, const AActor& B)
	{
		return FVector::DistSquared(Here, A.GetActorLocation()) < FVector::DistSquared(Here, B.GetActorLocation());
	});
	const int32 Current = Candidates.IndexOfByKey(CurrentTarget.Get());
	CurrentTarget = Candidates[(Current + 1) % Candidates.Num()]; // Anzeige im Zielrahmen des HUD
}

void AVCCharacter::Attack()
{
	if (AActor* Target = CurrentTarget.Get())
	{
		ServerRequestAttack(Target);
	}
}

void AVCCharacter::ServerRequestAttack_Implementation(AActor* Target)
{
	// Der Client nennt nur das Ziel. Ob der Angriff zählt, entscheidet die Fähigkeit auf dem Server.
	if (!Target || !IsAlive())
	{
		return;
	}
	FGameplayEventData Payload;
	Payload.Instigator = this;
	Payload.Target = Target;
	UAbilitySystemBlueprintLibrary::SendGameplayEventToActor(this, TAG_VC_Event_Attack, Payload);
}

void AVCCharacter::UseHotbar(const FInputActionValue& Value)
{
	const int32 Slot = FMath::RoundToInt(Value.Get<float>()) - 1;
	if (Slot >= 0 && Slot < UVCAbilityStateComponent::HotbarSlots)
	{
		ServerUseHotbarSlot(Slot, CurrentTarget.Get());
	}
}

bool AVCCharacter::ServerUseHotbarSlot_Validate(int32 Slot, AActor* Target)
{
	return Slot >= 0 && Slot < UVCAbilityStateComponent::HotbarSlots;
}

void AVCCharacter::ServerUseHotbarSlot_Implementation(int32 Slot, AActor* Target)
{
	const UVCAbilityStateComponent* State = UVCAbilityStateComponent::Find(this);
	const FName Code = State ? State->GetHotbarSlot(Slot) : NAME_None;
	if (Code.IsNone() || !IsAlive())
	{
		return;
	}
	FGameplayEventData Payload = UVCAbility_UseSkill::MakeRequest(this, Code, Target);
	UAbilitySystemBlueprintLibrary::SendGameplayEventToActor(this, TAG_VC_Event_UseAbility, Payload);
}
