using VC.GameData;

namespace VC.Tests;

/// <summary>Inventar- und Beuteregeln (ohne Datenbank).</summary>
public sealed class InventoryRulesTests
{
    [Fact]
    public void Stackable_items_fill_existing_stacks_first_then_lowest_free_slots()
    {
        var current = new List<InventorySlot> { new(0, 100, 7, 95), new(1, 101, 9, 1), new(3, 102, 7, 50) };
        var plan = InventoryRules.PlanAdd(current, itemId: 7, quantity: 160, stackable: true, maxStack: 99, capacity: 5);
        Assert.Equal([(100L, 99), (102L, 99)], plan.TopUps);   // +4 und +49
        Assert.Equal([(2, 99), (4, 8)], plan.NewStacks);        // 160 − 53 = 107 → 99 + 8
        Assert.Equal(0, plan.Overflow);
        Assert.Equal(160, plan.Placed(160));
    }

    [Fact]
    public void Unstackable_items_take_one_slot_each_and_overflow_when_full()
    {
        var current = new List<InventorySlot> { new(0, 100, 3, 1), new(2, 101, 3, 1) };
        var plan = InventoryRules.PlanAdd(current, itemId: 3, quantity: 3, stackable: false, maxStack: 1, capacity: 3);
        Assert.Empty(plan.TopUps);
        Assert.Equal([(1, 1)], plan.NewStacks);
        Assert.Equal(2, plan.Overflow);
        Assert.Equal(1, plan.Placed(3));
    }

    [Fact]
    public void Full_inventory_still_tops_up_existing_stacks()
    {
        var current = new List<InventorySlot> { new(0, 100, 7, 10), new(1, 101, 8, 99) };
        var plan = InventoryRules.PlanAdd(current, itemId: 7, quantity: 100, stackable: true, maxStack: 99, capacity: 2);
        Assert.Equal([(100L, 99)], plan.TopUps);
        Assert.Empty(plan.NewStacks);
        Assert.Equal(11, plan.Overflow);
    }

    [Fact]
    public void Loot_drops_only_with_known_chance_and_respects_quantity_range()
    {
        var entries = new[]
        {
            new LootEntry(1, 1.0, 2, 4),     // fällt immer
            new LootEntry(2, null, 1, 1),    // UNKNOWN: nie
            new LootEntry(3, 0.0, 1, 1),     // nie
            new LootEntry(4, 0.5, 1, 1),
        };
        var rng = new Random(42);
        var item4 = 0;
        for (var i = 0; i < 2000; i++)
        {
            var drops = InventoryRules.RollLoot(entries, rng);
            var first = drops.Single(d => d.ItemId == 1);
            Assert.InRange(first.Quantity, 2, 4);
            Assert.DoesNotContain(drops, d => d.ItemId is 2 or 3);
            item4 += drops.Count(d => d.ItemId == 4);
        }
        Assert.InRange(item4, 900, 1100); // etwa die Hälfte
    }

    [Fact]
    public void Gold_drop_needs_both_bounds()
    {
        var rng = new Random(1);
        Assert.Equal(0, InventoryRules.RollGold(null, 10, rng));
        Assert.Equal(0, InventoryRules.RollGold(5, null, rng));
        Assert.Equal(0, InventoryRules.RollGold(10, 5, rng));
        for (var i = 0; i < 200; i++)
        {
            Assert.InRange(InventoryRules.RollGold(5, 20, rng), 5, 20);
        }
        Assert.Equal(7, InventoryRules.RollGold(7, 7, rng));
    }
}
