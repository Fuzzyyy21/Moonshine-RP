using VC.GameData;

namespace VC.Tests;

/// <summary>Haltbarkeitsregeln (ohne Datenbank).</summary>
public sealed class DurabilityRulesTests
{
    [Fact]
    public void Unused_items_are_full_and_items_without_maximum_never_wear()
    {
        Assert.Equal(100, DurabilityRules.Current(null, 100));
        Assert.Equal(40, DurabilityRules.Current(40, 100));
        Assert.Equal(100, DurabilityRules.Current(250, 100)); // nie über dem Maximum
        Assert.Null(DurabilityRules.Current(null, null));
        Assert.Null(DurabilityRules.Wear(null, null, 5));
        Assert.False(DurabilityRules.IsBroken(null, null));
    }

    [Fact]
    public void Wear_stops_at_zero_and_zero_means_broken()
    {
        Assert.Equal(99, DurabilityRules.Wear(null, 100, 1));
        Assert.Equal(0, DurabilityRules.Wear(3, 100, 5));
        Assert.Equal(50, DurabilityRules.Wear(50, 100, -4)); // negativer Verlust zählt nicht
        Assert.True(DurabilityRules.IsBroken(0, 100));
        Assert.False(DurabilityRules.IsBroken(1, 100));
    }

    [Fact]
    public void Death_costs_a_share_of_the_maximum_rounded_up()
    {
        Assert.Equal(10, DurabilityRules.DeathLoss(100, 100));
        Assert.Equal(7, DurabilityRules.DeathLoss(61, 100)); // 6,1 → 7
        Assert.Equal(1, DurabilityRules.DeathLoss(5, 10));   // mindestens 1
        Assert.Equal(0, DurabilityRules.DeathLoss(100, 0));
    }

    [Fact]
    public void Repair_cost_scales_with_missing_points_and_rarity()
    {
        Assert.Equal(0L, DurabilityRules.RepairCost(null, 100, 1, 1000));
        Assert.Equal(30L, DurabilityRules.RepairCost(70, 100, 1, 1000));
        Assert.Equal(45L, DurabilityRules.RepairCost(70, 100, 1, 1500));
        Assert.Equal(2L, DurabilityRules.RepairCost(99, 100, 1, 1250)); // 1,25 → 2
        Assert.Equal(0L, DurabilityRules.RepairCost(5, null, 1, 1000));
        Assert.True(DurabilityRules.IsValidTuning(new DurabilityTuning(1, 100, 1)));
        Assert.False(DurabilityRules.IsValidTuning(new DurabilityTuning(1, 1001, 1)));
    }
}
