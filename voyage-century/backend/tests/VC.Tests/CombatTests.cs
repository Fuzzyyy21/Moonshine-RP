using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 3 (Backend-Seite): Belohnungen kommen aus den Gegnerdaten, nicht aus der Meldung des Servers;
/// PvP nur in Zonen, die es erlauben; jeder Kill zählt genau einmal; Lebenspunkte überdauern das Ausloggen.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class CombatTests(PostgresFixture db)
{
    [Fact]
    public async Task Test_zone_allows_pvp()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var zone = await backend.GameInternal.GetFromJsonAsync<ZoneInfo>("/internal/v1/zones/DEV_TESTZONE");
        Assert.Equal("FREE", zone!.PvpMode);
        Assert.Equal(HttpStatusCode.NotFound, (await backend.GameInternal.GetAsync("/internal/v1/zones/NOPE")).StatusCode);
    }

    [Fact]
    public async Task Monster_kill_awards_xp_from_monster_data_once()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await NewCharacter(backend);
        var key = Guid.NewGuid();

        var first = await Kill(backend, p, "DEV_PIRATE_BRAWLER", key);
        Assert.False(first.Duplicate);
        Assert.Equal(60, first.XpAwarded);              // aus design_data/dev_combat.json
        Assert.Equal(60, first.Progress!.Experience);

        var again = await Kill(backend, p, "DEV_PIRATE_BRAWLER", key);
        Assert.True(again.Duplicate);
        Assert.Equal(60L, await db.ScalarAsync<long>("SELECT experience FROM characters WHERE character_id = @c", ("c", p.CharacterId)));
        Assert.Equal(1L, await db.ScalarAsync<long>("SELECT count(*) FROM combat_kills WHERE killer_character_id = @c", ("c", p.CharacterId)));
    }

    [Fact]
    public async Task Unknown_or_unreleased_monsters_are_rejected()
    {
        await using (var backend = await TestBackend.StartAsync(db))
        {
            var p = await NewCharacter(backend);
            var res = await PostKill(backend, Monster(p, "NO_SUCH_MONSTER"));
            Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
        }
        await using (var prod = await TestBackend.StartAsync(db, new Dictionary<string, string?> { ["Content:AllowDevContent"] = "false" }))
        {
            var p = await NewCharacter(prod);
            var res = await PostKill(prod, Monster(p, "DEV_TRAINING_DUMMY"));
            Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode); // Entwicklungsgegner sind in Produktion gesperrt
        }
    }

    [Fact]
    public async Task Pvp_kill_updates_statistics_in_free_zone()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var killer = await NewCharacter(backend);
        var victim = await NewCharacter(backend);
        var res = await PostKill(backend, Pvp(killer, victim, "DEV_TESTZONE"));
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        Assert.Null((await res.Content.ReadFromJsonAsync<KillResponse>())!.XpAwarded); // PvP gibt keine XP (Original UNKNOWN)

        Assert.Equal(1, await db.ScalarAsync<int>("SELECT land_kills FROM pvp_statistics WHERE character_id = @c", ("c", killer.CharacterId)));
        Assert.Equal(1, await db.ScalarAsync<int>("SELECT land_deaths FROM pvp_statistics WHERE character_id = @c", ("c", victim.CharacterId)));
    }

    [Fact]
    public async Task Pvp_kill_in_safe_zone_is_refused()
    {
        await db.ExecAsync(
            "INSERT INTO zones (zone_id, zone_kind, map_asset) VALUES ('TEST_SAFE', 'CITY', '/Game/Test') ON CONFLICT DO NOTHING");
        await using var backend = await TestBackend.StartAsync(db);
        var killer = await NewCharacter(backend);
        var victim = await NewCharacter(backend);
        var res = await PostKill(backend, Pvp(killer, victim, "TEST_SAFE"));
        Assert.Equal(HttpStatusCode.Conflict, res.StatusCode);
        Assert.Equal(0L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM pvp_statistics WHERE character_id IN (@a, @b)", ("a", killer.CharacterId), ("b", victim.CharacterId)));
    }

    [Fact]
    public async Task Kill_reports_check_ownership()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var a = await NewCharacter(backend);
        var b = await NewCharacter(backend);

        var wrongKiller = Monster(a, "DEV_TRAINING_DUMMY") with { KillerAccountId = b.AccountId };
        Assert.Equal(HttpStatusCode.NotFound, (await PostKill(backend, wrongKiller)).StatusCode);

        var wrongVictim = Pvp(a, b, "DEV_TESTZONE") with { VictimAccountId = a.AccountId };
        Assert.Equal(HttpStatusCode.NotFound, (await PostKill(backend, wrongVictim)).StatusCode);

        var self = Pvp(a, a, "DEV_TESTZONE");
        Assert.Equal(HttpStatusCode.NotFound, (await PostKill(backend, self)).StatusCode);
    }

    [Fact]
    public async Task Vitals_are_saved_and_loaded()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await NewCharacter(backend);
        var save = await backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/state",
            new SaveStateRequest(p.AccountId, "DEV_TESTZONE", 0, 0, 100, 0, Health: 37, MaxHealth: 120, Stamina: 50, MaxStamina: 60));
        Assert.Equal(HttpStatusCode.NoContent, save.StatusCode);

        var state = await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{p.CharacterId}/state?accountId={p.AccountId}");
        Assert.Equal(new Vitals(37, 120, 50, 60), state!.Vitals);
    }

    [Theory]
    [InlineData(130, 120, 10, 10)]   // mehr als Maximum
    [InlineData(-1, 120, 10, 10)]
    [InlineData(10, 0, 10, 10)]      // Maximum 0
    [InlineData(10, 120, null, 10)]  // unvollständig
    public async Task Invalid_vitals_are_rejected(int? hp, int? maxHp, int? sp, int? maxSp)
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await NewCharacter(backend);
        var save = await backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/state",
            new SaveStateRequest(p.AccountId, "DEV_TESTZONE", 0, 0, 100, 0, hp, maxHp, sp, maxSp));
        Assert.Equal(HttpStatusCode.BadRequest, save.StatusCode);
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Player(long AccountId, long CharacterId);

    private static async Task<Player> NewCharacter(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        return new Player(login.AccountId, (await backend.CreateCharacterAsync(login.Ticket)).CharacterId);
    }

    private static KillRequest Monster(Player p, string code, Guid? key = null) =>
        new(key ?? Guid.NewGuid(), "zone-test", "DEV_TESTZONE", p.CharacterId, p.AccountId, "MONSTER", code, null, null);

    private static KillRequest Pvp(Player killer, Player victim, string zone) =>
        new(Guid.NewGuid(), "zone-test", zone, killer.CharacterId, killer.AccountId, "CHARACTER", null, victim.CharacterId, victim.AccountId);

    private static Task<HttpResponseMessage> PostKill(TestBackend backend, KillRequest req) =>
        backend.GameInternal.PostAsJsonAsync("/internal/v1/combat/kills", req);

    private static async Task<KillResponse> Kill(TestBackend backend, Player p, string code, Guid key)
    {
        var res = await PostKill(backend, Monster(p, code, key));
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<KillResponse>())!;
    }
}
