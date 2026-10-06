using VC.GameData;

namespace VC.Tests;

/// <summary>Belagerungsregeln (ohne Datenbank).</summary>
public sealed class SiegeRulesTests
{
    private static readonly DateTime Start = new(2026, 1, 1, 20, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void Phase_follows_the_clock()
    {
        var end = Start.AddMinutes(60);
        Assert.Equal(SiegePhase.Scheduled, SiegeRules.PhaseAt(Start.AddSeconds(-1), Start, end));
        Assert.Equal(SiegePhase.Running, SiegeRules.PhaseAt(Start, Start, end));
        Assert.Equal(SiegePhase.Running, SiegeRules.PhaseAt(end.AddSeconds(-1), Start, end));
        Assert.Equal(SiegePhase.Finished, SiegeRules.PhaseAt(end, Start, end));
    }

    [Fact]
    public void Only_cities_of_other_guilds_without_open_siege_can_be_besieged()
    {
        Assert.True(SiegeRules.CanDeclare(1, 2, openSiegeExists: false));
        Assert.False(SiegeRules.CanDeclare(1, 1, openSiegeExists: false));   // eigene Stadt
        Assert.False(SiegeRules.CanDeclare(1, null, openSiegeExists: false)); // frei: kaufen statt belagern
        Assert.False(SiegeRules.CanDeclare(1, 2, openSiegeExists: true));
    }

    [Fact]
    public void Defender_keeps_the_city_on_a_tie()
    {
        Assert.True(SiegeRules.AttackerWins(3, 2));
        Assert.False(SiegeRules.AttackerWins(2, 2));
        Assert.False(SiegeRules.AttackerWins(0, 0));
    }

    [Fact]
    public void Only_kills_between_the_two_guilds_score()
    {
        Assert.Equal(SiegeSide.Attacker, SiegeRules.ScoringSide(10, 20, 10, 20));
        Assert.Equal(SiegeSide.Defender, SiegeRules.ScoringSide(20, 10, 10, 20));
        Assert.Equal(SiegeSide.None, SiegeRules.ScoringSide(10, 10, 10, 20)); // eigene Leute
        Assert.Equal(SiegeSide.None, SiegeRules.ScoringSide(10, 30, 10, 20)); // Unbeteiligte
        Assert.Equal(SiegeSide.None, SiegeRules.ScoringSide(null, 20, 10, 20));
    }
}
