using UnrealBuildTool;

// Welt: Objekte, die in Karten platziert werden (Zonenausgänge, NPCs, Entdeckungspunkte; später Wetter).
// Läuft auf Client und Server, damit Karten auf beiden Seiten laden; Wirkung nur auf dem Server.
public class VCWorld : ModuleRules
{
	public VCWorld(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine", "NetCore", "DeveloperSettings", "VCCore", "VCData" });
	}
}
