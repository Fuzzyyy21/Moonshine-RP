using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 6, Iteration 4 (Backend-Seite): Angebote beim Auktionator einstellen (Gebühr), finden und kaufen (Preis an den
/// Verkäufer abzüglich Steuer, Steuer als Senke), eigene zurückziehen und Abgelaufenes abholen – jeder Schritt genau einmal.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class AuctionTests(PostgresFixture db)
{
    private const string Npc = "DEV_ATHENS_AUCTIONEER";
    private static readonly Dictionary<string, string?> InAthens = new() { ["World:StartZoneId"] = "CITY_ATHENS" };

    [Fact]
    public async Task Listing_and_buying_moves_item_and_gold_with_fee_and_tax()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var seller = await Player(backend, gold: 100);
        var buyer = await Player(backend, gold: 2000);
        var cloth = Find(await Grant(backend, seller, "DEV_MAT_CLOTH", 20), "DEV_MAT_CLOTH");

        var listed = await ReadList(await List(backend, seller, cloth.InstanceId, 10, 1000));
        Assert.Equal((20L, 80L), (listed.Fee, listed.Gold));
        Assert.Equal(10, Find(listed.Inventory, "DEV_MAT_CLOTH").Quantity);

        var offers = await Search(backend, buyer, "DEV_MAT_CLOTH");
        var offer = offers.Single(o => o.ListingId == listed.ListingId);
        Assert.Equal((10, 1000L, false, "OPEN"), (offer.Quantity, offer.Price, offer.Mine, offer.Status));

        var key = Guid.NewGuid();
        var bought = await ReadItem(await Action(backend, buyer, listed.ListingId, "buy", key));
        Assert.Equal(1000L, bought.Gold);
        Assert.Equal(10, Find(bought.Inventory, "DEV_MAT_CLOTH").Quantity);
        var again = await ReadItem(await Action(backend, buyer, listed.ListingId, "buy", key));
        Assert.True(again.Duplicate);
        Assert.Equal(1000L, again.Gold);

        Assert.Equal(1030L, await Gold(seller)); // 80 + 1000 − 50 Steuer
        Assert.Equal(["ADMIN_GRANT/SOURCE/100", "AUCTION_FEE/SINK/-20", "AUCTION_SALE/TRANSFER/950"], await Ledger(seller));
        Assert.Equal(["ADMIN_GRANT/SOURCE/2000", "AUCTION_BUY/TRANSFER/-950", "AUCTION_TAX/SINK/-50"], await Ledger(buyer));
        Assert.DoesNotContain(await Search(backend, buyer, "DEV_MAT_CLOTH"), o => o.ListingId == listed.ListingId);
        Assert.Equal("SOLD", (await Mine(backend, seller)).Single(o => o.ListingId == listed.ListingId).Status);

        var late = await Player(backend, gold: 2000);
        Assert.Equal(HttpStatusCode.Conflict, (await Action(backend, late, listed.ListingId, "buy")).StatusCode);
    }

    [Fact]
    public async Task Single_items_keep_their_instance_and_own_offers_cannot_be_bought()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var seller = await Player(backend, gold: 100);
        var buyer = await Player(backend, gold: 100);
        var sword = Find(await Grant(backend, seller, "DEV_SWORD", 1), "DEV_SWORD");

        var listed = await ReadList(await List(backend, seller, sword.InstanceId, 1, 50));
        Assert.DoesNotContain(listed.Inventory.Items, i => i.Code == "DEV_SWORD");
        Assert.Equal(HttpStatusCode.Conflict, (await Action(backend, seller, listed.ListingId, "buy")).StatusCode);

        var bought = await ReadItem(await Action(backend, buyer, listed.ListingId, "buy"));
        Assert.Equal(sword.InstanceId, Find(bought.Inventory, "DEV_SWORD").InstanceId); // dasselbe Exemplar
        Assert.Equal(147L, await Gold(seller)); // 100 − 1 Gebühr + 50 − 2 Steuer (50 × 5 % = 2,5 → 2)
    }

    [Fact]
    public async Task Cancel_returns_the_item_and_keeps_the_fee_and_listings_are_limited()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var seller = await Player(backend, gold: 100);
        var cloth = Find(await Grant(backend, seller, "DEV_MAT_CLOTH", 20), "DEV_MAT_CLOTH");

        var ids = new List<long>();
        for (var i = 0; i < 10; i++)
        {
            ids.Add((await ReadList(await List(backend, seller, cloth.InstanceId, 1, 10))).ListingId);
        }
        Assert.Equal(HttpStatusCode.Conflict, (await List(backend, seller, cloth.InstanceId, 1, 10)).StatusCode); // höchstens 10

        var cancelled = await ReadItem(await Action(backend, seller, ids[0], "cancel"));
        Assert.Equal(11, Find(cancelled.Inventory, "DEV_MAT_CLOTH").Quantity); // 10 übrig + 1 zurück
        Assert.Equal(90L, cancelled.Gold);                                    // 10 × Mindestgebühr 1, nicht erstattet
        Assert.Equal("CANCELLED", (await Mine(backend, seller)).Single(o => o.ListingId == ids[0]).Status);
        Assert.Equal(HttpStatusCode.Conflict, (await Action(backend, seller, ids[0], "cancel")).StatusCode);

        var other = await Player(backend, gold: 100);
        Assert.Equal(HttpStatusCode.Conflict, (await Action(backend, other, ids[1], "cancel")).StatusCode); // fremdes Angebot
    }

    [Fact]
    public async Task Expired_offers_cannot_be_bought_and_are_collected_by_the_seller()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var seller = await Player(backend, gold: 100);
        var buyer = await Player(backend, gold: 100);
        var iron = Find(await Grant(backend, seller, "DEV_MAT_IRON", 5), "DEV_MAT_IRON");
        var listed = await ReadList(await List(backend, seller, iron.InstanceId, 5, 30));
        await db.ExecAsync("UPDATE market_listings SET expires_at = now() - INTERVAL '1 minute' WHERE listing_id = @id",
            ("id", listed.ListingId));

        Assert.Equal(HttpStatusCode.Conflict, (await Action(backend, buyer, listed.ListingId, "buy")).StatusCode);
        Assert.DoesNotContain(await Search(backend, buyer, null), o => o.ListingId == listed.ListingId);
        Assert.Equal("EXPIRED", (await Mine(backend, seller)).Single(o => o.ListingId == listed.ListingId).Status);

        var collected = (await (await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{seller.CharacterId}/auction/collect",
            new AuctionActionRequest(seller.AccountId, seller.ServerId, Npc, Guid.NewGuid()))).Content.ReadFromJsonAsync<AuctionCollectResponse>())!;
        Assert.Equal((1, 0), (collected.Returned, collected.Pending));
        Assert.Equal(5, Find(collected.Inventory, "DEV_MAT_IRON").Quantity);
    }

    [Fact]
    public async Task Only_the_auctioneer_of_the_own_zone_serves()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var seller = await Player(backend, gold: 100);
        var cloth = Find(await Grant(backend, seller, "DEV_MAT_CLOTH", 2), "DEV_MAT_CLOTH");
        foreach (var npc in new[] { "DEV_LONDON_AUCTIONEER", "DEV_ATHENS_MERCHANT" })
        {
            var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{seller.CharacterId}/auction/list",
                new AuctionListRequest(seller.AccountId, seller.ServerId, npc, cloth.InstanceId, 1, 10, Guid.NewGuid()));
            Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
        }
        Assert.Equal(HttpStatusCode.BadRequest, (await List(backend, seller, cloth.InstanceId, 1, 0)).StatusCode);
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Who(long AccountId, long CharacterId, string ServerId);

    private async Task<Who> Player(TestBackend backend, long gold)
    {
        var login = await backend.RegisterAndLoginAsync();
        var characterId = (await backend.CreateCharacterAsync(login.Ticket)).CharacterId;
        var p = new Who(login.AccountId, characterId, await backend.EnterZoneAsync(characterId, login.AccountId, "CITY_ATHENS"));
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/gold",
            new AdminGoldRequest(await Admin(backend), gold, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
        res.EnsureSuccessStatusCode();
        return p;
    }

    private async Task<long> Admin(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        await db.ExecAsync("UPDATE accounts SET admin_level = 1 WHERE account_id = @a", ("a", login.AccountId));
        return login.AccountId;
    }

    private async Task<InventoryResponse> Grant(TestBackend backend, Who p, string item, int quantity)
    {
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/inventory/grant",
            new AdminItemRequest(await Admin(backend), item, quantity, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<ItemOperationResponse>())!.Inventory;
    }

    private static InventoryItem Find(InventoryResponse inventory, string code) => inventory.Items.Single(i => i.Code == code);

    private static Task<HttpResponseMessage> List(TestBackend backend, Who p, long instance, int quantity, long price) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/auction/list",
            new AuctionListRequest(p.AccountId, p.ServerId, Npc, instance, quantity, price, Guid.NewGuid()));

    private static Task<HttpResponseMessage> Action(TestBackend backend, Who p, long listing, string action, Guid? key = null) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/auction/{listing}/{action}",
            new AuctionActionRequest(p.AccountId, p.ServerId, Npc, key ?? Guid.NewGuid()));

    private static async Task<List<AuctionListing>> Search(TestBackend backend, Who p, string? item) =>
        (await backend.GameInternal.GetFromJsonAsync<List<AuctionListing>>(
            $"/internal/v1/auction?characterId={p.CharacterId}&accountId={p.AccountId}{(item is null ? "" : $"&itemCode={item}")}"))!;

    private static async Task<List<AuctionListing>> Mine(TestBackend backend, Who p) =>
        (await backend.GameInternal.GetFromJsonAsync<List<AuctionListing>>(
            $"/internal/v1/characters/{p.CharacterId}/auction?accountId={p.AccountId}"))!;

    private Task<long> Gold(Who p) =>
        db.ScalarAsync<long>("SELECT balance FROM character_wallets WHERE character_id = @c AND currency_code = 'GOLD'", ("c", p.CharacterId));

    private Task<string[]> Ledger(Who p) =>
        db.ScalarAsync<string[]>(
            "SELECT array_agg(reason || '/' || flow || '/' || delta ORDER BY ledger_id) FROM currency_ledger WHERE character_id = @c",
            ("c", p.CharacterId));

    private static async Task<AuctionListResponse> ReadList(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<AuctionListResponse>())!;
    }

    private static async Task<AuctionItemResponse> ReadItem(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<AuctionItemResponse>())!;
    }
}
