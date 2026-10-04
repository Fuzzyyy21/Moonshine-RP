namespace VC.GameData;

/// <summary>Benötigte Menge eines Materials.</summary>
public sealed record MaterialNeed(int ItemId, int Quantity);

/// <summary>
/// Herstellen und Sammeln [DESIGN], reine Funktionen ohne Datenbank. Belegt sind nur die Berufs-Skills (Sammeln: Bergbau, Holz,
/// Landwirtschaft, Fischen; Herstellen: Schmieden, Schneiderei, Alchemie, Schiffbau) und dass Sets aus Synthese-Materialien
/// entstehen; Rezepte, Mengen, Orte und Zeiten sind UNKNOWN und kommen als Daten herein.
/// </summary>
public static class CraftingRules
{
    /// <summary>Was für Times Durchläufe fehlt (leer = alles da). Gleiche Items in mehreren Zeilen werden zusammengezählt.</summary>
    public static List<MaterialNeed> Missing(IEnumerable<MaterialNeed> recipe, int times, IReadOnlyDictionary<int, int> have)
    {
        return recipe
            .GroupBy(n => n.ItemId)
            .Select(g => new MaterialNeed(g.Key, checked(g.Sum(n => n.Quantity) * times) - have.GetValueOrDefault(g.Key)))
            .Where(n => n.Quantity > 0)
            .OrderBy(n => n.ItemId)
            .ToList();
    }

    /// <summary>
    /// Welche Stapel wie weit abgebaut werden: kleinste Stapel zuerst (das gibt am ehesten Plätze frei), bei Gleichstand der
    /// höhere Platz. Neue Menge 0 = Stapel löschen. Null, wenn nicht genug da ist.
    /// </summary>
    public static List<(long InstanceId, int NewQuantity)>? PlanConsume(IEnumerable<InventorySlot> slots, int itemId, int quantity)
    {
        var plan = new List<(long, int)>();
        var left = quantity;
        foreach (var s in slots.Where(s => s.ItemId == itemId).OrderBy(s => s.Quantity).ThenByDescending(s => s.Slot))
        {
            if (left == 0)
            {
                break;
            }
            var take = Math.Min(left, s.Quantity);
            plan.Add((s.InstanceId, s.Quantity - take));
            left -= take;
        }
        return left == 0 ? plan : null;
    }

    /// <summary>Ausbeute eines Sammelpunkts, gleichverteilt zwischen Min und Max (Bonus durch Skillstufe UNKNOWN, daher keiner).</summary>
    public static int RollYield(int min, int max, Random rng) => min < 1 || max < min ? 0 : rng.Next(min, max + 1);
}
