using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 8, Iteration 2 (Backend-Seite): Sockel bohren (steigende Gebühr, bis zum Maximum des Teils), Edelsteine mit genau
/// einem Attribut einsetzen (verschiedene Attribute je Teil), verfeinern mit Stein der nächsten Stufe und höherem Edelstein;
/// alles genau einmal je Schlüssel, Fehlschläge verbrauchen nichts, die Werte zählen im Ausrüstungsbonus.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class ItemUpgradeTests(PostgresFixture db)
{
    private static readonly Dictionary<string, string?> InAthens = new() { ["World:StartZoneId"] = "CITY_ATHENS" };

    [Fact]
    public async Task Sockets_are_drilled_and_take_gems_with_different_attributes()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InAthensZone(backend);
        await GiveGold(backend, p, 1000);
        var sword = await Grant(backend, p, "DEV_SWORD", 1);
        var attack = await Grant(backend, p, "DEV_GEM_ATTACK_1", 2);
        var health = await Grant(backend, p, "DEV_GEM_HEALTH_1", 1);
        var cloth = await Grant(backend, p, "DEV_MAT_CLOTH", 1);

        var key = Guid.NewGuid();
        var first = await Ok(await Post(backend, p, "drill", new ItemUpgradeRequest(p.AccountId, p.ServerId, sword, key)));
        Assert.Equal((950L, 50L), (first.Gold, first.Total));
        Assert.Equal([null], Item(first, sword).Sockets!);
        var again = await Ok(await Post(backend, p, "drill", new ItemUpgradeRequest(p.AccountId, p.ServerId, sword, key)));
        Assert.True(again.Duplicate);
        Assert.Single(Item(again, sword).Sockets!);

        var socketed = await Ok(await Post(backend, p, "socket", Gem(p, sword, attack)));
        Assert.Equal(["DEV_GEM_ATTACK_1"], Item(socketed, sword).Sockets!);
        Assert.Equal(1, Item(socketed, attack).Quantity);
        Assert.Equal(HttpStatusCode.Conflict, (await Post(backend, p, "socket", Gem(p, sword, attack))).StatusCode); // kein freier Sockel

        Assert.Equal(850L, (await Ok(await Post(backend, p, "drill", Drill(p, sword)))).Gold);
        Assert.Equal(HttpStatusCode.Conflict, (await Post(backend, p, "socket", Gem(p, sword, attack))).StatusCode); // gleiches Attribut
        var two = await Ok(await Post(backend, p, "socket", Gem(p, sword, health)));
        Assert.Equal(["DEV_GEM_ATTACK_1", "DEV_GEM_HEALTH_1"], Item(two, sword).Sockets!);
        Assert.Equal(1, Item(two, attack).Quantity); // Fehlschläge verbrauchen nichts
        Assert.DoesNotContain(two.Inventory.Items, i => i.InstanceId == health);

        Assert.Equal(700L, (await Ok(await Post(backend, p, "drill", Drill(p, sword)))).Gold);
        Assert.Equal(HttpStatusCode.Conflict, (await Post(backend, p, "drill", Drill(p, sword))).StatusCode); // 3 von 3
        Assert.Equal(HttpStatusCode.BadRequest, (await Post(backend, p, "drill", Drill(p, cloth))).StatusCode); // kein Ausrüstungsteil
        Assert.Equal(HttpStatusCode.BadRequest, (await Post(backend, p, "socket", Gem(p, sword, cloth))).StatusCode); // kein Edelstein

        var equipped = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/inventory/equip",
            new ItemCommandRequest(p.AccountId, p.ServerId, sword));
        Assert.Equal(new StatBonus(25, 3, 0), (await equipped.Content.ReadFromJsonAsync<InventoryResponse>())!.Bonus);
        Assert.Equal(300L, await db.ScalarAsync<long>(
            "SELECT -sum(delta)::bigint FROM currency_ledger WHERE character_id = @c AND reason = 'SOCKET_DRILL'", ("c", p.CharacterId)));
    }

    [Fact]
    public async Task Refining_needs_the_next_stone_and_a_higher_gem_and_raises_the_stats()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InAthensZone(backend);
        await GiveGold(backend, p, 350);
        var hat = await Grant(backend, p, "DEV_ARMOR_HAT", 1);
        var stone1 = await Grant(backend, p, "DEV_REFINE_STONE_1", 1);
        var stone2 = await Grant(backend, p, "DEV_REFINE_STONE_2", 2);
        var gem1 = await Grant(backend, p, "DEV_GEM_DEFENSE_1", 1);
        var gem2 = await Grant(backend, p, "DEV_GEM_ATTACK_2", 1);
        var equip = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/inventory/equip",
            new ItemCommandRequest(p.AccountId, p.ServerId, hat)); // auch getragen verfeinerbar
        equip.EnsureSuccessStatusCode();

        Assert.Equal(HttpStatusCode.Conflict, (await Post(backend, p, "refine", Refine(p, hat, stone2, gem1))).StatusCode); // Stufe 1 nötig
        var one = await Ok(await Post(backend, p, "refine", Refine(p, hat, stone1, gem1)));
        Assert.Equal((250L, 100L, 1), (one.Gold, one.Total, Item(one, hat).Refinement));
        Assert.Equal(new StatBonus(0, 0, 4), one.Inventory.Bonus); // 2 + 1 × 2

        var gem1b = await Grant(backend, p, "DEV_GEM_DEFENSE_1", 1);
        Assert.Equal(HttpStatusCode.Conflict, (await Post(backend, p, "refine", Refine(p, hat, stone2, gem1b))).StatusCode); // Edelstein zu niedrig
        var two = await Ok(await Post(backend, p, "refine", Refine(p, hat, stone2, gem2)));
        Assert.Equal((50L, 200L, 2), (two.Gold, two.Total, Item(two, hat).Refinement));
        Assert.Equal(new StatBonus(0, 0, 6), two.Inventory.Bonus);
        Assert.Equal(1, Item(two, stone2).Quantity);

        await db.ExecAsync("UPDATE item_instances SET refine_gem_tier = 1 WHERE item_instance_id = @i", ("i", hat));
        var poor = await Post(backend, p, "refine", Refine(p, hat, stone2, gem1b)); // Stein passt nicht (Stufe 3 nötig)
        Assert.Equal(HttpStatusCode.Conflict, poor.StatusCode);
        Assert.Equal(1, Item(await GetInventory(backend, p), gem1b).Quantity);
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Player(long AccountId, long CharacterId, string ServerId = "");

    private static ItemUpgradeRequest Drill(Player p, long item) => new(p.AccountId, p.ServerId, item, Guid.NewGuid());

    private static ItemUpgradeRequest Gem(Player p, long item, long gem) => new(p.AccountId, p.ServerId, item, Guid.NewGuid(), gem);

    private static ItemUpgradeRequest Refine(Player p, long item, long stone, long gem) =>
        new(p.AccountId, p.ServerId, item, Guid.NewGuid(), gem, stone);

    private static async Task<Player> InAthensZone(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        var p = new Player(login.AccountId, (await backend.CreateCharacterAsync(login.Ticket)).CharacterId);
        return p with { ServerId = await backend.EnterZoneAsync(p.CharacterId, p.AccountId, "CITY_ATHENS") };
    }

    private async Task<long> Admin(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        await db.ExecAsync("UPDATE accounts SET admin_level = 1 WHERE account_id = @a", ("a", login.AccountId));
        return login.AccountId;
    }

    /// <summary>Legt das Item ins Inventar und gibt die Exemplarnummer des neuen Stapels zurück.</summary>
    private async Task<long> Grant(TestBackend backend, Player p, string item, int quantity)
    {
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/inventory/grant",
            new AdminItemRequest(await Admin(backend), item, quantity, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
        var op = await Ok(res);
        return op.Inventory.Items.Where(i => i.Code == item).Max(i => i.InstanceId);
    }

    private async Task GiveGold(TestBackend backend, Player p, long amount)
    {
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/gold",
            new AdminGoldRequest(await Admin(backend), amount, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
        res.EnsureSuccessStatusCode();
    }

    private static Task<HttpResponseMessage> Post(TestBackend backend, Player p, string action, ItemUpgradeRequest body) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/inventory/{action}", body);

    private static async Task<ItemOperationResponse> Ok(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<ItemOperationResponse>())!;
    }

    private static InventoryItem Item(ItemOperationResponse op, long instance) => Item(op.Inventory, instance);

    private static InventoryItem Item(InventoryResponse inventory, long instance) => inventory.Items.Single(i => i.InstanceId == instance);

    private static async Task<InventoryResponse> GetInventory(TestBackend backend, Player p) =>
        (await backend.GameInternal.GetFromJsonAsync<InventoryResponse>(
            $"/internal/v1/characters/{p.CharacterId}/inventory?accountId={p.AccountId}"))!;
}
