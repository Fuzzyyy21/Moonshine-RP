using UnrealBuildTool;

// Reine Kampfregeln ohne Engine-Abhängigkeit (nur C++-Standardbibliothek).
// Werden zusätzlich außerhalb von Unreal mit g++/clang kompiliert und getestet (tools/test_rules.sh).
public class VCRules : ModuleRules
{
	public VCRules(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] { "Core" });
	}
}
