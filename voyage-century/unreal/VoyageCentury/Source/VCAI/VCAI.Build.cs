using UnrealBuildTool;

// Gegner: Spielfigur, einfache KI (Zustandsautomat ohne Behavior-Tree-Assets) und Spawner.
public class VCAI : ModuleRules
{
	public VCAI(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", "CoreUObject", "Engine", "AIModule", "NavigationSystem",
			"GameplayAbilities", "GameplayTags", "VCCore", "VCData", "VCRules", "VCAbilities" });
	}
}
