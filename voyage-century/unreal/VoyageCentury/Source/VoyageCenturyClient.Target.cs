using UnrealBuildTool;

public class VoyageCenturyClientTarget : TargetRules
{
	public VoyageCenturyClientTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Client;
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.AddRange(new string[] { "VoyageCentury", "VCServer", "VCAI" });
	}
}
