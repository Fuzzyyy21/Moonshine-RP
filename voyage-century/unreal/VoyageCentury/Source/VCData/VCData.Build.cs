using UnrealBuildTool;

// Row-Structs der generierten Data Tables (Quelle: tools/export_content.py).
public class VCData : ModuleRules
{
	public VCData(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine" });
	}
}
