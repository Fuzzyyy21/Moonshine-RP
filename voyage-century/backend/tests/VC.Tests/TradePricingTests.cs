using VC.GameData;

namespace VC.Tests;

/// <summary>Preisregeln des Hafenhandels (ohne Datenbank).</summary>
public sealed class TradePricingTests
{
    private static readonly TradeTuning Tuning = new(Elasticity: 0.7, MinFactor: 0.4, MaxFactor: 2.5, Spread: 0.1);

    [Fact]
    public void Mid_price_rises_when_scarce_and_falls_with_oversupply_within_bounds()
    {
        Assert.Equal(100.0, TradePricing.MidPrice(100, 500, 500, Tuning), 6);
        Assert.True(TradePricing.MidPrice(100, 250, 500, Tuning) > 100);
        Assert.True(TradePricing.MidPrice(100, 1000, 500, Tuning) < 100);
        Assert.Equal(250.0, TradePricing.MidPrice(100, 0, 500, Tuning), 6);       // leer: Obergrenze
        Assert.Equal(40.0, TradePricing.MidPrice(100, 1_000_000, 500, Tuning), 6); // Schwemme: Untergrenze
    }

    [Fact]
    public void Buy_costs_more_than_sell_brings_and_tax_widens_the_gap()
    {
        var buy = TradePricing.BuyUnit(100, 500, 500, 0, Tuning);
        var sell = TradePricing.SellUnit(100, 500, 500, 0, Tuning);
        Assert.Equal(105, buy);
        Assert.Equal(95, sell);
        Assert.Equal(111, TradePricing.BuyUnit(100, 500, 500, 0.05, Tuning));   // ceil(105 × 1,05)
        Assert.Equal(90, TradePricing.SellUnit(100, 500, 500, 0.05, Tuning));   // floor(95 × 0,95)
        Assert.True(TradePricing.BuyUnit(1, 1_000_000, 500, 0, Tuning) >= 1);
    }

    [Fact]
    public void Buying_moves_price_up_unit_by_unit_and_stops_at_stock()
    {
        var one = TradePricing.QuoteBuy(100, 500, 500, 0, 1, Tuning)!;
        var many = TradePricing.QuoteBuy(100, 500, 500, 0, 200, Tuning)!;
        Assert.Equal(499, one.StockAfter);
        Assert.Equal(300, many.StockAfter);
        Assert.True(many.Total > 200 * one.Total); // jede weitere Einheit ist teurer
        Assert.Null(TradePricing.QuoteBuy(100, 10, 500, 0, 11, Tuning));
        Assert.Null(TradePricing.QuoteBuy(100, 10, 500, 0, 0, Tuning));
        Assert.NotNull(TradePricing.QuoteBuy(100, 10, 500, 0, 10, Tuning));
    }

    [Theory]
    [InlineData(500, 1)]
    [InlineData(500, 100)]
    [InlineData(20, 20)]
    [InlineData(5000, 300)]
    public void Buying_and_selling_back_in_the_same_port_never_profits(int stock, int quantity)
    {
        var buy = TradePricing.QuoteBuy(100, stock, 500, 0, quantity, Tuning)!;
        var sell = TradePricing.QuoteSell(100, buy.StockAfter, 500, 0, quantity, Tuning)!;
        Assert.Equal(stock, sell.StockAfter);
        Assert.True(sell.Total < buy.Total, $"Kauf {buy.Total}, Rückverkauf {sell.Total}");
    }

    [Fact]
    public void Price_difference_between_ports_makes_a_route_profitable()
    {
        // Ware im Hafen A billig (Basis 40), in B teuer (Basis 90); beide im Gleichgewicht.
        var buy = TradePricing.QuoteBuy(40, 500, 500, 0.05, 50, Tuning)!;
        var sell = TradePricing.QuoteSell(90, 500, 500, 0.05, 50, Tuning)!;
        Assert.True(sell.Total > buy.Total);
    }

    [Fact]
    public void Stock_recovers_towards_equilibrium_over_time_and_keeps_fractions()
    {
        Assert.Equal((300, TimeSpan.FromHours(1)), TradePricing.Restock(200, 500, 100, TimeSpan.FromHours(1)));
        Assert.Equal((900, TimeSpan.FromHours(1)), TradePricing.Restock(1000, 500, 100, TimeSpan.FromHours(1)));
        Assert.Equal((500, TimeSpan.FromHours(10)), TradePricing.Restock(450, 500, 100, TimeSpan.FromHours(10)));
        // 30 min bei 100/h = 50 Einheiten; 20 s bei 100/h = 0 Einheiten, Zeit bleibt stehen.
        Assert.Equal(250, TradePricing.Restock(200, 500, 100, TimeSpan.FromMinutes(30)).Stock);
        Assert.Equal((200, TimeSpan.Zero), TradePricing.Restock(200, 500, 100, TimeSpan.FromSeconds(20)));
        Assert.Equal((200, TimeSpan.Zero), TradePricing.Restock(200, 500, 0, TimeSpan.FromHours(5)));
    }
}
