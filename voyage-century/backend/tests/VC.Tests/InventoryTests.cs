using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 6, Iteration 2 (Backend-Seite): Inventar mit Plätzen und Stapeln, Waffe aus dem Inventar ausrüsten, Verkauf an
/// den Händler und Wegwerfen genau einmal, Beute aus Kills ins Inventar und Gold über den Ledger.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class InventoryTests(PostgresFixture db)
{
    private static readonly Dictionary<string, string?> InAthens = new() { ["World:StartZoneId"] = "CITY_ATHENS" };

    [Fact]
    public async Task Admin_grant_stacks_items_and_reports_what_does_not_fit()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InAthensZone(backend);

        var cloth = await Grant(backend, p, "DEV_MAT_CLOTH", 150);
        Assert.Equal(150, cloth.Placed);
        Assert.Equal(30, cloth.Inventory.Capacity);
        Assert.Equal([99, 51], cloth.Inventory.Items.Where(i => i.Code == "DEV_MAT_CLOTH").Select(i => i.Quantity));

        var key = Guid.NewGuid();
        var swords = await Grant(backend, p, "DEV_SWORD", 30, key); // 28 Plätze frei
        Assert.Equal(28, swords.Placed);
        Assert.Equal(2, swords.Lost);
        var again = await Grant(backend, p, "DEV_SWORD", 30, key);
        Assert.True(again.Duplicate);
        Assert.Equal(28, again.Placed);
        Assert.Equal(28, again.Inventory.Items.Count(i => i.Code == "DEV_SWORD"));
        Assert.Equal(2L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM admin_audit_log WHERE target_id = @c AND command = '/giveitem'", ("c", p.CharacterId.ToString())));

        var notAdmin = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/inventory/grant",
            new AdminItemRequest(p.AccountId, "DEV_SWORD", 1, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
        Assert.Equal(HttpStatusCode.Forbidden, notAdmin.StatusCode);
    }

    [Fact]
    public async Task Weapons_are_equipped_from_the_inventory_and_swap_places()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InAthensZone(backend);
        await Grant(backend, p, "DEV_MAT_CLOTH", 5);
        var sword = Find(await Grant(backend, p, "DEV_SWORD", 1), "DEV_SWORD");
        var pistol = Find(await Grant(backend, p, "DEV_PISTOL", 1), "DEV_PISTOL");
        Assert.Equal(("1", "2"), (sword.Slot, pistol.Slot));

        var equipped = await Inventory(await Post(backend, p, "equip", new ItemCommandRequest(p.AccountId, p.ServerId, sword.InstanceId)));
        Assert.Equal(("EQUIPMENT", "WEAPON"), (Find(equipped, "DEV_SWORD").Location, Find(equipped, "DEV_SWORD").Slot));
        Assert.Equal("DEV_SWORD", (await State(backend, p)).EquippedWeapon);

        var swapped = await Inventory(await Post(backend, p, "equip", new ItemCommandRequest(p.AccountId, p.ServerId, pistol.InstanceId)));
        Assert.Equal(("INVENTORY", "2"), (Find(swapped, "DEV_SWORD").Location, Find(swapped, "DEV_SWORD").Slot));
        Assert.Equal("WEAPON", Find(swapped, "DEV_PISTOL").Slot);

        var off = await Inventory(await Post(backend, p, "unequip", new ItemCommandRequest(p.AccountId, p.ServerId, 0)));
        Assert.Equal(("INVENTORY", "1"), (Find(off, "DEV_PISTOL").Location, Find(off, "DEV_PISTOL").Slot)); // erster freier Platz
        Assert.Null((await State(backend, p)).EquippedWeapon);
        Assert.Equal(HttpStatusCode.Conflict,
            (await Post(backend, p, "unequip", new ItemCommandRequest(p.AccountId, p.ServerId, 0))).StatusCode);

        var cloth = Find(off, "DEV_MAT_CLOTH");
        Assert.Equal(HttpStatusCode.BadRequest,
            (await Post(backend, p, "equip", new ItemCommandRequest(p.AccountId, p.ServerId, cloth.InstanceId))).StatusCode);
        var other = await InAthensZone(backend);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await Post(backend, other, "equip", new ItemCommandRequest(other.AccountId, other.ServerId, pistol.InstanceId))).StatusCode);
    }

    [Fact]
    public async Task Selling_to_the_merchant_and_discarding_happen_once()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InAthensZone(backend);
        var cloth = Find(await Grant(backend, p, "DEV_MAT_CLOTH", 10), "DEV_MAT_CLOTH");
        var key = Guid.NewGuid();

        var sold = await Operation(await Post(backend, p, "sell", Amount(p, cloth.InstanceId, 4, key, "DEV_ATHENS_MERCHANT")));
        Assert.Equal(12, sold.Total); // 3 Gold je Stoffrest
        Assert.Equal(12, sold.Gold);
        Assert.Equal(6, Find(sold.Inventory, "DEV_MAT_CLOTH").Quantity);
        var again = await Operation(await Post(backend, p, "sell", Amount(p, cloth.InstanceId, 4, key, "DEV_ATHENS_MERCHANT")));
        Assert.True(again.Duplicate);
        Assert.Equal(12, again.Gold);
        Assert.Equal(["ITEM_SELL/SOURCE"], await db.ScalarAsync<string[]>(
            "SELECT array_agg(reason || '/' || flow) FROM currency_ledger WHERE character_id = @c", ("c", p.CharacterId)));

        Assert.Equal(HttpStatusCode.BadRequest,  // Händler einer anderen Stadt
            (await Post(backend, p, "sell", Amount(p, cloth.InstanceId, 1, Guid.NewGuid(), "DEV_LONDON_MERCHANT"))).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict,
            (await Post(backend, p, "sell", Amount(p, cloth.InstanceId, 7, Guid.NewGuid(), "DEV_ATHENS_MERCHANT"))).StatusCode);

        var discarded = await Operation(await Post(backend, p, "discard", Amount(p, cloth.InstanceId, 6, Guid.NewGuid())));
        Assert.DoesNotContain(discarded.Inventory.Items, i => i.Code == "DEV_MAT_CLOTH");
        Assert.Equal(12, discarded.Gold);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await Post(backend, p, "discard", Amount(p, cloth.InstanceId, 1, Guid.NewGuid()))).StatusCode);
    }

    [Fact]
    public async Task Kill_loot_goes_to_the_inventory_and_gold_to_the_ledger_once()
    {
        await db.ExecAsync(
            """
            INSERT INTO loot_tables (code, gold_min, gold_max) VALUES ('TEST_LOOT', 10, 10) ON CONFLICT (code) DO NOTHING;
            INSERT INTO loot_entries (loot_table_id, item_id, chance, min_qty, max_qty)
            SELECT (SELECT loot_table_id FROM loot_tables WHERE code = 'TEST_LOOT'), item_id, 1, 2, 2 FROM items
            WHERE code IN ('DEV_MAT_IRON', 'DEV_AXE') ON CONFLICT DO NOTHING;
            INSERT INTO monsters (code, domain, xp_reward, loot_table_id)
            VALUES ('TEST_LOOT_MONSTER', 'LAND', 1, (SELECT loot_table_id FROM loot_tables WHERE code = 'TEST_LOOT'))
            ON CONFLICT (code) DO NOTHING;
            """);
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InAthensZone(backend);
        await Grant(backend, p, "DEV_SWORD", 29); // ein Platz frei: eine Axt passt nicht mehr
        var key = Guid.NewGuid();

        // Beute in Code-Reihenfolge: die erste Axt nimmt den letzten Platz, der Rest geht verloren.
        var kill = await Kill(backend, p, key);
        Assert.Equal(10, kill.LootGold);
        Assert.Equal([new LootDrop("DEV_AXE", "Übungsaxt", 2, 1), new LootDrop("DEV_MAT_IRON", "Eisenstück (Test)", 2, 2)], kill.Loot!);
        var again = await Kill(backend, p, key);
        Assert.True(again.Duplicate);

        var inventory = await GetInventory(backend, p);
        Assert.Single(inventory.Items, i => i.Code == "DEV_AXE");
        Assert.DoesNotContain(inventory.Items, i => i.Code == "DEV_MAT_IRON");
        Assert.Equal(["LOOT_GOLD/SOURCE"], await db.ScalarAsync<string[]>(
            "SELECT array_agg(reason || '/' || flow) FROM currency_ledger WHERE character_id = @c", ("c", p.CharacterId)));
        Assert.Equal(1L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM combat_kills WHERE killer_character_id = @c AND loot IS NOT NULL", ("c", p.CharacterId)));
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Player(long AccountId, long CharacterId, string ServerId = "");

    private static async Task<Player> InAthensZone(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        var p = new Player(login.AccountId, (await backend.CreateCharacterAsync(login.Ticket)).CharacterId);
        return p with { ServerId = await backend.EnterZoneAsync(p.CharacterId, p.AccountId, "CITY_ATHENS") };
    }

    private async Task<ItemOperationResponse> Grant(TestBackend backend, Player p, string item, int quantity, Guid? key = null)
    {
        var login = await backend.RegisterAndLoginAsync();
        await db.ExecAsync("UPDATE accounts SET admin_level = 1 WHERE account_id = @a", ("a", login.AccountId));
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/inventory/grant",
            new AdminItemRequest(login.AccountId, item, quantity, key ?? Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
        return await Operation(res);
    }

    private static ItemAmountRequest Amount(Player p, long instance, int quantity, Guid key, string? npc = null) =>
        new(p.AccountId, p.ServerId, instance, quantity, key, npc);

    private static Task<HttpResponseMessage> Post<T>(TestBackend backend, Player p, string action, T body) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/inventory/{action}", body);

    private static InventoryItem Find(ItemOperationResponse op, string code) => Find(op.Inventory, code);

    private static InventoryItem Find(InventoryResponse inventory, string code) => inventory.Items.Single(i => i.Code == code);

    private static async Task<ItemOperationResponse> Operation(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<ItemOperationResponse>())!;
    }

    private static async Task<InventoryResponse> Inventory(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<InventoryResponse>())!;
    }

    private static async Task<InventoryResponse> GetInventory(TestBackend backend, Player p) =>
        (await backend.GameInternal.GetFromJsonAsync<InventoryResponse>(
            $"/internal/v1/characters/{p.CharacterId}/inventory?accountId={p.AccountId}"))!;

    private static async Task<CharacterState> State(TestBackend backend, Player p) =>
        (await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{p.CharacterId}/state?accountId={p.AccountId}"))!;

    private static async Task<KillResponse> Kill(TestBackend backend, Player p, Guid key)
    {
        var res = await backend.GameInternal.PostAsJsonAsync("/internal/v1/combat/kills",
            new KillRequest(key, "zone-test", "CITY_ATHENS", p.CharacterId, p.AccountId, "MONSTER", "TEST_LOOT_MONSTER", null, null));
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<KillResponse>())!;
    }
}
