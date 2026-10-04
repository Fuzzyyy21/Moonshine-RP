using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 6, Iteration 3 (Backend-Seite): Sammeln nur an Punkten der eigenen Zone und ab der nötigen Skillstufe, Ausbeute
/// ins Inventar und Skill-XP; Herstellen verbraucht Material und Gebühr genau einmal, alles oder nichts.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class CraftingTests(PostgresFixture db)
{
    [Fact]
    public async Task Gathering_yields_items_and_skill_xp_once_per_key()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await InZone(backend, "DEV_TESTZONE");
        var key = Guid.NewGuid();

        var wood = await Read(await Gather(backend, p, "DEV_NODE_TREE", key));
        Assert.Equal("DEV_MAT_WOOD", wood.ItemCode);
        Assert.InRange(wood.Quantity, 2, 3);
        Assert.Equal(0, wood.Lost);
        Assert.Equal(wood.Quantity, wood.Inventory.Items.Single(i => i.Code == "DEV_MAT_WOOD").Quantity);
        Assert.Equal(("TIMBER", 10L), (wood.Skill!.Code, wood.Skill.Experience));

        var again = await Read(await Gather(backend, p, "DEV_NODE_TREE", key));
        Assert.True(again.Duplicate);
        Assert.Equal(wood.Quantity, again.Inventory.Items.Single(i => i.Code == "DEV_MAT_WOOD").Quantity);
        Assert.Equal(10L, await db.ScalarAsync<long>(
            "SELECT experience FROM skill_progress JOIN skills USING (skill_id) WHERE character_id = @c AND code = 'TIMBER'",
            ("c", p.CharacterId)));

        Assert.Equal(HttpStatusCode.Conflict, (await Gather(backend, p, "DEV_NODE_RICH_IRON")).StatusCode); // Bergbau 5 nötig
        Assert.Equal(HttpStatusCode.BadRequest, (await Gather(backend, p, "NO_SUCH_NODE")).StatusCode);
        await using var inAthens = await TestBackend.StartAsync(db, new Dictionary<string, string?> { ["World:StartZoneId"] = "CITY_ATHENS" });
        var athens = await InZone(inAthens, "CITY_ATHENS");
        Assert.Equal(HttpStatusCode.BadRequest, (await Gather(inAthens, athens, "DEV_NODE_TREE")).StatusCode); // nicht in dieser Zone
    }

    [Fact]
    public async Task Crafting_consumes_materials_and_fee_and_grants_skill_xp_once()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await InZone(backend, "DEV_TESTZONE");
        await Grant(backend, p, "DEV_MAT_IRON", 7);
        await Grant(backend, p, "DEV_MAT_WOOD", 2);
        await GiveGold(backend, p, 100);

        var recipes = (await backend.GameInternal.GetFromJsonAsync<List<RecipeInfo>>(
            $"/internal/v1/characters/{p.CharacterId}/recipes?accountId={p.AccountId}"))!;
        Assert.True(recipes.Single(r => r.Code == "DEV_RECIPE_SWORD").CanCraft);
        Assert.False(recipes.Single(r => r.Code == "DEV_RECIPE_AXE").CanCraft); // Schmieden 5 nötig
        Assert.Equal(7, recipes.Single(r => r.Code == "DEV_RECIPE_SWORD").Materials.Single(m => m.Code == "DEV_MAT_IRON").Have);

        var key = Guid.NewGuid();
        var swords = await Read(await Craft(backend, p, "DEV_RECIPE_SWORD", 2, key));
        Assert.Equal(("DEV_SWORD", 2, 20L, 80L), (swords.ItemCode, swords.Quantity, swords.GoldCost, swords.Gold));
        Assert.Equal(2, swords.Inventory.Items.Count(i => i.Code == "DEV_SWORD"));
        Assert.Equal(1, swords.Inventory.Items.Single(i => i.Code == "DEV_MAT_IRON").Quantity);
        Assert.DoesNotContain(swords.Inventory.Items, i => i.Code == "DEV_MAT_WOOD");
        Assert.Equal(("FOUNDRY", 60L), (swords.Skill!.Code, swords.Skill.Experience));

        var again = await Read(await Craft(backend, p, "DEV_RECIPE_SWORD", 2, key));
        Assert.True(again.Duplicate);
        Assert.Equal(80L, again.Gold);
        Assert.Equal(["ADMIN_GRANT/SOURCE", "CRAFT_FEE/SINK"], await db.ScalarAsync<string[]>(
            "SELECT array_agg(reason || '/' || flow ORDER BY ledger_id) FROM currency_ledger WHERE character_id = @c", ("c", p.CharacterId)));

        Assert.Equal(HttpStatusCode.Conflict, (await Craft(backend, p, "DEV_RECIPE_SWORD", 1)).StatusCode); // Material fehlt
        Assert.Equal(HttpStatusCode.Conflict, (await Craft(backend, p, "DEV_RECIPE_AXE", 1)).StatusCode);   // Stufe fehlt
        Assert.Equal(HttpStatusCode.BadRequest, (await Craft(backend, p, "NO_SUCH_RECIPE", 1)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Craft(backend, p, "DEV_RECIPE_SWORD", 0)).StatusCode);
    }

    [Fact]
    public async Task Crafting_into_a_full_inventory_changes_nothing()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await InZone(backend, "DEV_TESTZONE");
        await Grant(backend, p, "DEV_SWORD", 29);
        await Grant(backend, p, "DEV_MAT_CLOTH", 4); // letzter Platz; nach dem Nähen bleibt 1 Stoff und das Tuch braucht einen Platz

        var res = await Craft(backend, p, "DEV_RECIPE_CANVAS", 1);
        Assert.Equal(HttpStatusCode.Conflict, res.StatusCode);
        Assert.Equal(4, await db.ScalarAsync<int>(
            """
            SELECT quantity FROM item_instances JOIN items USING (item_id)
            WHERE owner_character_id = @c AND code = 'DEV_MAT_CLOTH'
            """, ("c", p.CharacterId)));
        Assert.Equal(0L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM skill_progress JOIN skills USING (skill_id) WHERE character_id = @c AND code = 'SEWING'", ("c", p.CharacterId)));
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Player(long AccountId, long CharacterId, string ServerId = "");

    private static async Task<Player> InZone(TestBackend backend, string zone)
    {
        var login = await backend.RegisterAndLoginAsync();
        var p = new Player(login.AccountId, (await backend.CreateCharacterAsync(login.Ticket)).CharacterId);
        return p with { ServerId = await backend.EnterZoneAsync(p.CharacterId, p.AccountId, zone) };
    }

    private async Task<long> Admin(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        await db.ExecAsync("UPDATE accounts SET admin_level = 1 WHERE account_id = @a", ("a", login.AccountId));
        return login.AccountId;
    }

    private async Task Grant(TestBackend backend, Player p, string item, int quantity)
    {
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/inventory/grant",
            new AdminItemRequest(await Admin(backend), item, quantity, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
        res.EnsureSuccessStatusCode();
    }

    private async Task GiveGold(TestBackend backend, Player p, long amount)
    {
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/gold",
            new AdminGoldRequest(await Admin(backend), amount, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
        res.EnsureSuccessStatusCode();
    }

    private static Task<HttpResponseMessage> Gather(TestBackend backend, Player p, string node, Guid? key = null) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/gather",
            new GatherRequest(p.AccountId, p.ServerId, node, key ?? Guid.NewGuid()));

    private static Task<HttpResponseMessage> Craft(TestBackend backend, Player p, string recipe, int times, Guid? key = null) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/craft",
            new CraftRequest(p.AccountId, p.ServerId, recipe, times, key ?? Guid.NewGuid()));

    private static async Task<CraftResponse> Read(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<CraftResponse>())!;
    }
}
