using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Logging;
using VC.Common.Security;

namespace VC.GameData;

public sealed class WorldOptions
{
    public const string Section = "World";

    /// <summary>
    /// Zone, in der neue Charaktere beginnen. Die Startstadt des Originals ist UNKNOWN; ohne Wert können
    /// neue Charaktere nicht verbinden (bewusst, statt eine Stadt zu raten).
    /// </summary>
    public string? StartZoneId { get; set; }

    /// <summary>Ohne Lebenszeichen gilt ein Zonen-Server nach dieser Zeit als ausgefallen.</summary>
    [Range(5, 600)]
    public int ServerTimeoutSeconds { get; set; } = 30;

    /// <summary>So lange bleibt ein Platz auf dem Zielserver eines Zonenwechsels reserviert.</summary>
    [Range(5, 600)]
    public int TransferTimeoutSeconds { get; set; } = 60;
}

public sealed record ServerRequest(string? ZoneId, string? Address, int Capacity);
public sealed record ServerRegistration(int HeartbeatSeconds);
public sealed record ClaimRequest(long AccountId, string? ServerId);
public sealed record ClaimResponse(string ZoneId, string? ArrivalTag);
public sealed record TransferRequest(long CharacterId, long AccountId, string? ServerId, string? ExitCode);
public sealed record ServerAssignment(string ZoneId, string Address, string? ArrivalTag = null);

/// <summary>
/// World Directory: welche Zonen-Server laufen, wo jeder Charakter gerade ist, und Zonenwechsel.
///
/// Ein Charakter hat höchstens eine Anwesenheit (character_presence): ONLINE auf einem lebenden Server oder
/// TRANSFER (für den Zielserver reserviert). Nur der Server, auf dem der Charakter ONLINE ist, darf seinen
/// Zustand speichern. So existiert kein Zustand doppelt, auch nicht bei gleichzeitigen Logins oder
/// Zonenwechseln. Läuft vorerst im GameData-Dienst, weil es dieselben Tabellen braucht.
/// </summary>
public static partial class WorldEndpoints
{
    [GeneratedRegex(@"^[A-Za-z0-9.\-]{1,253}:[0-9]{1,5}$")]
    private static partial Regex AddressPattern();

    [GeneratedRegex(@"^[A-Z0-9_]{1,32}$")]
    private static partial Regex CodePattern();

    private const string LiveServer = "s.last_heartbeat > now() - make_interval(secs => @timeout)";

    public static void Map(RouteGroupBuilder internalApi, RouteGroupBuilder client)
    {
        internalApi.MapPost("/world/servers/{serverId}", StartServer);
        internalApi.MapPut("/world/servers/{serverId}/heartbeat", Heartbeat);
        internalApi.MapDelete("/world/servers/{serverId}", StopServer);
        internalApi.MapPost("/world/characters/{characterId:long}/claim", Claim);
        internalApi.MapDelete("/world/characters/{characterId:long}/claim", Release);
        internalApi.MapPost("/world/transfers", Transfer);
        client.MapGet("/characters/{characterId:long}/server", FindServer);
    }

    /// <summary>Nur der Server, auf dem der Charakter ONLINE ist, darf für diese Zone speichern. Charakter muss gesperrt sein.</summary>
    internal static async Task<bool> HoldsPresence(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, string serverId, string zoneId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT 1 FROM character_presence
            WHERE character_id = @chr AND server_id = @server AND zone_id = @zone AND state = 'ONLINE'
            """, conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        cmd.Parameters.AddWithValue("server", serverId);
        cmd.Parameters.AddWithValue("zone", zoneId);
        return await cmd.ExecuteScalarAsync(ct) is not null;
    }

    // ---- Zonen-Server ------------------------------------------------------------------------

    /// <summary>Prozessstart: Server eintragen und Anwesenheiten eines früheren Laufs verwerfen (dort ist niemand mehr).</summary>
    private static Task<IResult> StartServer(
        string serverId, ServerRequest req, NpgsqlDataSource db, IOptions<WorldOptions> world, CancellationToken ct) =>
        UpsertServer(serverId, req, db, world.Value, dropPresences: true, ct);

    /// <summary>Lebenszeichen; legt den Server auch neu an (z. B. nach Bereinigung), ohne Anwesenheiten zu verwerfen.</summary>
    private static Task<IResult> Heartbeat(
        string serverId, ServerRequest req, NpgsqlDataSource db, IOptions<WorldOptions> world, CancellationToken ct) =>
        UpsertServer(serverId, req, db, world.Value, dropPresences: false, ct);

    private static async Task<IResult> UpsertServer(
        string serverId, ServerRequest req, NpgsqlDataSource db, WorldOptions world, bool dropPresences, CancellationToken ct)
    {
        if (serverId.Length > 64 || string.IsNullOrEmpty(req.ZoneId) || req.Address is null || !AddressPattern().IsMatch(req.Address)
            || req.Capacity is < 1 or > 10_000)
        {
            return BadRequest("zoneId, address (host:port) und capacity (1–10000) sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        try
        {
            await using var cmd = new NpgsqlCommand(
                $"""
                INSERT INTO zone_servers (server_id, zone_id, address, capacity) VALUES (@s, @zone, @address, @capacity)
                ON CONFLICT (server_id) DO UPDATE SET
                    zone_id = EXCLUDED.zone_id, address = EXCLUDED.address, capacity = EXCLUDED.capacity,
                    last_heartbeat = now(){(dropPresences ? ", started_at = now()" : "")}
                """, conn, tx);
            cmd.Parameters.AddWithValue("s", serverId);
            cmd.Parameters.AddWithValue("zone", req.ZoneId);
            cmd.Parameters.AddWithValue("address", req.Address);
            cmd.Parameters.AddWithValue("capacity", req.Capacity);
            await cmd.ExecuteNonQueryAsync(ct);
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.ForeignKeyViolation)
        {
            return BadRequest("Unbekannte Zone");
        }
        if (dropPresences)
        {
            await using var drop = new NpgsqlCommand(
                "DELETE FROM character_presence WHERE server_id = @s AND state = 'ONLINE'", conn, tx);
            drop.Parameters.AddWithValue("s", serverId);
            await drop.ExecuteNonQueryAsync(ct);
        }
        await tx.CommitAsync(ct);
        return Results.Ok(new ServerRegistration(Math.Max(1, world.ServerTimeoutSeconds / 3)));
    }

    /// <summary>Geordnetes Herunterfahren. Anwesenheiten auf diesem Server enden mit ihm (Fremdschlüssel).</summary>
    private static async Task<IResult> StopServer(string serverId, NpgsqlDataSource db, CancellationToken ct)
    {
        await using var cmd = db.CreateCommand("DELETE FROM zone_servers WHERE server_id = @s");
        cmd.Parameters.AddWithValue("s", serverId);
        await cmd.ExecuteNonQueryAsync(ct);
        return Results.NoContent();
    }

    // ---- Anwesenheit -------------------------------------------------------------------------

    private static async Task<IResult> Claim(
        long characterId, ClaimRequest req, NpgsqlDataSource db, IOptions<WorldOptions> world, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || req.ServerId.Length > 64)
        {
            return BadRequest("serverId ist erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return NotFound("Charakter nicht gefunden");
        }

        string? serverZone = null;
        var zoneIsDev = false;
        await using (var cmd = new NpgsqlCommand(
            $"""
            SELECT s.zone_id, z.is_dev FROM zone_servers s JOIN zones z USING (zone_id)
            WHERE s.server_id = @s AND {LiveServer}
            """, conn, tx))
        {
            cmd.Parameters.AddWithValue("s", req.ServerId);
            cmd.Parameters.AddWithValue("timeout", world.Value.ServerTimeoutSeconds);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (await r.ReadAsync(ct))
            {
                serverZone = r.GetString(0);
                zoneIsDev = r.GetBoolean(1);
            }
        }
        if (serverZone is null)
        {
            return Conflict("Server ist nicht angemeldet");
        }
        if (zoneIsDev && !content.Value.AllowDevContent)
        {
            return Conflict("Zone ist nicht freigegeben");
        }

        // Ein Charakter betritt nur die Zone, in der er gespeichert ist (neue Charaktere: Startzone).
        // Sonst wäre ein direktes Verbinden ein Teleport an jeder Regel vorbei.
        var characterZone = await CharacterZone(conn, tx, characterId, ct) ?? world.Value.StartZoneId;
        if (characterZone != serverZone)
        {
            return Conflict(characterZone is null ? "Keine Startzone konfiguriert" : $"Charakter befindet sich in Zone {characterZone}");
        }

        var presence = await LoadPresence(conn, tx, characterId, world.Value, ct);
        if (presence is not null && presence.ServerId != req.ServerId && presence.Live)
        {
            return Conflict(presence.State == "TRANSFER" ? "Zonenwechsel zu einem anderen Server läuft" : "Charakter ist bereits online");
        }
        var arrival = presence is { State: "TRANSFER" } && presence.ZoneId == serverZone ? presence.ArrivalTag : null;

        await using (var upsert = new NpgsqlCommand(
            """
            INSERT INTO character_presence (character_id, server_id, zone_id, state) VALUES (@chr, @s, @zone, 'ONLINE')
            ON CONFLICT (character_id) DO UPDATE SET
                server_id = EXCLUDED.server_id, zone_id = EXCLUDED.zone_id, state = 'ONLINE',
                arrival_tag = NULL, since = now(), expires_at = NULL
            """, conn, tx))
        {
            upsert.Parameters.AddWithValue("chr", characterId);
            upsert.Parameters.AddWithValue("s", req.ServerId);
            upsert.Parameters.AddWithValue("zone", serverZone);
            await upsert.ExecuteNonQueryAsync(ct);
        }
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("ZONE_ENTER", req.AccountId, characterId,
            NewValue: new { zone = serverZone, server = req.ServerId, arrival }), identity.Value.InstanceId, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new ClaimResponse(serverZone, arrival));
    }

    /// <summary>Beim Ausloggen nach dem letzten Speichern. Wirkt nur, wenn der Charakter noch auf diesem Server ONLINE ist.</summary>
    private static async Task<IResult> Release(long characterId, string? serverId, NpgsqlDataSource db, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(serverId))
        {
            return BadRequest("serverId ist erforderlich");
        }
        await using var cmd = db.CreateCommand(
            "DELETE FROM character_presence WHERE character_id = @chr AND server_id = @s AND state = 'ONLINE'");
        cmd.Parameters.AddWithValue("chr", characterId);
        cmd.Parameters.AddWithValue("s", serverId);
        await cmd.ExecuteNonQueryAsync(ct);
        return Results.NoContent();
    }

    // ---- Zonenwechsel ------------------------------------------------------------------------

    private static async Task<IResult> Transfer(
        TransferRequest req, NpgsqlDataSource db, IOptions<WorldOptions> world, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || req.ServerId.Length > 64 || req.ExitCode is null || !CodePattern().IsMatch(req.ExitCode))
        {
            return BadRequest("serverId und exitCode (A-Z, 0-9, _) sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, req.CharacterId, req.AccountId, ct) is null)
        {
            return NotFound("Charakter nicht gefunden");
        }
        var presence = await LoadPresence(conn, tx, req.CharacterId, world.Value, ct);
        if (presence is not { State: "ONLINE" } || presence.ServerId != req.ServerId)
        {
            return Conflict("Charakter ist nicht auf diesem Server");
        }

        string? toZone = null;
        string? arrival = null;
        var toDev = false;
        await using (var cmd = new NpgsqlCommand(
            """
            SELECT l.to_zone_id, l.arrival_tag, z.is_dev FROM zone_links l JOIN zones z ON z.zone_id = l.to_zone_id
            WHERE l.from_zone_id = @from AND l.exit_code = @exit
            """, conn, tx))
        {
            cmd.Parameters.AddWithValue("from", presence.ZoneId);
            cmd.Parameters.AddWithValue("exit", req.ExitCode);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (await r.ReadAsync(ct))
            {
                toZone = r.GetString(0);
                arrival = r.GetString(1);
                toDev = r.GetBoolean(2);
            }
        }
        if (toZone is null)
        {
            return BadRequest($"Zone {presence.ZoneId} hat keinen Ausgang {req.ExitCode}");
        }
        if (toDev && !content.Value.AllowDevContent)
        {
            return BadRequest("Zielzone ist nicht freigegeben");
        }
        var target = await PickServer(conn, tx, toZone, world.Value, ct);
        if (target is null)
        {
            return Results.Problem(statusCode: StatusCodes.Status503ServiceUnavailable, title: $"Kein Server für Zone {toZone} erreichbar");
        }

        // Position gehört zur alten Zone; am Ziel entscheidet der Ankunftspunkt.
        await using (var move = new NpgsqlCommand(
            "UPDATE characters SET zone_id = @zone, pos_x = NULL, pos_y = NULL, pos_z = NULL, yaw = NULL WHERE character_id = @chr",
            conn, tx))
        {
            move.Parameters.AddWithValue("zone", toZone);
            move.Parameters.AddWithValue("chr", req.CharacterId);
            await move.ExecuteNonQueryAsync(ct);
        }
        await using (var reserve = new NpgsqlCommand(
            """
            UPDATE character_presence
            SET server_id = @s, zone_id = @zone, state = 'TRANSFER', arrival_tag = @arrival, since = now(),
                expires_at = now() + make_interval(secs => @ttl)
            WHERE character_id = @chr
            """, conn, tx))
        {
            reserve.Parameters.AddWithValue("s", target.Value.ServerId);
            reserve.Parameters.AddWithValue("zone", toZone);
            reserve.Parameters.AddWithValue("arrival", arrival!);
            reserve.Parameters.AddWithValue("ttl", world.Value.TransferTimeoutSeconds);
            reserve.Parameters.AddWithValue("chr", req.CharacterId);
            await reserve.ExecuteNonQueryAsync(ct);
        }
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("ZONE_TRANSFER", req.AccountId, req.CharacterId,
            OldValue: new { zone = presence.ZoneId, server = req.ServerId, exit = req.ExitCode },
            NewValue: new { zone = toZone, server = target.Value.ServerId, arrival }), identity.Value.InstanceId, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new ServerAssignment(toZone, target.Value.Address, arrival));
    }

    // ---- Client: wohin verbinden? ------------------------------------------------------------

    private static async Task<IResult> FindServer(
        long characterId, HttpContext http, NpgsqlDataSource db, IOptions<WorldOptions> world, IOptions<ContentOptions> content,
        CancellationToken ct)
    {
        var session = SessionFilter.Get(http);
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, session.AccountId, ct) is null)
        {
            return NotFound("Charakter nicht gefunden");
        }
        var presence = await LoadPresence(conn, tx, characterId, world.Value, ct);
        if (presence is { Live: true, State: "ONLINE" })
        {
            return Conflict("Charakter ist bereits online");
        }
        if (presence is { Live: true, State: "TRANSFER" })
        {
            // Zonenwechsel unterbrochen (z. B. Client abgestürzt): zum reservierten Server.
            return Results.Ok(new ServerAssignment(presence.ZoneId, presence.Address!, presence.ArrivalTag));
        }

        var zone = await CharacterZone(conn, tx, characterId, ct) ?? world.Value.StartZoneId;
        if (zone is null)
        {
            return Unavailable("Keine Startzone konfiguriert");
        }
        await using (var dev = new NpgsqlCommand("SELECT is_dev FROM zones WHERE zone_id = @zone", conn, tx))
        {
            dev.Parameters.AddWithValue("zone", zone);
            if (await dev.ExecuteScalarAsync(ct) is not bool isDev || (isDev && !content.Value.AllowDevContent))
            {
                return Unavailable($"Zone {zone} ist nicht freigegeben");
            }
        }
        var target = await PickServer(conn, tx, zone, world.Value, ct);
        await tx.CommitAsync(ct);
        return target is null
            ? Unavailable($"Kein Server für Zone {zone} erreichbar")
            : Results.Ok(new ServerAssignment(zone, target.Value.Address));
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Presence(string ServerId, string ZoneId, string State, string? ArrivalTag, bool Live, string? Address);

    private static async Task<Presence?> LoadPresence(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, WorldOptions world, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            $"""
            SELECT p.server_id, p.zone_id, p.state, p.arrival_tag,
                   CASE WHEN p.state = 'TRANSFER' THEN p.expires_at > now() ELSE {LiveServer} END,
                   s.address
            FROM character_presence p JOIN zone_servers s USING (server_id)
            WHERE p.character_id = @chr
            FOR UPDATE OF p
            """, conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        cmd.Parameters.AddWithValue("timeout", world.ServerTimeoutSeconds);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct)
            ? new Presence(r.GetString(0), r.GetString(1), r.GetString(2), r.IsDBNull(3) ? null : r.GetString(3), r.GetBoolean(4),
                r.GetString(5))
            : null;
    }

    private static async Task<string?> CharacterZone(NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("SELECT zone_id FROM characters WHERE character_id = @chr", conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        return await cmd.ExecuteScalarAsync(ct) as string;
    }

    /// <summary>Lebender Server der Zone mit freiem Platz, der am wenigsten belegte zuerst.</summary>
    private static async Task<(string ServerId, string Address)?> PickServer(
        NpgsqlConnection conn, NpgsqlTransaction tx, string zoneId, WorldOptions world, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            $"""
            SELECT s.server_id, s.address
            FROM zone_servers s
            CROSS JOIN LATERAL (
                SELECT count(*) AS used FROM character_presence p
                WHERE p.server_id = s.server_id AND (p.state = 'ONLINE' OR p.expires_at > now())
            ) load
            WHERE s.zone_id = @zone AND {LiveServer} AND load.used < s.capacity
            ORDER BY load.used, s.server_id
            LIMIT 1
            """, conn, tx);
        cmd.Parameters.AddWithValue("zone", zoneId);
        cmd.Parameters.AddWithValue("timeout", world.ServerTimeoutSeconds);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct) ? (r.GetString(0), r.GetString(1)) : null;
    }

    private static IResult BadRequest(string title) => Results.Problem(statusCode: StatusCodes.Status400BadRequest, title: title);

    private static IResult NotFound(string title) => Results.Problem(statusCode: StatusCodes.Status404NotFound, title: title);

    private static IResult Conflict(string title) => Results.Problem(statusCode: StatusCodes.Status409Conflict, title: title);

    private static IResult Unavailable(string title) => Results.Problem(statusCode: StatusCodes.Status503ServiceUnavailable, title: title);
}
