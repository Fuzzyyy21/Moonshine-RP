using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 2 (Backend-Seite): Level und Skill-XP werden nur serverseitig vergeben,
/// überleben einen Neustart, und Clients können sie nicht verändern.
/// Die XP-Kurven in diesen Tests sind die markierten Entwicklungskurven (design_data/dev_curves.json):
/// Charakter 100·(L−1)², Skills 50·(L−1)².
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class ProgressionTests(PostgresFixture db)
{
    [Fact]
    public async Task Character_xp_levels_up_along_the_curve_and_survives_restart()
    {
        long characterId;
        LoginResult who;
        await using (var backend = await TestBackend.StartAsync(db))
        {
            who = await NewCharacter(backend);
            characterId = who.CharacterId;
            var progress = await GrantXp(backend, who, 450);
            Assert.Equal(3, progress.Level);      // Stufe 3 ab 400, Stufe 4 erst ab 900
            Assert.Equal(450, progress.Experience);
            Assert.Equal(230, progress.LevelCap); // Entwicklungskurve reicht bis 230
        }
        await using (var backend = await TestBackend.StartAsync(db))
        {
            var state = await State(backend, who);
            Assert.Equal(3, state.Level);
            Assert.Equal(450, state.Experience);
        }
        Assert.Equal(1L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM game_event_log WHERE character_id = @c AND action = 'LEVEL_UP'", ("c", characterId)));
    }

    [Fact]
    public async Task Without_known_thresholds_no_level_is_gained()
    {
        await using var backend = await TestBackend.StartAsync(db,
            new Dictionary<string, string?> { ["Progression:AllowDevCurves"] = "false" });
        var who = await NewCharacter(backend);
        var progress = await GrantXp(backend, who, 100_000);
        Assert.Equal(1, progress.Level);
        Assert.Equal(1, progress.LevelCap);
        Assert.Equal(100_000, progress.Experience); // XP bleibt erhalten, bis echte Schwellen bekannt sind
    }

    [Fact]
    public async Task Repeated_grant_with_same_key_counts_once()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var who = await NewCharacter(backend);
        var key = Guid.NewGuid();
        var first = await GrantXp(backend, who, 150, key);
        var second = await GrantXp(backend, who, 150, key);
        Assert.False(first.Duplicate);
        Assert.True(second.Duplicate);
        Assert.Equal(150, second.Experience);
    }

    [Fact]
    public async Task Parallel_grants_are_serialized_per_character()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var who = await NewCharacter(backend);
        await Task.WhenAll(Enumerable.Range(0, 20).Select(_ => GrantXp(backend, who, 10)));
        Assert.Equal(200, (await State(backend, who)).Experience);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-5)]
    [InlineData(1_000_001)]
    public async Task Implausible_amounts_are_rejected(long amount)
    {
        await using var backend = await TestBackend.StartAsync(db);
        var who = await NewCharacter(backend);
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{who.CharacterId}/experience",
            new GrantRequest(who.AccountId, amount, "test", Guid.NewGuid(), "zone-test"));
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }

    [Fact]
    public async Task Clients_cannot_change_progression()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var who = await NewCharacter(backend);

        // Mit Ticket gibt es keinen Client-Endpunkt für XP oder Level.
        var viaClient = await backend.Game.SendAsync(TestBackend.WithTicket(HttpMethod.Post,
            $"/v1/characters/{who.CharacterId}/experience", who.Ticket,
            new GrantRequest(who.AccountId, 999, "cheat", Guid.NewGuid(), "x")));
        Assert.Equal(HttpStatusCode.NotFound, viaClient.StatusCode);

        // Interner Endpunkt ohne Service-Key bleibt zu.
        var noKey = await backend.Game.PostAsJsonAsync($"/internal/v1/characters/{who.CharacterId}/experience",
            new GrantRequest(who.AccountId, 999, "cheat", Guid.NewGuid(), "x"));
        Assert.Equal(HttpStatusCode.Unauthorized, noKey.StatusCode);

        // Ein Server kann nur Charaktere des geprüften Kontos ändern.
        var other = await NewCharacter(backend);
        var foreign = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{who.CharacterId}/experience",
            new GrantRequest(other.AccountId, 10, "test", Guid.NewGuid(), "zone-test"));
        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);

        Assert.Equal(0, (await State(backend, who)).Experience);
    }

    [Fact]
    public async Task Skill_xp_stops_at_the_first_skill_stage()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var who = await NewCharacter(backend);
        var p = await GrantSkillXp(backend, who, "NAVIGATION", 100_000);
        Assert.Equal(31, p.Level);   // Grundstufe endet bei 31 (SKILL-STAGES)
        Assert.Equal(31, p.LevelCap);
        Assert.Equal(1, p.Stage);    // Beförderungsbedingungen UNKNOWN → keine automatische Beförderung

        var state = await State(backend, who);
        Assert.Equal(31, Assert.Single(state.Skills).Level);
    }

    [Fact]
    public async Task Total_skill_cap_limits_the_sum_of_all_skills()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var admin = await NewCharacter(backend);
        await db.ExecAsync("UPDATE accounts SET admin_level = 1 WHERE account_id = @a", ("a", admin.AccountId));
        var original = await db.ScalarAsync<long>("SELECT int_value FROM game_rules WHERE rule_key = 'SKILL_TOTAL_CAP'");
        Assert.Equal(1700, original); // aus SKILL-TOTAL-CAP
        try
        {
            await db.ExecAsync("UPDATE game_rules SET int_value = 40 WHERE rule_key = 'SKILL_TOTAL_CAP'");
            var set = await backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{admin.CharacterId}/skills/SWORD/level",
                new AdminSetRequest(admin.AccountId, 31, null, null, "zone-test"));
            Assert.Equal(HttpStatusCode.OK, set.StatusCode);

            var p = await GrantSkillXp(backend, admin, "MINING", 100_000);
            Assert.Equal(9, p.Level); // 40 − 31
        }
        finally
        {
            await db.ExecAsync("UPDATE game_rules SET int_value = @v WHERE rule_key = 'SKILL_TOTAL_CAP'", ("v", original));
        }
    }

    [Fact]
    public async Task Admin_setlevel_is_audited_in_the_same_transaction()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var target = await NewCharacter(backend);
        var admin = await NewCharacter(backend);

        var denied = await backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{target.CharacterId}/level",
            new AdminSetRequest(admin.AccountId, 50, null, null, "zone-test"));
        Assert.Equal(HttpStatusCode.Forbidden, denied.StatusCode);

        await db.ExecAsync("UPDATE accounts SET admin_level = 1 WHERE account_id = @a", ("a", admin.AccountId));
        var tooHigh = await backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{target.CharacterId}/level",
            new AdminSetRequest(admin.AccountId, 231, null, null, "zone-test"));
        Assert.Equal(HttpStatusCode.BadRequest, tooHigh.StatusCode);

        var ok = await backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{target.CharacterId}/level",
            new AdminSetRequest(admin.AccountId, 50, null, "203.0.113.9", "zone-test"));
        Assert.Equal(HttpStatusCode.OK, ok.StatusCode);

        var state = await State(backend, target);
        Assert.Equal(50, state.Level);
        Assert.Equal(100L * 49 * 49, state.Experience);
        Assert.Equal(1L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM admin_audit_log WHERE command = '/setlevel' AND target_id = @t AND admin_account_id = @a",
            ("t", target.CharacterId.ToString(System.Globalization.CultureInfo.InvariantCulture)), ("a", admin.AccountId)));
    }

    [Fact]
    public async Task Curve_ends_at_the_first_gap()
    {
        var curve = Curve.FromThresholds([0, 100, 400]);
        Assert.Equal(3, curve.Cap);
        Assert.Equal(1, curve.LevelFor(99));
        Assert.Equal(3, curve.LevelFor(10_000));
        Assert.Equal(1, Curve.FromThresholds([]).Cap);
        await Task.CompletedTask;
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record LoginResult(long AccountId, string Ticket, long CharacterId);

    private static async Task<LoginResult> NewCharacter(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        var character = await backend.CreateCharacterAsync(login.Ticket);
        return new LoginResult(login.AccountId, login.Ticket, character.CharacterId);
    }

    private static async Task<CharacterProgress> GrantXp(TestBackend backend, LoginResult who, long amount, Guid? key = null)
    {
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{who.CharacterId}/experience",
            new GrantRequest(who.AccountId, amount, "test", key ?? Guid.NewGuid(), "zone-test"));
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<CharacterProgress>())!;
    }

    private static async Task<SkillProgress> GrantSkillXp(TestBackend backend, LoginResult who, string skill, long amount)
    {
        var res = await backend.GameInternal.PostAsJsonAsync(
            $"/internal/v1/characters/{who.CharacterId}/skills/{skill}/experience",
            new GrantRequest(who.AccountId, amount, "test", Guid.NewGuid(), "zone-test"));
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<SkillProgress>())!;
    }

    private static async Task<CharacterState> State(TestBackend backend, LoginResult who) =>
        (await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{who.CharacterId}/state?accountId={who.AccountId}"))!;
}
