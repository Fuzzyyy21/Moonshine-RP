using System.Security.Cryptography;
using System.Text;

namespace VC.GameData;

/// <summary>Auktionshaus-Parameter (game_rules AUCTION_*). Im Original UNKNOWN; GDD 13: Einstellgebühr und Verkaufssteuer.</summary>
public sealed record AuctionTuning(int FeePermille, long MinFee, int TaxPermille, int DurationHours, int MaxListings);

/// <summary>Geldflüsse eines Verkaufs: Käufer zahlt Price, Verkäufer erhält Proceeds, Tax verlässt das Spiel.</summary>
public sealed record AuctionSale(long Price, long Tax, long Proceeds);

/// <summary>Auktionshaus [DESIGN], reine Funktionen ohne Datenbank.</summary>
public static class AuctionRules
{
    public const long MaxPrice = 1_000_000_000;

    /// <summary>Einstellgebühr: Anteil des Preises, aufgerundet, mindestens MinFee. Wird beim Einstellen fällig und nie erstattet.</summary>
    public static long ListingFee(long price, AuctionTuning t) =>
        Math.Max(t.MinFee, (price * t.FeePermille + 999) / 1000);

    /// <summary>Verkaufssteuer abgerundet (zugunsten des Verkäufers); der Verkäufer bekommt immer mindestens 0.</summary>
    public static AuctionSale Sale(long price, AuctionTuning t)
    {
        var tax = Math.Min(price, price * t.TaxPermille / 1000);
        return new AuctionSale(price, tax, price - tax);
    }

    public static bool IsValidPrice(long price) => price is >= 1 and <= MaxPrice;

    public static bool IsValidTuning(AuctionTuning t) =>
        t.FeePermille is >= 0 and <= 1000 && t.MinFee >= 0 && t.TaxPermille is >= 0 and <= 1000 && t.DurationHours > 0 && t.MaxListings > 0;

    /// <summary>
    /// Leitet aus einem Auftragsschlüssel weitere stabile Schlüssel ab (z. B. für die Ledger-Zeilen von Steuer und Verkäufer), damit
    /// ein Retry dieselben Buchungen trifft und der UNIQUE-Schlüssel im Ledger hält.
    /// </summary>
    public static Guid DeriveKey(Guid key, string purpose)
    {
        Span<byte> hash = stackalloc byte[32];
        SHA256.HashData(Encoding.UTF8.GetBytes($"{key:D}/{purpose}"), hash);
        return new Guid(hash[..16]);
    }
}
