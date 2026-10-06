namespace VC.GameData;

/// <summary>Belagerungs-Parameter (game_rules SIEGE_*). Zeitplan und Regeln des Originals UNKNOWN (SYS-CITY-SIEGE).</summary>
public sealed record SiegeTuning(long DeclareCost, int LeadHours, int DurationMinutes);

public enum SiegePhase
{
    Scheduled,
    Running,
    Finished,
}

public enum SiegeSide
{
    None,
    Attacker,
    Defender,
}

/// <summary>
/// Stadtbelagerung [DESIGN]. Belegt ist nur, dass es sie gibt und dass sie als Land-See-Kampf beworben wird (SYS-CITY-SIEGE).
/// Hier: Eine Gilde sagt die Belagerung einer fremden Stadt an; nach der Vorlaufzeit läuft sie eine feste Dauer, in der sich
/// Angreifer und Verteidiger in der Stadt und auf den angrenzenden Seezonen bekämpfen dürfen. Jeder Kill zählt einen Punkt; der
/// Angreifer gewinnt nur mit mehr Punkten, bei Gleichstand behält der Verteidiger die Stadt.
/// </summary>
public static class SiegeRules
{
    public static SiegePhase PhaseAt(DateTime now, DateTime startsAt, DateTime endsAt) =>
        now < startsAt ? SiegePhase.Scheduled : now < endsAt ? SiegePhase.Running : SiegePhase.Finished;

    /// <summary>Ansagen nur gegen eine Stadt, die einer anderen Gilde gehört (freie Städte kauft man) und ohne offene Belagerung.</summary>
    public static bool CanDeclare(long attackerGuildId, long? ownerGuildId, bool openSiegeExists) =>
        ownerGuildId is { } owner && owner != attackerGuildId && !openSiegeExists;

    public static bool AttackerWins(int attackerScore, int defenderScore) => attackerScore > defenderScore;

    /// <summary>Zählt der Kill für die Belagerung, und für welche Seite? Nur Kills zwischen den beiden Gilden.</summary>
    public static SiegeSide ScoringSide(long? killerGuild, long? victimGuild, long attackerGuild, long defenderGuild) =>
        killerGuild == attackerGuild && victimGuild == defenderGuild ? SiegeSide.Attacker
        : killerGuild == defenderGuild && victimGuild == attackerGuild ? SiegeSide.Defender
        : SiegeSide.None;

    public static bool IsValidTuning(SiegeTuning t) => t.DeclareCost >= 0 && t.LeadHours >= 0 && t.DurationMinutes > 0;
}
