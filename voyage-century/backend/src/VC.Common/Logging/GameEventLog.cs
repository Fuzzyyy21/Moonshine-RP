using System.Net;
using System.Text.Json;
using Npgsql;
using NpgsqlTypes;

namespace VC.Common.Logging;

/// <summary>Ein spielrelevantes Ereignis für <c>game_event_log</c> (Player, Zeit, Aktion, alter/neuer Wert, Session, IP, Server).</summary>
public sealed record GameEvent(
    string Action,
    long? AccountId = null,
    long? CharacterId = null,
    object? OldValue = null,
    object? NewValue = null,
    Guid? SessionId = null,
    IPAddress? Ip = null);

public static class GameEventLog
{
    public static async Task WriteAsync(
        NpgsqlConnection conn, NpgsqlTransaction? tx, GameEvent e, string serverId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            INSERT INTO game_event_log (account_id, character_id, action, old_value, new_value, session_id, ip, server_id)
            VALUES (@acc, @chr, @action, @old, @new, @sid, @ip, @server)
            """, conn, tx);
        cmd.Parameters.AddWithValue("acc", (object?)e.AccountId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("chr", (object?)e.CharacterId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("action", e.Action);
        cmd.Parameters.Add(Json("old", e.OldValue));
        cmd.Parameters.Add(Json("new", e.NewValue));
        cmd.Parameters.AddWithValue("sid", (object?)e.SessionId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("ip", (object?)e.Ip ?? DBNull.Value);
        cmd.Parameters.AddWithValue("server", serverId);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    public static NpgsqlParameter Json(string name, object? value) => new(name, NpgsqlDbType.Jsonb)
    {
        Value = value switch
        {
            null => DBNull.Value,
            JsonElement { ValueKind: JsonValueKind.Undefined or JsonValueKind.Null } => DBNull.Value,
            JsonElement el => el.GetRawText(),
            _ => JsonSerializer.Serialize(value),
        },
    };
}
