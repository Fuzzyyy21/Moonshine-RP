using UnrealBuildTool;

public class VoyageCenturyEditorTarget : TargetRules
{
	public VoyageCenturyEditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.AddRange(new string[] { "VoyageCentury", "VCServer", "VCAI" });
	}
}
