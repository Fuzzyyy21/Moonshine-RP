using System.ComponentModel.DataAnnotations;

namespace VC.Common;

/// <summary>Identität des laufenden Dienstes; landet in jedem Log-Eintrag als <c>server</c>.</summary>
public sealed class ServiceIdentityOptions
{
    public const string Section = "Service";

    [Required, RegularExpression("^[a-z][a-z0-9-]{1,31}$")]
    public string Name { get; set; } = "";

    /// <summary>Eindeutige Instanz-ID, z. B. Hostname oder Pod-Name.</summary>
    [Required, MinLength(1)]
    public string InstanceId { get; set; } = Environment.MachineName;
}

public sealed class DatabaseOptions
{
    public const string Section = "Database";

    [Required, MinLength(1)]
    public string ConnectionString { get; set; } = "";
}

/// <summary>
/// Schlüssel, mit denen sich Zonen-Server gegenüber internen Endpunkten ausweisen.
/// Mehrere Schlüssel erlauben Rotation ohne Ausfall. Nie in Client-Builds ausliefern.
/// </summary>
public sealed class ServiceKeyOptions
{
    public const string Section = "ServiceKeys";
    public const int MinimumLength = 32;

    /// <summary>Schlüssel mit diesem Präfix stehen in appsettings.Development.json und werden sonst abgelehnt.</summary>
    public const string DevelopmentPrefix = "dev-only-";

    [Required, MinLength(1)]
    public List<string> Keys { get; set; } = [];
}
