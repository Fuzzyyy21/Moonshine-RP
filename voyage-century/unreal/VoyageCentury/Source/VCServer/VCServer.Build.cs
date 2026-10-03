using UnrealBuildTool;

// Serverlogik: Ticketprüfung beim Verbinden, Laden/Speichern über den GameData-Dienst, Admin-Kommandos.
// Läuft nur mit Autorität. Der Service-Key wird ausschließlich zur Laufzeit aus der Umgebung gelesen
// und ist in Client-Builds (WITH_SERVER_CODE == 0) gar nicht erst vorhanden.
public class VCServer : ModuleRules
{
	public VCServer(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine", "DeveloperSettings", "VCCore", "VCNet", "VoyageCentury" });
		PrivateDependencyModuleNames.AddRange(new string[] { "Json" });
	}
}
