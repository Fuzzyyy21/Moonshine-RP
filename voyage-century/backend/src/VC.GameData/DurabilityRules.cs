namespace VC.GameData;

/// <summary>Abnutzung und Reparatur (game_rules WEAR_* / REPAIR_*). Im Original UNKNOWN.</summary>
public sealed record DurabilityTuning(int WeaponWearPerKill, int DeathWearPermille, long RepairGoldPerPoint);

/// <summary>
/// Haltbarkeit [DESIGN] (GDD 15: „Haltbarkeit sinkt durch Kampf, Reparatur kostet Gold“; Werte des Originals UNKNOWN).
/// Teile ohne items.durability_max nutzen sich nie ab. item_instances.durability NULL = unbenutzt (voll).
/// Ein Kill nutzt die getragene Waffe um einen festen Betrag ab, ein Tod jedes getragene Teil um einen Anteil seines Maximums
/// (mindestens 1). Bei 0 ist das Teil kaputt: es gibt keine Werte und zählt nicht zum Set, eine kaputte Waffe gilt als keine.
/// Reparatur stellt das Maximum wieder her und kostet Gold je fehlendem Punkt, gewichtet mit der Seltenheit (Promille).
/// </summary>
public static class DurabilityRules
{
    /// <summary>Aktuelle Haltbarkeit; null, wenn das Teil keine hat.</summary>
    public static int? Current(int? durability, int? max) => max is { } m ? Math.Clamp(durability ?? m, 0, m) : null;

    public static bool IsBroken(int? durability, int? max) => Current(durability, max) == 0;

    public static int? Wear(int? durability, int? max, int loss) =>
        Current(durability, max) is { } current ? Math.Max(0, current - Math.Max(0, loss)) : null;

    /// <summary>Verlust beim Tod: Anteil des Maximums, aufgerundet, mindestens 1 (0 ‰ = kein Verlust).</summary>
    public static int DeathLoss(int max, int permille) =>
        permille <= 0 || max <= 0 ? 0 : Math.Max(1, (int)Math.Ceiling(max * (double)permille / 1000));

    /// <summary>Kosten, um auf das Maximum zu kommen: fehlende Punkte × Gold je Punkt × Seltenheit (Promille), aufgerundet.</summary>
    public static long RepairCost(int? durability, int? max, long goldPerPoint, int rarityPermille)
    {
        if (Current(durability, max) is not { } current)
        {
            return 0;
        }
        var missing = max!.Value - current;
        return missing <= 0 ? 0 : (long)Math.Ceiling(missing * goldPerPoint * (double)Math.Max(0, rarityPermille) / 1000);
    }

    public static bool IsValidTuning(DurabilityTuning t) =>
        t.WeaponWearPerKill >= 0 && t.DeathWearPermille is >= 0 and <= 1000 && t.RepairGoldPerPoint >= 0;
}
