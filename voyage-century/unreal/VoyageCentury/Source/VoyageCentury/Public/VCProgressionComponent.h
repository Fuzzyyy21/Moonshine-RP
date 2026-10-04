#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "VCProgressionComponent.generated.h"

/** Stand eines Skills, wie ihn der GameData-Dienst meldet. */
USTRUCT(BlueprintType)
struct VOYAGECENTURY_API FVCSkillState
{
	GENERATED_BODY()

	/** Code aus DT_Skills, z. B. NAVIGATION. */
	UPROPERTY(BlueprintReadOnly, Category = "Skill")
	FName Code;

	UPROPERTY(BlueprintReadOnly, Category = "Skill")
	int32 Level = 1;

	/** Skillstufe 1–3 (Grenzen 31 / 100 / 120 laut SKILL-STAGES). */
	UPROPERTY(BlueprintReadOnly, Category = "Skill")
	int32 Stage = 1;

	UPROPERTY(BlueprintReadOnly, Category = "Skill")
	int64 Experience = 0;
};

DECLARE_MULTICAST_DELEGATE(FOnVCProgressChanged);

/**
 * Level, XP und Skills eines Spielers – nur eine Anzeige-Kopie.
 * Die Wahrheit liegt im GameData-Dienst; nur der Server schreibt hier (ApplyFromBackend),
 * und zwar ausschließlich mit Werten, die das Backend bestätigt hat.
 * Level sehen alle Spieler, XP und Skills nur der Besitzer.
 */
UCLASS(ClassGroup = (VoyageCentury), meta = (BlueprintSpawnableComponent))
class VOYAGECENTURY_API UVCProgressionComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UVCProgressionComponent();

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

	UFUNCTION(BlueprintPure, Category = "Progression")
	int32 GetLevel() const { return Level; }

	UFUNCTION(BlueprintPure, Category = "Progression")
	int64 GetExperience() const { return Experience; }

	const TArray<FVCSkillState>& GetSkills() const { return Skills; }

	/** Nur Server: Charakterwerte aus einer Backend-Antwort übernehmen. */
	void ServerApplyCharacter(int32 InLevel, int64 InExperience, int32 InLevelCap);

	/** Nur Server: einen Skill aus einer Backend-Antwort übernehmen (fügt ihn bei Bedarf hinzu). */
	void ServerApplySkill(const FVCSkillState& Skill);

	/** Nur Server: komplette Skillliste ersetzen (beim Laden des Charakters). */
	void ServerSetSkills(const TArray<FVCSkillState>& InSkills);

	/** Feuert auf Server und Client, wenn sich etwas geändert hat (für HUD/UI). */
	FOnVCProgressChanged OnProgressChanged;

private:
	UPROPERTY(ReplicatedUsing = OnRep_Progress)
	int32 Level = 1;

	UPROPERTY(ReplicatedUsing = OnRep_Progress)
	int64 Experience = 0;

	/** Höchste Stufe mit bekannter XP-Schwelle. */
	UPROPERTY(ReplicatedUsing = OnRep_Progress)
	int32 LevelCap = 1;

	UPROPERTY(ReplicatedUsing = OnRep_Progress)
	TArray<FVCSkillState> Skills;

	UFUNCTION()
	void OnRep_Progress();

	bool CheckAuthority(const TCHAR* Caller) const;
};
