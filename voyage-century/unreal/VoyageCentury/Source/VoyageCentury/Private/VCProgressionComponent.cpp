#include "VCProgressionComponent.h"
#include "Net/UnrealNetwork.h"
#include "VCCore.h"

UVCProgressionComponent::UVCProgressionComponent()
{
	PrimaryComponentTick.bCanEverTick = false;
	SetIsReplicatedByDefault(true);
}

void UVCProgressionComponent::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);
	DOREPLIFETIME(UVCProgressionComponent, Level);
	DOREPLIFETIME_CONDITION(UVCProgressionComponent, Experience, COND_OwnerOnly);
	DOREPLIFETIME_CONDITION(UVCProgressionComponent, LevelCap, COND_OwnerOnly);
	DOREPLIFETIME_CONDITION(UVCProgressionComponent, Skills, COND_OwnerOnly);
}

bool UVCProgressionComponent::CheckAuthority(const TCHAR* Caller) const
{
	const AActor* Owner = GetOwner();
	if (!Owner || !Owner->HasAuthority())
	{
		UE_LOG(LogVC, Error, TEXT("%s ohne Autorität aufgerufen – ignoriert"), Caller);
		return false;
	}
	return true;
}

void UVCProgressionComponent::ServerApplyCharacter(int32 InLevel, int64 InExperience, int32 InLevelCap)
{
	if (!CheckAuthority(TEXT("ServerApplyCharacter")))
	{
		return;
	}
	Level = FMath::Max(1, InLevel);
	Experience = FMath::Max<int64>(0, InExperience);
	LevelCap = FMath::Max(Level, InLevelCap);
	OnProgressChanged.Broadcast();
}

void UVCProgressionComponent::ServerApplySkill(const FVCSkillState& Skill)
{
	if (!CheckAuthority(TEXT("ServerApplySkill")))
	{
		return;
	}
	if (FVCSkillState* Existing = Skills.FindByPredicate([&Skill](const FVCSkillState& S) { return S.Code == Skill.Code; }))
	{
		*Existing = Skill;
	}
	else
	{
		Skills.Add(Skill);
	}
	OnProgressChanged.Broadcast();
}

void UVCProgressionComponent::ServerSetSkills(const TArray<FVCSkillState>& InSkills)
{
	if (!CheckAuthority(TEXT("ServerSetSkills")))
	{
		return;
	}
	Skills = InSkills;
	OnProgressChanged.Broadcast();
}

void UVCProgressionComponent::OnRep_Progress()
{
	OnProgressChanged.Broadcast();
}
