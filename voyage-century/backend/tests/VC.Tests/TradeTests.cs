using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 6, Iteration 1 (Backend-Seite): Handel nur beim Händler der eigenen Zone, Ware im Laderaum des aktiven Schiffs,
/// Gold im Ledger (Kauf Senke, Verkauf Quelle), jeder Handel genau einmal, Preisgefälle zwischen Häfen, Bestände füllen sich auf.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class TradeTests(PostgresFixture db)
{
    private static readonly Dictionary<string, string?> InAthens = new() { ["World:StartZoneId"] = "CITY_ATHENS" };

    [Fact]
    public async Task Buying_cheap_in_athens_and_selling_in_london_earns_gold()
    {
        await ResetMarkets();
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await Trader(backend, gold: 5000);

        var athens = await View(backend, p, "DEV_ATHENS_MERCHANT");
        var oilHere = athens.Goods.Single(g => g.Code == "DEV_GOOD_OIL");
        Assert.Equal(600, oilHere.Stock);
        Assert.Equal(50, athens.CargoCapacity); // Anfängerschiff
        Assert.Equal(0, athens.CargoUsed);

        var buy = await Read(await Trade(backend, p, "DEV_ATHENS_MERCHANT", "DEV_GOOD_OIL", "BUY", 30));
        Assert.False(buy.Duplicate);
        Assert.Equal(30, buy.InCargo);
        Assert.Equal(570, buy.Stock);
        Assert.Equal(5000 - buy.Total, buy.Gold);
        Assert.True(buy.Total >= 30 * oilHere.BuyPrice!.Value); // jede weitere Einheit kostet mindestens so viel

        p = await MoveTo(backend, p, "CITY_LONDON");
        var london = await View(backend, p, "DEV_LONDON_MERCHANT");
        Assert.Equal(30, london.Goods.Single(g => g.Code == "DEV_GOOD_OIL").InCargo);
        var sell = await Read(await Trade(backend, p, "DEV_LONDON_MERCHANT", "DEV_GOOD_OIL", "SELL", 30));
        Assert.Equal(0, sell.InCargo);
        Assert.Equal(0, sell.CargoUsed);
        Assert.True(sell.Total > buy.Total, $"Kauf {buy.Total}, Verkauf {sell.Total}");
        Assert.Equal(5000 - buy.Total + sell.Total, sell.Gold);

        Assert.Equal(["ADMIN_GRANT/SOURCE", "TRADE_BUY/SINK", "TRADE_SELL/SOURCE"], await db.ScalarAsync<string[]>(
            "SELECT array_agg(reason || '/' || flow ORDER BY ledger_id) FROM currency_ledger WHERE character_id = @c", ("c", p.CharacterId)));
        Assert.Equal(0L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM item_instances WHERE location_type = 'SHIP_CARGO' AND owner_character_id = @c", ("c", p.CharacterId)));
        Assert.Equal(2L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM game_event_log WHERE character_id = @c AND action LIKE 'TRADE_%'", ("c", p.CharacterId)));
    }

    [Fact]
    public async Task Same_key_trades_once_and_limits_are_enforced()
    {
        await ResetMarkets();
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await Trader(backend, gold: 1000);
        var key = Guid.NewGuid();

        var first = await Read(await Trade(backend, p, "DEV_ATHENS_MERCHANT", "DEV_GOOD_OIL", "BUY", 5, key));
        var again = await Read(await Trade(backend, p, "DEV_ATHENS_MERCHANT", "DEV_GOOD_OIL", "BUY", 5, key));
        Assert.True(again.Duplicate);
        Assert.Equal(first.Total, again.Total);
        Assert.Equal(first.Gold, again.Gold);
        Assert.Equal(5, again.InCargo);
        Assert.Equal(1L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM currency_ledger WHERE character_id = @c AND reason = 'TRADE_BUY'", ("c", p.CharacterId)));

        // Laderaum 50, schon 5 belegt.
        Assert.Equal(HttpStatusCode.Conflict, (await Trade(backend, p, "DEV_ATHENS_MERCHANT", "DEV_GOOD_OIL", "BUY", 46)).StatusCode);
        // Nicht genug Gold (Gewürze kosten über 240 je Einheit).
        Assert.Equal(HttpStatusCode.Conflict, (await Trade(backend, p, "DEV_ATHENS_MERCHANT", "DEV_GOOD_SPICE", "BUY", 10)).StatusCode);
        // Mehr verkaufen als an Bord.
        Assert.Equal(HttpStatusCode.Conflict, (await Trade(backend, p, "DEV_ATHENS_MERCHANT", "DEV_GOOD_OIL", "SELL", 6)).StatusCode);
        // Preisgrenze: höchstens 1 Gold für 5 Einheiten.
        Assert.Equal(HttpStatusCode.Conflict,
            (await Trade(backend, p, "DEV_ATHENS_MERCHANT", "DEV_GOOD_OIL", "BUY", 5, limit: 1)).StatusCode);
        // Händler einer anderen Stadt, unbekannte Ware, ungültige Seite.
        Assert.Equal(HttpStatusCode.BadRequest, (await Trade(backend, p, "DEV_LONDON_MERCHANT", "DEV_GOOD_OIL", "BUY", 1)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Trade(backend, p, "DEV_ATHENS_MERCHANT", "DEV_SWORD", "BUY", 1)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Trade(backend, p, "DEV_ATHENS_MERCHANT", "DEV_GOOD_OIL", "STEAL", 1)).StatusCode);

        var view = await View(backend, p, "DEV_ATHENS_MERCHANT");
        Assert.Equal(5, view.CargoUsed);
        Assert.Equal(first.Gold, view.Gold);
    }

    [Fact]
    public async Task Trading_needs_an_active_ship()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InZone(backend);
        await GiveGold(backend, p, 1000);
        Assert.Equal(HttpStatusCode.Conflict, (await Trade(backend, p, "DEV_ATHENS_MERCHANT", "DEV_GOOD_OIL", "BUY", 1)).StatusCode);
        var view = await View(backend, p, "DEV_ATHENS_MERCHANT");
        Assert.Null(view.ShipInstanceId);
        Assert.Equal(3, view.Goods.Count);
    }

    [Fact]
    public async Task Stock_recovers_towards_equilibrium_over_time()
    {
        await ResetMarkets();
        await db.ExecAsync(
            """
            UPDATE markets SET stock = 100, updated_at = now() - INTERVAL '30 minutes'
            WHERE item_id = (SELECT item_id FROM items WHERE code = 'DEV_GOOD_OIL')
              AND port_id = (SELECT port_id FROM npcs WHERE code = 'DEV_ATHENS_MERCHANT')
            """);
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await Trader(backend, gold: 1000);

        var oil = (await View(backend, p, "DEV_ATHENS_MERCHANT")).Goods.Single(g => g.Code == "DEV_GOOD_OIL");
        Assert.Equal(250, oil.Stock); // 300 je Stunde, halbe Stunde
        var bought = await Read(await Trade(backend, p, "DEV_ATHENS_MERCHANT", "DEV_GOOD_OIL", "BUY", 1));
        Assert.Equal(249, bought.Stock); // Auffüllen wird beim Handel fortgeschrieben
        Assert.Equal(249, await db.ScalarAsync<int>(
            """
            SELECT stock FROM markets WHERE item_id = (SELECT item_id FROM items WHERE code = 'DEV_GOOD_OIL')
              AND port_id = (SELECT port_id FROM npcs WHERE code = 'DEV_ATHENS_MERCHANT')
            """));
    }

    [Fact]
    public async Task Economy_summary_separates_sources_and_sinks()
    {
        await ResetMarkets();
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var before = (await backend.GameInternal.GetFromJsonAsync<EconomySummary>("/internal/v1/economy/summary?days=1"))!;
        var p = await Trader(backend, gold: 2000);
        var buy = await Read(await Trade(backend, p, "DEV_ATHENS_MERCHANT", "DEV_GOOD_WOOL", "BUY", 10));

        var after = (await backend.GameInternal.GetFromJsonAsync<EconomySummary>("/internal/v1/economy/summary?days=1"))!;
        Assert.Equal(before.Sources + 2000, after.Sources);
        Assert.Equal(before.Sinks + buy.Total, after.Sinks);
        Assert.Equal(after.Sources - after.Sinks, after.Net);
        Assert.Contains(after.Rows, r => r.Reason == "TRADE_BUY" && r.Flow == "SINK" && r.Gold < 0);
        Assert.Equal(HttpStatusCode.BadRequest, (await backend.GameInternal.GetAsync("/internal/v1/economy/summary?days=0")).StatusCode);
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Player(long AccountId, long CharacterId, string ServerId = "");

    private Task ResetMarkets() => db.ExecAsync("UPDATE markets SET stock = target_stock, updated_at = now()");

    private static async Task<Player> InZone(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        var p = new Player(login.AccountId, (await backend.CreateCharacterAsync(login.Ticket)).CharacterId);
        return p with { ServerId = await backend.EnterZoneAsync(p.CharacterId, p.AccountId, "CITY_ATHENS") };
    }

    /// <summary>Charakter in Athen mit Anfängerschiff (Laderaum 50) und Gold.</summary>
    private async Task<Player> Trader(TestBackend backend, long gold)
    {
        var p = await InZone(backend);
        await GiveGold(backend, p, gold);
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/ships",
            new BuyShipRequest(p.AccountId, p.ServerId, "ATHENS_SHIPYARD", "DEV_STARTER_SHIP", Guid.NewGuid()));
        res.EnsureSuccessStatusCode();
        return p;
    }

    private async Task GiveGold(TestBackend backend, Player p, long amount)
    {
        var login = await backend.RegisterAndLoginAsync();
        await db.ExecAsync("UPDATE accounts SET admin_level = 1 WHERE account_id = @a", ("a", login.AccountId));
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/gold",
            new AdminGoldRequest(login.AccountId, amount, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
        res.EnsureSuccessStatusCode();
    }

    /// <summary>Zonenwechsel ohne Seereise: Anwesenheit lösen und auf einem Server der Zielzone neu anmelden.</summary>
    private async Task<Player> MoveTo(TestBackend backend, Player p, string zone)
    {
        await db.ExecAsync("DELETE FROM character_presence WHERE character_id = @c", ("c", p.CharacterId));
        await db.ExecAsync("UPDATE characters SET zone_id = @z WHERE character_id = @c", ("z", zone), ("c", p.CharacterId));
        return p with { ServerId = await backend.EnterZoneAsync(p.CharacterId, p.AccountId, zone) };
    }

    private static async Task<MarketResponse> View(TestBackend backend, Player p, string npc) =>
        (await backend.GameInternal.GetFromJsonAsync<MarketResponse>(
            $"/internal/v1/characters/{p.CharacterId}/market?accountId={p.AccountId}&serverId={p.ServerId}&npcCode={npc}"))!;

    private static Task<HttpResponseMessage> Trade(TestBackend backend, Player p, string npc, string item, string side, int quantity,
        Guid? key = null, long? limit = null) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/trade",
            new TradeRequest(p.AccountId, p.ServerId, npc, item, side, quantity, key ?? Guid.NewGuid(), limit));

    private static async Task<TradeResponse> Read(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<TradeResponse>())!;
    }
}
