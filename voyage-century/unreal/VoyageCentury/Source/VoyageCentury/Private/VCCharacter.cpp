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
