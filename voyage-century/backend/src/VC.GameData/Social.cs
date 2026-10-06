using System.Net;
using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common.Logging;

namespace VC.GameData;

public sealed record ChatSendRequest(long CharacterId, long AccountId, string? ServerId, string? Channel, string? Message, string? TargetName = null);
public sealed record ChatSent(long MessageId, string Channel, string SenderName, string Message, long? TargetCharacterId, string? TargetName);
/// <summary>Recipients: bei GUILD die Gildenmitglieder, die auf dem abfragenden Server online sind.</summary>
public sealed record ChatMessage(
    long MessageId, string Channel, long? SenderCharacterId, string? SenderName, long? TargetCharacterId, string Message, DateTime CreatedAt,
    long[]? Recipients = null);
/// <summary>LastId: ab hier beim nächsten Mal weiterfragen.</summary>
public sealed record ChatPoll(long LastId, List<ChatMessage> Messages);
public sealed record SocialEntry(long CharacterId, string Name, bool Online, string? ZoneId);
public sealed record NameRequest(long AccountId, string? Name);
public sealed record ReportRequest(long AccountId, string? ServerId, string? Name, string? Reason);
public sealed record AdminMuteRequest(
    long AdminAccountId, string? CharacterName, int Minutes, string? Channel, string? Reason, Guid? SessionId, string? Ip, string? ServerId);
public sealed record AdminAnnounceRequest(long AdminAccountId, string? Message, Guid? SessionId, string? Ip, string? ServerId);

/// <summary>
/// Chat, Freunde, Ignorieren, Melden und Chat-Moderation [DESIGN] (GDD 19; im Original UNKNOWN). Der Zonen-Server stellt LOCAL
/// selbst zu und meldet alles hierher (Prüfung, Protokoll). WORLD, TRADE, SYSTEM und WHISPER verteilt chat_log: Jeder Server holt
/// regelmäßig ab, was nach seiner letzten message_id dazukam – WHISPER nur für Spieler, die bei ihm angemeldet sind.
/// </summary>
public static class SocialEndpoints
{
    private const int PollLimit = 200;

    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapPost("/chat", Send);
        internalApi.MapGet("/chat", Poll);
        internalApi.MapGet("/characters/{characterId:long}/friends", (long characterId, long accountId, NpgsqlDataSource db, CancellationToken ct) =>
            ListEntries(characterId, accountId, "friends", "friend_character_id", db, ct));
        internalApi.MapPost("/characters/{characterId:long}/friends", (long characterId, NameRequest req, NpgsqlDataSource db,
            IOptions<ChatOptions> chat, CancellationToken ct) => AddEntry(characterId, req, "friends", "friend_character_id", chat.Value.MaxFriends, db, ct));
        internalApi.MapDelete("/characters/{characterId:long}/friends/{otherId:long}", (long characterId, long otherId, long accountId,
            NpgsqlDataSource db, CancellationToken ct) => RemoveEntry(characterId, otherId, accountId, "friends", "friend_character_id", db, ct));
        internalApi.MapGet("/characters/{characterId:long}/ignores", (long characterId, long accountId, NpgsqlDataSource db, CancellationToken ct) =>
            ListEntries(characterId, accountId, "ignores", "ignored_character_id", db, ct));
        internalApi.MapPost("/characters/{characterId:long}/ignores", (long characterId, NameRequest req, NpgsqlDataSource db,
            IOptions<ChatOptions> chat, CancellationToken ct) => AddEntry(characterId, req, "ignores", "ignored_character_id", chat.Value.MaxFriends, db, ct));
        internalApi.MapDelete("/characters/{characterId:long}/ignores/{otherId:long}", (long characterId, long otherId, long accountId,
            NpgsqlDataSource db, CancellationToken ct) => RemoveEntry(characterId, otherId, accountId, "ignores", "ignored_character_id", db, ct));
        internalApi.MapPost("/characters/{characterId:long}/reports", Report);
        internalApi.MapPost("/admin/mutes", AdminMute);
        internalApi.MapPost("/admin/announce", AdminAnnounce);
    }

    // ---- Chat ---------------------------------------------------------------------------------

    private static async Task<IResult> Send(ChatSendRequest req, NpgsqlDataSource db, IOptions<ChatOptions> options, CancellationToken ct)
    {
        var o = options.Value;
        var channel = req.Channel?.ToUpperInvariant();
        var message = ChatRules.Sanitize(req.Message, o.MaxLength);
        if (channel is null || !ChatRules.PlayerChannels.Contains(channel) || string.IsNullOrEmpty(req.ServerId))
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId und channel (LOCAL, WORLD, TRADE, WHISPER, GUILD) sind erforderlich");
        }
        if (message is null)
        {
            return Problem(StatusCodes.Status400BadRequest, $"Nachricht leer oder länger als {o.MaxLength} Zeichen");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, req.CharacterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        var zone = await WorldEndpoints.PresenceZone(conn, tx, req.CharacterId, req.ServerId, ct);
        if (zone is null)
        {
            return Problem(StatusCodes.Status409Conflict, "Charakter ist nicht auf diesem Server");
        }
        await using (var mute = new NpgsqlCommand(
            """
            SELECT max(muted_until) FROM chat_mutes
            WHERE character_id = @chr AND muted_until > now() AND (channel IS NULL OR channel = @ch)
            """, conn, tx))
        {
            mute.Parameters.AddWithValue("chr", req.CharacterId);
            mute.Parameters.AddWithValue("ch", channel);
            if (await mute.ExecuteScalarAsync(ct) is DateTime until)
            {
                return Problem(StatusCodes.Status403Forbidden, $"Stummgeschaltet bis {until:yyyy-MM-dd HH:mm} UTC");
            }
        }
        var recent = new List<DateTime>();
        DateTime now;
        await using (var rate = new NpgsqlCommand(
            """
            SELECT created_at, now() FROM chat_log
            WHERE sender_character_id = @chr AND channel = @ch AND created_at > now() - make_interval(secs => @win)
            """, conn, tx))
        {
            rate.Parameters.AddWithValue("chr", req.CharacterId);
            rate.Parameters.AddWithValue("ch", channel);
            rate.Parameters.AddWithValue("win", (double)o.WindowSeconds);
            await using var r = await rate.ExecuteReaderAsync(ct);
            now = DateTime.UtcNow;
            while (await r.ReadAsync(ct))
            {
                recent.Add(r.GetDateTime(0));
                now = r.GetDateTime(1);
            }
        }
        if (!ChatRules.WithinRate(recent, now, ChatRules.IsWide(channel) ? o.WideMaxPerWindow : o.MaxPerWindow,
                TimeSpan.FromSeconds(o.WindowSeconds)))
        {
            return Problem(StatusCodes.Status429TooManyRequests, "Zu viele Nachrichten – kurz warten");
        }

        long? targetId = null;
        string? targetName = null;
        long? guildId = null;
        if (channel == "GUILD" && (guildId = await GuildEndpoints.GuildIdOf(conn, tx, req.CharacterId, ct)) is null)
        {
            return Problem(StatusCodes.Status409Conflict, "Du bist in keiner Gilde");
        }
        if (channel == "WHISPER")
        {
            if (await FindCharacter(conn, tx, req.TargetName, ct) is not { } target || target.Id == req.CharacterId)
            {
                return Problem(StatusCodes.Status404NotFound, "Empfänger unbekannt");
            }
            (targetId, targetName) = (target.Id, target.Name);
            await using var check = new NpgsqlCommand(
                """
                SELECT EXISTS (SELECT 1 FROM character_presence WHERE character_id = @t AND state = 'ONLINE'),
                       EXISTS (SELECT 1 FROM ignores WHERE character_id = @t AND ignored_character_id = @chr)
                """, conn, tx);
            check.Parameters.AddWithValue("t", target.Id);
            check.Parameters.AddWithValue("chr", req.CharacterId);
            await using var r = await check.ExecuteReaderAsync(ct);
            await r.ReadAsync(ct);
            if (!r.GetBoolean(0))
            {
                return Problem(StatusCodes.Status409Conflict, $"{target.Name} ist nicht online");
            }
            if (r.GetBoolean(1))
            {
                return Problem(StatusCodes.Status409Conflict, $"{target.Name} nimmt keine Nachrichten von dir an");
            }
        }
        string senderName;
        await using (var name = new NpgsqlCommand("SELECT name FROM characters WHERE character_id = @chr", conn, tx))
        {
            name.Parameters.AddWithValue("chr", req.CharacterId);
            senderName = (string)(await name.ExecuteScalarAsync(ct))!;
        }
        long messageId;
        await using (var insert = new NpgsqlCommand(
            """
            INSERT INTO chat_log (channel, sender_character_id, target_ref, target_character_id, target_guild_id, zone_id, message)
            VALUES (@ch, @chr, @tref, @t, @g, @zone, @msg) RETURNING message_id
            """, conn, tx))
        {
            insert.Parameters.AddWithValue("ch", channel);
            insert.Parameters.AddWithValue("chr", req.CharacterId);
            insert.Parameters.AddWithValue("tref", (object?)targetId?.ToString(System.Globalization.CultureInfo.InvariantCulture) ?? DBNull.Value);
            insert.Parameters.AddWithValue("t", (object?)targetId ?? DBNull.Value);
            insert.Parameters.AddWithValue("g", (object?)guildId ?? DBNull.Value);
            insert.Parameters.AddWithValue("zone", zone);
            insert.Parameters.AddWithValue("msg", message);
            messageId = (long)(await insert.ExecuteScalarAsync(ct))!;
        }
        await tx.CommitAsync(ct);
        return Results.Ok(new ChatSent(messageId, channel, senderName, message, targetId, targetName));
    }

    /// <summary>
    /// Neue Nachrichten für einen Zonen-Server. after &lt; 0: nur den aktuellen Stand holen (Serverstart, nichts Altes zustellen).
    /// </summary>
    private static async Task<IResult> Poll(string? serverId, long? after, NpgsqlDataSource db, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(serverId) || after is null)
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId und after sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(System.Data.IsolationLevel.RepeatableRead, ct);
        long max;
        await using (var top = new NpgsqlCommand("SELECT coalesce(max(message_id), 0) FROM chat_log", conn, tx))
        {
            max = (long)(await top.ExecuteScalarAsync(ct))!;
        }
        if (after < 0)
        {
            return Results.Ok(new ChatPoll(max, []));
        }
        await using var cmd = new NpgsqlCommand(
            $"""
            SELECT * FROM (
                SELECT l.message_id, l.channel, l.sender_character_id, c.name, l.target_character_id, l.message, l.created_at,
                       CASE WHEN l.channel = 'GUILD' THEN ARRAY(
                           SELECT m.character_id FROM guild_members m JOIN character_presence p USING (character_id)
                           WHERE m.guild_id = l.target_guild_id AND p.server_id = @server AND p.state = 'ONLINE') END AS recipients
                FROM chat_log l LEFT JOIN characters c ON c.character_id = l.sender_character_id
                WHERE l.message_id > @after AND l.message_id <= @max
                  AND (l.channel IN ('WORLD', 'TRADE', 'SYSTEM', 'GUILD')
                       OR (l.channel = 'WHISPER' AND EXISTS (SELECT 1 FROM character_presence p
                           WHERE p.character_id = l.target_character_id AND p.server_id = @server AND p.state = 'ONLINE')))
            ) x
            WHERE x.channel <> 'GUILD' OR cardinality(x.recipients) > 0
            ORDER BY x.message_id
            LIMIT {PollLimit}
            """, conn, tx);
        cmd.Parameters.AddWithValue("after", after.Value);
        cmd.Parameters.AddWithValue("max", max);
        cmd.Parameters.AddWithValue("server", serverId);
        var messages = new List<ChatMessage>();
        await using (var r = await cmd.ExecuteReaderAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                messages.Add(new ChatMessage(r.GetInt64(0), r.GetString(1), r.IsDBNull(2) ? null : r.GetInt64(2),
                    r.IsDBNull(3) ? null : r.GetString(3), r.IsDBNull(4) ? null : r.GetInt64(4), r.GetString(5), r.GetDateTime(6),
                    r.IsDBNull(7) ? null : r.GetFieldValue<long[]>(7)));
            }
        }
        await tx.CommitAsync(ct);
        // Volle Seite: nur bis zur letzten gelieferten weiter; sonst bis zum Stand dieser Abfrage (Nachrichten für andere übersprungen).
        return Results.Ok(new ChatPoll(messages.Count == PollLimit ? messages[^1].MessageId : max, messages));
    }

    // ---- Freunde und Ignorieren ---------------------------------------------------------------

    private static async Task<IResult> ListEntries(
        long characterId, long accountId, string table, string column, NpgsqlDataSource db, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, accountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        var list = await LoadEntries(conn, tx, characterId, table, column, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(list);
    }

    private static async Task<IResult> AddEntry(
        long characterId, NameRequest req, string table, string column, int max, NpgsqlDataSource db, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await FindCharacter(conn, tx, req.Name, ct) is not { } other || other.Id == characterId)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter unbekannt");
        }
        var current = await LoadEntries(conn, tx, characterId, table, column, ct);
        if (current.Count >= max && current.All(e => e.CharacterId != other.Id))
        {
            return Problem(StatusCodes.Status409Conflict, $"Liste voll (höchstens {max})");
        }
        await using (var insert = new NpgsqlCommand(
            $"INSERT INTO {table} (character_id, {column}) VALUES (@chr, @other) ON CONFLICT DO NOTHING", conn, tx))
        {
            insert.Parameters.AddWithValue("chr", characterId);
            insert.Parameters.AddWithValue("other", other.Id);
            await insert.ExecuteNonQueryAsync(ct);
        }
        var list = await LoadEntries(conn, tx, characterId, table, column, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(list);
    }

    private static async Task<IResult> RemoveEntry(
        long characterId, long otherId, long accountId, string table, string column, NpgsqlDataSource db, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, accountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        await using (var delete = new NpgsqlCommand($"DELETE FROM {table} WHERE character_id = @chr AND {column} = @other", conn, tx))
        {
            delete.Parameters.AddWithValue("chr", characterId);
            delete.Parameters.AddWithValue("other", otherId);
            await delete.ExecuteNonQueryAsync(ct);
        }
        var list = await LoadEntries(conn, tx, characterId, table, column, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(list);
    }

    /// <summary>Ignorierte Charaktere (für den Zustand beim Login; der Zonen-Server filtert damit die Zustellung).</summary>
    internal static async Task<List<long>> LoadIgnores(NpgsqlConnection conn, long characterId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("SELECT ignored_character_id FROM ignores WHERE character_id = @chr ORDER BY 1", conn);
        cmd.Parameters.AddWithValue("chr", characterId);
        var ids = new List<long>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            ids.Add(r.GetInt64(0));
        }
        return ids;
    }

    private static async Task<List<SocialEntry>> LoadEntries(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, string table, string column, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            $"""
            SELECT c.character_id, c.name, p.state = 'ONLINE', p.zone_id
            FROM {table} t JOIN characters c ON c.character_id = t.{column}
            LEFT JOIN character_presence p ON p.character_id = c.character_id AND p.state = 'ONLINE'
            WHERE t.character_id = @chr AND c.deleted_at IS NULL
            ORDER BY lower(c.name)
            """, conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        var list = new List<SocialEntry>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            var online = !r.IsDBNull(2) && r.GetBoolean(2);
            list.Add(new SocialEntry(r.GetInt64(0), r.GetString(1), online, online && !r.IsDBNull(3) ? r.GetString(3) : null));
        }
        return list;
    }

    // ---- Melden und Moderation ----------------------------------------------------------------

    /// <summary>Spieler melden; die letzten Nachrichten des Gemeldeten werden als Kontext mitgespeichert.</summary>
    private static async Task<IResult> Report(long characterId, ReportRequest req, NpgsqlDataSource db, CancellationToken ct)
    {
        var reason = ChatRules.Sanitize(req.Reason, 500);
        if (reason is null || string.IsNullOrEmpty(req.ServerId))
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId und ein Grund (bis 500 Zeichen) sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await FindCharacter(conn, tx, req.Name, ct) is not { } reported || reported.Id == characterId)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter unbekannt");
        }
        long reportId;
        await using (var insert = new NpgsqlCommand(
            """
            INSERT INTO player_reports (reporter_character_id, reported_character_id, reason, context)
            SELECT @me, @them, @reason, jsonb_build_object('serverId', @server::text, 'recentMessages', coalesce(jsonb_agg(m ORDER BY m.created_at), '[]'))
            FROM (SELECT channel, message, created_at FROM chat_log WHERE sender_character_id = @them
                  AND created_at > now() - INTERVAL '1 hour' ORDER BY created_at DESC LIMIT 20) m
            RETURNING report_id
            """, conn, tx))
        {
            insert.Parameters.AddWithValue("me", characterId);
            insert.Parameters.AddWithValue("them", reported.Id);
            insert.Parameters.AddWithValue("reason", reason);
            insert.Parameters.AddWithValue("server", req.ServerId);
            reportId = (long)(await insert.ExecuteScalarAsync(ct))!;
        }
        await tx.CommitAsync(ct);
        return Results.Ok(new { reportId });
    }

    private static async Task<IResult> AdminMute(
        AdminMuteRequest req, NpgsqlDataSource db, IOptions<ProgressionOptions> options, CancellationToken ct)
    {
        var channel = req.Channel?.ToUpperInvariant();
        var reason = ChatRules.Sanitize(req.Reason, 500);
        if (req.Minutes is < 1 or > 60 * 24 * 30 || reason is null || (channel is not null && !ChatRules.PlayerChannels.Contains(channel)))
        {
            return Problem(StatusCodes.Status400BadRequest, "minutes (1 … 43200), reason und optional channel (LOCAL, WORLD, TRADE, WHISPER) sind erforderlich");
        }
        var admin = new AdminSetRequest(req.AdminAccountId, 0, req.SessionId, req.Ip, req.ServerId);
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.CheckAdmin(conn, tx, admin, options.Value.AdminMinLevel, ct) is { } denied)
        {
            return denied;
        }
        if (await FindCharacter(conn, tx, req.CharacterName, ct) is not { } target)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter unbekannt");
        }
        DateTime until;
        await using (var insert = new NpgsqlCommand(
            """
            INSERT INTO chat_mutes (character_id, channel, muted_until, reason, admin_account_id)
            VALUES (@chr, @ch, now() + make_interval(mins => @min), @reason, @admin) RETURNING muted_until
            """, conn, tx))
        {
            insert.Parameters.AddWithValue("chr", target.Id);
            insert.Parameters.AddWithValue("ch", (object?)channel ?? DBNull.Value);
            insert.Parameters.AddWithValue("min", req.Minutes);
            insert.Parameters.AddWithValue("reason", reason);
            insert.Parameters.AddWithValue("admin", req.AdminAccountId);
            until = (DateTime)(await insert.ExecuteScalarAsync(ct))!;
        }
        var auditId = await ProgressionEndpoints.Audit(conn, tx, admin, "/mute", target.Id, new { }, new { mutedUntil = until, channel },
            ct, args: new { name = target.Name, minutes = req.Minutes, channel, reason });
        await tx.CommitAsync(ct);
        return Results.Ok(new { characterId = target.Id, name = target.Name, mutedUntil = until, auditId });
    }

    /// <summary>Systemmeldung an alle Server (Kanal SYSTEM, ohne Absender), protokolliert im Admin-Audit.</summary>
    private static async Task<IResult> AdminAnnounce(
        AdminAnnounceRequest req, NpgsqlDataSource db, IOptions<ProgressionOptions> options, IOptions<ChatOptions> chat, CancellationToken ct)
    {
        var message = ChatRules.Sanitize(req.Message, chat.Value.MaxLength);
        if (message is null)
        {
            return Problem(StatusCodes.Status400BadRequest, $"Nachricht leer oder länger als {chat.Value.MaxLength} Zeichen");
        }
        var admin = new AdminSetRequest(req.AdminAccountId, 0, req.SessionId, req.Ip, req.ServerId);
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.CheckAdmin(conn, tx, admin, options.Value.AdminMinLevel, ct) is { } denied)
        {
            return denied;
        }
        long messageId;
        await using (var insert = new NpgsqlCommand(
            "INSERT INTO chat_log (channel, message) VALUES ('SYSTEM', @msg) RETURNING message_id", conn, tx))
        {
            insert.Parameters.AddWithValue("msg", message);
            messageId = (long)(await insert.ExecuteScalarAsync(ct))!;
        }
        await using (var audit = new NpgsqlCommand(
            """
            INSERT INTO admin_audit_log (admin_account_id, command, target_type, target_id, args, session_id, ip, server_id)
            VALUES (@acc, '/announce', 'CHAT', @mid, @args, @sid, @ip, @server)
            """, conn, tx))
        {
            audit.Parameters.AddWithValue("acc", req.AdminAccountId);
            audit.Parameters.AddWithValue("mid", messageId.ToString(System.Globalization.CultureInfo.InvariantCulture));
            audit.Parameters.Add(GameEventLog.Json("args", new { message }));
            audit.Parameters.AddWithValue("sid", (object?)req.SessionId ?? DBNull.Value);
            audit.Parameters.AddWithValue("ip", req.Ip is null ? DBNull.Value : IPAddress.Parse(req.Ip));
            audit.Parameters.AddWithValue("server", req.ServerId!);
            await audit.ExecuteNonQueryAsync(ct);
        }
        await tx.CommitAsync(ct);
        return Results.Ok(new { messageId });
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private static async Task<(long Id, string Name)?> FindCharacter(NpgsqlConnection conn, NpgsqlTransaction tx, string? name, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(name) || name.Length > 24)
        {
            return null;
        }
        await using var cmd = new NpgsqlCommand(
            "SELECT character_id, name FROM characters WHERE lower(name) = lower(@n) AND deleted_at IS NULL", conn, tx);
        cmd.Parameters.AddWithValue("n", name.Trim());
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct) ? (r.GetInt64(0), r.GetString(1)) : null;
    }

    private static IResult Problem(int status, string title) => Results.Problem(statusCode: status, title: title);
}
