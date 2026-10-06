namespace VC.GameData;

/// <summary>Stadtbesitz-Parameter (game_rules CITY_*, Promille). Im Original UNKNOWN; belegt ist nur, dass Gilden Städte kaufen.</summary>
public sealed record CityTuning(int TaxSharePermille, int TaxMinPermille, int TaxMaxPermille);

/// <summary>
/// Städtebesitz [DESIGN] bis auf das Belegte (SYS-GUILD: Gildenoffiziere kaufen und besetzen Städte und erhalten Belohnungen und
/// Verwaltungsrechte). Belohnung hier: Anteil der Handelssteuer im Hafen; Verwaltungsrecht: den Steuersatz in Grenzen setzen.
/// </summary>
public static class CityRules
{
    /// <summary>Anteil des Besitzers an der Steuer eines Handels, abgerundet (der Rest bleibt eine Senke).</summary>
    public static long OwnerShare(long tax, CityTuning t) => tax <= 0 ? 0 : tax * Math.Clamp(t.TaxSharePermille, 0, 1000) / 1000;

    public static bool IsValidTaxRate(int permille, CityTuning t) => permille >= t.TaxMinPermille && permille <= t.TaxMaxPermille;

    public static bool IsValidTuning(CityTuning t) =>
        t.TaxSharePermille is >= 0 and <= 1000 && t.TaxMinPermille >= 0 && t.TaxMaxPermille <= 1000 && t.TaxMinPermille <= t.TaxMaxPermille;

    /// <summary>Steuersatz, der im Hafen gilt: der des Besitzers, sonst der des Marktes.</summary>
    public static double EffectiveTaxRate(double marketRate, int? ownerPermille) => ownerPermille is { } p ? p / 1000.0 : marketRate;
}
