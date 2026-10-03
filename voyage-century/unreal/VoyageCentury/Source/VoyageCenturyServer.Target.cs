using UnrealBuildTool;

public class VoyageCenturyServerTarget : TargetRules
{
	public VoyageCenturyServerTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Server;
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.AddRange(new string[] { "VoyageCentury", "VCServer" });
	}
}
