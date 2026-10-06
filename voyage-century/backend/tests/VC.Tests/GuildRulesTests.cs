using VC.GameData;

namespace VC.Tests;

/// <summary>Gildenregeln (ohne Datenbank).</summary>
public sealed class GuildRulesTests
{
    private static readonly GuildRank Leader = new(0, "Gildenleiter", new HashSet<string>());
    private static readonly GuildRank Officer = new(1, "Gildenoffizier", new HashSet<string> { GuildRules.Invite, GuildRules.Kick, GuildRules.Promote });
    private static readonly GuildRank Member = new(2, "Mitglied", new HashSet<string>());

    [Fact]
    public void Names_tags_and_banners_are_validated()
    {
        Assert.True(GuildRules.IsValidName("Die Seefahrer"));
        Assert.True(GuildRules.IsValidName("航海者"));
        Assert.False(GuildRules.IsValidName("ab"));
        Assert.False(GuildRules.IsValidName(" Seefahrer"));
        Assert.False(GuildRules.IsValidName("See  fahrer"));
        Assert.False(GuildRules.IsValidName("Piraten!"));
        Assert.False(GuildRules.IsValidName(new string('a', 21)));
        Assert.True(GuildRules.IsValidTag(null));
        Assert.True(GuildRules.IsValidTag("SEE"));
        Assert.False(GuildRules.IsValidTag("see"));
        Assert.False(GuildRules.IsValidTag("ABCDE"));
        Assert.True(GuildRules.IsValidBanner(0, 15, 3));
        Assert.False(GuildRules.IsValidBanner(16, 0, 0));
        Assert.False(GuildRules.IsValidBanner(0, -1, 0));
    }

    [Fact]
    public void Leader_has_every_right_members_none()
    {
        Assert.True(GuildRules.Has(Leader, GuildRules.Kick));
        Assert.True(GuildRules.Has(Officer, GuildRules.Invite));
        Assert.False(GuildRules.Has(Member, GuildRules.Invite));
    }

    [Fact]
    public void Kicking_works_only_downwards()
    {
        Assert.True(GuildRules.CanKick(Officer, 2, self: false));
        Assert.False(GuildRules.CanKick(Officer, 1, self: false));  // gleicher Rang
        Assert.False(GuildRules.CanKick(Officer, 0, self: false));  // Leiter
        Assert.False(GuildRules.CanKick(Member, 2, self: false));   // kein Recht
        Assert.False(GuildRules.CanKick(Leader, 0, self: true));
    }

    [Fact]
    public void Ranks_change_only_below_the_own_rank_and_leadership_only_by_the_leader()
    {
        Assert.True(GuildRules.CanSetRank(Leader, 2, 1, self: false));    // befördern zum Offizier
        Assert.True(GuildRules.CanSetRank(Leader, 1, 0, self: false));    // Leitung übergeben
        Assert.False(GuildRules.CanSetRank(Officer, 2, 1, self: false));  // nicht auf den eigenen Rang
        Assert.True(GuildRules.CanSetRank(Officer with { RankNo = 1 }, 3, 2, self: false));
        Assert.False(GuildRules.CanSetRank(Officer, 2, 0, self: false));  // nur der Leiter gibt die Leitung ab
        Assert.False(GuildRules.CanSetRank(Leader, 2, 2, self: false));   // keine Änderung
        Assert.False(GuildRules.CanSetRank(Leader, 0, 1, self: true));
    }
}
