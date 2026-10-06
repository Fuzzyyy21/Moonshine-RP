using System.Text.RegularExpressions;

namespace VC.GameData;

/// <summary>Ein Rang einer Gilde: 0 = Gildenleiter (alle Rechte), höhere Nummer = niedrigerer Rang.</summary>
public sealed record GuildRank(short RankNo, string Name, IReadOnlySet<string> Permissions);

/// <summary>
/// Gildenregeln [DESIGN] bis auf das Belegte (SYS-GUILD: Leiter gründet mit Name und Banner; Ränge mindestens Leiter und
/// Gildenoffiziere). Reine Funktionen ohne Datenbank.
/// </summary>
public static partial class GuildRules
{
    public const short LeaderRank = 0;
    public const string Invite = "INVITE";
    public const string Kick = "KICK";
    public const string Promote = "PROMOTE";
    /// <summary>Aus der Gildenkasse auszahlen.</summary>
    public const string Treasury = "TREASURY";
    /// <summary>Städte kaufen und verwalten (belegt: Gildenoffiziere kaufen Städte).</summary>
    public const string City = "CITY";
    public static readonly IReadOnlySet<string> KnownPermissions = new HashSet<string> { Invite, Kick, Promote, Treasury, City };

    /// <summary>Banner: Symbol und zwei Farben aus festen Paletten, bis es Assets gibt (Gestaltung im Original UNKNOWN).</summary>
    public const int BannerSymbols = 16;
    public const int BannerColors = 16;

    [GeneratedRegex(@"^[\p{L}\p{N}][\p{L}\p{N} ]{1,18}[\p{L}\p{N}]$")]
    private static partial Regex NamePattern();

    [GeneratedRegex(@"^[\p{Lu}\p{N}]{2,4}$")]
    private static partial Regex TagPattern();

    /// <summary>3–20 Zeichen, Buchstaben, Ziffern und einzelne Leerzeichen, nicht am Rand.</summary>
    public static bool IsValidName(string? name) => name is not null && NamePattern().IsMatch(name) && !name.Contains("  ", StringComparison.Ordinal);

    /// <summary>Kürzel 2–4 Großbuchstaben oder Ziffern (optional).</summary>
    public static bool IsValidTag(string? tag) => tag is null || TagPattern().IsMatch(tag);

    public static bool IsValidBanner(int symbol, int color1, int color2) =>
        symbol is >= 0 and < BannerSymbols && color1 is >= 0 and < BannerColors && color2 is >= 0 and < BannerColors;

    /// <summary>Hat der Rang das Recht? Der Leiter hat alle.</summary>
    public static bool Has(GuildRank rank, string permission) => rank.RankNo == LeaderRank || rank.Permissions.Contains(permission);

    /// <summary>Entfernen: mit Recht KICK und nur Mitglieder mit niedrigerem Rang (höhere Nummer); nie sich selbst.</summary>
    public static bool CanKick(GuildRank actor, short targetRank, bool self) => !self && Has(actor, Kick) && targetRank > actor.RankNo;

    /// <summary>
    /// Rang setzen: mit Recht PROMOTE, nur bei Mitgliedern unter dem eigenen Rang und nur auf Ränge unter dem eigenen. Die Leitung
    /// (Rang 0) gibt nur der Leiter ab – das ist eine Übergabe, kein gewöhnlicher Rangwechsel.
    /// </summary>
    public static bool CanSetRank(GuildRank actor, short targetCurrent, short newRank, bool self)
    {
        if (self || newRank == targetCurrent)
        {
            return false;
        }
        if (newRank == LeaderRank)
        {
            return actor.RankNo == LeaderRank;
        }
        return Has(actor, Promote) && targetCurrent > actor.RankNo && newRank > actor.RankNo;
    }
}
