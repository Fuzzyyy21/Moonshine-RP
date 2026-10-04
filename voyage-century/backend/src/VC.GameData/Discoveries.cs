using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Logging;

namespace VC.GameData;

public sealed record DiscoveryRequest(long CharacterId, long AccountId, string? ServerId, string? DiscoveryCode);

/// <summary>FirstTime = erstmals entdeckt; nur dann gibt es eine Belohnung (aus den Daten, nicht aus der Meldung).</summary>
public sealed record DiscoveryResponse(bool FirstTime, long? XpAwarded, CharacterProgress? Progress);

/// <summary>
/// Entdeckungen: Der Zonen-Server meldet, dass eine Spielfigur einen Entdeckungspunkt betreten hat. Gezählt wird nur,
/// wenn der Charakter auf diesem Server ONLINE ist und der Punkt in dieser Zone liegt; jede Entdeckung einmal je Charakter.
/// </summary>
public static class DiscoveryEndpoints
{
    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapPost("/world/discoveries", Discover);
    }

    public static async Task<List<string>> LoadDiscoveries(NpgsqlConnection conn, long characterId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT d.code FROM character_discoveries cd JOIN discoveries d USING (discovery_id)
            WHERE cd.character_id = @chr ORDER BY d.code
            """, conn);
        cmd.Parameters.AddWithValue("chr", characterId);
        var list = new List<string>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            list.Add(r.GetString(0));
        }
        return list;
    }

    private static async Task<IResult> Discover(
        DiscoveryRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content, IOptions<ProgressionOptions> progression,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || req.ServerId.Length > 64 || string.IsNullOrEmpty(req.DiscoveryCode)
            || req.DiscoveryCode.Length > 64)
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId und discoveryCode sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        var current = await ProgressionEndpoints.LockCharacter(conn, tx, req.CharacterId, req.AccountId, ct);
        if (current is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }

        int? discoveryId = null;
        string? zone = null;
        long? xpReward = null;
        await using (var cmd = new NpgsqlCommand(
            "SELECT discovery_id, zone_id, xp_reward FROM discoveries WHERE code = @code AND (NOT is_dev OR @dev)", conn, tx))
        {
            cmd.Parameters.AddWithValue("code", req.DiscoveryCode);
            cmd.Parameters.AddWithValue("dev", content.Value.AllowDevContent);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (await r.ReadAsync(ct))
            {
                discoveryId = r.GetInt32(0);
                zone = r.GetString(1);
                xpReward = r.IsDBNull(2) ? null : r.GetInt64(2);
            }
        }
        if (discoveryId is null)
        {
            return Problem(StatusCodes.Status400BadRequest, "Entdeckung unbekannt oder nicht freigegeben");
        }
        if (!await WorldEndpoints.HoldsPresence(conn, tx, req.CharacterId, req.ServerId, zone!, ct))
        {
            // Falsche Zone oder falscher Server: Meldungen eines alten oder fremden Servers zählen nicht.
            return Problem(StatusCodes.Status409Conflict, "Charakter ist nicht auf diesem Server in dieser Zone");
        }

        await using (var insert = new NpgsqlCommand(
            """
            INSERT INTO character_discoveries (character_id, discovery_id, server_id, xp_awarded)
            VALUES (@chr, @d, @server, @xp)
            ON CONFLICT (character_id, discovery_id) DO NOTHING
            """, conn, tx))
        {
            insert.Parameters.AddWithValue("chr", req.CharacterId);
            insert.Parameters.AddWithValue("d", discoveryId.Value);
            insert.Parameters.AddWithValue("server", req.ServerId);
            insert.Parameters.AddWithValue("xp", (object?)xpReward ?? DBNull.Value);
            if (await insert.ExecuteNonQueryAsync(ct) == 0)
            {
                return Results.Ok(new DiscoveryResponse(FirstTime: false, null, null));
            }
        }

        CharacterProgress? progress = null;
        if (xpReward is > 0)
        {
            progress = await ProgressionEndpoints.ApplyCharacterXp(conn, tx, req.CharacterId, current.Value,
                new GrantRequest(req.AccountId, xpReward.Value, $"discovery:{req.DiscoveryCode}", Guid.NewGuid(), req.ServerId),
                progression.Value.AllowDevCurves, ct);
        }
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("DISCOVERY", req.AccountId, req.CharacterId,
            NewValue: new { discovery = req.DiscoveryCode, zone, xp = xpReward, server = req.ServerId }), identity.Value.InstanceId, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new DiscoveryResponse(FirstTime: true, xpReward, progress));
    }

    private static IResult Problem(int status, string title) => Results.Problem(statusCode: status, title: title);
}
