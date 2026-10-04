using UnrealBuildTool;

public class VoyageCenturyTarget : TargetRules
{
	public VoyageCenturyTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.AddRange(new string[] { "VoyageCentury", "VCServer", "VCAI" });
	}
}
