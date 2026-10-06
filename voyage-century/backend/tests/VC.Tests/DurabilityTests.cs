using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 8, Iteration 3 (Backend-Seite): Kills nutzen die getragene Waffe ab, ein Tod alle getragenen Teile; kaputte Teile
/// geben keine Werte und eine kaputte Waffe gilt als keine; Reparatur beim Händler kostet Gold nach Seltenheit, genau einmal.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class DurabilityTests(PostgresFixture db)
{
    private static readonly Dictionary<string, string?> InAthens = new() { ["World:StartZoneId"] = "CITY_ATHENS" };

    [Fact]
    public async Task Kills_wear_the_weapon_and_deaths_wear_everything_worn()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InAthensZone(backend);
        var sword = await Grant(backend, p, "DEV_SWORD");
        var hat = await Grant(backend, p, "DEV_ARMOR_HAT");
        await Equip(backend, p, sword);
        var start = await Equip(backend, p, hat);
        Assert.Equal((100, 100, "COMMON"), (Item(start, sword).Durability, Item(start, sword).DurabilityMax, Item(start, sword).Rarity));

        var key = Guid.NewGuid();
        var kill = await Kill(backend, p, key);
        Assert.Equal(99, Item(kill.Inventory!, sword).Durability);
        Assert.Equal(60, Item(kill.Inventory!, hat).Durability); // Rüstung nutzt sich beim Kill nicht ab
        Assert.True((await Kill(backend, p, key)).Duplicate);
        Assert.Equal(99, Item(await GetInventory(backend, p), sword).Durability);

        var deathKey = Guid.NewGuid();
        var death = await Ok(await Death(backend, p, deathKey));
        Assert.Equal((89, 54), (Item(death, sword).Durability, Item(death, hat).Durability)); // je 10 % des Maximums
        Assert.True((await Ok(await Death(backend, p, deathKey))).Duplicate);
        Assert.Equal(54, Item(await GetInventory(backend, p), hat).Durability);

        await db.ExecAsync("UPDATE item_instances SET durability = 0 WHERE item_instance_id = @i", ("i", hat));
        Assert.Equal(StatBonus.Zero, (await GetInventory(backend, p)).Bonus); // kaputt: keine Werte
        await db.ExecAsync("UPDATE item_instances SET durability = 0 WHERE item_instance_id = @i", ("i", sword));
        Assert.Null((await State(backend, p)).EquippedWeapon); // kaputte Waffe gilt als keine
        Assert.Null((await Kill(backend, p, Guid.NewGuid())).Inventory); // kaputt nutzt sich nicht weiter ab

        var stranger = await InAthensZone(backend);
        Assert.Equal(HttpStatusCode.NotFound, (await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/death",
            new DeathRequest(stranger.AccountId, stranger.ServerId, Guid.NewGuid()))).StatusCode);
    }

    [Fact]
    public async Task Repairs_cost_gold_by_rarity_at_a_merchant_once()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var p = await InAthensZone(backend);
        await GiveGold(backend, p, 100);
        var sword = await Grant(backend, p, "DEV_SWORD");
        var hat = await Grant(backend, p, "DEV_ARMOR_HAT");
        var loose = await Grant(backend, p, "DEV_ARMOR_COAT");
        await Equip(backend, p, sword);
        await Equip(backend, p, hat);
        await db.ExecAsync("UPDATE item_instances SET durability = 70 WHERE item_instance_id = @i", ("i", sword));
        await db.ExecAsync("UPDATE item_instances SET durability = 40 WHERE item_instance_id = @i", ("i", hat));
        await db.ExecAsync("UPDATE item_instances SET durability = 0 WHERE item_instance_id = @i", ("i", loose));

        Assert.Equal(HttpStatusCode.BadRequest, (await Repair(backend, p, 0, "DEV_LONDON_MERCHANT")).StatusCode); // nicht hier
        var key = Guid.NewGuid();
        var all = await Ok(await Repair(backend, p, 0, "DEV_ATHENS_MERCHANT", key));
        Assert.Equal((55L, 45L), (all.Total, all.Gold)); // Schwert 30 × 1,0 + Hut 20 × 1,25 (UNCOMMON)
        Assert.Equal((100, 60), (Item(all, sword).Durability, Item(all, hat).Durability));
        Assert.Equal(0, Item(all, loose).Durability); // nur Getragenes
        var again = await Ok(await Repair(backend, p, 0, "DEV_ATHENS_MERCHANT", key));
        Assert.Equal((true, 45L), (again.Duplicate, again.Gold));

        Assert.Equal(HttpStatusCode.Conflict, (await Repair(backend, p, 0, "DEV_ATHENS_MERCHANT")).StatusCode); // nichts kaputt
        Assert.Equal(HttpStatusCode.Conflict, (await Repair(backend, p, loose, "DEV_ATHENS_MERCHANT")).StatusCode); // 100 > 45 Gold
        await GiveGold(backend, p, 100);
        var coat = await Ok(await Repair(backend, p, loose, "DEV_ATHENS_MERCHANT"));
        Assert.Equal((100L, 45L, 80), (coat.Total, coat.Gold, Item(coat, loose).Durability));
        Assert.Equal(155L, await db.ScalarAsync<long>(
            "SELECT -sum(delta)::bigint FROM currency_ledger WHERE character_id = @c AND reason = 'ITEM_REPAIR'", ("c", p.CharacterId)));
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Player(long AccountId, long CharacterId, string ServerId = "");

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

    private async Task<long> Grant(TestBackend backend, Player p, string item)
    {
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/inventory/grant",
            new AdminItemRequest(await Admin(backend), item, 1, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
        return (await Ok(res)).Inventory.Items.Where(i => i.Code == item).Max(i => i.InstanceId);
    }

    private async Task GiveGold(TestBackend backend, Player p, long amount)
    {
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/gold",
            new AdminGoldRequest(await Admin(backend), amount, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
        res.EnsureSuccessStatusCode();
    }

    private static async Task<InventoryResponse> Equip(TestBackend backend, Player p, long instance)
    {
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/inventory/equip",
            new ItemCommandRequest(p.AccountId, p.ServerId, instance));
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<InventoryResponse>())!;
    }

    private static async Task<KillResponse> Kill(TestBackend backend, Player p, Guid key)
    {
        var res = await backend.GameInternal.PostAsJsonAsync("/internal/v1/combat/kills",
            new KillRequest(key, p.ServerId, "CITY_ATHENS", p.CharacterId, p.AccountId, "MONSTER", "DEV_TRAINING_DUMMY", null, null));
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<KillResponse>())!;
    }

    private static Task<HttpResponseMessage> Death(TestBackend backend, Player p, Guid key) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/death", new DeathRequest(p.AccountId, p.ServerId, key));

    private static Task<HttpResponseMessage> Repair(TestBackend backend, Player p, long instance, string npc, Guid? key = null) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/inventory/repair",
            new RepairRequest(p.AccountId, p.ServerId, instance, npc, key ?? Guid.NewGuid()));

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

    private static async Task<CharacterState> State(TestBackend backend, Player p) =>
        (await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{p.CharacterId}/state?accountId={p.AccountId}"))!;
}
