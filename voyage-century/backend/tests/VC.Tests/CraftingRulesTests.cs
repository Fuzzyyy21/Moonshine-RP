using VC.GameData;

namespace VC.Tests;

/// <summary>Herstell- und Sammelregeln (ohne Datenbank).</summary>
public sealed class CraftingRulesTests
{
    [Fact]
    public void Missing_lists_shortfalls_for_all_runs_and_merges_duplicate_lines()
    {
        var recipe = new[] { new MaterialNeed(1, 3), new MaterialNeed(2, 1), new MaterialNeed(1, 1) };
        var have = new Dictionary<int, int> { [1] = 7, [2] = 5 };
        Assert.Empty(CraftingRules.Missing(recipe, 1, have));
        Assert.Equal([new MaterialNeed(1, 1)], CraftingRules.Missing(recipe, 2, have)); // 8 nötig, 7 da
        Assert.Equal([new MaterialNeed(1, 8), new MaterialNeed(2, 1)], CraftingRules.Missing(recipe, 2, new Dictionary<int, int> { [2] = 1 }));
    }

    [Fact]
    public void Consume_takes_smallest_stacks_first_and_reports_shortage()
    {
        var slots = new List<InventorySlot> { new(0, 100, 7, 50), new(1, 101, 7, 5), new(2, 102, 9, 3), new(3, 103, 7, 5) };
        Assert.Equal([(103L, 0), (101L, 0), (100L, 48)], CraftingRules.PlanConsume(slots, 7, 12));
        Assert.Equal([(103L, 2)], CraftingRules.PlanConsume(slots, 7, 3));
        Assert.Null(CraftingRules.PlanConsume(slots, 7, 61));
        Assert.Null(CraftingRules.PlanConsume(slots, 8, 1));
        Assert.Empty(CraftingRules.PlanConsume(slots, 8, 0)!);
    }

    [Fact]
    public void Yield_stays_within_bounds()
    {
        var rng = new Random(3);
        for (var i = 0; i < 500; i++)
        {
            Assert.InRange(CraftingRules.RollYield(1, 3, rng), 1, 3);
        }
        Assert.Equal(2, CraftingRules.RollYield(2, 2, rng));
        Assert.Equal(0, CraftingRules.RollYield(0, 2, rng));
        Assert.Equal(0, CraftingRules.RollYield(3, 2, rng));
    }
}
