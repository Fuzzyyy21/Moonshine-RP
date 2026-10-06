namespace VC.GameData;

/// <summary>Kosten und Wirkung von Sockeln und Verfeinern (game_rules SOCKET_* / REFINE_*). Im Original UNKNOWN.</summary>
public sealed record UpgradeTuning(long DrillGoldBase, long RefineGoldPerLevel, int RefineMax, int RefineWeaponAttack, int RefineArmorDefense);

public enum DrillCheck
{
    Ok,
    NoSockets,
    Full,
}

public enum SocketCheck
{
    Ok,
    NotAGem,
    NoFreeSocket,
    SameAttribute,
}

public enum RefineCheck
{
    Ok,
    MaxReached,
    WrongStoneTier,
    GemTooLow,
}

/// <summary>
/// Sockeln und Verfeinern.
/// Sockeln (SYS-SOCKETING, LIKELY): Sockel werden gebohrt (höchstens items.socket_max, beobachtet 3); jeder Sockel nimmt einen
/// Edelstein, der genau ein Attribut gibt; zwei Sockel brauchen verschiedene Steine – hier gelesen als verschiedene Attribute.
/// Verfeinern (SYS-REFINEMENT, UNCERTAIN): Verfeinerungsstein mit Stufe = bisherige Verfeinerungen + 1 und ein Edelstein, der
/// höherstufig ist als der zuletzt verwendete; beide werden verbraucht.
/// [DESIGN]: Bohrkosten steigen je Sockel, Verfeinern kostet Gold je Stufe, kein Fehlschlag (Erfolgsrate UNKNOWN), Höchststufe
/// aus den Daten; Wirkung je Stufe: Waffe +Angriff, sonst +Verteidigung. Edelsteine bleiben im Sockel (Entfernen UNKNOWN).
/// </summary>
public static class ItemUpgradeRules
{
    public static DrillCheck CanDrill(int drilled, int? socketMax) =>
        socketMax is not { } max || max <= 0 ? DrillCheck.NoSockets : drilled >= max ? DrillCheck.Full : DrillCheck.Ok;

    /// <summary>Erster Sockel kostet die Grundgebühr, jeder weitere ein Vielfaches (2., 3. …).</summary>
    public static long DrillCost(int drilled, UpgradeTuning t) => t.DrillGoldBase * (drilled + 1);

    /// <summary>Das eine Attribut eines Edelsteins, oder null, wenn er keins oder mehrere gibt.</summary>
    public static string? AttributeOf(StatBonus gem)
    {
        var set = new List<string>();
        if (gem.MaxHealth != 0) set.Add("maxHealth");
        if (gem.AttackPower != 0) set.Add("attackPower");
        if (gem.Defense != 0) set.Add("defense");
        return set.Count == 1 ? set[0] : null;
    }

    /// <summary>sockets: Attribut des Steins je gebohrtem Sockel, null = leer.</summary>
    public static SocketCheck CanSocket(IReadOnlyList<string?> sockets, StatBonus gem)
    {
        var attribute = AttributeOf(gem);
        if (attribute is null)
        {
            return SocketCheck.NotAGem;
        }
        if (!sockets.Contains(null))
        {
            return SocketCheck.NoFreeSocket;
        }
        return sockets.Contains(attribute) ? SocketCheck.SameAttribute : SocketCheck.Ok;
    }

    public static RefineCheck CanRefine(int level, int stoneTier, int gemTier, int lastGemTier, UpgradeTuning t) =>
        level >= t.RefineMax ? RefineCheck.MaxReached
        : stoneTier != level + 1 ? RefineCheck.WrongStoneTier
        : gemTier <= lastGemTier ? RefineCheck.GemTooLow
        : RefineCheck.Ok;

    /// <summary>Gebühr für den Schritt auf Stufe level + 1.</summary>
    public static long RefineCost(int level, UpgradeTuning t) => t.RefineGoldPerLevel * (level + 1);

    public static StatBonus RefineBonus(bool weapon, int level, UpgradeTuning t) =>
        weapon ? new StatBonus(0, t.RefineWeaponAttack * level, 0) : new StatBonus(0, 0, t.RefineArmorDefense * level);

    /// <summary>Werte eines getragenen Teils: eigene Werte, Edelsteine und Verfeinerung.</summary>
    public static StatBonus PieceStats(StatBonus own, IEnumerable<StatBonus> gems, bool weapon, int refinement, UpgradeTuning t) =>
        gems.Aggregate(own, (sum, g) => sum + g) + RefineBonus(weapon, refinement, t);

    public static bool IsValidTuning(UpgradeTuning t) =>
        t.DrillGoldBase >= 0 && t.RefineGoldPerLevel >= 0 && t.RefineMax >= 0 && t.RefineWeaponAttack >= 0 && t.RefineArmorDefense >= 0;
}
