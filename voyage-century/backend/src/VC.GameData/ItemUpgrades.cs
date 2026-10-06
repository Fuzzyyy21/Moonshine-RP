using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Logging;

namespace VC.GameData;

/// <summary>Bohren: InstanceId. Sockeln: dazu GemInstanceId. Verfeinern: dazu StoneInstanceId und GemInstanceId.</summary>
public sealed record ItemUpgradeRequest(
    long AccountId, string? ServerId, long InstanceId, Guid Key, long? GemInstanceId = null, long? StoneInstanceId = null);

/// <summary>
/// Sockel bohren, Edelstein einsetzen, verfeinern (ItemUpgradeRules). Das Teil darf im Inventar liegen oder getragen werden;
/// Edelsteine und Steine kommen aus dem Inventar und werden verbraucht. Gebühren sind Gold-Senken; jede Aktion genau einmal je
/// Schlüssel. Ohne Werte in game_rules (SOCKET_* / REFINE_*) gibt es beides nicht.
/// </summary>
public static class ItemUpgradeEndpoints
{
    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapPost("/characters/{characterId:long}/inventory/drill", Drill);
        internalApi.MapPost("/characters/{characterId:long}/inventory/socket", Socket);
        internalApi.MapPost("/characters/{characterId:long}/inventory/refine", Refine);
    }

    private sealed record Target(string ItemType, int? SocketMax, List<long?> Sockets, int Refinement, int RefineGemTier);

    private sealed record Consumable(int ItemId, string Code, int Tier, StatBonus Stats);

    private static Task<IResult> Drill(long characterId, ItemUpgradeRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct) =>
        Run(characterId, req, "DRILL", db, content.Value.AllowDevContent, identity.Value.InstanceId,
            async (conn, tx, target, tuning) =>
            {
                switch (ItemUpgradeRules.CanDrill(target.Sockets.Count, target.SocketMax))
                {
                    case DrillCheck.NoSockets: return Fail(StatusCodes.Status400BadRequest, "Dieses Teil hat keine Sockel");
                    case DrillCheck.Full: return Fail(StatusCodes.Status409Conflict, $"Alle {target.SocketMax} Sockel sind gebohrt");
                }
                var sockets = target.Sockets.Append(null).ToList();
                await Exec(conn, tx, "UPDATE item_instances SET sockets = @s::jsonb, version = version + 1 WHERE item_instance_id = @id", ct,
                    ("s", SocketsJson(sockets)), ("id", req.InstanceId));
                return Done(ItemUpgradeRules.DrillCost(target.Sockets.Count, tuning), "SOCKET_DRILL", new { sockets = sockets.Count });
            }, ct);

    private static Task<IResult> Socket(long characterId, ItemUpgradeRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct) =>
        Run(characterId, req, "SOCKET", db, content.Value.AllowDevContent, identity.Value.InstanceId,
            async (conn, tx, target, _) =>
            {
                if (req.GemInstanceId is not { } gemId
                    || await TakeOne(conn, tx, characterId, gemId, "GEM", content.Value.AllowDevContent, ct) is not { } gem)
                {
                    return Fail(StatusCodes.Status400BadRequest, "Kein Edelstein dieses Charakters im Inventar");
                }
                var present = await GemAttributes(conn, tx, target.Sockets, ct);
                switch (ItemUpgradeRules.CanSocket(present, gem.Stats))
                {
                    case SocketCheck.NotAGem: return Fail(StatusCodes.Status400BadRequest, "Dieser Stein gibt nicht genau ein Attribut");
                    case SocketCheck.NoFreeSocket: return Fail(StatusCodes.Status409Conflict, "Kein freier Sockel (erst bohren)");
                    case SocketCheck.SameAttribute:
                        return Fail(StatusCodes.Status409Conflict, "Ein Stein mit diesem Attribut sitzt schon in diesem Teil");
                }
                var sockets = target.Sockets.ToList();
                sockets[sockets.IndexOf(null)] = gem.ItemId;
                await Exec(conn, tx, "UPDATE item_instances SET sockets = @s::jsonb, version = version + 1 WHERE item_instance_id = @id", ct,
                    ("s", SocketsJson(sockets)), ("id", req.InstanceId));
                return Done(0, null, new { gem = gem.Code });
            }, ct);

    private static Task<IResult> Refine(long characterId, ItemUpgradeRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct) =>
        Run(characterId, req, "REFINE", db, content.Value.AllowDevContent, identity.Value.InstanceId,
            async (conn, tx, target, tuning) =>
            {
                var dev = content.Value.AllowDevContent;
                if (req.StoneInstanceId is not { } stoneId || req.GemInstanceId is not { } gemId
                    || await TakeOne(conn, tx, characterId, stoneId, "REFINE_STONE", dev, ct) is not { } stone)
                {
                    return Fail(StatusCodes.Status400BadRequest, "Kein Verfeinerungsstein dieses Charakters im Inventar");
                }
                if (await TakeOne(conn, tx, characterId, gemId, "GEM", dev, ct) is not { } gem)
                {
                    return Fail(StatusCodes.Status400BadRequest, "Kein Edelstein dieses Charakters im Inventar");
                }
                switch (ItemUpgradeRules.CanRefine(target.Refinement, stone.Tier, gem.Tier, target.RefineGemTier, tuning))
                {
                    case RefineCheck.MaxReached: return Fail(StatusCodes.Status409Conflict, $"Höchste Stufe {tuning.RefineMax} erreicht");
                    case RefineCheck.WrongStoneTier:
                        return Fail(StatusCodes.Status409Conflict, $"Verfeinerungsstein der Stufe {target.Refinement + 1} nötig");
                    case RefineCheck.GemTooLow:
                        return Fail(StatusCodes.Status409Conflict, $"Edelstein über Stufe {target.RefineGemTier} nötig");
                }
                await Exec(conn, tx,
                    """
                    UPDATE item_instances SET refinement_level = refinement_level + 1, refine_gem_tier = @tier, version = version + 1
                    WHERE item_instance_id = @id
                    """, ct, ("tier", (short)gem.Tier), ("id", req.InstanceId));
                return Done(ItemUpgradeRules.RefineCost(target.Refinement, tuning), "ITEM_REFINE",
                    new { level = target.Refinement + 1, stone = stone.Code, gem = gem.Code });
            }, ct);

    // ---- Ablauf ------------------------------------------------------------------------------

    /// <summary>Ergebnis einer Aktion: Fehler oder Gebühr (Senke reason) und Daten fürs Protokoll.</summary>
    private sealed record Outcome(IResult? Error, long Cost = 0, string? Reason = null, object? Detail = null);

    private static Outcome Fail(int status, string title) => new(Results.Problem(statusCode: status, title: title));

    private static Outcome Done(long cost, string? reason, object detail) => new(null, cost, reason, detail);

    private static async Task<IResult> Run(long characterId, ItemUpgradeRequest req, string kind, NpgsqlDataSource db, bool allowDev,
        string instanceId, Func<NpgsqlConnection, NpgsqlTransaction, Target, UpgradeTuning, Task<Outcome>> action, CancellationToken ct)
    {
        if (req.Key == Guid.Empty || req.InstanceId <= 0)
        {
            return Problem(StatusCodes.Status400BadRequest, "instanceId und key sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await InventoryEndpoints.Duplicate(conn, tx, characterId, req.Key, allowDev, ct) is { } duplicate)
        {
            return duplicate;
        }
        if (string.IsNullOrEmpty(req.ServerId) || await WorldEndpoints.PresenceZone(conn, tx, characterId, req.ServerId, ct) is null)
        {
            return Problem(StatusCodes.Status409Conflict, "Charakter ist nicht auf diesem Server");
        }
        if (await LoadTuning(conn, tx, allowDev, ct) is not { } tuning)
        {
            return Problem(StatusCodes.Status409Conflict, "Sockeln und Verfeinern sind nicht verfügbar (Werte unbekannt)");
        }
        if (await LoadTarget(conn, tx, characterId, req.InstanceId, allowDev, ct) is not { } target)
        {
            return Problem(StatusCodes.Status400BadRequest, "Kein Ausrüstungsteil dieses Charakters (Inventar oder getragen)");
        }
        var outcome = await action(conn, tx, target, tuning);
        if (outcome.Error is not null)
        {
            return outcome.Error; // Transaktion wird verworfen: verbrauchte Steine bleiben erhalten
        }
        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        if (gold < outcome.Cost)
        {
            return Problem(StatusCodes.Status409Conflict, $"Nicht genug Gold ({gold} von {outcome.Cost})");
        }
        if (outcome.Cost > 0)
        {
            gold = await ShipEndpoints.Book(conn, tx, characterId, -outcome.Cost, outcome.Reason!, "SINK", req.Key, req.ServerId, ct);
        }
        await InventoryEndpoints.RecordOperation(conn, tx, req.Key, characterId, kind,
            new { instance = req.InstanceId, total = outcome.Cost, detail = outcome.Detail }, req.ServerId, ct);
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("ITEM_" + kind, req.AccountId, characterId,
            NewValue: new { instance = req.InstanceId, cost = outcome.Cost, detail = outcome.Detail }), instanceId, ct);
        var inventory = await InventoryEndpoints.Load(conn, tx, characterId, allowDev, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new ItemOperationResponse(false, gold, outcome.Cost, 0, 0, inventory));
    }

    /// <summary>Werte aus game_rules; fehlt einer, gibt es Sockeln und Verfeinern nicht (null). tx darf null sein.</summary>
    internal static async Task<UpgradeTuning?> LoadTuning(NpgsqlConnection conn, NpgsqlTransaction? tx, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT rule_key, int_value FROM game_rules
            WHERE rule_key IN ('SOCKET_DRILL_GOLD', 'REFINE_GOLD_PER_LEVEL', 'REFINE_MAX', 'REFINE_WEAPON_ATTACK', 'REFINE_ARMOR_DEFENSE')
              AND int_value IS NOT NULL AND (NOT is_dev OR @dev)
            """, conn, tx);
        cmd.Parameters.AddWithValue("dev", allowDev);
        var values = new Dictionary<string, long>();
        await using (var r = await cmd.ExecuteReaderAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                values[r.GetString(0)] = r.GetInt64(1);
            }
        }
        if (values.Count != 5)
        {
            return null;
        }
        var t = new UpgradeTuning(values["SOCKET_DRILL_GOLD"], values["REFINE_GOLD_PER_LEVEL"], (int)values["REFINE_MAX"],
            (int)values["REFINE_WEAPON_ATTACK"], (int)values["REFINE_ARMOR_DEFENSE"]);
        return ItemUpgradeRules.IsValidTuning(t) ? t : null;
    }

    private static async Task<Target?> LoadTarget(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, long instanceId, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT i.item_type, i.equip_slot, i.socket_max, ii.sockets::text, ii.refinement_level, ii.refine_gem_tier
            FROM item_instances ii JOIN items i USING (item_id)
            WHERE ii.item_instance_id = @id AND ii.owner_character_id = @chr AND ii.location_type IN ('INVENTORY', 'EQUIPMENT')
              AND (NOT i.is_dev OR @dev)
            FOR UPDATE OF ii
            """, conn, tx);
        cmd.Parameters.AddWithValue("id", instanceId);
        cmd.Parameters.AddWithValue("chr", characterId);
        cmd.Parameters.AddWithValue("dev", allowDev);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct) || EquipmentRules.SlotFor(r.GetString(0), r.IsDBNull(1) ? null : r.GetString(1)) is null)
        {
            return null;
        }
        var sockets = JsonNode.Parse(r.GetString(3))?.AsArray()
            .Select(n => n?["gem_item_id"]?.GetValue<long>()).ToList() ?? [];
        return new Target(r.GetString(0), r.IsDBNull(2) ? null : r.GetInt16(2), sockets, r.GetInt16(4), r.GetInt16(5));
    }

    /// <summary>Ein Stück eines Steins der Art type aus dem Inventar nehmen; null, wenn es keins ist.</summary>
    private static async Task<Consumable?> TakeOne(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, long instanceId, string type, bool allowDev, CancellationToken ct)
    {
        Consumable item;
        int quantity;
        await using (var cmd = new NpgsqlCommand(
            """
            SELECT i.item_id, i.code, coalesce(i.tier, 0), i.base_stats::text, ii.quantity
            FROM item_instances ii JOIN items i USING (item_id)
            WHERE ii.item_instance_id = @id AND ii.owner_character_id = @chr AND ii.location_type = 'INVENTORY'
              AND i.item_type = @type AND (NOT i.is_dev OR @dev)
            FOR UPDATE OF ii
            """, conn, tx))
        {
            cmd.Parameters.AddWithValue("id", instanceId);
            cmd.Parameters.AddWithValue("chr", characterId);
            cmd.Parameters.AddWithValue("type", type);
            cmd.Parameters.AddWithValue("dev", allowDev);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
            {
                return null;
            }
            item = new Consumable(r.GetInt32(0), r.GetString(1), r.GetInt16(2),
                r.IsDBNull(3) ? StatBonus.Zero : InventoryEndpoints.ParseStats(r.GetString(3)));
            quantity = r.GetInt32(4);
        }
        await Exec(conn, tx, quantity > 1
            ? "UPDATE item_instances SET quantity = quantity - 1 WHERE item_instance_id = @id"
            : "DELETE FROM item_instances WHERE item_instance_id = @id", ct, ("id", instanceId));
        return item;
    }

    /// <summary>Attribut des Steins je Sockel (null = leer).</summary>
    private static async Task<List<string?>> GemAttributes(NpgsqlConnection conn, NpgsqlTransaction tx, List<long?> sockets, CancellationToken ct)
    {
        var stats = new Dictionary<long, StatBonus>();
        var ids = sockets.OfType<long>().Distinct().ToArray();
        if (ids.Length > 0)
        {
            await using var cmd = new NpgsqlCommand("SELECT item_id, base_stats::text FROM items WHERE item_id = ANY(@ids)", conn, tx);
            cmd.Parameters.AddWithValue("ids", ids.Select(i => (int)i).ToArray());
            await using var r = await cmd.ExecuteReaderAsync(ct);
            while (await r.ReadAsync(ct))
            {
                stats[r.GetInt32(0)] = r.IsDBNull(1) ? StatBonus.Zero : InventoryEndpoints.ParseStats(r.GetString(1));
            }
        }
        return sockets.Select(s => s is { } id && stats.TryGetValue(id, out var b) ? ItemUpgradeRules.AttributeOf(b) ?? "?" : null).ToList();
    }

    private static string SocketsJson(List<long?> sockets) =>
        JsonSerializer.Serialize(sockets.Select(s => s is { } id ? new { gem_item_id = id } : null));

    private static Task<int> Exec(NpgsqlConnection conn, NpgsqlTransaction tx, string sql, CancellationToken ct,
        params (string Name, object Value)[] parameters) => InventoryEndpoints.Exec(conn, tx, sql, ct, parameters);

    private static IResult Problem(int status, string title) => Results.Problem(statusCode: status, title: title);
}
