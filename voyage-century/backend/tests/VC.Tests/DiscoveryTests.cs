using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 4, Iteration 2 (Backend-Seite): Eine Entdeckung zählt je Charakter einmal, die Belohnung kommt aus den
/// Daten, und nur der Server, auf dem der Charakter in der Zone des Punktes ist, kann sie melden.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class DiscoveryTests(PostgresFixture db)
{
    [Fact]
    public async Task Discovery_counts_once_and_rewards_from_data()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await NewCharacter(backend);
        var server = await backend.EnterZoneAsync(p.CharacterId, p.AccountId);

        var first = await Report(backend, p, server, "DEV_DISC_TESTZONE_RUIN");
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var body = (await first.Content.ReadFromJsonAsync<DiscoveryResponse>())!;
        Assert.True(body.FirstTime);
        Assert.Equal(50, body.XpAwarded); // aus design_data/dev_discoveries.json
        Assert.Equal(50, body.Progress!.Experience);

        var again = (await (await Report(backend, p, server, "DEV_DISC_TESTZONE_RUIN")).Content.ReadFromJsonAsync<DiscoveryResponse>())!;
        Assert.False(again.FirstTime);
        Assert.Null(again.XpAwarded);
        Assert.Equal(50L, await db.ScalarAsync<long>("SELECT experience FROM characters WHERE character_id = @c", ("c", p.CharacterId)));

        var state = await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{p.CharacterId}/state?accountId={p.AccountId}");
        Assert.Equal(["DEV_DISC_TESTZONE_RUIN"], state!.Discoveries!);
    }

    [Fact]
    public async Task Only_the_server_holding_the_character_in_that_zone_can_report()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await NewCharacter(backend);
        var server = await backend.EnterZoneAsync(p.CharacterId, p.AccountId);
        var stranger = await backend.StartZoneServerAsync("DEV_TESTZONE");

        Assert.Equal(HttpStatusCode.Conflict, (await Report(backend, p, stranger, "DEV_DISC_TESTZONE_RUIN")).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await Report(backend, p, server, "DEV_DISC_SEA_WRECK")).StatusCode); // andere Zone
        Assert.Equal(HttpStatusCode.BadRequest, (await Report(backend, p, server, "NO_SUCH_DISCOVERY")).StatusCode);

        var other = await NewCharacter(backend);
        var foreign = await backend.GameInternal.PostAsJsonAsync("/internal/v1/world/discoveries",
            new DiscoveryRequest(p.CharacterId, other.AccountId, server, "DEV_DISC_TESTZONE_RUIN"));
        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);
        Assert.Equal(0L, await db.ScalarAsync<long>("SELECT count(*) FROM character_discoveries WHERE character_id = @c", ("c", p.CharacterId)));
    }

    [Fact]
    public async Task Development_discoveries_are_locked_without_dev_content()
    {
        await using var prod = await TestBackend.StartAsync(db, new Dictionary<string, string?> { ["Content:AllowDevContent"] = "false" });
        var p = await NewCharacter(prod);
        // Die Testzone selbst ist eine Entwicklungszone; zum Melden reicht hier ein direkt gesetzter Aufenthalt.
        var server = await prod.StartZoneServerAsync("DEV_TESTZONE");
        await db.ExecAsync("INSERT INTO character_presence (character_id, server_id, zone_id, state) VALUES (@c, @s, 'DEV_TESTZONE', 'ONLINE')",
            ("c", p.CharacterId), ("s", server));
        Assert.Equal(HttpStatusCode.BadRequest, (await Report(prod, p, server, "DEV_DISC_TESTZONE_RUIN")).StatusCode);
    }

    private sealed record Player(long AccountId, long CharacterId);

    private static async Task<Player> NewCharacter(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        return new Player(login.AccountId, (await backend.CreateCharacterAsync(login.Ticket)).CharacterId);
    }

    private static Task<HttpResponseMessage> Report(TestBackend backend, Player p, string serverId, string code) =>
        backend.GameInternal.PostAsJsonAsync("/internal/v1/world/discoveries", new DiscoveryRequest(p.CharacterId, p.AccountId, serverId, code));
}
