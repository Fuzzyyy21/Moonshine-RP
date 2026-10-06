using System.Text.Json;
using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Logging;

namespace VC.GameData;

/// <summary>State: SCHEDULED, RUNNING (aus der Zeit), FINISHED, CANCELLED.</summary>
public sealed record SiegeInfo(
    long WarId, string CityCode, long AttackerGuildId, string AttackerName, long DefenderGuildId, string DefenderName, DateTime StartsAt,
    DateTime EndsAt, string State, int AttackerScore, int DefenderScore, long? WinnerGuildId);
/// <summary>Laufende Belagerung, die diese Zone betrifft, mit den Teilnehmern, die auf dem fragenden Server online sind.</summary>
public sealed record ActiveSiege(long WarId, string CityCode, DateTime EndsAt, long AttackerGuildId, long DefenderGuildId, long[] Attackers,
    long[] Defenders);
public sealed record SiegeDeclareRequest(long AccountId, string? ServerId, Guid Key);

/// <summary>
/// Stadtbelagerung [DESIGN] (belegt nur: es gibt sie, beworben als Land-See-Kampf – SYS-CITY-SIEGE). Gekämpft wird in der Stadtzone
/// und den Seezonen, in die ihr Hafen führt. Abgerechnet wird bei der nächsten Abfrage nach Ende (kein Hintergrunddienst nötig).
/// </summary>
public static class SiegeEndpoints
{
    private const string OpenStates = "('SCHEDULED', 'RUNNING')";

    /// <summary>Stadtzone und die Seezonen, in die ihr Hafen führt (Land-See-Kampf).</summary>
    private const string SiegeZones =
        """
        (SELECT c.zone_id UNION SELECT l.to_zone_id FROM zone_links l JOIN zones z ON z.zone_id = l.to_zone_id
         WHERE l.from_zone_id = c.zone_id AND z.zone_kind = 'SEA')
        """;

    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapGet("/sieges", List);
        internalApi.MapGet("/zones/{zoneId}/sieges/active", Active);
        internalApi.MapPost("/characters/{characterId:long}/guild/cities/{cityCode}/siege", Declare);
    }

    private static async Task<IResult> List(NpgsqlDataSource db, IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        await ResolveFinished(conn, tx, identity.Value.InstanceId, ct);
        var list = await Load(conn, tx, $"w.state IN {OpenStates} OR w.resolved_at > now() - INTERVAL '7 days'", null, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(list);
    }

    private static async Task<IResult> Active(string zoneId, string? serverId, NpgsqlDataSource db, IOptions<ServiceIdentityOptions> identity,
        CancellationToken ct)
    {
        if (string.IsNullOrEmpty(serverId))
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId ist erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        await ResolveFinished(conn, tx, identity.Value.InstanceId, ct);
        await using var cmd = new NpgsqlCommand(
            $"""
            SELECT w.war_id, c.code, w.ends_at, w.attacker_guild_id, w.defender_guild_id,
                   ARRAY(SELECT m.character_id FROM guild_members m JOIN character_presence p USING (character_id)
                         WHERE m.guild_id = w.attacker_guild_id AND p.server_id = @server AND p.state = 'ONLINE'),
                   ARRAY(SELECT m.character_id FROM guild_members m JOIN character_presence p USING (character_id)
                         WHERE m.guild_id = w.defender_guild_id AND p.server_id = @server AND p.state = 'ONLINE')
            FROM territory_wars w JOIN territories t USING (territory_id) JOIN cities c USING (city_id)
            WHERE w.state IN {OpenStates} AND w.scheduled_at <= now() AND w.ends_at > now() AND @zone IN {SiegeZones}
            """, conn, tx);
        cmd.Parameters.AddWithValue("server", serverId);
        cmd.Parameters.AddWithValue("zone", zoneId);
        var list = new List<ActiveSiege>();
        await using (var r = await cmd.ExecuteReaderAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                list.Add(new ActiveSiege(r.GetInt64(0), r.GetString(1), r.GetDateTime(2), r.GetInt64(3), r.GetInt64(4),
                    r.GetFieldValue<long[]>(5), r.GetFieldValue<long[]>(6)));
            }
        }
        await tx.CommitAsync(ct);
        return Results.Ok(list);
    }

    /// <summary>Belagerung einer fremden Stadt ansagen (Recht CITY), bezahlt aus der Gildenkasse (Senke SIEGE_DECLARE).</summary>
    private static async Task<IResult> Declare(
        long characterId, string cityCode, SiegeDeclareRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (req.Key == Guid.Empty)
        {
            return Problem(StatusCodes.Status400BadRequest, "key ist erforderlich");
        }
        var code = cityCode.ToUpperInvariant();
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await GuildEndpoints.BeginMember(conn, tx, characterId, req.AccountId, req.ServerId, ct) is not { } me)
        {
            return Problem(StatusCodes.Status409Conflict, "Nur Gildenmitglieder auf diesem Server");
        }
        var existing = await Load(conn, tx, "w.declare_key = @key", ("key", req.Key), ct);
        if (existing.Count == 1)
        {
            await tx.CommitAsync(ct);
            return Results.Ok(existing[0]);
        }
        if (!GuildRules.Has(me.Rank, GuildRules.City))
        {
            return Problem(StatusCodes.Status403Forbidden, "Belagerungen ansagen darf nur, wer das Recht für Städte hat");
        }
        await ResolveFinished(conn, tx, identity.Value.InstanceId, ct);
        if (await LoadTuning(conn, tx, content.Value.AllowDevContent, ct) is not { } tuning)
        {
            return Problem(StatusCodes.Status400BadRequest, "Belagerungen sind nicht verfügbar (Werte fehlen)");
        }
        long territoryId;
        long? owner;
        bool open;
        await using (var t = new NpgsqlCommand(
            $"""
            SELECT t.territory_id, g.guild_id,
                   EXISTS (SELECT 1 FROM territory_wars w WHERE w.territory_id = t.territory_id AND w.state IN {OpenStates})
            FROM territories t JOIN cities c USING (city_id)
            LEFT JOIN guilds g ON g.guild_id = t.owner_guild_id AND g.disbanded_at IS NULL
            WHERE c.code = @code AND (NOT t.is_dev OR @dev)
            FOR UPDATE OF t
            """, conn, tx))
        {
            t.Parameters.AddWithValue("code", code);
            t.Parameters.AddWithValue("dev", content.Value.AllowDevContent);
            await using var r = await t.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
            {
                return Problem(StatusCodes.Status404NotFound, "Stadt unbekannt");
            }
            (territoryId, owner, open) = (r.GetInt64(0), r.IsDBNull(1) ? null : r.GetInt64(1), r.GetBoolean(2));
        }
        if (!SiegeRules.CanDeclare(me.GuildId, owner, open))
        {
            return Problem(StatusCodes.Status409Conflict, "Belagern geht nur bei Städten anderer Gilden ohne laufende Belagerung (freie Städte kauft man)");
        }
        if (await GuildCityEndpoints.Treasury(conn, tx, me.GuildId, ct) < tuning.DeclareCost)
        {
            return Problem(StatusCodes.Status409Conflict, $"Zu wenig in der Gildenkasse ({tuning.DeclareCost} nötig)");
        }
        if (tuning.DeclareCost > 0)
        {
            await GuildCityEndpoints.BookGuild(conn, tx, me.GuildId, characterId, -tuning.DeclareCost, "SIEGE_DECLARE", "SINK", req.Key,
                req.ServerId!, ct);
        }
        await using (var insert = new NpgsqlCommand(
            """
            INSERT INTO territory_wars (territory_id, attacker_guild_id, defender_guild_id, scheduled_at, ends_at, declare_key, declared_by)
            VALUES (@t, @a, @d, now() + make_interval(hours => @lead), now() + make_interval(hours => @lead, mins => @dur), @key, @chr)
            """, conn, tx))
        {
            insert.Parameters.AddWithValue("t", territoryId);
            insert.Parameters.AddWithValue("a", me.GuildId);
            insert.Parameters.AddWithValue("d", owner!.Value);
            insert.Parameters.AddWithValue("lead", tuning.LeadHours);
            insert.Parameters.AddWithValue("dur", tuning.DurationMinutes);
            insert.Parameters.AddWithValue("key", req.Key);
            insert.Parameters.AddWithValue("chr", characterId);
            await insert.ExecuteNonQueryAsync(ct);
        }
        var siege = (await Load(conn, tx, "w.declare_key = @key", ("key", req.Key), ct))[0];
        await Announce(conn, tx,
            $"{siege.AttackerName} belagert {code} (Verteidiger: {siege.DefenderName}) ab {siege.StartsAt:yyyy-MM-dd HH:mm} UTC für {tuning.DurationMinutes} Minuten.", ct);
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("SIEGE_DECLARE", req.AccountId, characterId,
            NewValue: new { war = siege.WarId, city = code, attacker = me.GuildId, defender = owner }), identity.Value.InstanceId, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(siege);
    }

    // ---- Für Kampf und Gilden -----------------------------------------------------------------

    /// <summary>
    /// Laufende Belagerung in dieser Zone zwischen den Gilden von Killer und Opfer: Kriegs-ID und Seite, die punktet. Null, wenn der
    /// Kill nicht zur Belagerung gehört. Sperrt die Kriegszeile, damit die Wertung bei gleichzeitigen Kills stimmt.
    /// </summary>
    internal static async Task<(long WarId, SiegeSide Side)?> SiegeForKill(
        NpgsqlConnection conn, NpgsqlTransaction tx, string zoneId, long killerId, long victimId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            $"""
            SELECT w.war_id, w.attacker_guild_id, w.defender_guild_id,
                   (SELECT guild_id FROM guild_members WHERE character_id = @killer),
                   (SELECT guild_id FROM guild_members WHERE character_id = @victim)
            FROM territory_wars w JOIN territories t USING (territory_id) JOIN cities c USING (city_id)
            WHERE w.state IN {OpenStates} AND w.scheduled_at <= now() AND w.ends_at > now() AND @zone IN {SiegeZones}
            ORDER BY w.war_id
            FOR UPDATE OF w
            """, conn, tx);
        cmd.Parameters.AddWithValue("zone", zoneId);
        cmd.Parameters.AddWithValue("killer", killerId);
        cmd.Parameters.AddWithValue("victim", victimId);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            var side = SiegeRules.ScoringSide(r.IsDBNull(3) ? null : r.GetInt64(3), r.IsDBNull(4) ? null : r.GetInt64(4), r.GetInt64(1), r.GetInt64(2));
            if (side != SiegeSide.None)
            {
                return (r.GetInt64(0), side);
            }
        }
        return null;
    }

    internal static async Task Score(NpgsqlConnection conn, NpgsqlTransaction tx, long warId, SiegeSide side, CancellationToken ct)
    {
        var column = side == SiegeSide.Attacker ? "attacker_score" : "defender_score";
        await using var cmd = new NpgsqlCommand($"UPDATE territory_wars SET {column} = {column} + 1 WHERE war_id = @w", conn, tx);
        cmd.Parameters.AddWithValue("w", warId);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    /// <summary>Offene Belagerungen einer aufgelösten Gilde entfallen.</summary>
    internal static async Task CancelForGuild(NpgsqlConnection conn, NpgsqlTransaction tx, long guildId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            $"""
            UPDATE territory_wars SET state = 'CANCELLED', resolved_at = now()
            WHERE state IN {OpenStates} AND (attacker_guild_id = @g OR defender_guild_id = @g)
            """, conn, tx);
        cmd.Parameters.AddWithValue("g", guildId);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    /// <summary>
    /// Beendete Belagerungen abrechnen: Gewinnt der Angreifer, geht die Stadt an ihn (Steuersatz zurück auf den Markt), sonst bleibt
    /// sie beim Verteidiger. Ergebnis als Systemmeldung an alle.
    /// </summary>
    internal static async Task ResolveFinished(NpgsqlConnection conn, NpgsqlTransaction tx, string serverId, CancellationToken ct)
    {
        var done = new List<(long War, long Territory, long Attacker, long Defender, int A, int D, string City)>();
        await using (var cmd = new NpgsqlCommand(
            $"""
            SELECT w.war_id, w.territory_id, w.attacker_guild_id, w.defender_guild_id, w.attacker_score, w.defender_score, c.code
            FROM territory_wars w JOIN territories t USING (territory_id) JOIN cities c USING (city_id)
            WHERE w.state IN {OpenStates} AND w.ends_at <= now()
            ORDER BY w.war_id
            FOR UPDATE OF w, t
            """, conn, tx))
        {
            await using var r = await cmd.ExecuteReaderAsync(ct);
            while (await r.ReadAsync(ct))
            {
                done.Add((r.GetInt64(0), r.GetInt64(1), r.GetInt64(2), r.GetInt64(3), r.GetInt32(4), r.GetInt32(5), r.GetString(6)));
            }
        }
        foreach (var w in done)
        {
            var attackerWins = SiegeRules.AttackerWins(w.A, w.D);
            var winner = attackerWins ? w.Attacker : w.Defender;
            if (attackerWins)
            {
                await using var take = new NpgsqlCommand(
                    """
                    UPDATE territories SET owner_guild_id = @a, captured_at = now(), tax_rate = NULL
                    WHERE territory_id = @t AND owner_guild_id = @d
                      AND EXISTS (SELECT 1 FROM guilds WHERE guild_id = @a AND disbanded_at IS NULL)
                    """, conn, tx);
                take.Parameters.AddWithValue("a", w.Attacker);
                take.Parameters.AddWithValue("t", w.Territory);
                take.Parameters.AddWithValue("d", w.Defender);
                await take.ExecuteNonQueryAsync(ct);
            }
            await using (var fin = new NpgsqlCommand(
                """
                UPDATE territory_wars SET state = 'FINISHED', winner_guild_id = @win, resolved_at = now(), result = @result::jsonb
                WHERE war_id = @w
                """, conn, tx))
            {
                fin.Parameters.AddWithValue("win", winner);
                fin.Parameters.AddWithValue("result", JsonSerializer.Serialize(new { attackerScore = w.A, defenderScore = w.D, attackerWins }));
                fin.Parameters.AddWithValue("w", w.War);
                await fin.ExecuteNonQueryAsync(ct);
            }
            await Announce(conn, tx, attackerWins
                ? $"Belagerung von {w.City} beendet ({w.A}:{w.D}) – die Angreifer übernehmen die Stadt."
                : $"Belagerung von {w.City} beendet ({w.A}:{w.D}) – die Verteidiger halten die Stadt.", ct);
            await GameEventLog.WriteAsync(conn, tx, new GameEvent("SIEGE_RESOLVED",
                NewValue: new { war = w.War, city = w.City, attackerScore = w.A, defenderScore = w.D, winner }), serverId, ct);
        }
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private static async Task Announce(NpgsqlConnection conn, NpgsqlTransaction tx, string message, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("INSERT INTO chat_log (channel, message) VALUES ('SYSTEM', @m)", conn, tx);
        cmd.Parameters.AddWithValue("m", message);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    private static async Task<SiegeTuning?> LoadTuning(NpgsqlConnection conn, NpgsqlTransaction tx, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            "SELECT rule_key, int_value FROM game_rules WHERE rule_key LIKE 'SIEGE\\_%' AND (NOT is_dev OR @dev)", conn, tx);
        cmd.Parameters.AddWithValue("dev", allowDev);
        var v = new Dictionary<string, long>();
        await using (var r = await cmd.ExecuteReaderAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                v[r.GetString(0)] = r.GetInt64(1);
            }
        }
        if (!v.TryGetValue("SIEGE_DECLARE_COST", out var cost) || !v.TryGetValue("SIEGE_LEAD_HOURS", out var lead)
            || !v.TryGetValue("SIEGE_DURATION_MINUTES", out var dur))
        {
            return null;
        }
        var tuning = new SiegeTuning(cost, (int)lead, (int)dur);
        return SiegeRules.IsValidTuning(tuning) ? tuning : null;
    }

    private static async Task<List<SiegeInfo>> Load(
        NpgsqlConnection conn, NpgsqlTransaction tx, string where, (string, object)? parameter, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            $"""
            SELECT w.war_id, c.code, w.attacker_guild_id, ga.name, w.defender_guild_id, gd.name, w.scheduled_at, w.ends_at,
                   CASE WHEN w.state IN {OpenStates} AND w.scheduled_at <= now() THEN 'RUNNING' ELSE w.state END,
                   w.attacker_score, w.defender_score, w.winner_guild_id
            FROM territory_wars w JOIN territories t USING (territory_id) JOIN cities c USING (city_id)
            JOIN guilds ga ON ga.guild_id = w.attacker_guild_id JOIN guilds gd ON gd.guild_id = w.defender_guild_id
            WHERE {where}
            ORDER BY w.scheduled_at DESC
            LIMIT 100
            """, conn, tx);
        if (parameter is { } p)
        {
            cmd.Parameters.AddWithValue(p.Item1, p.Item2);
        }
        var list = new List<SiegeInfo>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            list.Add(new SiegeInfo(r.GetInt64(0), r.GetString(1), r.GetInt64(2), r.GetString(3), r.GetInt64(4), r.GetString(5), r.GetDateTime(6),
                r.GetDateTime(7), r.GetString(8), r.GetInt32(9), r.GetInt32(10), r.IsDBNull(11) ? null : r.GetInt64(11)));
        }
        return list;
    }

    private static IResult Problem(int status, string title) => Results.Problem(statusCode: status, title: title);
}
