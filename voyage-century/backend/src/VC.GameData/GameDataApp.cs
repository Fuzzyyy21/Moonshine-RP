using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Options;
using Npgsql;
using NpgsqlTypes;
using VC.Common;
using VC.Common.Hosting;
using VC.Common.Logging;
using VC.Common.Security;

namespace VC.GameData;

public sealed class GameDataOptions
{
    public const string Section = "GameData";

    /// <summary>Technisches Limit, kein Originalwert (die Zahl im Original ist UNKNOWN).</summary>
    [Range(1, 20)]
    public int MaxCharactersPerAccount { get; set; } = 3;
}

public sealed record CharacterSummary(long CharacterId, string Name, string ProfessionCode, short Level, string? ZoneId);
public sealed record CreateCharacterRequest(string? Name, string? Gender, string? ProfessionCode, JsonElement? Appearance);

public sealed record Position(double X, double Y, double Z, float Yaw);
public sealed record CharacterState(
    long CharacterId, long AccountId, string Name, short Level, long Experience, string ProfessionCode, string? ZoneId,
    Position? Position, IReadOnlyList<SkillState> Skills, string Gender, IReadOnlyDictionary<string, int> Appearance,
    Vitals? Vitals = null);
public sealed record SaveStateRequest(
    long AccountId, string? ZoneId, double X, double Y, double Z, float Yaw,
    int? Health = null, int? MaxHealth = null, int? Stamina = null, int? MaxStamina = null);

/// <summary>Aktuelle Lebens- und Ausdauerpunkte; null, solange der Charakter noch nie gespeichert wurde.</summary>
public sealed record Vitals(int Health, int MaxHealth, int Stamina, int MaxStamina);

public sealed record AdminAuditRequest(
    long AdminAccountId, string? Command, string? TargetType, string? TargetId,
    JsonElement? Args, JsonElement? OldValue, JsonElement? NewValue, Guid? SessionId, string? Ip, string? ServerId);
public sealed record AdminAuditResponse(long AuditId);

/// <summary>
/// Persistenzdienst für Spielzustand. Clients dürfen nur ihre Charakterliste lesen und Charaktere anlegen;
/// Zustand lesen/schreiben und Admin-Audit sind Zonen-Servern mit Service-Key vorbehalten.
/// </summary>
public static partial class GameDataApp
{
    // Positionsgrenze gegen offensichtlich manipulierte Werte; deutlich größer als jede geplante Karte.
    private const double MaxCoordinate = 10_000_000;

    [GeneratedRegex(@"^[\p{L}\p{N}]{2,24}$")]
    private static partial Regex NamePattern();

    public static WebApplicationBuilder ConfigureServices(WebApplicationBuilder builder)
    {
        builder.AddVcDefaults();
        builder.Services.AddOptions<GameDataOptions>()
            .Bind(builder.Configuration.GetSection(GameDataOptions.Section)).ValidateDataAnnotations().ValidateOnStart();
        builder.Services.AddOptions<ContentOptions>().Bind(builder.Configuration.GetSection(ContentOptions.Section));
        builder.Services.AddOptions<ProgressionOptions>()
            .Bind(builder.Configuration.GetSection(ProgressionOptions.Section)).ValidateDataAnnotations().ValidateOnStart();
        return builder;
    }

    public static WebApplication Configure(WebApplication app)
    {
        app.UseVcDefaults();

        var client = app.MapGroup("/v1").RequireSession();
        client.MapGet("/characters", ListCharacters);
        client.MapPost("/characters", CreateCharacter);
        CharacterOptions.Map(client);

        var internalApi = app.MapGroup("/internal/v1").RequireServiceKey();
        internalApi.MapGet("/characters/{characterId:long}/state", GetState);
        internalApi.MapPut("/characters/{characterId:long}/state", SaveState);
        internalApi.MapPost("/admin-audit", WriteAdminAudit);
        ProgressionEndpoints.Map(internalApi);
        CombatEndpoints.Map(internalApi);
        return app;
    }

    private static async Task<IResult> ListCharacters(HttpContext http, NpgsqlDataSource db, CancellationToken ct)
    {
        var session = SessionFilter.Get(http);
        await using var cmd = db.CreateCommand(
            """
            SELECT c.character_id, c.name, p.code, c.level, c.zone_id
            FROM characters c JOIN professions p USING (profession_id)
            WHERE c.account_id = @acc AND c.deleted_at IS NULL
            ORDER BY c.created_at
            """);
        cmd.Parameters.AddWithValue("acc", session.AccountId);
        var list = new List<CharacterSummary>();
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            list.Add(new CharacterSummary(reader.GetInt64(0), reader.GetString(1), reader.GetString(2), reader.GetInt16(3),
                reader.IsDBNull(4) ? null : reader.GetString(4)));
        }
        return Results.Ok(list);
    }

    private static async Task<IResult> CreateCharacter(
        CreateCharacterRequest req, HttpContext http, NpgsqlDataSource db, IOptions<GameDataOptions> options,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        var session = SessionFilter.Get(http);
        var name = req.Name?.Trim();
        if (name is null || !NamePattern().IsMatch(name))
        {
            return BadRequest("Name: 2–24 Buchstaben oder Ziffern");
        }
        if (req.Gender is not ("MALE" or "FEMALE"))
        {
            return BadRequest("Geschlecht: MALE oder FEMALE");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);

        var (appearance, appearanceError) = CharacterOptions.Normalize(req.Appearance, await CharacterOptions.LoadSlots(conn, tx, ct));
        if (appearance is null)
        {
            return BadRequest(appearanceError!);
        }

        // Kontozeile sperren, damit parallele Anfragen das Charakterlimit nicht überschreiten.
        await using (var lockCmd = new NpgsqlCommand(
            """
            SELECT count(c.character_id)
            FROM (SELECT account_id FROM accounts WHERE account_id = @acc FOR UPDATE) a
            LEFT JOIN characters c ON c.account_id = a.account_id AND c.deleted_at IS NULL
            """, conn, tx))
        {
            lockCmd.Parameters.AddWithValue("acc", session.AccountId);
            var count = (long)(await lockCmd.ExecuteScalarAsync(ct))!;
            if (count >= options.Value.MaxCharactersPerAccount)
            {
                return Results.Problem(statusCode: StatusCodes.Status409Conflict, title: "Charakterlimit erreicht");
            }
        }

        short? professionId;
        await using (var profCmd = new NpgsqlCommand("SELECT profession_id FROM professions WHERE code = @code", conn, tx))
        {
            profCmd.Parameters.AddWithValue("code", req.ProfessionCode ?? "");
            professionId = (short?)await profCmd.ExecuteScalarAsync(ct);
        }
        if (professionId is null)
        {
            return BadRequest("Unbekannter Beruf");
        }

        long characterId;
        try
        {
            await using var insert = new NpgsqlCommand(
                """
                INSERT INTO characters (account_id, name, gender, appearance, profession_id)
                VALUES (@acc, @name, @gender, @appearance, @prof)
                RETURNING character_id
                """, conn, tx);
            insert.Parameters.AddWithValue("acc", session.AccountId);
            insert.Parameters.AddWithValue("name", name);
            insert.Parameters.AddWithValue("gender", req.Gender);
            insert.Parameters.Add(new NpgsqlParameter("appearance", NpgsqlDbType.Jsonb) { Value = appearance });
            insert.Parameters.AddWithValue("prof", professionId.Value);
            characterId = (long)(await insert.ExecuteScalarAsync(ct))!;
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            return Results.Problem(statusCode: StatusCodes.Status409Conflict, title: "Name ist bereits vergeben");
        }

        // Startguthaben im Original UNKNOWN: Wallet existiert, Kontostand bleibt 0.
        await using (var wallet = new NpgsqlCommand(
            "INSERT INTO character_wallets (character_id, currency_code, balance) VALUES (@chr, 'GOLD', 0)", conn, tx))
        {
            wallet.Parameters.AddWithValue("chr", characterId);
            await wallet.ExecuteNonQueryAsync(ct);
        }
        await GameEventLog.WriteAsync(conn, tx,
            new GameEvent("CHARACTER_CREATE", session.AccountId, characterId,
                NewValue: new { name, profession = req.ProfessionCode, gender = req.Gender },
                SessionId: session.SessionId, Ip: http.Connection.RemoteIpAddress),
            identity.Value.InstanceId, ct);
        await tx.CommitAsync(ct);

        return Results.Created($"/v1/characters/{characterId}",
            new CharacterSummary(characterId, name, req.ProfessionCode!, 1, null));
    }

    private static async Task<IResult> GetState(long characterId, long accountId, NpgsqlDataSource db, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        CharacterState state;
        await using (var cmd = new NpgsqlCommand(
            """
            SELECT c.character_id, c.account_id, c.name, c.level, c.experience, p.code, c.zone_id, c.pos_x, c.pos_y, c.pos_z, c.yaw,
                   c.gender, c.appearance::text, st.hp, st.hp_max, st.sp, st.sp_max
            FROM characters c JOIN professions p USING (profession_id)
            LEFT JOIN character_stats st ON st.character_id = c.character_id
            WHERE c.character_id = @chr AND c.account_id = @acc AND c.deleted_at IS NULL
            """, conn))
        {
            cmd.Parameters.AddWithValue("chr", characterId);
            cmd.Parameters.AddWithValue("acc", accountId);
            await using var reader = await cmd.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct))
            {
                // Gleiche Antwort für "gibt es nicht" und "gehört jemand anderem".
                return Results.Problem(statusCode: StatusCodes.Status404NotFound, title: "Charakter nicht gefunden");
            }
            Position? position = reader.IsDBNull(7) || reader.IsDBNull(8) || reader.IsDBNull(9)
                ? null
                : new Position(reader.GetDouble(7), reader.GetDouble(8), reader.GetDouble(9), reader.IsDBNull(10) ? 0f : reader.GetFloat(10));
            state = new CharacterState(reader.GetInt64(0), reader.GetInt64(1), reader.GetString(2), reader.GetInt16(3),
                reader.GetInt64(4), reader.GetString(5), reader.IsDBNull(6) ? null : reader.GetString(6), position, [],
                reader.GetString(11), JsonSerializer.Deserialize<Dictionary<string, int>>(reader.GetString(12)) ?? [],
                reader.IsDBNull(13) ? null : new Vitals(reader.GetInt32(13), reader.GetInt32(14), reader.GetInt32(15), reader.GetInt32(16)));
        }
        return Results.Ok(state with { Skills = await ProgressionEndpoints.LoadSkills(conn, characterId, ct) });
    }

    private static async Task<IResult> SaveState(long characterId, SaveStateRequest req, NpgsqlDataSource db, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ZoneId) || req.ZoneId.Length > 64)
        {
            return BadRequest("zoneId ist erforderlich");
        }
        if (!ValidCoordinate(req.X) || !ValidCoordinate(req.Y) || !ValidCoordinate(req.Z) || !float.IsFinite(req.Yaw))
        {
            return BadRequest("Position ist ungültig");
        }
        int?[] vitals = [req.Health, req.MaxHealth, req.Stamina, req.MaxStamina];
        var hasVitals = vitals.Any(v => v is not null);
        if (hasVitals && (vitals.Any(v => v is null) || req.MaxHealth <= 0 || req.MaxStamina <= 0
            || req.Health < 0 || req.Health > req.MaxHealth || req.Stamina < 0 || req.Stamina > req.MaxStamina))
        {
            return BadRequest("Lebens- und Ausdauerwerte unvollständig oder außerhalb von 0 … Maximum");
        }

        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        try
        {
            await using var cmd = new NpgsqlCommand(
                """
                UPDATE characters
                SET zone_id = @zone, pos_x = @x, pos_y = @y, pos_z = @z, yaw = @yaw, last_saved_at = now()
                WHERE character_id = @chr AND account_id = @acc AND deleted_at IS NULL
                """, conn, tx);
            cmd.Parameters.AddWithValue("zone", req.ZoneId);
            cmd.Parameters.AddWithValue("x", req.X);
            cmd.Parameters.AddWithValue("y", req.Y);
            cmd.Parameters.AddWithValue("z", req.Z);
            cmd.Parameters.AddWithValue("yaw", req.Yaw);
            cmd.Parameters.AddWithValue("chr", characterId);
            cmd.Parameters.AddWithValue("acc", req.AccountId);
            if (await cmd.ExecuteNonQueryAsync(ct) != 1)
            {
                return Results.Problem(statusCode: StatusCodes.Status404NotFound, title: "Charakter nicht gefunden");
            }
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.ForeignKeyViolation)
        {
            return BadRequest("Unbekannte Zone");
        }

        if (hasVitals)
        {
            // Maximalwerte berechnet der Zonen-Server aus den Kampfregeln; gespeichert wird der zuletzt gültige Stand.
            await using var stats = new NpgsqlCommand(
                """
                INSERT INTO character_stats (character_id, hp, hp_max, sp, sp_max) VALUES (@chr, @hp, @hpMax, @sp, @spMax)
                ON CONFLICT (character_id) DO UPDATE SET hp = EXCLUDED.hp, hp_max = EXCLUDED.hp_max, sp = EXCLUDED.sp, sp_max = EXCLUDED.sp_max
                """, conn, tx);
            stats.Parameters.AddWithValue("chr", characterId);
            stats.Parameters.AddWithValue("hp", req.Health!.Value);
            stats.Parameters.AddWithValue("hpMax", req.MaxHealth!.Value);
            stats.Parameters.AddWithValue("sp", req.Stamina!.Value);
            stats.Parameters.AddWithValue("spMax", req.MaxStamina!.Value);
            await stats.ExecuteNonQueryAsync(ct);
        }
        await tx.CommitAsync(ct);
        return Results.NoContent();
    }

    private static async Task<IResult> WriteAdminAudit(AdminAuditRequest req, NpgsqlDataSource db, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.Command) || !req.Command.StartsWith('/') || req.Command.Length > 64)
        {
            return BadRequest("command muss mit / beginnen");
        }
        if (string.IsNullOrEmpty(req.ServerId) || req.ServerId.Length > 64)
        {
            return BadRequest("serverId ist erforderlich");
        }
        IPAddress? ip = null;
        if (req.Ip is not null && !IPAddress.TryParse(req.Ip, out ip))
        {
            return BadRequest("ip ist ungültig");
        }

        await using var conn = await db.OpenConnectionAsync(ct);
        await using (var check = new NpgsqlCommand("SELECT admin_level FROM accounts WHERE account_id = @acc", conn))
        {
            // Zweite Prüfung neben dem Zonen-Server: ohne Adminrecht wird nichts protokolliert und nichts bestätigt.
            check.Parameters.AddWithValue("acc", req.AdminAccountId);
            var level = (short?)await check.ExecuteScalarAsync(ct);
            if (level is null or 0)
            {
                return Results.Problem(statusCode: StatusCodes.Status403Forbidden, title: "Konto hat keine Adminrechte");
            }
        }

        await using var cmd = new NpgsqlCommand(
            """
            INSERT INTO admin_audit_log (admin_account_id, command, target_type, target_id, args, old_value, new_value, session_id, ip, server_id)
            VALUES (@acc, @cmd, @ttype, @tid, COALESCE(@args, '{}'::jsonb), @old, @new, @sid, @ip, @server)
            RETURNING audit_id
            """, conn);
        cmd.Parameters.AddWithValue("acc", req.AdminAccountId);
        cmd.Parameters.AddWithValue("cmd", req.Command);
        cmd.Parameters.AddWithValue("ttype", (object?)req.TargetType ?? DBNull.Value);
        cmd.Parameters.AddWithValue("tid", (object?)req.TargetId ?? DBNull.Value);
        cmd.Parameters.Add(GameEventLog.Json("args", req.Args));
        cmd.Parameters.Add(GameEventLog.Json("old", req.OldValue));
        cmd.Parameters.Add(GameEventLog.Json("new", req.NewValue));
        cmd.Parameters.AddWithValue("sid", (object?)req.SessionId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("ip", (object?)ip ?? DBNull.Value);
        cmd.Parameters.AddWithValue("server", req.ServerId);
        var auditId = (long)(await cmd.ExecuteScalarAsync(ct))!;
        return Results.Created($"/internal/v1/admin-audit/{auditId}", new AdminAuditResponse(auditId));
    }

    private static bool ValidCoordinate(double v) => double.IsFinite(v) && Math.Abs(v) <= MaxCoordinate;

    private static IResult BadRequest(string title) => Results.Problem(statusCode: StatusCodes.Status400BadRequest, title: title);
}
