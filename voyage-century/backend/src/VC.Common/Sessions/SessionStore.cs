using System.Net;
using System.Security.Cryptography;
using Npgsql;

namespace VC.Common.Sessions;

public sealed record SessionInfo(Guid SessionId, long AccountId, short AdminLevel);

public sealed record IssuedSession(Guid SessionId, string Ticket, DateTime ExpiresAt);

/// <summary>
/// Session-Tickets: zufällige 256 Bit, an den Client als Base64url, in der Datenbank nur als SHA-256.
/// Gültig ist ein Ticket, solange es nicht abgelaufen, nicht widerrufen und das Konto nicht gesperrt ist.
/// </summary>
public sealed class SessionStore(NpgsqlDataSource db)
{
    public static async Task<IssuedSession> IssueAsync(
        NpgsqlConnection conn, NpgsqlTransaction tx, long accountId, IPAddress? ip, string? clientVersion,
        TimeSpan lifetime, string serverId, CancellationToken ct)
    {
        var ticket = Base64Url(RandomNumberGenerator.GetBytes(32));
        var sessionId = Guid.NewGuid();
        await using var cmd = new NpgsqlCommand(
            """
            INSERT INTO account_sessions (session_id, account_id, ip, client_version, expires_at, token_hash, server_id)
            VALUES (@sid, @acc, @ip, @ver, now() + make_interval(secs => @secs), @hash, @server)
            RETURNING expires_at
            """, conn, tx);
        cmd.Parameters.AddWithValue("sid", sessionId);
        cmd.Parameters.AddWithValue("acc", accountId);
        cmd.Parameters.AddWithValue("ip", (object?)ip ?? DBNull.Value);
        cmd.Parameters.AddWithValue("ver", (object?)clientVersion ?? DBNull.Value);
        cmd.Parameters.AddWithValue("secs", lifetime.TotalSeconds);
        cmd.Parameters.AddWithValue("hash", HashTicket(ticket));
        cmd.Parameters.AddWithValue("server", serverId);
        var expires = (DateTime)(await cmd.ExecuteScalarAsync(ct))!;
        return new IssuedSession(sessionId, ticket, expires);
    }

    public async Task<SessionInfo?> ValidateAsync(string ticket, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(ticket) || ticket.Length > 128)
        {
            return null;
        }
        await using var cmd = db.CreateCommand(
            """
            UPDATE account_sessions s SET last_seen_at = now()
            FROM accounts a
            WHERE s.token_hash = @hash
              AND a.account_id = s.account_id
              AND s.revoked_at IS NULL
              AND s.expires_at > now()
              AND a.status = 'ACTIVE'
            RETURNING s.session_id, s.account_id, a.admin_level
            """);
        cmd.Parameters.AddWithValue("hash", HashTicket(ticket));
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct))
        {
            return null;
        }
        return new SessionInfo(reader.GetGuid(0), reader.GetInt64(1), reader.GetInt16(2));
    }

    public async Task<bool> RevokeAsync(Guid sessionId, CancellationToken ct)
    {
        await using var cmd = db.CreateCommand(
            "UPDATE account_sessions SET revoked_at = now() WHERE session_id = @sid AND revoked_at IS NULL");
        cmd.Parameters.AddWithValue("sid", sessionId);
        return await cmd.ExecuteNonQueryAsync(ct) == 1;
    }

    public static byte[] HashTicket(string ticket) => SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(ticket));

    private static string Base64Url(byte[] data) =>
        Convert.ToBase64String(data).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
