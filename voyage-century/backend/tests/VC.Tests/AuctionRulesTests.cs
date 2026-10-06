using VC.GameData;

namespace VC.Tests;

/// <summary>Auktionshaus-Regeln (ohne Datenbank).</summary>
public sealed class AuctionRulesTests
{
    private static readonly AuctionTuning Tuning = new(FeePermille: 20, MinFee: 1, TaxPermille: 50, DurationHours: 24, MaxListings: 10);

    [Fact]
    public void Listing_fee_is_a_rounded_up_share_with_a_minimum()
    {
        Assert.Equal(20, AuctionRules.ListingFee(1000, Tuning));
        Assert.Equal(3, AuctionRules.ListingFee(101, Tuning));  // 2,02 → 3
        Assert.Equal(1, AuctionRules.ListingFee(1, Tuning));    // Mindestgebühr
        Assert.Equal(0, AuctionRules.ListingFee(10, Tuning with { FeePermille = 0, MinFee = 0 }));
    }

    [Fact]
    public void Sale_splits_price_into_tax_and_proceeds()
    {
        Assert.Equal(new AuctionSale(1000, 50, 950), AuctionRules.Sale(1000, Tuning));
        Assert.Equal(new AuctionSale(19, 0, 19), AuctionRules.Sale(19, Tuning));      // 0,95 → 0 (abgerundet)
        Assert.Equal(new AuctionSale(10, 10, 0), AuctionRules.Sale(10, Tuning with { TaxPermille = 1000 }));
        var big = AuctionRules.Sale(AuctionRules.MaxPrice, Tuning);
        Assert.Equal(big.Price, big.Tax + big.Proceeds);
    }

    [Fact]
    public void Prices_and_tuning_are_bounded()
    {
        Assert.False(AuctionRules.IsValidPrice(0));
        Assert.True(AuctionRules.IsValidPrice(1));
        Assert.False(AuctionRules.IsValidPrice(AuctionRules.MaxPrice + 1));
        Assert.True(AuctionRules.IsValidTuning(Tuning));
        Assert.False(AuctionRules.IsValidTuning(Tuning with { TaxPermille = 1001 }));
        Assert.False(AuctionRules.IsValidTuning(Tuning with { DurationHours = 0 }));
    }

    [Fact]
    public void Derived_keys_are_stable_and_distinct()
    {
        var key = Guid.NewGuid();
        Assert.Equal(AuctionRules.DeriveKey(key, "tax"), AuctionRules.DeriveKey(key, "tax"));
        Assert.NotEqual(AuctionRules.DeriveKey(key, "tax"), AuctionRules.DeriveKey(key, "seller"));
        Assert.NotEqual(key, AuctionRules.DeriveKey(key, "tax"));
    }
}
