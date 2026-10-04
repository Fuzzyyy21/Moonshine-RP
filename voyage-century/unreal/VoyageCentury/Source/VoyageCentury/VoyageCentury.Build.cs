using UnrealBuildTool;

// Primäres Spielmodul: Klassen, die Client und Server gemeinsam brauchen (PlayerController, Charakter).
public class VoyageCentury : ModuleRules
{
	public VoyageCentury(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine", "NetCore", "EnhancedInput", "InputCore", "AnimGraphRuntime", "Slate", "SlateCore", "DeveloperSettings", "GameplayAbilities", "GameplayTags", "VCCore", "VCData", "VCNet", "VCRules", "VCAbilities" });
	}
}
