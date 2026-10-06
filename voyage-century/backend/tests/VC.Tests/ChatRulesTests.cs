using VC.GameData;

namespace VC.Tests;

/// <summary>Chat-Regeln (ohne Datenbank).</summary>
public sealed class ChatRulesTests
{
    [Fact]
    public void Sanitize_trims_collapses_whitespace_and_drops_control_characters()
    {
        Assert.Equal("Hallo Welt", ChatRules.Sanitize("  Hallo \t\n  Welt  ", 200));
        Assert.Equal("ab", ChatRules.Sanitize("a\u0000\u0007b", 200));
        Assert.Equal("ab", ChatRules.Sanitize("a‮b", 200));     // Schreibrichtung umkehren
        Assert.Equal("Grüße an alle", ChatRules.Sanitize("Grüße  an alle", 200));
    }

    [Fact]
    public void Sanitize_rejects_empty_and_too_long_messages()
    {
        Assert.Null(ChatRules.Sanitize(null, 200));
        Assert.Null(ChatRules.Sanitize("   \n ", 200));
        Assert.Null(ChatRules.Sanitize(new string('x', 201), 200));
        Assert.NotNull(ChatRules.Sanitize(new string('x', 200), 200));
        Assert.NotNull(ChatRules.Sanitize(new string('x', 200) + "   ", 200)); // Leerraum am Ende zählt nicht
    }

    [Fact]
    public void Rate_limit_counts_only_messages_inside_the_window()
    {
        var now = new DateTime(2026, 1, 1, 12, 0, 10, DateTimeKind.Utc);
        var window = TimeSpan.FromSeconds(10);
        var recent = new[] { now.AddSeconds(-1), now.AddSeconds(-5) };
        Assert.True(ChatRules.WithinRate(recent, now, 3, window));
        Assert.False(ChatRules.WithinRate(recent, now, 2, window));
        Assert.True(ChatRules.WithinRate([now.AddSeconds(-10), now.AddSeconds(-11)], now, 1, window)); // genau 10 s = draußen
    }

    [Fact]
    public void Players_may_use_only_their_channels()
    {
        Assert.Contains("WHISPER", ChatRules.PlayerChannels);
        Assert.DoesNotContain("SYSTEM", ChatRules.PlayerChannels);
        Assert.True(ChatRules.IsWide("WORLD"));
        Assert.False(ChatRules.IsWide("LOCAL"));
    }
}
