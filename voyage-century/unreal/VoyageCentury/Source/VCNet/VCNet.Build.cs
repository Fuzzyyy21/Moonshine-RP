using UnrealBuildTool;

// HTTP/JSON-Anbindung an die Backend-Dienste und clientseitiger Login-Ablauf.
public class VCNet : ModuleRules
{
	public VCNet(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine", "HTTP", "Json", "VCCore" });
	}
}
