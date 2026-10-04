using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 5, Iteration 1 (Backend-Seite): Schiffe nur beim Werftmeister der eigenen Zone, Gold im Ledger, jeder Kauf
/// genau einmal, ein aktives Schiff, Schiffszustand kann ohne Werft nicht steigen.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class ShipTests(PostgresFixture db)
{
    private static readonly Dictionary<string, string?> InAthens = new() { ["World:StartZoneId"] = "CITY_ATHENS" };

    [Fact]
    public async Task Starter_ship_is_free_once_and_becomes_active()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InZone(backend, "CITY_ATHENS");

        var res = await Buy(backend, p, "DEV_STARTER_SHIP");
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var bought = (await res.Content.ReadFromJsonAsync<BuyShipResponse>())!;
        Assert.False(bought.Duplicate);
        Assert.True(bought.Ship.Active);
        Assert.Equal(500, bought.Ship.HullHp);
        Assert.Equal(6, bought.Ship.Crew);        // Hälfte von 12 (Community-Rat)
        Assert.Equal(200, bought.Ship.Provisions);
        Assert.Equal(0, bought.Gold);

        Assert.Equal(HttpStatusCode.Conflict, (await Buy(backend, p, "DEV_STARTER_SHIP")).StatusCode);
        var state = await State(backend, p);
        Assert.Single(state.Ships!);
        Assert.Equal(1L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM game_event_log WHERE character_id = @c AND action = 'SHIP_BUY'", ("c", p.CharacterId)));
    }

    [Fact]
    public async Task Buying_costs_gold_from_the_ledger_and_counts_once()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InZone(backend, "CITY_ATHENS");
        Assert.Equal(HttpStatusCode.Conflict, (await Buy(backend, p, "DEV_BATTLE_SLOOP")).StatusCode); // kein Gold

        var admin = await Admin(backend);
        var grant = await GiveGold(backend, admin, p, 6000, Guid.NewGuid());
        Assert.True(grant.IsSuccessStatusCode, await grant.Content.ReadAsStringAsync());

        var key = Guid.NewGuid();
        var first = (await (await Buy(backend, p, "DEV_BATTLE_SLOOP", key)).Content.ReadFromJsonAsync<BuyShipResponse>())!;
        Assert.Equal(1000, first.Gold);
        var again = (await (await Buy(backend, p, "DEV_BATTLE_SLOOP", key)).Content.ReadFromJsonAsync<BuyShipResponse>())!;
        Assert.True(again.Duplicate);
        Assert.Equal(first.Ship.InstanceId, again.Ship.InstanceId);
        Assert.Equal(1000, again.Gold);

        var state = await State(backend, p);
        Assert.Equal(1000, state.Gold);
        Assert.Single(state.Ships!);
        Assert.Equal(["ADMIN_GRANT", "SHIP_BUY"], await db.ScalarAsync<string[]>(
            "SELECT array_agg(reason ORDER BY ledger_id) FROM currency_ledger WHERE character_id = @c", ("c", p.CharacterId)));
    }

    [Fact]
    public async Task Ships_are_only_sold_by_a_shipyard_in_the_current_zone()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await InZone(backend, "DEV_TESTZONE");
        Assert.Equal(HttpStatusCode.BadRequest, (await Buy(backend, p, "DEV_STARTER_SHIP")).StatusCode); // Werft steht in Athen

        await using var athens = await TestBackend.StartAsync(db, InAthens);
        var q = await NewCharacter(athens);
        Assert.Equal(HttpStatusCode.Conflict, (await Buy(athens, q, "DEV_STARTER_SHIP", server: "not-present")).StatusCode);
        await athens.EnterZoneAsync(q.CharacterId, q.AccountId, "CITY_ATHENS");
        var wrongNpc = await athens.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{q.CharacterId}/ships",
            new BuyShipRequest(q.AccountId, q.ServerId, "LONDON_OFFICER_EXCHANGE", "DEV_STARTER_SHIP", Guid.NewGuid()));
        Assert.Equal(HttpStatusCode.BadRequest, wrongNpc.StatusCode);
    }

    [Fact]
    public async Task One_active_ship_and_state_can_only_decrease()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InZone(backend, "CITY_ATHENS");
        await GiveGold(backend, await Admin(backend), p, 5000, Guid.NewGuid());
        var starter = (await (await Buy(backend, p, "DEV_STARTER_SHIP")).Content.ReadFromJsonAsync<BuyShipResponse>())!.Ship;
        var cutter = (await (await Buy(backend, p, "DEV_RAIDER_CUTTER")).Content.ReadFromJsonAsync<BuyShipResponse>())!.Ship;
        Assert.False(cutter.Active); // das erste bleibt aktiv

        var activate = await backend.GameInternal.PutAsJsonAsync(
            $"/internal/v1/characters/{p.CharacterId}/ships/{cutter.InstanceId}/active", new ShipCommandRequest(p.AccountId, p.ServerId));
        Assert.Equal(HttpStatusCode.NoContent, activate.StatusCode);
        var ships = (await State(backend, p)).Ships!;
        Assert.True(ships.Single(s => s.InstanceId == cutter.InstanceId).Active);
        Assert.False(ships.Single(s => s.InstanceId == starter.InstanceId).Active);

        Assert.Equal(HttpStatusCode.NoContent, (await SaveShip(backend, p, starter.InstanceId, 400, 5, 150)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await SaveShip(backend, p, starter.InstanceId, 500, 5, 150)).StatusCode); // Rumpf gestiegen
        Assert.Equal(HttpStatusCode.Conflict, (await SaveShip(backend, p, starter.InstanceId, 400, 5, 999)).StatusCode); // Proviant gestiegen
        var other = await NewCharacter(backend);
        var foreign = await backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/ships/{starter.InstanceId}/state",
            new SaveShipRequest(other.AccountId, p.ServerId, 1, 1, 1));
        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);
        var saved = (await State(backend, p)).Ships!.Single(s => s.InstanceId == starter.InstanceId);
        Assert.Equal((400, 5, 150), (saved.HullHp, saved.Crew, saved.Provisions));
    }

    [Fact]
    public async Task Gold_grants_need_admin_rights_and_count_once()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await NewCharacter(backend);
        var notAdmin = await NewCharacter(backend);
        Assert.Equal(HttpStatusCode.Forbidden, (await GiveGold(backend, notAdmin.AccountId, p, 100, Guid.NewGuid())).StatusCode);

        var admin = await Admin(backend);
        var key = Guid.NewGuid();
        await GiveGold(backend, admin, p, 100, key);
        await GiveGold(backend, admin, p, 100, key);
        Assert.Equal(100, (await State(backend, p)).Gold);
        Assert.Equal(1L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM admin_audit_log WHERE command = '/givegold' AND target_id = @c", ("c", p.CharacterId.ToString(System.Globalization.CultureInfo.InvariantCulture))));
    }

    [Fact]
    public async Task Development_ships_are_not_sold_without_dev_content()
    {
        var overrides = new Dictionary<string, string?>(InAthens) { ["Content:AllowDevContent"] = "false" };
        await using var prod = await TestBackend.StartAsync(db, overrides);
        var p = await InZone(prod, "CITY_ATHENS");
        Assert.Equal(HttpStatusCode.BadRequest, (await Buy(prod, p, "DEV_STARTER_SHIP")).StatusCode);
    }

    [Fact]
    public async Task Harbor_services_cost_gold_and_respect_limits()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InZone(backend, "CITY_ATHENS");
        var ship = (await (await Buy(backend, p, "DEV_STARTER_SHIP")).Content.ReadFromJsonAsync<BuyShipResponse>())!.Ship;
        // Gefecht: 100 Rumpf verloren, 2 Matrosen verletzt, 1 tot, 20 Proviant verbraucht.
        Assert.Equal(HttpStatusCode.NoContent, (await SaveShip(backend, p, ship.InstanceId, 400, 3, 180, injured: 2)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await Service(backend, p, ship, "REPAIR")).StatusCode); // kein Gold
        await GiveGold(backend, await Admin(backend), p, 10_000, Guid.NewGuid());

        var key = Guid.NewGuid();
        var repair = (await (await Service(backend, p, ship, "REPAIR", key: key)).Content.ReadFromJsonAsync<ShipServiceResponse>())!;
        Assert.Equal((500, 200L), (repair.Ship.HullHp, repair.Cost)); // 100 HP × 2 Gold
        var again = (await (await Service(backend, p, ship, "REPAIR", key: key)).Content.ReadFromJsonAsync<ShipServiceResponse>())!;
        Assert.True(again.Duplicate);
        Assert.Equal(repair.Gold, again.Gold);

        var heal = (await (await Service(backend, p, ship, "HEAL")).Content.ReadFromJsonAsync<ShipServiceResponse>())!;
        Assert.Equal((5, 0, 40L), (heal.Ship.Crew, heal.Ship.Injured, heal.Cost));
        var hire = (await (await Service(backend, p, ship, "HIRE", 50)).Content.ReadFromJsonAsync<ShipServiceResponse>())!;
        Assert.Equal((12, 350L), (hire.Ship.Crew, hire.Cost)); // nur bis zur Kapazität: 7 × 50
        var food = (await (await Service(backend, p, ship, "PROVISIONS", 500)).Content.ReadFromJsonAsync<ShipServiceResponse>())!;
        Assert.Equal((200, 20L), (food.Ship.Provisions, food.Cost));
        Assert.Equal(HttpStatusCode.Conflict, (await Service(backend, p, ship, "REPAIR")).StatusCode); // bereits ganz
        Assert.Equal(10_000 - 200 - 40 - 350 - 20, (await State(backend, p)).Gold);
    }

    [Fact]
    public async Task Crew_cannot_grow_and_services_need_the_shipyard()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InZone(backend, "CITY_ATHENS");
        var ship = (await (await Buy(backend, p, "DEV_STARTER_SHIP")).Content.ReadFromJsonAsync<BuyShipResponse>())!.Ship;
        Assert.Equal(HttpStatusCode.Conflict, (await SaveShip(backend, p, ship.InstanceId, 500, 5, 200, injured: 5)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Service(backend, p, ship, "TELEPORT")).StatusCode);

        await using var test = await TestBackend.StartAsync(db);
        var q = await InZone(test, "DEV_TESTZONE");
        var res = await test.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{q.CharacterId}/ships/{ship.InstanceId}/services",
            new ShipServiceRequest(q.AccountId, q.ServerId, "ATHENS_SHIPYARD", "REPAIR", 0, Guid.NewGuid()));
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Player(long AccountId, long CharacterId, string ServerId = "");

    private static async Task<Player> NewCharacter(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        return new Player(login.AccountId, (await backend.CreateCharacterAsync(login.Ticket)).CharacterId);
    }

    private static async Task<Player> InZone(TestBackend backend, string zone)
    {
        var p = await NewCharacter(backend);
        return p with { ServerId = await backend.EnterZoneAsync(p.CharacterId, p.AccountId, zone) };
    }

    private async Task<long> Admin(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        await db.ExecAsync("UPDATE accounts SET admin_level = 1 WHERE account_id = @a", ("a", login.AccountId));
        return login.AccountId;
    }

    private static Task<HttpResponseMessage> Buy(TestBackend backend, Player p, string ship, Guid? key = null, string? server = null) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/ships",
            new BuyShipRequest(p.AccountId, server ?? p.ServerId, "ATHENS_SHIPYARD", ship, key ?? Guid.NewGuid()));

    private static Task<HttpResponseMessage> GiveGold(TestBackend backend, long admin, Player p, long amount, Guid key) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/gold",
            new AdminGoldRequest(admin, amount, key, null, "203.0.113.9", "zone-test"));

    private static Task<HttpResponseMessage> SaveShip(TestBackend backend, Player p, long instance, int hull, int crew, int provisions,
        int? injured = null) =>
        backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/ships/{instance}/state",
            new SaveShipRequest(p.AccountId, p.ServerId, hull, crew, provisions, injured));

    private static Task<HttpResponseMessage> Service(TestBackend backend, Player p, ShipState ship, string kind, int amount = 0, Guid? key = null) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/ships/{ship.InstanceId}/services",
            new ShipServiceRequest(p.AccountId, p.ServerId, "ATHENS_SHIPYARD", kind, amount, key ?? Guid.NewGuid()));

    private static async Task<CharacterState> State(TestBackend backend, Player p) =>
        (await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{p.CharacterId}/state?accountId={p.AccountId}"))!;
}
