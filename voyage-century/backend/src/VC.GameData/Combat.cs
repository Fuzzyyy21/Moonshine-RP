using System.ComponentModel.DataAnnotations;
using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common.Logging;

namespace VC.GameData;

public sealed class ContentOptions
{
    public const string Section = "Content";

    /// <summary>Entwicklungsinhalte (is_dev: DEV_-Waffen, DEV_-Gegner) zulassen. Nur Development/Tests.</summary>
    public bool AllowDevContent { get; set; }
}

public sealed record ZoneInfo(string ZoneId, string ZoneKind, string PvpMode);

public sealed record KillRequest(
    Guid IdempotencyKey, string? ServerId, string? ZoneId,
    long KillerCharacterId, long KillerAccountId,
    string? VictimType, string? MonsterCode, long? VictimCharacterId, long? VictimAccountId);

/// <summary>Loot: was der Gegner fallen ließ (Lost = passte nicht ins Inventar); LootGold: gutgeschriebenes Gold.</summary>
/// <summary>Inventory: neuer Stand des Töters, wenn sich etwas daran geändert hat (Waffe abgenutzt); sonst null.</summary>
public sealed record KillResponse(bool Duplicate, long? XpAwarded, CharacterProgress? Progress, List<LootDrop>? Loot = null, long LootGold = 0,
    InventoryResponse? Inventory = null);

/// <summary>
/// Kampfergebnisse, die der Zonen-Server meldet. Der Server entscheidet über Treffer und Tod; das Backend
/// entscheidet über Belohnungen (XP aus den Gegnerdaten, nicht aus der Meldung) und prüft die PvP-Regel der Zone.
/// </summary>
public static class CombatEndpoints
{
    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapGet("/zones/{zoneId}", GetZone);
        internalApi.MapPost("/combat/kills", ReportKill);
    }

    private static async Task<IResult> GetZone(string zoneId, NpgsqlDataSource db, CancellationToken ct)
    {
        await using var cmd = db.CreateCommand("SELECT zone_id, zone_kind, pvp_mode FROM zones WHERE zone_id = @z");
        cmd.Parameters.AddWithValue("z", zoneId);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct)
            ? Results.Ok(new ZoneInfo(r.GetString(0), r.GetString(1), r.GetString(2)))
            : Results.Problem(statusCode: StatusCodes.Status404NotFound, title: "Zone unbekannt");
    }

    private static async Task<IResult> ReportKill(
        KillRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content, IOptions<ProgressionOptions> progression,
        CancellationToken ct)
    {
        if (req.IdempotencyKey == Guid.Empty || string.IsNullOrEmpty(req.ServerId) || req.ServerId.Length > 64
            || string.IsNullOrEmpty(req.ZoneId))
        {
            return BadRequest("idempotencyKey, serverId und zoneId sind erforderlich");
        }
        var isMonster = req.VictimType == "MONSTER";
        if (!isMonster && req.VictimType != "CHARACTER")
        {
            return BadRequest("victimType: MONSTER oder CHARACTER");
        }
        if (isMonster ? string.IsNullOrEmpty(req.MonsterCode) : req.VictimCharacterId is null || req.VictimAccountId is null)
        {
            return BadRequest(isMonster ? "monsterCode fehlt" : "victimCharacterId und victimAccountId fehlen");
        }

        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);

        var pvpMode = await Scalar<string>(conn, tx, "SELECT pvp_mode FROM zones WHERE zone_id = @z", ("z", req.ZoneId), ct);
        if (pvpMode is null)
        {
            return BadRequest("Zone unbekannt");
        }
        // Bei PvP immer zuerst die kleinere Charakter-ID sperren, damit gleichzeitige gegenseitige Kills nicht verklemmen.
        if (!isMonster && req.VictimCharacterId < req.KillerCharacterId
            && await ProgressionEndpoints.LockCharacter(conn, tx, req.VictimCharacterId!.Value, req.VictimAccountId, ct) is null)
        {
            return NotFound("Opfer nicht gefunden");
        }
        var killer = await ProgressionEndpoints.LockCharacter(conn, tx, req.KillerCharacterId, req.KillerAccountId, ct);
        if (killer is null)
        {
            return NotFound("Angreifer nicht gefunden");
        }

        int? monsterId = null;
        long? xpReward = null;
        int? lootTableId = null;
        if (isMonster)
        {
            await using var cmd = new NpgsqlCommand(
                """
                SELECT m.monster_id, m.xp_reward, lt.loot_table_id
                FROM monsters m LEFT JOIN loot_tables lt ON lt.loot_table_id = m.loot_table_id AND (NOT lt.is_dev OR @dev)
                WHERE m.code = @c AND (NOT m.is_dev OR @dev)
                """, conn, tx);
            cmd.Parameters.AddWithValue("c", req.MonsterCode!);
            cmd.Parameters.AddWithValue("dev", content.Value.AllowDevContent);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
            {
                return BadRequest("Gegner unbekannt oder nicht freigegeben");
            }
            monsterId = r.GetInt32(0);
            xpReward = r.IsDBNull(1) ? null : r.GetInt64(1);
            lootTableId = r.IsDBNull(2) ? null : r.GetInt32(2);
        }
        (long WarId, SiegeSide Side)? siege = null;
        if (!isMonster)
        {
            if (req.VictimCharacterId == req.KillerCharacterId
                || await ProgressionEndpoints.LockCharacter(conn, tx, req.VictimCharacterId!.Value, req.VictimAccountId, ct) is null)
            {
                return NotFound("Opfer nicht gefunden");
            }
            // Während einer Belagerung dürfen Angreifer und Verteidiger sich auch dort bekämpfen, wo sonst kein PvP gilt.
            siege = await SiegeEndpoints.SiegeForKill(conn, tx, req.ZoneId, req.KillerCharacterId, req.VictimCharacterId.Value, ct);
            if (pvpMode != "FREE" && siege is null)
            {
                // Der Zonen-Server hätte diesen Kampf nicht zulassen dürfen.
                return Results.Problem(statusCode: StatusCodes.Status409Conflict, title: "PvP ist in dieser Zone nicht erlaubt");
            }
        }

        await using (var insert = new NpgsqlCommand(
            """
            INSERT INTO combat_kills (idempotency_key, zone_id, killer_character_id, victim_character_id, monster_id, xp_awarded, server_id, war_id)
            VALUES (@key, @zone, @killer, @victim, @monster, @xp, @server, @war)
            ON CONFLICT (idempotency_key) DO NOTHING
            """, conn, tx))
        {
            insert.Parameters.AddWithValue("key", req.IdempotencyKey);
            insert.Parameters.AddWithValue("zone", req.ZoneId);
            insert.Parameters.AddWithValue("killer", req.KillerCharacterId);
            insert.Parameters.AddWithValue("victim", (object?)(isMonster ? null : req.VictimCharacterId) ?? DBNull.Value);
            insert.Parameters.AddWithValue("monster", (object?)monsterId ?? DBNull.Value);
            insert.Parameters.AddWithValue("xp", (object?)xpReward ?? DBNull.Value);
            insert.Parameters.AddWithValue("server", req.ServerId);
            insert.Parameters.AddWithValue("war", (object?)siege?.WarId ?? DBNull.Value);
            if (await insert.ExecuteNonQueryAsync(ct) == 0)
            {
                return Results.Ok(new KillResponse(Duplicate: true, null, null));
            }
        }

        CharacterProgress? progress = null;
        if (isMonster && xpReward is > 0)
        {
            progress = await ProgressionEndpoints.ApplyCharacterXp(conn, tx, req.KillerCharacterId, killer.Value,
                new GrantRequest(req.KillerAccountId, xpReward.Value, $"kill:{req.MonsterCode}", req.IdempotencyKey, req.ServerId),
                progression.Value.AllowDevCurves, ct);
        }
        if (siege is { } war)
        {
            await SiegeEndpoints.Score(conn, tx, war.WarId, war.Side, ct);
        }
        List<LootDrop>? loot = null;
        long lootGold = 0;
        if (lootTableId is { } table)
        {
            (loot, lootGold) = await RollLoot(conn, tx, req, table, content.Value.AllowDevContent, ct);
        }
        if (!isMonster)
        {
            await Exec(conn, tx,
                """
                INSERT INTO pvp_statistics (character_id, land_kills) VALUES (@k, 1)
                ON CONFLICT (character_id) DO UPDATE SET land_kills = pvp_statistics.land_kills + 1
                """, ("k", req.KillerCharacterId), ct);
            await Exec(conn, tx,
                """
                INSERT INTO pvp_statistics (character_id, land_deaths) VALUES (@v, 1)
                ON CONFLICT (character_id) DO UPDATE SET land_deaths = pvp_statistics.land_deaths + 1
                """, ("v", req.VictimCharacterId!.Value), ct);
        }
        // Abnutzung der getragenen Waffe des Töters (DurabilityRules); der Zonen-Server übernimmt dann das neue Inventar.
        var inventory = await DurabilityEndpoints.WearWeapon(conn, tx, req.KillerCharacterId, content.Value.AllowDevContent, ct)
            ? await InventoryEndpoints.Load(conn, tx, req.KillerCharacterId, content.Value.AllowDevContent, ct)
            : null;
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("KILL", req.KillerAccountId, req.KillerCharacterId,
            NewValue: new { victimType = req.VictimType, monster = req.MonsterCode, victim = req.VictimCharacterId, zone = req.ZoneId, xp = xpReward,
                loot, gold = lootGold }),
            req.ServerId, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new KillResponse(Duplicate: false, xpReward, progress, loot, lootGold, inventory));
    }

    /// <summary>
    /// Beute würfeln (InventoryRules) und dem Töter gutschreiben: Items ins Inventar (was nicht passt, ist verloren), Gold über den
    /// Ledger als Quelle LOOT_GOLD. Die Kill-Zeile ist schon angelegt, also passiert das je Kill genau einmal.
    /// </summary>
    private static async Task<(List<LootDrop> Loot, long Gold)> RollLoot(
        NpgsqlConnection conn, NpgsqlTransaction tx, KillRequest req, int lootTableId, bool allowDev, CancellationToken ct)
    {
        var entries = new List<LootEntry>();
        var names = new Dictionary<int, (string Code, string? NameDe)>();
        long? goldMin = null, goldMax = null;
        await using (var cmd = new NpgsqlCommand(
            """
            SELECT e.item_id, e.chance::float8, e.min_qty, e.max_qty, i.code, i.name_de, lt.gold_min, lt.gold_max
            FROM loot_tables lt
            LEFT JOIN loot_entries e ON e.loot_table_id = lt.loot_table_id
            LEFT JOIN items i ON i.item_id = e.item_id AND (NOT i.is_dev OR @dev)
            WHERE lt.loot_table_id = @t
            ORDER BY i.code
            """, conn, tx))
        {
            cmd.Parameters.AddWithValue("t", lootTableId);
            cmd.Parameters.AddWithValue("dev", allowDev);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            while (await r.ReadAsync(ct))
            {
                goldMin = r.IsDBNull(6) ? null : r.GetInt64(6);
                goldMax = r.IsDBNull(7) ? null : r.GetInt64(7);
                if (r.IsDBNull(0) || r.IsDBNull(4))
                {
                    continue; // Tabelle ohne Einträge oder Item nicht freigegeben
                }
                entries.Add(new LootEntry(r.GetInt32(0), r.IsDBNull(1) ? null : r.GetDouble(1), r.GetInt32(2), r.GetInt32(3)));
                names[r.GetInt32(0)] = (r.GetString(4), r.IsDBNull(5) ? null : r.GetString(5));
            }
        }
        var loot = new List<LootDrop>();
        foreach (var (itemId, quantity) in InventoryRules.RollLoot(entries, Random.Shared))
        {
            var placed = await InventoryEndpoints.AddItems(conn, tx, req.KillerCharacterId, itemId, quantity, "DROP",
                req.IdempotencyKey.ToString(), allowDev, ct);
            loot.Add(new LootDrop(names[itemId].Code, names[itemId].NameDe, quantity, quantity - placed));
        }
        var gold = InventoryRules.RollGold(goldMin, goldMax, Random.Shared);
        if (gold > 0)
        {
            await ShipEndpoints.Book(conn, tx, req.KillerCharacterId, gold, "LOOT_GOLD", "SOURCE", req.IdempotencyKey, req.ServerId!, ct);
        }
        await using (var upd = new NpgsqlCommand("UPDATE combat_kills SET loot = @loot::jsonb WHERE idempotency_key = @key", conn, tx))
        {
            upd.Parameters.AddWithValue("loot", System.Text.Json.JsonSerializer.Serialize(new { items = loot, gold }));
            upd.Parameters.AddWithValue("key", req.IdempotencyKey);
            await upd.ExecuteNonQueryAsync(ct);
        }
        return (loot, gold);
    }

    private static async Task<T?> Scalar<T>(NpgsqlConnection conn, NpgsqlTransaction tx, string sql, (string, object) p, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(sql, conn, tx);
        cmd.Parameters.AddWithValue(p.Item1, p.Item2);
        return (T?)await cmd.ExecuteScalarAsync(ct);
    }

    private static async Task Exec(NpgsqlConnection conn, NpgsqlTransaction tx, string sql, (string, object) p, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(sql, conn, tx);
        cmd.Parameters.AddWithValue(p.Item1, p.Item2);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    private static IResult BadRequest(string title) => Results.Problem(statusCode: StatusCodes.Status400BadRequest, title: title);

    private static IResult NotFound(string title) => Results.Problem(statusCode: StatusCodes.Status404NotFound, title: title);
}
