using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Logging;

namespace VC.GameData;

public sealed record ShipState(long InstanceId, string ShipCode, bool Active, int HullHp, int HullMax, int Crew, int Provisions);
public sealed record BuyShipRequest(long AccountId, string? ServerId, string? NpcCode, string? ShipCode, Guid PurchaseKey);
public sealed record BuyShipResponse(bool Duplicate, ShipState Ship, long Gold);
public sealed record ShipCommandRequest(long AccountId, string? ServerId);
public sealed record SaveShipRequest(long AccountId, string? ServerId, int HullHp, int Crew, int Provisions);
public sealed record AdminGoldRequest(long AdminAccountId, long Amount, Guid IdempotencyKey, Guid? SessionId, string? Ip, string? ServerId);

/// <summary>
/// Schiffe und Gold. Schiffe gibt es nur beim Werftmeister (SHIP-ACQUISITION): Der Zonen-Server meldet den Kauf, das Backend
/// prüft, dass der Charakter auf diesem Server ist und in dieser Zone ein Werftmeister steht, bucht das Gold im Ledger ab und
/// legt das Schiff an – alles in einer Transaktion und genau einmal je Kaufschlüssel.
/// </summary>
public static class ShipEndpoints
{
    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapPost("/characters/{characterId:long}/ships", Buy);
        internalApi.MapPut("/characters/{characterId:long}/ships/{instanceId:long}/active", SetActive);
        internalApi.MapPut("/characters/{characterId:long}/ships/{instanceId:long}/state", SaveShip);
        internalApi.MapPost("/characters/{characterId:long}/gold", AdminGrantGold);
    }

    public static async Task<List<ShipState>> LoadShips(NpgsqlConnection conn, NpgsqlTransaction? tx, long characterId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT i.ship_instance_id, s.code, i.is_active, i.hull_hp, s.hull_hp, i.crew_healthy, i.provisions
            FROM ship_instances i JOIN ships s USING (ship_id)
            WHERE i.owner_character_id = @chr ORDER BY i.ship_instance_id
            """, conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        var list = new List<ShipState>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            list.Add(new ShipState(r.GetInt64(0), r.GetString(1), r.GetBoolean(2), r.GetInt32(3), r.IsDBNull(4) ? 0 : r.GetInt32(4),
                r.GetInt32(5), r.GetInt32(6)));
        }
        return list;
    }

    public static async Task<long> LoadGold(NpgsqlConnection conn, NpgsqlTransaction? tx, long characterId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            "SELECT balance FROM character_wallets WHERE character_id = @chr AND currency_code = 'GOLD'", conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        return await cmd.ExecuteScalarAsync(ct) is long balance ? balance : 0;
    }

    private static async Task<IResult> Buy(
        long characterId, BuyShipRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || req.ServerId.Length > 64 || string.IsNullOrEmpty(req.NpcCode)
            || string.IsNullOrEmpty(req.ShipCode) || req.PurchaseKey == Guid.Empty)
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId, npcCode, shipCode und purchaseKey sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }

        // Wiederholter Kauf mit demselben Schlüssel: Ergebnis des ersten Kaufs, nichts doppelt.
        await using (var dup = new NpgsqlCommand(
            "SELECT ship_instance_id FROM ship_instances WHERE purchase_key = @key AND owner_character_id = @chr", conn, tx))
        {
            dup.Parameters.AddWithValue("key", req.PurchaseKey);
            dup.Parameters.AddWithValue("chr", characterId);
            if (await dup.ExecuteScalarAsync(ct) is long existing)
            {
                var ships = await LoadShips(conn, tx, characterId, ct);
                return Results.Ok(new BuyShipResponse(true, ships.First(s => s.InstanceId == existing), await LoadGold(conn, tx, characterId, ct)));
            }
        }

        var zone = await WorldEndpoints.PresenceZone(conn, tx, characterId, req.ServerId, ct);
        if (zone is null)
        {
            return Problem(StatusCodes.Status409Conflict, "Charakter ist nicht auf diesem Server");
        }
        int? portId;
        await using (var npc = new NpgsqlCommand(
            "SELECT port_id FROM npcs WHERE code = @code AND npc_role = 'SHIPYARD' AND zone_id = @zone", conn, tx))
        {
            npc.Parameters.AddWithValue("code", req.NpcCode);
            npc.Parameters.AddWithValue("zone", zone);
            portId = await npc.ExecuteScalarAsync(ct) as int?;
        }
        if (portId is null)
        {
            return Problem(StatusCodes.Status400BadRequest, "Hier gibt es keinen Werftmeister mit diesem Code");
        }

        int shipId, hullHp, startCrew, startProvisions;
        long cost;
        bool onePerCharacter;
        await using (var ship = new NpgsqlCommand(
            """
            SELECT ship_id, hull_hp, coalesce(start_crew, crew_min), start_provisions, cost_gold, one_per_character
            FROM ships WHERE code = @code AND (NOT is_dev OR @dev)
            """, conn, tx))
        {
            ship.Parameters.AddWithValue("code", req.ShipCode);
            ship.Parameters.AddWithValue("dev", content.Value.AllowDevContent);
            await using var r = await ship.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct) || r.IsDBNull(1) || r.IsDBNull(2) || r.IsDBNull(3) || r.IsDBNull(4))
            {
                // Schiffe ohne bekannten Preis oder ohne Werte werden nicht verkauft (nie Ersatzwerte).
                return Problem(StatusCodes.Status400BadRequest, "Schiff unbekannt, nicht freigegeben oder ohne vollständige Werte");
            }
            (shipId, hullHp, startCrew, startProvisions, cost, onePerCharacter) =
                (r.GetInt32(0), r.GetInt32(1), r.GetInt32(2), r.GetInt32(3), r.GetInt64(4), r.GetBoolean(5));
        }
        if (onePerCharacter)
        {
            await using var owned = new NpgsqlCommand(
                "SELECT 1 FROM ship_instances WHERE owner_character_id = @chr AND ship_id = @ship", conn, tx);
            owned.Parameters.AddWithValue("chr", characterId);
            owned.Parameters.AddWithValue("ship", shipId);
            if (await owned.ExecuteScalarAsync(ct) is not null)
            {
                return Problem(StatusCodes.Status409Conflict, "Dieses Schiff gibt es nur einmal je Charakter");
            }
        }

        long gold = await LoadGold(conn, tx, characterId, ct);
        if (cost > 0)
        {
            if (gold < cost)
            {
                return Problem(StatusCodes.Status409Conflict, $"Nicht genug Gold ({gold} von {cost})");
            }
            gold = await Book(conn, tx, characterId, -cost, "SHIP_BUY", "SINK", req.PurchaseKey, req.ServerId, ct);
        }

        long instanceId;
        await using (var insert = new NpgsqlCommand(
            """
            INSERT INTO ship_instances (ship_id, owner_character_id, hull_hp, crew_healthy, provisions, docked_port_id, is_active, purchase_key)
            VALUES (@ship, @chr, @hull, @crew, @prov, @port,
                    NOT EXISTS (SELECT 1 FROM ship_instances WHERE owner_character_id = @chr AND is_active), @key)
            RETURNING ship_instance_id
            """, conn, tx))
        {
            insert.Parameters.AddWithValue("ship", shipId);
            insert.Parameters.AddWithValue("chr", characterId);
            insert.Parameters.AddWithValue("hull", hullHp);
            insert.Parameters.AddWithValue("crew", startCrew);
            insert.Parameters.AddWithValue("prov", startProvisions);
            insert.Parameters.AddWithValue("port", portId.Value);
            insert.Parameters.AddWithValue("key", req.PurchaseKey);
            instanceId = (long)(await insert.ExecuteScalarAsync(ct))!;
        }
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("SHIP_BUY", req.AccountId, characterId,
            NewValue: new { ship = req.ShipCode, instance = instanceId, cost, npc = req.NpcCode, zone }), identity.Value.InstanceId, ct);
        var result = (await LoadShips(conn, tx, characterId, ct)).First(s => s.InstanceId == instanceId);
        await tx.CommitAsync(ct);
        return Results.Ok(new BuyShipResponse(false, result, gold));
    }

    private static async Task<IResult> SetActive(
        long characterId, long instanceId, ShipCommandRequest req, NpgsqlDataSource db, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId))
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId ist erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await WorldEndpoints.PresenceZone(conn, tx, characterId, req.ServerId, ct) is null)
        {
            return Problem(StatusCodes.Status409Conflict, "Charakter ist nicht auf diesem Server");
        }
        await using (var off = new NpgsqlCommand(
            "UPDATE ship_instances SET is_active = FALSE WHERE owner_character_id = @chr AND is_active AND ship_instance_id <> @id", conn, tx))
        {
            off.Parameters.AddWithValue("chr", characterId);
            off.Parameters.AddWithValue("id", instanceId);
            await off.ExecuteNonQueryAsync(ct);
        }
        await using (var on = new NpgsqlCommand(
            "UPDATE ship_instances SET is_active = TRUE WHERE owner_character_id = @chr AND ship_instance_id = @id", conn, tx))
        {
            on.Parameters.AddWithValue("chr", characterId);
            on.Parameters.AddWithValue("id", instanceId);
            if (await on.ExecuteNonQueryAsync(ct) != 1)
            {
                return Problem(StatusCodes.Status404NotFound, "Schiff nicht gefunden");
            }
        }
        await tx.CommitAsync(ct);
        return Results.NoContent();
    }

    /// <summary>
    /// Zustand nach der Fahrt. Ohne Werft und Anheuern (folgen später) können Rumpf, Besatzung und Proviant nur sinken;
    /// höhere Werte des Servers werden abgelehnt.
    /// </summary>
    private static async Task<IResult> SaveShip(
        long characterId, long instanceId, SaveShipRequest req, NpgsqlDataSource db, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || req.HullHp < 0 || req.Crew < 0 || req.Provisions < 0)
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId und nicht negative Werte sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await WorldEndpoints.PresenceZone(conn, tx, characterId, req.ServerId, ct) is null)
        {
            return Problem(StatusCodes.Status409Conflict, "Charakter ist nicht auf diesem Server");
        }
        await using var cmd = new NpgsqlCommand(
            """
            UPDATE ship_instances SET hull_hp = @hull, crew_healthy = @crew, provisions = @prov
            WHERE ship_instance_id = @id AND owner_character_id = @chr
              AND @hull <= hull_hp AND @crew <= crew_healthy AND @prov <= provisions
            """, conn, tx);
        cmd.Parameters.AddWithValue("hull", req.HullHp);
        cmd.Parameters.AddWithValue("crew", req.Crew);
        cmd.Parameters.AddWithValue("prov", req.Provisions);
        cmd.Parameters.AddWithValue("id", instanceId);
        cmd.Parameters.AddWithValue("chr", characterId);
        if (await cmd.ExecuteNonQueryAsync(ct) != 1)
        {
            return Problem(StatusCodes.Status409Conflict, "Schiff nicht gefunden oder Werte gestiegen");
        }
        await tx.CommitAsync(ct);
        return Results.NoContent();
    }

    /// <summary>Admin: Gold gutschreiben (Startguthaben des Originals UNKNOWN). Rechte, Buchung und Audit in einer Transaktion.</summary>
    private static async Task<IResult> AdminGrantGold(
        long characterId, AdminGoldRequest req, NpgsqlDataSource db, IOptions<ProgressionOptions> options, CancellationToken ct)
    {
        if (req.Amount is <= 0 or > 1_000_000_000 || req.IdempotencyKey == Guid.Empty)
        {
            return Problem(StatusCodes.Status400BadRequest, "amount (1 … 1.000.000.000) und idempotencyKey sind erforderlich");
        }
        var admin = new AdminSetRequest(req.AdminAccountId, 0, req.SessionId, req.Ip, req.ServerId);
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.CheckAdmin(conn, tx, admin, options.Value.AdminMinLevel, ct) is { } denied)
        {
            return denied;
        }
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, accountId: null, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        await using (var dup = new NpgsqlCommand("SELECT balance_after FROM currency_ledger WHERE idempotency_key = @key", conn, tx))
        {
            dup.Parameters.AddWithValue("key", req.IdempotencyKey);
            if (await dup.ExecuteScalarAsync(ct) is long already)
            {
                return Results.Ok(new { gold = already, duplicate = true });
            }
        }
        var before = await LoadGold(conn, tx, characterId, ct);
        var after = await Book(conn, tx, characterId, req.Amount, "ADMIN_GRANT", "SOURCE", req.IdempotencyKey, req.ServerId!, ct);
        var auditId = await ProgressionEndpoints.Audit(conn, tx, admin, "/givegold", characterId,
            new { gold = before }, new { gold = after }, ct, args: new { amount = req.Amount });
        await tx.CommitAsync(ct);
        return Results.Ok(new { gold = after, duplicate = false, auditId });
    }

    /// <summary>Kontostand ändern und im Ledger buchen (append-only). Gibt den neuen Stand zurück.</summary>
    private static async Task<long> Book(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, long delta, string reason, string flow, Guid key,
        string serverId, CancellationToken ct)
    {
        // Das Wallet entsteht mit dem Charakter; der CHECK balance >= 0 fängt jede Überziehung zusätzlich ab.
        long balance;
        await using (var wallet = new NpgsqlCommand(
            """
            UPDATE character_wallets SET balance = balance + @delta
            WHERE character_id = @chr AND currency_code = 'GOLD'
            RETURNING balance
            """, conn, tx))
        {
            wallet.Parameters.AddWithValue("chr", characterId);
            wallet.Parameters.AddWithValue("delta", delta);
            balance = await wallet.ExecuteScalarAsync(ct) as long?
                ?? throw new InvalidOperationException($"Charakter {characterId} hat kein Gold-Wallet");
        }
        await using var ledger = new NpgsqlCommand(
            """
            INSERT INTO currency_ledger (character_id, currency_code, delta, balance_after, reason, flow, idempotency_key, server_id)
            VALUES (@chr, 'GOLD', @delta, @after, @reason, @flow, @key, @server)
            """, conn, tx);
        ledger.Parameters.AddWithValue("chr", characterId);
        ledger.Parameters.AddWithValue("delta", delta);
        ledger.Parameters.AddWithValue("after", balance);
        ledger.Parameters.AddWithValue("reason", reason);
        ledger.Parameters.AddWithValue("flow", flow);
        ledger.Parameters.AddWithValue("key", key);
        ledger.Parameters.AddWithValue("server", serverId);
        await ledger.ExecuteNonQueryAsync(ct);
        return balance;
    }

    private static IResult Problem(int status, string title) => Results.Problem(statusCode: status, title: title);
}
