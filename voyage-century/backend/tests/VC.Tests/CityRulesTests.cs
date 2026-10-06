using VC.GameData;

namespace VC.Tests;

/// <summary>Stadtbesitz-Regeln und Steueranteil im Handelspreis (ohne Datenbank).</summary>
public sealed class CityRulesTests
{
    private static readonly CityTuning Tuning = new(TaxSharePermille: 500, TaxMinPermille: 0, TaxMaxPermille: 150);
    private static readonly TradeTuning Trade = new(Elasticity: 0.7, MinFactor: 0.4, MaxFactor: 2.5, Spread: 0.1);

    [Fact]
    public void Quotes_report_the_tax_they_contain()
    {
        var buy = TradePricing.QuoteBuy(100, 500, 500, 0.05, 10, Trade)!;
        var buyFree = TradePricing.QuoteBuy(100, 500, 500, 0, 10, Trade)!;
        Assert.Equal(buy.Total - buyFree.Total, buy.Tax);
        Assert.True(buy.Tax > 0);
        var sell = TradePricing.QuoteSell(100, 500, 500, 0.05, 10, Trade)!;
        var sellFree = TradePricing.QuoteSell(100, 500, 500, 0, 10, Trade)!;
        Assert.Equal(sellFree.Total - sell.Total, sell.Tax);
        Assert.Equal(0, TradePricing.QuoteBuy(100, 500, 500, 0, 10, Trade)!.Tax);
    }

    [Fact]
    public void Owner_gets_a_rounded_down_share_of_the_tax()
    {
        Assert.Equal(50, CityRules.OwnerShare(100, Tuning));
        Assert.Equal(0, CityRules.OwnerShare(1, Tuning));
        Assert.Equal(0, CityRules.OwnerShare(-5, Tuning));
        Assert.Equal(7, CityRules.OwnerShare(7, Tuning with { TaxSharePermille = 1000 }));
    }

    [Fact]
    public void Owners_set_the_tax_rate_within_bounds_and_it_replaces_the_market_rate()
    {
        Assert.True(CityRules.IsValidTaxRate(0, Tuning));
        Assert.True(CityRules.IsValidTaxRate(150, Tuning));
        Assert.False(CityRules.IsValidTaxRate(151, Tuning));
        Assert.Equal(0.05, CityRules.EffectiveTaxRate(0.05, null));
        Assert.Equal(0.12, CityRules.EffectiveTaxRate(0.05, 120), 6);
        Assert.False(CityRules.IsValidTuning(Tuning with { TaxMinPermille = 200 }));
    }
}
