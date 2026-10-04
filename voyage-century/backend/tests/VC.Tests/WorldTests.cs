using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 4, Iteration 1 (Backend-Seite): Ein Charakter ist immer in genau einer Zone; Zonenwechsel
/// laufen nur über Ausgänge aus den Daten; ein alter Server kann nach dem Wechsel nichts mehr überschreiben;
/// der Client erfährt, mit welchem Server er sich verbinden soll.
/// Jeder Test legt eigene Zonen an, damit Server anderer Tests nicht stören.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class WorldTests(PostgresFixture db)
{
    [Fact]
    public async Task Client_is_routed_to_a_live_server_of_the_start_zone()
    {
        var (start, _) = await TwoLinkedZones();
        await using var backend = await TestBackend.StartAsync(db, Start(start));
        var p = await NewCharacter(backend);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await FindServer(backend, p)).StatusCode);

        await backend.StartZoneServerAsync(start, "zone-a.test:7001");
        var res = await FindServer(backend, p);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        Assert.Equal(new ServerAssignment(start, "zone-a.test:7001"), await res.Content.ReadFromJsonAsync<ServerAssignment>());

        // Ausgefallene Server (kein Lebenszeichen) werden nicht mehr vermittelt.
        await db.ExecAsync("UPDATE zone_servers SET last_heartbeat = now() - interval '1 hour' WHERE zone_id = @z", ("z", start));
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await FindServer(backend, p)).StatusCode);
    }

    [Fact]
    public async Task A_character_cannot_be_online_twice()
    {
        var (start, _) = await TwoLinkedZones();
        await using var backend = await TestBackend.StartAsync(db, Start(start));
        var p = await NewCharacter(backend);
        var first = await backend.StartZoneServerAsync(start);
        var second = await backend.StartZoneServerAsync(start);

        Assert.Equal(HttpStatusCode.OK, (await Claim(backend, p, first)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await Claim(backend, p, second)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await FindServer(backend, p)).StatusCode);

        // Ausloggen gibt frei; ein Release eines fremden Servers ändert nichts.
        Assert.Equal(HttpStatusCode.NoContent, (await Release(backend, p, second)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await Claim(backend, p, second)).StatusCode);
        await Release(backend, p, first);
        Assert.Equal(HttpStatusCode.OK, (await Claim(backend, p, second)).StatusCode);
    }

    [Fact]
    public async Task Final_save_releases_the_presence_atomically()
    {
        var (start, _) = await TwoLinkedZones();
        await using var backend = await TestBackend.StartAsync(db, Start(start));
        var p = await NewCharacter(backend);
        var server = await backend.StartZoneServerAsync(start);
        await Claim(backend, p, server);

        var final = await backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/state",
            new SaveStateRequest(p.AccountId, start, 7, 8, 9, 0, ServerId: server, ReleasePresence: true));
        Assert.Equal(HttpStatusCode.NoContent, final.StatusCode);
        Assert.Equal(new Position(7, 8, 9, 0), (await State(backend, p)).Position);
        Assert.Equal(0L, await db.ScalarAsync<long>("SELECT count(*) FROM character_presence WHERE character_id = @c", ("c", p.CharacterId)));
        // Danach darf dieser Server nichts mehr schreiben.
        Assert.Equal(HttpStatusCode.Conflict, (await Save(backend, p, server, start)).StatusCode);
    }

    [Fact]
    public async Task Presence_on_a_dead_or_restarted_server_does_not_block()
    {
        var (start, _) = await TwoLinkedZones();
        await using var backend = await TestBackend.StartAsync(db, Start(start));
        var p = await NewCharacter(backend);
        var crashed = await backend.StartZoneServerAsync(start);
        var other = await backend.StartZoneServerAsync(start);
        await Claim(backend, p, crashed);

        await db.ExecAsync("UPDATE zone_servers SET last_heartbeat = now() - interval '1 hour' WHERE server_id = @s", ("s", crashed));
        Assert.Equal(HttpStatusCode.OK, (await Claim(backend, p, other)).StatusCode);

        // Neustart eines Servers: dort ist niemand mehr online.
        var q = await NewCharacter(backend);
        var restarted = await backend.StartZoneServerAsync(start);
        await Claim(backend, q, restarted);
        var again = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/world/servers/{restarted}",
            new ServerRequest(start, "127.0.0.1:7777", 100));
        Assert.Equal(HttpStatusCode.OK, again.StatusCode);
        Assert.Equal(0L, await db.ScalarAsync<long>("SELECT count(*) FROM character_presence WHERE server_id = @s", ("s", restarted)));

        // Abmelden beendet alle Anwesenheiten auf diesem Server.
        var r = await NewCharacter(backend);
        var leaving = await backend.StartZoneServerAsync(start);
        await Claim(backend, r, leaving);
        Assert.Equal(HttpStatusCode.NoContent, (await backend.GameInternal.DeleteAsync($"/internal/v1/world/servers/{leaving}")).StatusCode);
        Assert.Equal(0L, await db.ScalarAsync<long>("SELECT count(*) FROM character_presence WHERE character_id = @c", ("c", r.CharacterId)));
    }

    [Fact]
    public async Task Zone_transfer_moves_the_character_and_locks_out_the_old_server()
    {
        var (from, to) = await TwoLinkedZones();
        await using var backend = await TestBackend.StartAsync(db, Start(from));
        var p = await NewCharacter(backend);
        var serverA = await backend.StartZoneServerAsync(from, "zone-a.test:7001");
        var serverB = await backend.StartZoneServerAsync(to, "zone-b.test:7002");
        await Claim(backend, p, serverA);
        Assert.Equal(HttpStatusCode.NoContent, (await Save(backend, p, serverA, from)).StatusCode);

        var res = await Transfer(backend, p, serverA, "GATE");
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        Assert.Equal(new ServerAssignment(to, "zone-b.test:7002", "FROM_A"), await res.Content.ReadFromJsonAsync<ServerAssignment>());

        var state = await State(backend, p);
        Assert.Equal(to, state.ZoneId);
        Assert.Null(state.Position); // Ankunftspunkt statt alter Koordinaten

        // Der alte Server kann nichts mehr speichern und nicht mehr freigeben.
        Assert.Equal(HttpStatusCode.Conflict, (await Save(backend, p, serverA, from)).StatusCode);
        await Release(backend, p, serverA);

        // Unterbrochener Wechsel: der Client wird zum reservierten Server geschickt.
        var find = await FindServer(backend, p);
        Assert.Equal("zone-b.test:7002", (await find.Content.ReadFromJsonAsync<ServerAssignment>())!.Address);

        var claim = await Claim(backend, p, serverB);
        Assert.Equal(new ClaimResponse(to, "FROM_A"), await claim.Content.ReadFromJsonAsync<ClaimResponse>());
        Assert.Equal(HttpStatusCode.NoContent, (await Save(backend, p, serverB, to)).StatusCode);

        // Zurück in die alte Zone nur über einen Ausgang, nicht durch direktes Verbinden.
        await Release(backend, p, serverB);
        Assert.Equal(HttpStatusCode.Conflict, (await Claim(backend, p, serverA)).StatusCode);

        var actions = await db.ScalarAsync<string[]>(
            "SELECT array_agg(action ORDER BY log_id) FROM game_event_log WHERE character_id = @c", ("c", p.CharacterId));
        Assert.Equal(["CHARACTER_CREATE", "ZONE_ENTER", "ZONE_TRANSFER", "ZONE_ENTER"], actions);
    }

    [Fact]
    public async Task Invalid_transfers_change_nothing()
    {
        var (from, to) = await TwoLinkedZones();
        await using var backend = await TestBackend.StartAsync(db, Start(from));
        var p = await NewCharacter(backend);
        var serverA = await backend.StartZoneServerAsync(from);
        var stranger = await backend.StartZoneServerAsync(from);
        await Claim(backend, p, serverA);

        Assert.Equal(HttpStatusCode.BadRequest, (await Transfer(backend, p, serverA, "NO_SUCH_EXIT")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Transfer(backend, p, serverA, "lower case")).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await Transfer(backend, p, stranger, "GATE")).StatusCode);
        // Zielzone ohne Server: Spieler bleibt, wo er ist.
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await Transfer(backend, p, serverA, "GATE")).StatusCode);

        Assert.Null((await State(backend, p)).ZoneId);
        Assert.Equal(HttpStatusCode.NoContent, (await Save(backend, p, serverA, from)).StatusCode);
        Assert.Equal(1L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM character_presence WHERE character_id = @c AND server_id = @s AND state = 'ONLINE'",
            ("c", p.CharacterId), ("s", serverA)));
        _ = to;
    }

    [Fact]
    public async Task Expired_transfer_reservation_can_be_taken_by_another_server_of_the_zone()
    {
        var (from, to) = await TwoLinkedZones();
        await using var backend = await TestBackend.StartAsync(db, Start(from));
        var p = await NewCharacter(backend);
        var serverA = await backend.StartZoneServerAsync(from);
        var serverB = await backend.StartZoneServerAsync(to);
        await Claim(backend, p, serverA);
        await Transfer(backend, p, serverA, "GATE");

        var serverB2 = await backend.StartZoneServerAsync(to);
        Assert.Equal(HttpStatusCode.Conflict, (await Claim(backend, p, serverB2)).StatusCode); // noch für B reserviert
        await db.ExecAsync("UPDATE character_presence SET expires_at = now() - interval '1 second' WHERE character_id = @c",
            ("c", p.CharacterId));
        var claim = await Claim(backend, p, serverB2);
        Assert.Equal(new ClaimResponse(to, "FROM_A"), await claim.Content.ReadFromJsonAsync<ClaimResponse>());
        _ = serverB;
    }

    [Fact]
    public async Task Full_servers_and_development_zones_are_not_offered()
    {
        var (start, _) = await TwoLinkedZones();
        await using (var backend = await TestBackend.StartAsync(db, Start(start)))
        {
            var p = await NewCharacter(backend);
            var q = await NewCharacter(backend);
            var small = await backend.StartZoneServerAsync(start, capacity: 1);
            await Claim(backend, p, small);
            Assert.Equal(HttpStatusCode.ServiceUnavailable, (await FindServer(backend, q)).StatusCode);
        }

        var devZone = await NewZone(isDev: true);
        var (prodStart, _) = await TwoLinkedZones();
        await db.ExecAsync("INSERT INTO zone_links VALUES (@f, 'DEV', @t, 'ARRIVE')", ("f", prodStart), ("t", devZone));
        var overrides = Start(prodStart);
        overrides["Content:AllowDevContent"] = "false";
        await using (var prod = await TestBackend.StartAsync(db, overrides))
        {
            var p = await NewCharacter(prod);
            var server = await prod.StartZoneServerAsync(prodStart);
            await prod.StartZoneServerAsync(devZone);
            await Claim(prod, p, server);
            Assert.Equal(HttpStatusCode.BadRequest, (await Transfer(prod, p, server, "DEV")).StatusCode);
        }
    }

    [Fact]
    public async Task New_characters_start_only_in_the_start_zone()
    {
        var (start, other) = await TwoLinkedZones();
        await using (var backend = await TestBackend.StartAsync(db, Start(start)))
        {
            var p = await NewCharacter(backend);
            var wrong = await backend.StartZoneServerAsync(other);
            Assert.Equal(HttpStatusCode.Conflict, (await Claim(backend, p, wrong)).StatusCode);
        }
        await using (var unconfigured = await TestBackend.StartAsync(db, new Dictionary<string, string?> { ["World:StartZoneId"] = null }))
        {
            var p = await NewCharacter(unconfigured);
            Assert.Equal(HttpStatusCode.ServiceUnavailable, (await FindServer(unconfigured, p)).StatusCode);
        }
    }

    [Theory]
    [InlineData("DEV_TESTZONE", "no-port", 10)]
    [InlineData("DEV_TESTZONE", "127.0.0.1:7777", 0)]
    [InlineData("NO_SUCH_ZONE", "127.0.0.1:7777", 10)]
    public async Task Invalid_server_registrations_are_rejected(string zone, string address, int capacity)
    {
        await using var backend = await TestBackend.StartAsync(db);
        var res = await backend.GameInternal.PostAsJsonAsync("/internal/v1/world/servers/test-invalid",
            new ServerRequest(zone, address, capacity));
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }

    [Fact]
    public async Task Directory_endpoints_require_service_key_or_ticket()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await NewCharacter(backend);
        var register = await backend.Game.PostAsJsonAsync("/internal/v1/world/servers/test-nokey",
            new ServerRequest("DEV_TESTZONE", "127.0.0.1:7777", 10));
        Assert.Equal(HttpStatusCode.Unauthorized, register.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await backend.Game.GetAsync($"/v1/characters/{p.CharacterId}/server")).StatusCode);

        // Fremder Charakter: gleiche Antwort wie "gibt es nicht".
        var other = await backend.RegisterAndLoginAsync();
        var res = await backend.Game.SendAsync(TestBackend.WithTicket(HttpMethod.Get, $"/v1/characters/{p.CharacterId}/server", other.Ticket));
        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Player(long AccountId, long CharacterId, string Ticket);

    private static Dictionary<string, string?> Start(string zone) => new() { ["World:StartZoneId"] = zone };

    private async Task<string> NewZone(bool isDev = false)
    {
        var zone = "T_" + Guid.NewGuid().ToString("N")[..10].ToUpperInvariant();
        await db.ExecAsync("INSERT INTO zones (zone_id, zone_kind, map_asset, is_dev) VALUES (@z, 'LAND', '/Game/Test', @dev)",
            ("z", zone), ("dev", isDev));
        return zone;
    }

    /// <summary>Zwei Zonen; aus der ersten führt der Ausgang GATE zur zweiten (Ankunft FROM_A).</summary>
    private async Task<(string From, string To)> TwoLinkedZones()
    {
        var from = await NewZone();
        var to = await NewZone();
        await db.ExecAsync("INSERT INTO zone_links VALUES (@f, 'GATE', @t, 'FROM_A'), (@t, 'BACK', @f, 'FROM_B')", ("f", from), ("t", to));
        return (from, to);
    }

    private static async Task<Player> NewCharacter(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        return new Player(login.AccountId, (await backend.CreateCharacterAsync(login.Ticket)).CharacterId, login.Ticket);
    }

    private static Task<HttpResponseMessage> FindServer(TestBackend backend, Player p) =>
        backend.Game.SendAsync(TestBackend.WithTicket(HttpMethod.Get, $"/v1/characters/{p.CharacterId}/server", p.Ticket));

    private static Task<HttpResponseMessage> Claim(TestBackend backend, Player p, string serverId) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/world/characters/{p.CharacterId}/claim", new ClaimRequest(p.AccountId, serverId));

    private static Task<HttpResponseMessage> Release(TestBackend backend, Player p, string serverId) =>
        backend.GameInternal.DeleteAsync($"/internal/v1/world/characters/{p.CharacterId}/claim?serverId={serverId}");

    private static Task<HttpResponseMessage> Transfer(TestBackend backend, Player p, string serverId, string exit) =>
        backend.GameInternal.PostAsJsonAsync("/internal/v1/world/transfers", new TransferRequest(p.CharacterId, p.AccountId, serverId, exit));

    private static Task<HttpResponseMessage> Save(TestBackend backend, Player p, string serverId, string zone) =>
        backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/state",
            new SaveStateRequest(p.AccountId, zone, 1, 2, 3, 0, ServerId: serverId));

    private static async Task<CharacterState> State(TestBackend backend, Player p) =>
        (await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{p.CharacterId}/state?accountId={p.AccountId}"))!;
}
