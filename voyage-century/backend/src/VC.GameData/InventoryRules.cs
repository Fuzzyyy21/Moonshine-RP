namespace VC.GameData;

/// <summary>Ein belegter Inventarplatz (Platz 0 … Kapazität−1).</summary>
public sealed record InventorySlot(int Slot, long InstanceId, int ItemId, int Quantity);

/// <summary>Plan für das Hinzufügen: vorhandene Stapel auffüllen, neue Stapel auf freie Plätze, Rest passt nicht.</summary>
public sealed record AddPlan(List<(long InstanceId, int NewQuantity)> TopUps, List<(int Slot, int Quantity)> NewStacks, int Overflow)
{
    public int Placed(int requested) => requested - Overflow;
}

/// <summary>Ein Eintrag einer Beutetabelle. Chance null = UNKNOWN → fällt nie (nie Ersatzwerte).</summary>
public sealed record LootEntry(int ItemId, double? Chance, int MinQuantity, int MaxQuantity);

/// <summary>
/// Inventar und Beute [DESIGN], reine Funktionen ohne Datenbank. Größe des Inventars, Stapelgrößen, Beutetabellen und
/// Goldbeute des Originals sind UNKNOWN; die Zahlen kommen als Daten herein.
/// </summary>
public static class InventoryRules
{
    /// <summary>
    /// Stapelbare Items füllen zuerst vorhandene Stapel derselben Sorte (niedrigster Platz zuerst), dann freie Plätze
    /// (niedrigster zuerst); nicht stapelbare brauchen je Stück einen Platz. Was nicht passt, ist Überlauf.
    /// </summary>
    public static AddPlan PlanAdd(IReadOnlyCollection<InventorySlot> current, int itemId, int quantity, bool stackable, int maxStack,
        int capacity)
    {
        var topUps = new List<(long, int)>();
        var newStacks = new List<(int, int)>();
        var left = Math.Max(0, quantity);
        var stackSize = stackable ? Math.Max(1, maxStack) : 1;
        if (stackable)
        {
            foreach (var s in current.Where(s => s.ItemId == itemId && s.Quantity < stackSize).OrderBy(s => s.Slot))
            {
                if (left == 0)
                {
                    break;
                }
                var add = Math.Min(left, stackSize - s.Quantity);
                topUps.Add((s.InstanceId, s.Quantity + add));
                left -= add;
            }
        }
        var used = current.Select(s => s.Slot).ToHashSet();
        for (var slot = 0; slot < capacity && left > 0; slot++)
        {
            if (used.Contains(slot))
            {
                continue;
            }
            var add = Math.Min(left, stackSize);
            newStacks.Add((slot, add));
            left -= add;
        }
        return new AddPlan(topUps, newStacks, left);
    }

    /// <summary>Würfelt jeden Eintrag einzeln (unabhängig); Menge gleichverteilt zwischen Min und Max.</summary>
    public static List<(int ItemId, int Quantity)> RollLoot(IEnumerable<LootEntry> entries, Random rng)
    {
        var drops = new List<(int, int)>();
        foreach (var e in entries)
        {
            if (e.Chance is not { } chance || chance <= 0 || e.MinQuantity < 1 || e.MaxQuantity < e.MinQuantity)
            {
                continue;
            }
            if (rng.NextDouble() < chance)
            {
                drops.Add((e.ItemId, rng.Next(e.MinQuantity, e.MaxQuantity + 1)));
            }
        }
        return drops;
    }

    /// <summary>Goldbeute gleichverteilt; ohne Angabe (null) kein Gold.</summary>
    public static long RollGold(long? min, long? max, Random rng) =>
        min is { } lo && max is { } hi && lo >= 0 && hi >= lo ? rng.NextInt64(lo, hi + 1) : 0;
}
