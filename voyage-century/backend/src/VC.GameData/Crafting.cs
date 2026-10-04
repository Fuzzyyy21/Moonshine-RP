using System.Text.Json;
using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Logging;

namespace VC.GameData;

public sealed record RecipeMaterial(string Code, string? NameDe, int Quantity, int Have);
public sealed record RecipeInfo(
    string Code, string? NameDe, string Skill, short RequiredLevel, short SkillLevel, List<RecipeMaterial> Materials, string ResultCode,
    string? ResultNameDe, int ResultQuantity, long GoldCost, bool CanCraft);
public sealed record CraftRequest(long AccountId, string? ServerId, string? RecipeCode, int Times, Guid Key);
public sealed record GatherRequest(long AccountId, string? ServerId, string? NodeCode, Guid Key);
/// <summary>Ergebnis von Sammeln oder Herstellen. Lost: Sammelausbeute, die nicht ins Inventar passte.</summary>
public sealed record CraftResponse(
    bool Duplicate, string ItemCode, string? NameDe, int Quantity, int Lost, long GoldCost, long Gold, SkillProgress? Skill,
    InventoryResponse Inventory);

/// <summary>
/// Sammeln und Herstellen [DESIGN]. Der Zonen-Server entscheidet, dass ein Spieler an einem Sammelpunkt fertig gesammelt hat
/// (Abstand, Sammelzeit, Nachwachsen); das Backend prüft Zone und Skillstufe und würfelt die Ausbeute. Herstellen prüft und
/// verbraucht alles im Backend: Skillstufe, Material, Gebühr (Senke CRAFT_FEE) – alles oder nichts in einer Transaktion.
/// </summary>
public static class CraftingEndpoints
{
    private const int MaxTimes = 50;

    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapGet("/characters/{characterId:long}/recipes", Recipes);
        internalApi.MapPost("/characters/{characterId:long}/craft", Craft);
        internalApi.MapPost("/characters/{characterId:long}/gather", Gather);
    }

    private sealed record Recipe(
        int Id, string Code, string? NameDe, short SkillId, string Skill, short RequiredLevel, int ResultItemId, string ResultCode,
        string? ResultNameDe, int ResultQuantity, long GoldCost, long? SkillXp, List<(int ItemId, string Code, string? NameDe, int Quantity)> Materials);

    private static async Task<IResult> Recipes(
        long characterId, long accountId, NpgsqlDataSource db, IOptions<ContentOptions> content, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, accountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        var have = Count(await InventoryEndpoints.Slots(conn, tx, characterId, ct));
        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        var list = new List<RecipeInfo>();
        foreach (var r in await LoadRecipes(conn, tx, null, content.Value.AllowDevContent, ct))
        {
            var level = await SkillLevel(conn, tx, characterId, r.SkillId, ct);
            var materials = r.Materials.Select(m => new RecipeMaterial(m.Code, m.NameDe, m.Quantity, have.GetValueOrDefault(m.ItemId))).ToList();
            var canCraft = level >= r.RequiredLevel && gold >= r.GoldCost && materials.All(m => m.Have >= m.Quantity);
            list.Add(new RecipeInfo(r.Code, r.NameDe, r.Skill, r.RequiredLevel, level, materials, r.ResultCode, r.ResultNameDe,
                r.ResultQuantity, r.GoldCost, canCraft));
        }
        await tx.CommitAsync(ct);
        return Results.Ok(list);
    }

    private static async Task<IResult> Craft(
        long characterId, CraftRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content, IOptions<ProgressionOptions> progression,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || string.IsNullOrEmpty(req.RecipeCode) || req.Times is < 1 or > MaxTimes || req.Key == Guid.Empty)
        {
            return Problem(StatusCodes.Status400BadRequest, $"serverId, recipeCode, times (1 … {MaxTimes}) und key sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await Duplicate(conn, tx, characterId, req.Key, content.Value.AllowDevContent, ct) is { } duplicate)
        {
            return duplicate;
        }
        if (await WorldEndpoints.PresenceZone(conn, tx, characterId, req.ServerId, ct) is null)
        {
            return Problem(StatusCodes.Status409Conflict, "Charakter ist nicht auf diesem Server");
        }
        if ((await LoadRecipes(conn, tx, req.RecipeCode, content.Value.AllowDevContent, ct)).FirstOrDefault() is not { } recipe)
        {
            return Problem(StatusCodes.Status400BadRequest, "Rezept unbekannt oder nicht freigegeben");
        }
        var level = await SkillLevel(conn, tx, characterId, recipe.SkillId, ct);
        if (level < recipe.RequiredLevel)
        {
            return Problem(StatusCodes.Status409Conflict, $"{recipe.Skill} Stufe {recipe.RequiredLevel} nötig (du hast {level})");
        }
        var slots = await InventoryEndpoints.Slots(conn, tx, characterId, ct);
        var missing = CraftingRules.Missing(recipe.Materials.Select(m => new MaterialNeed(m.ItemId, m.Quantity)), req.Times, Count(slots));
        if (missing.Count > 0)
        {
            var names = recipe.Materials.ToDictionary(m => m.ItemId, m => m.NameDe ?? m.Code);
            return Problem(StatusCodes.Status409Conflict, "Es fehlt: " + string.Join(", ", missing.Select(m => $"{m.Quantity} × {names[m.ItemId]}")));
        }
        var fee = checked(recipe.GoldCost * req.Times);
        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        if (gold < fee)
        {
            return Problem(StatusCodes.Status409Conflict, $"Nicht genug Gold für die Gebühr ({gold} von {fee})");
        }

        // Erst verbrauchen (macht Plätze frei), dann das Ergebnis einlagern; passt es nicht, wird alles zurückgerollt.
        foreach (var m in recipe.Materials)
        {
            foreach (var (instanceId, newQuantity) in CraftingRules.PlanConsume(slots, m.ItemId, m.Quantity * req.Times)!)
            {
                await InventoryEndpoints.Exec(conn, tx, newQuantity == 0
                    ? "DELETE FROM item_instances WHERE item_instance_id = @id"
                    : "UPDATE item_instances SET quantity = @q WHERE item_instance_id = @id", ct, ("id", instanceId), ("q", newQuantity));
            }
        }
        var total = checked(recipe.ResultQuantity * req.Times);
        var placed = await InventoryEndpoints.AddItems(conn, tx, characterId, recipe.ResultItemId, total, "CRAFT", req.RecipeCode,
            content.Value.AllowDevContent, ct);
        if (placed < total)
        {
            return Problem(StatusCodes.Status409Conflict, "Inventar voll – nichts hergestellt");
        }
        if (fee > 0)
        {
            gold = await ShipEndpoints.Book(conn, tx, characterId, -fee, "CRAFT_FEE", "SINK", req.Key, req.ServerId, ct);
        }
        SkillProgress? skill = null;
        if (recipe.SkillXp is > 0)
        {
            skill = await ProgressionEndpoints.ApplySkillXp(conn, tx, characterId, recipe.SkillId, recipe.Skill,
                new GrantRequest(req.AccountId, recipe.SkillXp.Value * req.Times, $"craft:{recipe.Code}", req.Key, req.ServerId),
                progression.Value.AllowDevCurves, ct);
        }
        await InventoryEndpoints.RecordOperation(conn, tx, req.Key, characterId, "CRAFT",
            new Stored(recipe.ResultCode, recipe.ResultNameDe, total, 0, fee), req.ServerId, ct);
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("CRAFT", req.AccountId, characterId,
            NewValue: new { recipe = recipe.Code, times = req.Times, result = recipe.ResultCode, quantity = total, fee }), identity.Value.InstanceId, ct);
        var inventory = await InventoryEndpoints.Load(conn, tx, characterId, content.Value.AllowDevContent, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new CraftResponse(false, recipe.ResultCode, recipe.ResultNameDe, total, 0, fee, gold, skill, inventory));
    }

    private static async Task<IResult> Gather(
        long characterId, GatherRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content, IOptions<ProgressionOptions> progression,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || string.IsNullOrEmpty(req.NodeCode) || req.Key == Guid.Empty)
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId, nodeCode und key sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await Duplicate(conn, tx, characterId, req.Key, content.Value.AllowDevContent, ct) is { } duplicate)
        {
            return duplicate;
        }
        var zone = await WorldEndpoints.PresenceZone(conn, tx, characterId, req.ServerId, ct);
        if (zone is null)
        {
            return Problem(StatusCodes.Status409Conflict, "Charakter ist nicht auf diesem Server");
        }
        short skillId, required;
        string skill, itemCode;
        string? itemName;
        int itemId, min, max;
        long? skillXp;
        await using (var cmd = new NpgsqlCommand(
            """
            SELECT n.skill_id, s.code, n.required_level, n.item_id, i.code, i.name_de, n.min_qty, n.max_qty, n.skill_xp
            FROM gather_nodes n JOIN gather_node_zones z USING (gather_node_id) JOIN skills s USING (skill_id) JOIN items i ON i.item_id = n.item_id
            WHERE n.code = @code AND z.zone_id = @zone AND ((NOT n.is_dev AND NOT i.is_dev) OR @dev)
            """, conn, tx))
        {
            cmd.Parameters.AddWithValue("code", req.NodeCode);
            cmd.Parameters.AddWithValue("zone", zone);
            cmd.Parameters.AddWithValue("dev", content.Value.AllowDevContent);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
            {
                return Problem(StatusCodes.Status400BadRequest, "Diesen Sammelpunkt gibt es in dieser Zone nicht");
            }
            (skillId, skill, required, itemId, itemCode, itemName, min, max, skillXp) = (r.GetInt16(0), r.GetString(1), r.GetInt16(2),
                r.GetInt32(3), r.GetString(4), r.IsDBNull(5) ? null : r.GetString(5), r.GetInt32(6), r.GetInt32(7),
                r.IsDBNull(8) ? null : r.GetInt64(8));
        }
        var level = await SkillLevel(conn, tx, characterId, skillId, ct);
        if (level < required)
        {
            return Problem(StatusCodes.Status409Conflict, $"{skill} Stufe {required} nötig (du hast {level})");
        }
        var quantity = CraftingRules.RollYield(min, max, Random.Shared);
        var placed = await InventoryEndpoints.AddItems(conn, tx, characterId, itemId, quantity, "DROP", req.NodeCode,
            content.Value.AllowDevContent, ct);
        if (placed == 0)
        {
            return Problem(StatusCodes.Status409Conflict, "Inventar voll");
        }
        SkillProgress? progress = null;
        if (skillXp is > 0)
        {
            progress = await ProgressionEndpoints.ApplySkillXp(conn, tx, characterId, skillId, skill,
                new GrantRequest(req.AccountId, skillXp.Value, $"gather:{req.NodeCode}", req.Key, req.ServerId), progression.Value.AllowDevCurves, ct);
        }
        await InventoryEndpoints.RecordOperation(conn, tx, req.Key, characterId, "GATHER",
            new Stored(itemCode, itemName, quantity, quantity - placed, 0), req.ServerId, ct);
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("GATHER", req.AccountId, characterId,
            NewValue: new { node = req.NodeCode, zone, item = itemCode, quantity, placed }), identity.Value.InstanceId, ct);
        var inventory = await InventoryEndpoints.Load(conn, tx, characterId, content.Value.AllowDevContent, ct);
        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new CraftResponse(false, itemCode, itemName, quantity, quantity - placed, 0, gold, progress, inventory));
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    /// <summary>Was im Operationsprotokoll steht, um Wiederholungen dieselbe Antwort zu geben.</summary>
    private sealed record Stored(string ItemCode, string? NameDe, int Quantity, int Lost, long GoldCost);

    private static async Task<IResult?> Duplicate(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, Guid key, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            "SELECT result::text FROM inventory_operations WHERE op_key = @key AND character_id = @chr AND kind IN ('CRAFT', 'GATHER')",
            conn, tx);
        cmd.Parameters.AddWithValue("key", key);
        cmd.Parameters.AddWithValue("chr", characterId);
        if (await cmd.ExecuteScalarAsync(ct) is not string json || JsonSerializer.Deserialize<Stored>(json) is not { } stored)
        {
            return null;
        }
        return Results.Ok(new CraftResponse(true, stored.ItemCode, stored.NameDe, stored.Quantity, stored.Lost, stored.GoldCost,
            await ShipEndpoints.LoadGold(conn, tx, characterId, ct), null, await InventoryEndpoints.Load(conn, tx, characterId, allowDev, ct)));
    }

    private static Dictionary<int, int> Count(IEnumerable<InventorySlot> slots) =>
        slots.GroupBy(s => s.ItemId).ToDictionary(g => g.Key, g => g.Sum(s => s.Quantity));

    /// <summary>Stufe eines Skills; ohne Fortschrittszeile Stufe 1 (Startstufe).</summary>
    private static async Task<short> SkillLevel(NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, short skillId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("SELECT level FROM skill_progress WHERE character_id = @chr AND skill_id = @sk", conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        cmd.Parameters.AddWithValue("sk", skillId);
        return await cmd.ExecuteScalarAsync(ct) as short? ?? 1;
    }

    private static async Task<List<Recipe>> LoadRecipes(
        NpgsqlConnection conn, NpgsqlTransaction tx, string? code, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT r.recipe_id, r.code, r.name_de, r.required_skill_id, s.code, coalesce(r.required_level, 1), r.result_item_id, ri.code,
                   ri.name_de, r.result_quantity, coalesce(r.gold_cost, 0), r.skill_xp, m.item_id, mi.code, mi.name_de, m.quantity
            FROM recipes r
            JOIN skills s ON s.skill_id = r.required_skill_id
            JOIN items ri ON ri.item_id = r.result_item_id
            JOIN recipe_materials m ON m.recipe_id = r.recipe_id
            JOIN items mi ON mi.item_id = m.item_id
            WHERE (@code::text IS NULL OR r.code = @code) AND (NOT r.is_dev OR @dev)
            ORDER BY r.code, mi.code
            """, conn, tx);
        cmd.Parameters.AddWithValue("code", (object?)code ?? DBNull.Value);
        cmd.Parameters.AddWithValue("dev", allowDev);
        var recipes = new List<Recipe>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            if (recipes.Count == 0 || recipes[^1].Id != r.GetInt32(0))
            {
                recipes.Add(new Recipe(r.GetInt32(0), r.GetString(1), r.IsDBNull(2) ? null : r.GetString(2), r.GetInt16(3), r.GetString(4),
                    r.GetInt16(5), r.GetInt32(6), r.GetString(7), r.IsDBNull(8) ? null : r.GetString(8), r.GetInt32(9), r.GetInt64(10),
                    r.IsDBNull(11) ? null : r.GetInt64(11), []));
            }
            recipes[^1].Materials.Add((r.GetInt32(12), r.GetString(13), r.IsDBNull(14) ? null : r.GetString(14), r.GetInt32(15)));
        }
        return recipes;
    }

    private static IResult Problem(int status, string title) => Results.Problem(statusCode: status, title: title);
}
