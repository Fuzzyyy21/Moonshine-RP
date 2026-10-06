using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 7, Iteration 4 (Backend-Seite): Belagerung ansagen (Recht, Kasse, genau einmal), während sie läuft PvP zwischen
/// den beiden Gilden in Stadt- und Seezone mit Wertung, Abrechnung nach Ende (Angreifer braucht mehr Punkte), Auflösen bricht ab.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class SiegeTests(PostgresFixture db)
{
    private static readonly Dictionary<string, string?> InAthens = new() { ["World:StartZoneId"] = "CITY_ATHENS" };

    [Fact]
    public async Task Declaring_needs_the_right_costs_from_the_treasury_and_happens_once()
    {
        await Reset();
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var (defender, _) = await Owner(backend, "ATHENS");
        var (attacker, attackerGuild) = await GuildWithTreasury(backend, 6000);
        var member = await Online(backend, 0);
        await Join(backend, attacker, attackerGuild, member);

        Assert.Equal(HttpStatusCode.Forbidden, (await Declare(backend, member, "ATHENS")).StatusCode);
        var key = Guid.NewGuid();
        var siege = await Read(await Declare(backend, attacker, "athens", key));
        Assert.Equal(("ATHENS", "SCHEDULED", attackerGuild), (siege.CityCode, siege.State, siege.AttackerGuildId));
        Assert.InRange(siege.StartsAt, DateTime.UtcNow.AddHours(23.9), DateTime.UtcNow.AddHours(24.1));
        Assert.Equal(TimeSpan.FromMinutes(60), siege.EndsAt - siege.StartsAt);
        Assert.Equal(siege.WarId, (await Read(await Declare(backend, attacker, "ATHENS", key))).WarId);
        Assert.Equal(1000L, await Treasury(attackerGuild)); // 6000 − 5000

        Assert.Equal(HttpStatusCode.Conflict, (await Declare(backend, attacker, "ATHENS")).StatusCode);  // schon angesagt
        Assert.Equal(HttpStatusCode.Conflict, (await Declare(backend, defender, "ATHENS")).StatusCode);  // eigene Stadt
        Assert.Equal(HttpStatusCode.Conflict, (await Declare(backend, attacker, "LONDON")).StatusCode);  // frei: kaufen
        Assert.Contains((await backend.GameInternal.GetFromJsonAsync<List<SiegeInfo>>("/internal/v1/sieges"))!, s => s.WarId == siege.WarId);
        Assert.True(await db.ScalarAsync<bool>(
            "SELECT EXISTS (SELECT 1 FROM chat_log WHERE channel = 'SYSTEM' AND message LIKE '%belagert ATHENS%')"));
    }

    [Fact]
    public async Task During_the_siege_the_guilds_fight_in_city_and_sea_and_the_attacker_takes_the_city()
    {
        await Reset();
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var (defender, defenderGuild) = await Owner(backend, "ATHENS");
        var (attacker, attackerGuild) = await GuildWithTreasury(backend, 6000);
        var outsider = await Online(backend, 0);
        var siege = await Read(await Declare(backend, attacker, "ATHENS"));
        await db.ExecAsync("UPDATE territory_wars SET scheduled_at = now() - INTERVAL '1 minute', ends_at = now() + INTERVAL '59 minutes' WHERE war_id = @w",
            ("w", siege.WarId));

        var active = await Active(backend, "CITY_ATHENS", attacker.ServerId);
        Assert.Equal([attacker.CharacterId], Assert.Single(active).Attackers);
        Assert.Single(await Active(backend, "SEA_DEV", attacker.ServerId)); // Land-See-Kampf: auch die Seezone vor dem Hafen
        Assert.Empty(await Active(backend, "CITY_LONDON", attacker.ServerId));

        Assert.Equal(HttpStatusCode.OK, (await Kill(backend, attacker, defender, "CITY_ATHENS")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await Kill(backend, attacker, defender, "SEA_DEV")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await Kill(backend, defender, attacker, "CITY_ATHENS")).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await Kill(backend, outsider, defender, "CITY_ATHENS")).StatusCode); // Unbeteiligte nicht
        Assert.Equal(2L, await db.ScalarAsync<long>("SELECT count(*) FROM combat_kills WHERE war_id = @w AND killer_character_id = @k",
            ("w", siege.WarId), ("k", attacker.CharacterId)));

        await db.ExecAsync("UPDATE territory_wars SET ends_at = now() - INTERVAL '1 second' WHERE war_id = @w", ("w", siege.WarId));
        var done = (await backend.GameInternal.GetFromJsonAsync<List<SiegeInfo>>("/internal/v1/sieges"))!.Single(s => s.WarId == siege.WarId);
        Assert.Equal(("FINISHED", 2, 1, (long?)attackerGuild), (done.State, done.AttackerScore, done.DefenderScore, done.WinnerGuildId));
        Assert.Equal(attackerGuild, await db.ScalarAsync<long>(
            "SELECT owner_guild_id FROM territories t JOIN cities c USING (city_id) WHERE c.code = 'ATHENS'"));
        Assert.NotEqual(defenderGuild, attackerGuild);
        Assert.Equal(HttpStatusCode.Conflict, (await Kill(backend, attacker, defender, "CITY_ATHENS")).StatusCode); // vorbei
    }

    [Fact]
    public async Task On_a_tie_the_defender_keeps_the_city_and_disbanding_cancels()
    {
        await Reset();
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var (_, defenderGuild) = await Owner(backend, "ATHENS");
        var (attacker, _) = await GuildWithTreasury(backend, 11000); // zwei Ansagen
        var siege = await Read(await Declare(backend, attacker, "ATHENS"));
        await db.ExecAsync("UPDATE territory_wars SET scheduled_at = now() - INTERVAL '2 hours', ends_at = now() - INTERVAL '1 hour' WHERE war_id = @w",
            ("w", siege.WarId));
        var done = (await backend.GameInternal.GetFromJsonAsync<List<SiegeInfo>>("/internal/v1/sieges"))!.Single(s => s.WarId == siege.WarId);
        Assert.Equal(((long?)defenderGuild, 0, 0), (done.WinnerGuildId, done.AttackerScore, done.DefenderScore));
        Assert.Equal(defenderGuild, await db.ScalarAsync<long>(
            "SELECT owner_guild_id FROM territories t JOIN cities c USING (city_id) WHERE c.code = 'ATHENS'"));

        var again = await Read(await Declare(backend, attacker, "ATHENS"));
        Assert.Equal(HttpStatusCode.NoContent,
            (await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{attacker.CharacterId}/guild/disband",
                new GuildActionRequest(attacker.AccountId, attacker.ServerId))).StatusCode);
        Assert.Equal("CANCELLED", await db.ScalarAsync<string>("SELECT state FROM territory_wars WHERE war_id = @w", ("w", again.WarId)));
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Who(long AccountId, long CharacterId, string Name, string ServerId);

    private Task Reset() => db.ExecAsync(
        """
        UPDATE territory_wars SET state = 'CANCELLED' WHERE state IN ('SCHEDULED', 'RUNNING');
        UPDATE territories SET owner_guild_id = NULL, tax_rate = NULL, captured_at = NULL;
        """);

    private static string Unique(string prefix) => $"{prefix} {Random.Shared.Next(100000, 999999)}";

    private async Task<Who> Online(TestBackend backend, long gold)
    {
        var login = await backend.RegisterAndLoginAsync();
        var created = await backend.CreateCharacterAsync(login.Ticket);
        var server = await backend.EnterZoneAsync(created.CharacterId, login.AccountId, "CITY_ATHENS");
        if (gold > 0)
        {
            var admin = await backend.RegisterAndLoginAsync();
            await db.ExecAsync("UPDATE accounts SET admin_level = 1 WHERE account_id = @a", ("a", admin.AccountId));
            var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{created.CharacterId}/gold",
                new AdminGoldRequest(admin.AccountId, gold, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
            res.EnsureSuccessStatusCode();
        }
        var state = (await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{created.CharacterId}/state?accountId={login.AccountId}"))!;
        return new Who(login.AccountId, created.CharacterId, state.Name, server);
    }

    /// <summary>Gildenleiter mit Gilde und so viel Gold in der Kasse.</summary>
    private async Task<(Who Leader, long GuildId)> GuildWithTreasury(TestBackend backend, long treasury)
    {
        var leader = await Online(backend, treasury + 1000);
        var found = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{leader.CharacterId}/guild",
            new GuildFoundRequest(leader.AccountId, leader.ServerId, Unique("Belagerer"), null, 0, 0, 1, Guid.NewGuid()));
        Assert.True(found.IsSuccessStatusCode, await found.Content.ReadAsStringAsync());
        var guild = (await found.Content.ReadFromJsonAsync<GuildInfo>())!;
        var deposit = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{leader.CharacterId}/guild/treasury/deposit",
            new TreasuryRequest(leader.AccountId, leader.ServerId, treasury, Guid.NewGuid()));
        deposit.EnsureSuccessStatusCode();
        return (leader, guild.GuildId);
    }

    /// <summary>Gilde, der die Stadt gehört.</summary>
    private async Task<(Who Leader, long GuildId)> Owner(TestBackend backend, string city)
    {
        var (leader, guildId) = await GuildWithTreasury(backend, 20000);
        var buy = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{leader.CharacterId}/guild/cities/{city}/buy",
            new CityBuyRequest(leader.AccountId, leader.ServerId, Guid.NewGuid()));
        Assert.True(buy.IsSuccessStatusCode, await buy.Content.ReadAsStringAsync());
        return (leader, guildId);
    }

    private static async Task Join(TestBackend backend, Who leader, long guildId, Who member)
    {
        (await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{leader.CharacterId}/guild/invite",
            new GuildTargetRequest(leader.AccountId, leader.ServerId, member.Name))).EnsureSuccessStatusCode();
        (await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{member.CharacterId}/guild-invites/{guildId}/accept",
            new GuildActionRequest(member.AccountId, member.ServerId))).EnsureSuccessStatusCode();
    }

    private static Task<HttpResponseMessage> Declare(TestBackend backend, Who p, string city, Guid? key = null) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/guild/cities/{city}/siege",
            new SiegeDeclareRequest(p.AccountId, p.ServerId, key ?? Guid.NewGuid()));

    private static async Task<List<ActiveSiege>> Active(TestBackend backend, string zone, string server) =>
        (await backend.GameInternal.GetFromJsonAsync<List<ActiveSiege>>($"/internal/v1/zones/{zone}/sieges/active?serverId={server}"))!;

    private static Task<HttpResponseMessage> Kill(TestBackend backend, Who killer, Who victim, string zone) =>
        backend.GameInternal.PostAsJsonAsync("/internal/v1/combat/kills",
            new KillRequest(Guid.NewGuid(), "zone-test", zone, killer.CharacterId, killer.AccountId, "CHARACTER", null, victim.CharacterId,
                victim.AccountId));

    private static async Task<SiegeInfo> Read(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<SiegeInfo>())!;
    }

    private Task<long> Treasury(long guildId) => db.ScalarAsync<long>("SELECT treasury_gold FROM guilds WHERE guild_id = @g", ("g", guildId));
}
