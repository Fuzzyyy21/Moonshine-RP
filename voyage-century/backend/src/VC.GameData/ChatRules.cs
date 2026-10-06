using System.ComponentModel.DataAnnotations;
using System.Text;

namespace VC.GameData;

/// <summary>Chat-Grenzen (appsettings, Abschnitt Chat). Technische Schutzwerte, keine Spielwerte des Originals.</summary>
public sealed class ChatOptions
{
    public const string Section = "Chat";

    [Range(1, 1000)]
    public int MaxLength { get; set; } = 200;

    /// <summary>Höchstens so viele Nachrichten je Fenster und Kanal (WORLD und TRADE: WideMaxPerWindow).</summary>
    [Range(1, 1000)]
    public int MaxPerWindow { get; set; } = 5;

    [Range(1, 1000)]
    public int WideMaxPerWindow { get; set; } = 2;

    [Range(1, 3600)]
    public int WindowSeconds { get; set; } = 10;

    [Range(1, 1000)]
    public int MaxFriends { get; set; } = 100;
}

/// <summary>Chat-Regeln [DESIGN] (GDD 19), reine Funktionen ohne Datenbank.</summary>
public static class ChatRules
{
    /// <summary>Kanäle, die Spieler beschreiben dürfen; SYSTEM nur Admins, COMBAT nur Server, GUILD/PARTY folgen mit Gilden/Gruppen.</summary>
    public static readonly IReadOnlySet<string> PlayerChannels = new HashSet<string> { "LOCAL", "WORLD", "TRADE", "WHISPER" };

    /// <summary>Kanäle, die über alle Zonen-Server gehen (strengeres Rate-Limit).</summary>
    public static bool IsWide(string channel) => channel is "WORLD" or "TRADE";

    /// <summary>
    /// Steuerzeichen entfernen, Leerraum zusammenfassen, trimmen. Null, wenn danach leer oder länger als MaxLength (es wird
    /// abgelehnt, nicht gekürzt, damit niemand halbe Sätze verschickt).
    /// </summary>
    public static string? Sanitize(string? message, int maxLength)
    {
        if (message is null)
        {
            return null;
        }
        var sb = new StringBuilder(message.Length);
        var space = false;
        foreach (var c in message)
        {
            if (char.IsWhiteSpace(c))
            {
                space = sb.Length > 0;
                continue;
            }
            if (char.IsControl(c) || char.GetUnicodeCategory(c) is System.Globalization.UnicodeCategory.Format)
            {
                continue; // u. a. Zeichen für Schreibrichtung und unsichtbare Trenner
            }
            if (space)
            {
                sb.Append(' ');
                space = false;
            }
            sb.Append(c);
        }
        return sb.Length == 0 || sb.Length > maxLength ? null : sb.ToString();
    }

    /// <summary>Darf jetzt noch eine Nachricht raus? Recent: Sendezeiten im Kanal (beliebige Reihenfolge).</summary>
    public static bool WithinRate(IEnumerable<DateTime> recent, DateTime now, int maxPerWindow, TimeSpan window) =>
        recent.Count(t => now - t < window) < maxPerWindow;
}
