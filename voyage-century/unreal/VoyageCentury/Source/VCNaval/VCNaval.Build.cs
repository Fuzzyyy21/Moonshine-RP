using UnrealBuildTool;

// Seefahrt: Schiff als Spielfigur, Segelphysik über VCRules, Wind je Zone, Schiffsdaten.
public class VCNaval : ModuleRules
{
	public VCNaval(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", "CoreUObject", "Engine", "NetCore", "DeveloperSettings", "EnhancedInput", "InputCore",
			"VCCore", "VCData", "VCRules" });
	}
}
