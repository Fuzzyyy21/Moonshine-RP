using VC.GameData;

namespace VC.Tests;

/// <summary>Ausrüstungsregeln (ohne Datenbank).</summary>
public sealed class EquipmentRulesTests
{
    private static readonly Dictionary<string, IReadOnlyList<SetBonusTier>> Sets = new()
    {
        ["SET_A"] = [new(2, new StatBonus(0, 0, 5)), new(4, new StatBonus(50, 5, 0))],
    };

    [Fact]
    public void Weapons_go_to_the_weapon_slot_armor_to_its_own()
    {
        Assert.Equal("WEAPON", EquipmentRules.SlotFor("WEAPON", null));
        Assert.Equal("HEAD", EquipmentRules.SlotFor("ARMOR", "HEAD"));
        Assert.Equal("RING", EquipmentRules.SlotFor("ACCESSORY", "RING"));
        Assert.Null(EquipmentRules.SlotFor("ARMOR", null));
        Assert.Null(EquipmentRules.SlotFor("ARMOR", "WEAPON")); // Rüstung belegt nie den Waffenplatz
        Assert.Null(EquipmentRules.SlotFor("MATERIAL", "HEAD"));
    }

    [Fact]
    public void Level_requirement_is_checked_against_the_character_level()
    {
        Assert.True(EquipmentRules.MeetsLevel(1, null));
        Assert.True(EquipmentRules.MeetsLevel(160, 160));
        Assert.False(EquipmentRules.MeetsLevel(159, 160));
    }

    [Fact]
    public void Set_bonuses_stack_by_worn_pieces()
    {
        StatBonus Piece(int def) => new(0, 0, def);
        var one = EquipmentRules.Evaluate([new("HEAD", "SET_A", Piece(2))], Sets);
        Assert.Equal(new StatBonus(0, 0, 2), one.Total);
        Assert.Equal(new ActiveSet("SET_A", 1, 0), Assert.Single(one.Sets));

        var three = EquipmentRules.Evaluate(
            [new("HEAD", "SET_A", Piece(2)), new("BODY", "SET_A", Piece(4)), new("FEET", "SET_A", Piece(1)), new("WEAPON", null, StatBonus.Zero)],
            Sets);
        Assert.Equal(new StatBonus(0, 0, 12), three.Total);
        Assert.Equal(new ActiveSet("SET_A", 3, 1), Assert.Single(three.Sets));

        var four = EquipmentRules.Evaluate(
            [new("HEAD", "SET_A", Piece(2)), new("BODY", "SET_A", Piece(4)), new("FEET", "SET_A", Piece(1)), new("HANDS", "SET_A", Piece(1))],
            Sets);
        Assert.Equal(new StatBonus(50, 5, 13), four.Total);
        Assert.Equal(2, four.Sets[0].ActiveTiers);

        // Unbekanntes Set: Teile zählen, aber kein Bonus.
        var unknown = EquipmentRules.Evaluate([new("HEAD", "SET_X", Piece(1)), new("BODY", "SET_X", Piece(1))], Sets);
        Assert.Equal(new StatBonus(0, 0, 2), unknown.Total);
        Assert.Equal(0, unknown.Sets[0].ActiveTiers);
    }

    [Fact]
    public void Set_tiers_must_be_ascending_and_need_two_pieces()
    {
        Assert.True(EquipmentRules.IsValidSet(Sets["SET_A"]));
        Assert.False(EquipmentRules.IsValidSet([]));
        Assert.False(EquipmentRules.IsValidSet([new(1, StatBonus.Zero)]));
        Assert.False(EquipmentRules.IsValidSet([new(3, StatBonus.Zero), new(2, StatBonus.Zero)]));
        Assert.False(EquipmentRules.IsValidSet([new(2, StatBonus.Zero), new(2, StatBonus.Zero)]));
    }
}
