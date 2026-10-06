using VC.GameData;

namespace VC.Tests;

/// <summary>Sockel- und Verfeinerungsregeln (ohne Datenbank).</summary>
public sealed class ItemUpgradeRulesTests
{
    private static readonly UpgradeTuning T = new(DrillGoldBase: 50, RefineGoldPerLevel: 100, RefineMax: 3, RefineWeaponAttack: 3,
        RefineArmorDefense: 2);

    [Fact]
    public void Sockets_are_drilled_up_to_the_item_maximum_at_rising_cost()
    {
        Assert.Equal(DrillCheck.Ok, ItemUpgradeRules.CanDrill(0, 3));
        Assert.Equal(DrillCheck.Full, ItemUpgradeRules.CanDrill(3, 3));
        Assert.Equal(DrillCheck.NoSockets, ItemUpgradeRules.CanDrill(0, null));
        Assert.Equal(DrillCheck.NoSockets, ItemUpgradeRules.CanDrill(0, 0));
        Assert.Equal(50L, ItemUpgradeRules.DrillCost(0, T));
        Assert.Equal(150L, ItemUpgradeRules.DrillCost(2, T));
    }

    [Fact]
    public void Each_gem_gives_one_attribute_and_sockets_need_different_ones()
    {
        var attack = new StatBonus(0, 3, 0);
        Assert.Equal("attackPower", ItemUpgradeRules.AttributeOf(attack));
        Assert.Null(ItemUpgradeRules.AttributeOf(StatBonus.Zero));
        Assert.Null(ItemUpgradeRules.AttributeOf(new StatBonus(10, 3, 0)));

        Assert.Equal(SocketCheck.Ok, ItemUpgradeRules.CanSocket([null, null], attack));
        Assert.Equal(SocketCheck.SameAttribute, ItemUpgradeRules.CanSocket(["attackPower", null], attack));
        Assert.Equal(SocketCheck.Ok, ItemUpgradeRules.CanSocket(["defense", null], attack));
        Assert.Equal(SocketCheck.NoFreeSocket, ItemUpgradeRules.CanSocket(["defense"], attack));
        Assert.Equal(SocketCheck.NoFreeSocket, ItemUpgradeRules.CanSocket([], attack)); // erst bohren
        Assert.Equal(SocketCheck.NotAGem, ItemUpgradeRules.CanSocket([null], new StatBonus(10, 3, 0)));
    }

    [Fact]
    public void Refining_needs_the_next_stone_tier_and_a_higher_gem()
    {
        Assert.Equal(RefineCheck.Ok, ItemUpgradeRules.CanRefine(0, stoneTier: 1, gemTier: 1, lastGemTier: 0, T));
        Assert.Equal(RefineCheck.WrongStoneTier, ItemUpgradeRules.CanRefine(1, stoneTier: 1, gemTier: 2, lastGemTier: 1, T));
        Assert.Equal(RefineCheck.GemTooLow, ItemUpgradeRules.CanRefine(1, stoneTier: 2, gemTier: 1, lastGemTier: 1, T));
        Assert.Equal(RefineCheck.Ok, ItemUpgradeRules.CanRefine(1, stoneTier: 2, gemTier: 2, lastGemTier: 1, T));
        Assert.Equal(RefineCheck.MaxReached, ItemUpgradeRules.CanRefine(3, stoneTier: 4, gemTier: 9, lastGemTier: 3, T));
        Assert.Equal(300L, ItemUpgradeRules.RefineCost(2, T));
    }

    [Fact]
    public void Piece_stats_add_gems_and_refinement()
    {
        List<StatBonus> gems = [new(0, 3, 0), new(30, 0, 0)];
        Assert.Equal(new StatBonus(30, 9, 0), ItemUpgradeRules.PieceStats(StatBonus.Zero, gems, weapon: true, refinement: 2, T));
        Assert.Equal(new StatBonus(0, 0, 6), ItemUpgradeRules.PieceStats(new StatBonus(0, 0, 2), [], weapon: false, refinement: 2, T));
        Assert.True(ItemUpgradeRules.IsValidTuning(T));
        Assert.False(ItemUpgradeRules.IsValidTuning(T with { RefineMax = -1 }));
    }
}
