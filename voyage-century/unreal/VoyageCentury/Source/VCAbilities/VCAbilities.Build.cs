using UnrealBuildTool;

// Gameplay Ability System: Attribute, Schadensberechnung (über VCRules), Grundangriff, Kampfdaten.
public class VCAbilities : ModuleRules
{
	public VCAbilities(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", "CoreUObject", "Engine", "NetCore", "DeveloperSettings",
			"GameplayAbilities", "GameplayTags", "GameplayTasks",
			"VCCore", "VCData", "VCRules" });
	}
}
