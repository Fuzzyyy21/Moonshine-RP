using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Text.RegularExpressions;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Hosting;
using VC.Common.Logging;
using VC.Common.Security;
using VC.Common.Sessions;

namespace VC.Auth;

public sealed class AuthOptions
{
    public const string Section = "Auth";

    /// <summary>Offene Registrierung. In Produktion aus, bis es einen Account-Prozess gibt.</summary>
    public bool AllowRegistration { get; set; }

    public TimeSpan TicketLifetime { get; set; } = TimeSpan.FromHours(12);

    [Range(1, 10_000)]
    public int LoginAttemptsPerMinute { get; set; } = 10;
}

public sealed record RegisterRequest(string? Login, string? Password, string? Email);
public sealed record RegisterResponse(long AccountId);
public sealed record LoginRequest(string? Login, string? Password);
public sealed record LoginResponse(string Ticket, Guid SessionId, long AccountId, DateTime ExpiresAt);
public sealed record ValidateRequest(string? Ticket);
public sealed record ValidateResponse(long AccountId, Guid SessionId, short AdminLevel);

/// <summary>Login-Dienst: Konten, Passwörter (argon2id), Session-Tickets und Ticketprüfung für Zonen-Server.</summary>
public static partial class AuthApp
{
    private const string LoginPolicy = "login";

    [GeneratedRegex("^[A-Za-z0-9_]{3,32}$")]
    private static partial Regex LoginPattern();

    public static WebApplicationBuilder ConfigureServices(WebApplicationBuilder builder)
    {
        builder.AddVcDefaults();
        builder.Services.AddOptions<AuthOptions>()
            .Bind(builder.Configuration.GetSection(AuthOptions.Section)).ValidateDataAnnotations()
            .Validate(o => o.TicketLifetime > TimeSpan.Zero, "Auth:TicketLifetime muss positiv sein")
            .ValidateOnStart();
        builder.Services.AddOptions<PasswordHashOptions>().Bind(builder.Configuration.GetSection(PasswordHashOptions.Section));
        builder.Services.AddSingleton(sp => new PasswordHasher(sp.GetRequiredService<IOptions<PasswordHashOptions>>().Value));
        builder.Services.AddRateLimiter(o =>
        {
            o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            o.AddPolicy(LoginPolicy, http =>
            {
                var limit = http.RequestServices.GetRequiredService<IOptions<AuthOptions>>().Value.LoginAttemptsPerMinute;
                return RateLimitPartition.GetFixedWindowLimiter(
                    http.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                    _ => new FixedWindowRateLimiterOptions { PermitLimit = limit, Window = TimeSpan.FromMinutes(1) });
            });
        });
        return builder;
    }

    public static WebApplication Configure(WebApplication app)
    {
        app.UseVcDefaults();
        app.UseRateLimiter();

        var v1 = app.MapGroup("/v1");
        v1.MapPost("/accounts", Register).RequireRateLimiting(LoginPolicy);
        v1.MapPost("/sessions", Login).RequireRateLimiting(LoginPolicy);
        v1.MapGroup("/sessions/current").RequireSession().MapDelete("", Logout);

        app.MapGroup("/internal/v1").RequireServiceKey().MapPost("/sessions/validate", Validate);
        return app;
    }

    private static async Task<IResult> Register(
        RegisterRequest req, HttpContext http, NpgsqlDataSource db, PasswordHasher hasher,
        IOptions<AuthOptions> options, IOptions<ServiceIdentityOptions> identity, ILogger<AuthLog> log, CancellationToken ct)
    {
        if (!options.Value.AllowRegistration)
        {
            return Results.Problem(statusCode: StatusCodes.Status403Forbidden, title: "Registrierung ist deaktiviert");
        }
        if (req.Login is null || !LoginPattern().IsMatch(req.Login))
        {
            return BadRequest("Login: 3–32 Zeichen, nur A–Z, a–z, 0–9 und _");
        }
        if (req.Password is null || req.Password.Length is < 10 or > 128)
        {
            return BadRequest("Passwort: 10–128 Zeichen");
        }
        if (req.Email is not null && (req.Email.Length > 254 || !req.Email.Contains('@', StringComparison.Ordinal)))
        {
            return BadRequest("E-Mail ist ungültig");
        }

        var hash = hasher.Hash(req.Password);
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        long accountId;
        try
        {
            await using var cmd = new NpgsqlCommand(
                "INSERT INTO accounts (login, email, password_hash) VALUES (@login, @email, @hash) RETURNING account_id", conn, tx);
            cmd.Parameters.AddWithValue("login", req.Login);
            cmd.Parameters.AddWithValue("email", (object?)req.Email ?? DBNull.Value);
            cmd.Parameters.AddWithValue("hash", hash);
            accountId = (long)(await cmd.ExecuteScalarAsync(ct))!;
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            return Results.Problem(statusCode: StatusCodes.Status409Conflict, title: "Login oder E-Mail ist bereits vergeben");
        }
        await GameEventLog.WriteAsync(conn, tx,
            new GameEvent("ACCOUNT_CREATE", AccountId: accountId, NewValue: new { login = req.Login },
                Ip: http.Connection.RemoteIpAddress), identity.Value.InstanceId, ct);
        await tx.CommitAsync(ct);
        AuthLog.AccountCreated(log, accountId);
        return Results.Created($"/v1/accounts/{accountId}", new RegisterResponse(accountId));
    }

    private static async Task<IResult> Login(
        LoginRequest req, HttpContext http, NpgsqlDataSource db, PasswordHasher hasher,
        IOptions<AuthOptions> options, IOptions<ServiceIdentityOptions> identity, ILogger<AuthLog> log, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.Login) || string.IsNullOrEmpty(req.Password) || req.Password.Length > 128)
        {
            return BadRequest("Login und Passwort sind erforderlich");
        }
        var ip = http.Connection.RemoteIpAddress;

        long accountId;
        string storedHash;
        string status;
        bool banActive;
        DateTime? bannedUntil;
        await using (var cmd = db.CreateCommand(
            """
            SELECT account_id, password_hash, status,
                   status = 'BANNED' AND (banned_until IS NULL OR banned_until > now()) AS ban_active,
                   banned_until
            FROM accounts WHERE lower(login) = lower(@login)
            """))
        {
            cmd.Parameters.AddWithValue("login", req.Login);
            await using var reader = await cmd.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct))
            {
                hasher.VerifyDummy(req.Password);
                AuthLog.LoginFailed(log, "unknown_login", ip);
                return InvalidCredentials();
            }
            accountId = reader.GetInt64(0);
            storedHash = reader.GetString(1);
            status = reader.GetString(2);
            banActive = reader.GetBoolean(3);
            bannedUntil = reader.IsDBNull(4) ? null : reader.GetDateTime(4);
        }

        if (!PasswordHasher.Verify(req.Password, storedHash) || status == "DELETED")
        {
            AuthLog.LoginFailed(log, "invalid_credentials", ip);
            return InvalidCredentials();
        }
        if (banActive)
        {
            AuthLog.LoginFailed(log, "banned", ip);
            return Results.Problem(statusCode: StatusCodes.Status403Forbidden, title: "Konto ist gesperrt",
                extensions: new Dictionary<string, object?> { ["bannedUntil"] = bannedUntil });
        }

        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        await using (var cmd = new NpgsqlCommand(
            """
            UPDATE accounts SET
                last_login_at = now(),
                status        = CASE WHEN status = 'BANNED' THEN 'ACTIVE' ELSE status END,
                banned_until  = CASE WHEN status = 'BANNED' THEN NULL ELSE banned_until END,
                password_hash = COALESCE(@rehash, password_hash)
            WHERE account_id = @acc
            """, conn, tx))
        {
            // Abgelaufene Sperren werden beim Login aufgehoben; veraltete Hash-Parameter werden erneuert.
            cmd.Parameters.AddWithValue("acc", accountId);
            cmd.Parameters.AddWithValue("rehash", hasher.NeedsRehash(storedHash) ? hasher.Hash(req.Password) : DBNull.Value);
            await cmd.ExecuteNonQueryAsync(ct);
        }
        var session = await SessionStore.IssueAsync(conn, tx, accountId, ip, http.Request.Headers["X-Client-Version"].FirstOrDefault(),
            options.Value.TicketLifetime, identity.Value.InstanceId, ct);
        await GameEventLog.WriteAsync(conn, tx,
            new GameEvent("ACCOUNT_LOGIN", AccountId: accountId, SessionId: session.SessionId, Ip: ip), identity.Value.InstanceId, ct);
        await tx.CommitAsync(ct);

        AuthLog.LoginSucceeded(log, accountId, session.SessionId);
        return Results.Ok(new LoginResponse(session.Ticket, session.SessionId, accountId, session.ExpiresAt));
    }

    private static async Task<IResult> Logout(HttpContext http, SessionStore sessions, CancellationToken ct)
    {
        await sessions.RevokeAsync(SessionFilter.Get(http).SessionId, ct);
        return Results.NoContent();
    }

    private static async Task<IResult> Validate(ValidateRequest req, SessionStore sessions, CancellationToken ct)
    {
        var session = await sessions.ValidateAsync(req.Ticket ?? "", ct);
        return session is null
            ? Results.Problem(statusCode: StatusCodes.Status401Unauthorized, title: "Ticket ungültig")
            : Results.Ok(new ValidateResponse(session.AccountId, session.SessionId, session.AdminLevel));
    }

    private static IResult BadRequest(string title) => Results.Problem(statusCode: StatusCodes.Status400BadRequest, title: title);

    private static IResult InvalidCredentials() =>
        Results.Problem(statusCode: StatusCodes.Status401Unauthorized, title: "Login oder Passwort falsch");
}

/// <summary>Log-Kategorie und quellgenerierte Log-Methoden des Login-Dienstes.</summary>
public sealed partial class AuthLog
{
    [LoggerMessage(EventId = 3000, Level = LogLevel.Information, Message = "Konto {AccountId} angelegt")]
    public static partial void AccountCreated(ILogger logger, long accountId);

    [LoggerMessage(EventId = 3001, Level = LogLevel.Information, Message = "Login von Konto {AccountId}, Session {SessionId}")]
    public static partial void LoginSucceeded(ILogger logger, long accountId, Guid sessionId);

    [LoggerMessage(EventId = 3002, Level = LogLevel.Warning, Message = "Login abgelehnt ({Reason}) von {Ip}")]
    public static partial void LoginFailed(ILogger logger, string reason, IPAddress? ip);
}
