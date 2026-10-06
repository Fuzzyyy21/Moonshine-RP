using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Logging;

namespace VC.GameData;

/// <summary>Tod eines Spielercharakters, gemeldet vom Zonen-Server (gleich, wer ihn getötet hat).</summary>
public sealed record DeathRequest(long AccountId, string? ServerId, Guid Key);

/// <summary>InstanceId 0 = alle getragenen Teile. NpcCode: Händler in Reichweite (der Zonen-Server prüft die Entfernung).</summary>
public sealed record RepairRequest(long AccountId, string? ServerId, long InstanceId, string? NpcCode, Guid Key);

/// <summary>
/// Haltbarkeit (DurabilityRules): Abnutzung beim Tod und durch Kills, Reparatur beim Händler gegen Gold (Senke ITEM_REPAIR).
/// Ohne Werte in game_rules (WEAR_* / REPAIR_*) nutzt sich nichts ab und es gibt keine Reparatur.
/// </summary>
public static class DurabilityEndpoints
{
    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapPost("/characters/{characterId:long}/death", Death);
        internalApi.MapPost("/characters/{characterId:long}/inventory/repair", Repair);
    }

    private sealed record Piece(long InstanceId, int? Durability, int? Max, int RarityPermille);

    /// <summary>Jedes getragene Teil mit Haltbarkeit verliert WEAR_ON_DEATH_PERMILLE seines Maximums; genau einmal je Schlüssel.</summary>
    private static async Task<IResult> Death(long characterId, DeathRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (req.Key == Guid.Empty)
        {
            return Problem(StatusCodes.Status400BadRequest, "key ist erforderlich");
        }
        var dev = content.Value.AllowDevContent;
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await InventoryEndpoints.Duplicate(conn, tx, characterId, req.Key, dev, ct) is { } duplicate)
        {
            return duplicate;
        }
        if (string.IsNullOrEmpty(req.ServerId) || await WorldEndpoints.PresenceZone(conn, tx, characterId, req.ServerId, ct) is null)
        {
            return Problem(StatusCodes.Status409Conflict, "Charakter ist nicht auf diesem Server");
        }
        var worn = new List<object>();
        if (await LoadTuning(conn, tx, dev, ct) is { } tuning)
        {
            foreach (var p in await Pieces(conn, tx, characterId, null, weaponOnly: false, ct))
            {
                var after = DurabilityRules.Wear(p.Durability, p.Max, DurabilityRules.DeathLoss(p.Max!.Value, tuning.DeathWearPermille));
                await SetDurability(conn, tx, p.InstanceId, after!.Value, ct);
                worn.Add(new { instance = p.InstanceId, durability = after });
            }
        }
        await InventoryEndpoints.RecordOperation(conn, tx, req.Key, characterId, "DEATH", new { total = 0, worn }, req.ServerId, ct);
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("CHARACTER_DEATH", req.AccountId, characterId, NewValue: new { worn }),
            identity.Value.InstanceId, ct);
        var inventory = await InventoryEndpoints.Load(conn, tx, characterId, dev, ct);
        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new ItemOperationResponse(false, gold, 0, 0, 0, inventory));
    }

    private static async Task<IResult> Repair(long characterId, RepairRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (req.Key == Guid.Empty || req.InstanceId < 0 || string.IsNullOrEmpty(req.NpcCode))
        {
            return Problem(StatusCodes.Status400BadRequest, "instanceId (0 = alles Getragene), npcCode und key sind erforderlich");
        }
        var dev = content.Value.AllowDevContent;
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await InventoryEndpoints.Duplicate(conn, tx, characterId, req.Key, dev, ct) is { } duplicate)
        {
            return duplicate;
        }
        if (string.IsNullOrEmpty(req.ServerId) || await WorldEndpoints.PresenceZone(conn, tx, characterId, req.ServerId, ct) is not { } zone)
        {
            return Problem(StatusCodes.Status409Conflict, "Charakter ist nicht auf diesem Server");
        }
        await using (var npc = new NpgsqlCommand(
            "SELECT 1 FROM npcs WHERE code = @code AND npc_role = 'MERCHANT' AND zone_id = @zone AND (NOT is_dev OR @dev)", conn, tx))
        {
            npc.Parameters.AddWithValue("code", req.NpcCode);
            npc.Parameters.AddWithValue("zone", zone);
            npc.Parameters.AddWithValue("dev", dev);
            if (await npc.ExecuteScalarAsync(ct) is null)
            {
                return Problem(StatusCodes.Status400BadRequest, "Hier gibt es keinen Händler mit diesem Code");
            }
        }
        if (await LoadTuning(conn, tx, dev, ct) is not { } tuning)
        {
            return Problem(StatusCodes.Status409Conflict, "Reparatur ist nicht verfügbar (Werte unbekannt)");
        }
        var pieces = await Pieces(conn, tx, characterId, req.InstanceId == 0 ? null : req.InstanceId, weaponOnly: false, ct);
        if (req.InstanceId != 0 && pieces.Count == 0)
        {
            return Problem(StatusCodes.Status400BadRequest, "Kein Teil mit Haltbarkeit dieses Charakters (Inventar oder getragen)");
        }
        var damaged = pieces
            .Select(p => (Piece: p, Cost: DurabilityRules.RepairCost(p.Durability, p.Max, tuning.RepairGoldPerPoint, p.RarityPermille)))
            .Where(x => DurabilityRules.Current(x.Piece.Durability, x.Piece.Max) < x.Piece.Max)
            .ToList();
        if (damaged.Count == 0)
        {
            return Problem(StatusCodes.Status409Conflict, "Nichts zu reparieren");
        }
        var total = damaged.Sum(x => x.Cost);
        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        if (gold < total)
        {
            return Problem(StatusCodes.Status409Conflict, $"Nicht genug Gold ({gold} von {total})");
        }
        foreach (var (piece, _) in damaged)
        {
            await InventoryEndpoints.Exec(conn, tx,
                "UPDATE item_instances SET durability = NULL, version = version + 1 WHERE item_instance_id = @id", ct,
                ("id", piece.InstanceId));
        }
        if (total > 0)
        {
            gold = await ShipEndpoints.Book(conn, tx, characterId, -total, "ITEM_REPAIR", "SINK", req.Key, req.ServerId, ct);
        }
        var repaired = damaged.Select(x => x.Piece.InstanceId).ToList();
        await InventoryEndpoints.RecordOperation(conn, tx, req.Key, characterId, "REPAIR", new { total, repaired }, req.ServerId, ct);
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("ITEM_REPAIR", req.AccountId, characterId,
            NewValue: new { total, repaired, npc = req.NpcCode }), identity.Value.InstanceId, ct);
        var inventory = await InventoryEndpoints.Load(conn, tx, characterId, dev, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new ItemOperationResponse(false, gold, total, 0, 0, inventory));
    }

    /// <summary>
    /// Kill gemeldet: die getragene Waffe des Töters verliert WEAR_WEAPON_PER_KILL. true, wenn sich etwas geändert hat
    /// (dann soll der Zonen-Server das Inventar neu übernehmen).
    /// </summary>
    internal static async Task<bool> WearWeapon(NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, bool allowDev, CancellationToken ct)
    {
        if (await LoadTuning(conn, tx, allowDev, ct) is not { WeaponWearPerKill: > 0 } tuning)
        {
            return false;
        }
        var weapon = (await Pieces(conn, tx, characterId, null, weaponOnly: true, ct)).FirstOrDefault();
        if (weapon is null || DurabilityRules.IsBroken(weapon.Durability, weapon.Max))
        {
            return false;
        }
        await SetDurability(conn, tx, weapon.InstanceId, DurabilityRules.Wear(weapon.Durability, weapon.Max, tuning.WeaponWearPerKill)!.Value, ct);
        return true;
    }

    internal static async Task<DurabilityTuning?> LoadTuning(NpgsqlConnection conn, NpgsqlTransaction? tx, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT rule_key, int_value FROM game_rules
            WHERE rule_key IN ('WEAR_WEAPON_PER_KILL', 'WEAR_ON_DEATH_PERMILLE', 'REPAIR_GOLD_PER_POINT')
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
        if (values.Count != 3)
        {
            return null;
        }
        var t = new DurabilityTuning((int)values["WEAR_WEAPON_PER_KILL"], (int)values["WEAR_ON_DEATH_PERMILLE"], values["REPAIR_GOLD_PER_POINT"]);
        return DurabilityRules.IsValidTuning(t) ? t : null;
    }

    /// <summary>
    /// Teile mit Haltbarkeit: ein bestimmtes (Inventar oder getragen) oder ohne instanceId alle getragenen; gesperrt für die
    /// Änderung. Seltenheit ohne Stufe zählt einfach (1000 ‰).
    /// </summary>
    private static async Task<List<Piece>> Pieces(NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, long? instanceId,
        bool weaponOnly, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT ii.item_instance_id, ii.durability, i.durability_max, coalesce(r.repair_factor_permille, 1000)
            FROM item_instances ii JOIN items i USING (item_id) LEFT JOIN item_rarities r ON r.code = i.rarity
            WHERE ii.owner_character_id = @chr AND i.durability_max IS NOT NULL
              AND (CASE WHEN @id::bigint IS NULL THEN ii.location_type = 'EQUIPMENT'
                        ELSE ii.item_instance_id = @id AND ii.location_type IN ('INVENTORY', 'EQUIPMENT') END)
              AND (NOT @weapon OR (ii.location_type = 'EQUIPMENT' AND ii.slot = 'WEAPON'))
            ORDER BY ii.item_instance_id
            FOR UPDATE OF ii
            """, conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        cmd.Parameters.AddWithValue("id", (object?)instanceId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("weapon", weaponOnly);
        var list = new List<Piece>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            list.Add(new Piece(r.GetInt64(0), r.IsDBNull(1) ? null : r.GetInt32(1), r.GetInt32(2), r.GetInt32(3)));
        }
        return list;
    }

    private static Task<int> SetDurability(NpgsqlConnection conn, NpgsqlTransaction tx, long instanceId, int durability, CancellationToken ct) =>
        InventoryEndpoints.Exec(conn, tx, "UPDATE item_instances SET durability = @d, version = version + 1 WHERE item_instance_id = @id",
            ct, ("d", durability), ("id", instanceId));

    private static IResult Problem(int status, string title) => Results.Problem(statusCode: status, title: title);
}
