namespace VC.GameData;

/// <summary>Preismodell-Parameter (game_rules TRADE_*, Promille). Im Original ist das Preismodell UNKNOWN (SYS-TRADE).</summary>
public sealed record TradeTuning(double Elasticity, double MinFactor, double MaxFactor, double Spread);

/// <summary>Kurs einer Menge: Summe der Einzelpreise und der Bestand danach.</summary>
public sealed record TradeQuote(long Total, int StockAfter);

/// <summary>
/// Hafenpreise [DESIGN], reine Funktionen ohne Datenbank. Der Mittelpreis hängt am Verhältnis von Gleichgewichtsbestand zu
/// aktuellem Bestand: knappe Ware wird teurer, Überangebot billiger, begrenzt auf MinFactor … MaxFactor. Kaufen kostet Mittelpreis
/// plus halbe Spanne plus Steuer, Verkaufen bringt Mittelpreis minus halbe Spanne minus Steuer.
///
/// Jede Einheit wird zum Bestand <em>nach</em> ihrer Bewegung bewertet (Kauf: Bestand − 1, Verkauf: Bestand + 1). Damit bringt
/// Kaufen und sofortiges Zurückverkaufen im selben Hafen nie Gewinn – Gewinn gibt es nur über Preisunterschiede zwischen Häfen.
/// </summary>
public static class TradePricing
{
    /// <summary>Gleitkomma-Rest (105,00000000001) soll nicht auf die nächste Goldmünze runden.</summary>
    private const double Epsilon = 1e-9;

    public static double MidPrice(long basePrice, int stock, int targetStock, TradeTuning t)
    {
        var ratio = (double)Math.Max(targetStock, 1) / Math.Max(stock, 1);
        return basePrice * Math.Clamp(Math.Pow(ratio, t.Elasticity), t.MinFactor, t.MaxFactor);
    }

    /// <summary>Preis einer gekauften Einheit, mindestens 1.</summary>
    public static long BuyUnit(long basePrice, int stockAfter, int targetStock, double taxRate, TradeTuning t) =>
        Math.Max(1, (long)Math.Ceiling(MidPrice(basePrice, stockAfter, targetStock, t) * (1 + t.Spread / 2) * (1 + taxRate) - Epsilon));

    /// <summary>Erlös einer verkauften Einheit, mindestens 0.</summary>
    public static long SellUnit(long basePrice, int stockAfter, int targetStock, double taxRate, TradeTuning t) =>
        Math.Max(0, (long)Math.Floor(MidPrice(basePrice, stockAfter, targetStock, t) * (1 - t.Spread / 2) * (1 - taxRate) + Epsilon));

    /// <summary>Gesamtpreis für Quantity Einheiten aus dem Bestand; null, wenn der Bestand nicht reicht.</summary>
    public static TradeQuote? QuoteBuy(long basePrice, int stock, int targetStock, double taxRate, int quantity, TradeTuning t)
    {
        if (quantity < 1 || quantity > stock)
        {
            return null;
        }
        long total = 0;
        for (var i = 1; i <= quantity; i++)
        {
            total += BuyUnit(basePrice, stock - i, targetStock, taxRate, t);
        }
        return new TradeQuote(total, stock - quantity);
    }

    /// <summary>Gesamterlös für Quantity verkaufte Einheiten.</summary>
    public static TradeQuote? QuoteSell(long basePrice, int stock, int targetStock, double taxRate, int quantity, TradeTuning t)
    {
        if (quantity < 1 || stock > int.MaxValue - quantity)
        {
            return null;
        }
        long total = 0;
        for (var i = 1; i <= quantity; i++)
        {
            total += SellUnit(basePrice, stock + i, targetStock, taxRate, t);
        }
        return new TradeQuote(total, stock + quantity);
    }

    /// <summary>
    /// Bestand bewegt sich mit RatePerHour Einheiten je Stunde zum Gleichgewicht (Händler kaufen nach bzw. verkaufen weiter).
    /// Gibt den neuen Bestand und die verbrauchte Zeit zurück; Bruchteile bleiben für das nächste Mal stehen.
    /// </summary>
    public static (int Stock, TimeSpan Used) Restock(int stock, int targetStock, int ratePerHour, TimeSpan elapsed)
    {
        if (ratePerHour <= 0 || elapsed <= TimeSpan.Zero || stock == targetStock)
        {
            return (stock, stock == targetStock ? elapsed : TimeSpan.Zero);
        }
        var gap = Math.Abs(targetStock - stock);
        var steps = (long)Math.Floor(elapsed.TotalHours * ratePerHour);
        if (steps >= gap)
        {
            return (targetStock, elapsed); // Gleichgewicht erreicht: Restzeit verfällt
        }
        var moved = (int)steps;
        return (stock + (targetStock > stock ? moved : -moved), TimeSpan.FromHours((double)moved / ratePerHour));
    }
}
