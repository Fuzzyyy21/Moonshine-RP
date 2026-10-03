using UnrealBuildTool;

// Gemeinsame Grundlagen: Log-Kategorie, Backend-Einstellungen, Schnittstellen zwischen Modulen.
public class VCCore : ModuleRules
{
	public VCCore(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine", "DeveloperSettings" });
	}
}
