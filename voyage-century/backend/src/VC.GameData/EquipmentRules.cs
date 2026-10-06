namespace VC.GameData;

/// <summary>Zusatzwerte aus Ausrüstung. Schlüssel wie in items.base_stats und item_sets.bonuses (maxHealth, attackPower, defense).</summary>
public sealed record StatBonus(int MaxHealth, int AttackPower, int Defense)
{
    public static readonly StatBonus Zero = new(0, 0, 0);

    public static StatBonus operator +(StatBonus a, StatBonus b) =>
        new(a.MaxHealth + b.MaxHealth, a.AttackPower + b.AttackPower, a.Defense + b.Defense);
}

/// <summary>Setbonus ab einer Anzahl getragener Teile.</summary>
public sealed record SetBonusTier(int Pieces, StatBonus Bonus);

/// <summary>Ein ausgerüstetes Teil: Platz, Set (oder keins) und eigene Werte.</summary>
public sealed record EquippedPiece(string Slot, string? SetCode, StatBonus Stats);

/// <summary>Getragenes Set: Teile und Zahl der erreichten Bonusstufen.</summary>
public sealed record ActiveSet(string Code, int Pieces, int ActiveTiers);

/// <summary>
/// Ausrüstung [DESIGN]. Belegt sind Ausrüstungssets mit Stufe (SET-KING-148 … SET-TALOS-168) und dass sie per Synthese entstehen
/// (SYS-EQUIP-SYNTHESIS); Plätze, Werte und Setboni des Originals sind UNKNOWN. Hier: Waffen in WEAPON, Rüstung und Schmuck im
/// Platz aus items.equip_slot; die Stufenanforderung gilt gegen die Charakterstufe; Setboni sind gestaffelt und addieren sich
/// (alle Stufen bis zur getragenen Teilezahl).
/// </summary>
public static class EquipmentRules
{
    public const string WeaponSlot = "WEAPON";

    /// <summary>Platz, in den das Item gehört, oder null, wenn es nicht ausrüstbar ist.</summary>
    public static string? SlotFor(string itemType, string? equipSlot) => itemType switch
    {
        "WEAPON" => WeaponSlot,
        "ARMOR" or "ACCESSORY" when !string.IsNullOrEmpty(equipSlot) && equipSlot != WeaponSlot => equipSlot,
        _ => null,
    };

    /// <summary>Ohne Anforderung (NULL) darf jede Stufe das Teil tragen.</summary>
    public static bool MeetsLevel(int characterLevel, int? levelReq) => levelReq is not { } req || characterLevel >= req;

    public static (StatBonus Total, List<ActiveSet> Sets) Evaluate(
        IEnumerable<EquippedPiece> pieces, IReadOnlyDictionary<string, IReadOnlyList<SetBonusTier>> sets)
    {
        var list = pieces.ToList();
        var total = list.Aggregate(StatBonus.Zero, (sum, p) => sum + p.Stats);
        var active = new List<ActiveSet>();
        foreach (var group in list.Where(p => p.SetCode is not null).GroupBy(p => p.SetCode!).OrderBy(g => g.Key, StringComparer.Ordinal))
        {
            var count = group.Select(p => p.Slot).Distinct().Count();
            var tiers = sets.TryGetValue(group.Key, out var t) ? t.Where(x => x.Pieces <= count).ToList() : [];
            total = tiers.Aggregate(total, (sum, x) => sum + x.Bonus);
            active.Add(new ActiveSet(group.Key, count, tiers.Count));
        }
        return (total, active);
    }

    /// <summary>Stufen aufsteigend, je Teilezahl höchstens eine, mindestens 2 Teile (ein Teil allein ist kein Set).</summary>
    public static bool IsValidSet(IReadOnlyList<SetBonusTier> tiers) =>
        tiers.Count > 0 && tiers.All(t => t.Pieces >= 2)
        && tiers.Zip(tiers.Skip(1)).All(p => p.First.Pieces < p.Second.Pieces);
}
