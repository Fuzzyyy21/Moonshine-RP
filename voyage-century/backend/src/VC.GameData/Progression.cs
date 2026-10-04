using System.ComponentModel.DataAnnotations;
using System.Net;
using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Hosting;
using VC.Common.Logging;

namespace VC.GameData;

public sealed class ProgressionOptions
{
    public const string Section = "Progression";

    /// <summary>Entwicklungskurven (is_dev) verwenden. Nur Development/Tests; in Produktion aus.</summary>
    public bool AllowDevCurves { get; set; }

    /// <summary>Obergrenze je Vergabe (Plausibilitätsschutz gegen fehlerhafte oder manipulierte Server-Aufrufe).</summary>
    [Range(1, long.MaxValue)]
    public long MaxCharacterXpPerGrant { get; set; } = 1_000_000;

    [Range(1, long.MaxValue)]
    public long MaxSkillXpPerGrant { get; set; } = 100_000;

    /// <summary>Mindest-Adminlevel für /setlevel und /setskill.</summary>
    [Range(1, 10)]
    public short AdminMinLevel { get; set; } = 1;
}

public sealed record GrantRequest(long AccountId, long Amount, string? Source, Guid IdempotencyKey, string? ServerId);
public sealed record CharacterProgress(short Level, long Experience, short LevelCap, bool Duplicate);
public sealed record SkillProgress(string Code, short Level, short Stage, long Experience, short LevelCap, bool Duplicate);
public sealed record SkillState(string Code, short Level, short Stage, long Experience);

public sealed record AdminSetRequest(
    long AdminAccountId, short Level, Guid? SessionId, string? Ip, string? ServerId);

/// <summary>
/// Serverseitige Progression. Die Datenbank ist die einzige Wahrheit; der Zonen-Server meldet nur
/// Ereignisse ("Spieler bekommt X XP aus Quelle Y") und übernimmt das Ergebnis.
/// Pro Charakter wird die Zeile in <c>characters</c> gesperrt, damit parallele Vergaben seriell laufen.
/// </summary>
public static class ProgressionEndpoints
{
    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapPost("/characters/{characterId:long}/experience", GrantCharacterXp);
        internalApi.MapPost("/characters/{characterId:long}/skills/{skillCode}/experience", GrantSkillXp);
        internalApi.MapPut("/characters/{characterId:long}/level", AdminSetLevel);
        internalApi.MapPut("/characters/{characterId:long}/skills/{skillCode}/level", AdminSetSkill);
    }

    public static async Task<List<SkillState>> LoadSkills(NpgsqlConnection conn, long characterId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT s.code, sp.level, sp.stage_no, sp.experience
            FROM skill_progress sp JOIN skills s USING (skill_id)
            WHERE sp.character_id = @chr ORDER BY s.code
            """, conn);
        cmd.Parameters.AddWithValue("chr", characterId);
        var list = new List<SkillState>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            list.Add(new SkillState(r.GetString(0), r.GetInt16(1), r.GetInt16(2), r.GetInt64(3)));
        }
        return list;
    }

    private static async Task<IResult> GrantCharacterXp(
        long characterId, GrantRequest req, NpgsqlDataSource db, IOptions<ProgressionOptions> options, CancellationToken ct)
    {
        if (Validate(req, options.Value.MaxCharacterXpPerGrant) is { } invalid)
        {
            return invalid;
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        var current = await LockCharacter(conn, tx, characterId, req.AccountId, ct);
        if (current is null)
        {
            return NotFound();
        }
        var progress = await ApplyCharacterXp(conn, tx, characterId, current.Value, req, options.Value.AllowDevCurves, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(progress);
    }

    /// <summary>
    /// Verbucht Charakter-XP innerhalb einer laufenden Transaktion. Der Aufrufer muss die Charakterzeile
    /// bereits gesperrt haben (<see cref="LockCharacter"/>). Wird auch für XP aus Kills benutzt.
    /// </summary>
    internal static async Task<CharacterProgress> ApplyCharacterXp(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, (short Level, long Experience) current,
        GrantRequest req, bool allowDevCurves, CancellationToken ct)
    {
        var curve = await Curve.Load(conn, tx, "level_table", allowDevCurves, ct);
        if (!await RecordGrant(conn, tx, req, characterId, "CHARACTER_XP", null, ct))
        {
            return new CharacterProgress(current.Level, current.Experience, curve.Cap, Duplicate: true);
        }

        var xp = checked(current.Experience + req.Amount);
        var level = Math.Max(current.Level, curve.LevelFor(xp));
        await using (var upd = new NpgsqlCommand(
            "UPDATE characters SET experience = @xp, level = @lvl WHERE character_id = @chr", conn, tx))
        {
            upd.Parameters.AddWithValue("xp", xp);
            upd.Parameters.AddWithValue("lvl", level);
            upd.Parameters.AddWithValue("chr", characterId);
            await upd.ExecuteNonQueryAsync(ct);
        }
        if (level != current.Level)
        {
            await GameEventLog.WriteAsync(conn, tx, new GameEvent("LEVEL_UP", req.AccountId, characterId,
                OldValue: new { level = current.Level }, NewValue: new { level, source = req.Source }), req.ServerId!, ct);
        }
        return new CharacterProgress(level, xp, curve.Cap, Duplicate: false);
    }

    private static async Task<IResult> GrantSkillXp(
        long characterId, string skillCode, GrantRequest req, NpgsqlDataSource db, IOptions<ProgressionOptions> options,
        CancellationToken ct)
    {
        if (Validate(req, options.Value.MaxSkillXpPerGrant) is { } invalid)
        {
            return invalid;
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return NotFound();
        }
        var skillId = await SkillId(conn, tx, skillCode, ct);
        if (skillId is null)
        {
            return BadRequest("Unbekannter Skill");
        }
        var progress = await ApplySkillXp(conn, tx, characterId, skillId.Value, skillCode, req, options.Value.AllowDevCurves, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(progress);
    }

    /// <summary>
    /// Verbucht Skill-XP innerhalb einer laufenden Transaktion (Charakterzeile bereits gesperrt). Wird auch für XP aus
    /// Sammeln und Herstellen benutzt.
    /// </summary>
    internal static async Task<SkillProgress> ApplySkillXp(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, short skillId, string skillCode, GrantRequest req,
        bool allowDevCurves, CancellationToken ct)
    {
        var state = await LoadOrCreateSkill(conn, tx, characterId, skillId, ct);
        var limits = await SkillLimits.Load(conn, tx, characterId, skillId, state.Stage, allowDevCurves, ct);
        var cap = limits.CapFor(state.Level);

        if (!await RecordGrant(conn, tx, req, characterId, "SKILL_XP", skillId, ct))
        {
            return new SkillProgress(skillCode, state.Level, state.Stage, state.Experience, cap, Duplicate: true);
        }

        var xp = checked(state.Experience + req.Amount);
        var level = (short)Math.Max(state.Level, Math.Min(limits.Curve.LevelFor(xp), cap));
        await using (var upd = new NpgsqlCommand(
            "UPDATE skill_progress SET experience = @xp, level = @lvl WHERE character_id = @chr AND skill_id = @sk", conn, tx))
        {
            upd.Parameters.AddWithValue("xp", xp);
            upd.Parameters.AddWithValue("lvl", level);
            upd.Parameters.AddWithValue("chr", characterId);
            upd.Parameters.AddWithValue("sk", skillId);
            await upd.ExecuteNonQueryAsync(ct);
        }
        if (level != state.Level)
        {
            await GameEventLog.WriteAsync(conn, tx, new GameEvent("SKILL_LEVEL_UP", req.AccountId, characterId,
                OldValue: new { skill = skillCode, level = state.Level },
                NewValue: new { skill = skillCode, level, source = req.Source }), req.ServerId!, ct);
        }
        return new SkillProgress(skillCode, level, state.Stage, xp, cap, Duplicate: false);
    }

    private static async Task<IResult> AdminSetLevel(
        long characterId, AdminSetRequest req, NpgsqlDataSource db, IOptions<ProgressionOptions> options, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await CheckAdmin(conn, tx, req, options.Value.AdminMinLevel, ct) is { } denied)
        {
            return denied;
        }
        var current = await LockCharacter(conn, tx, characterId, accountId: null, ct);
        if (current is null)
        {
            return NotFound();
        }
        var curve = await Curve.Load(conn, tx, "level_table", options.Value.AllowDevCurves, ct);
        if (req.Level < 1 || req.Level > curve.Cap)
        {
            return BadRequest($"Level muss zwischen 1 und {curve.Cap} liegen (höhere Stufen haben keine bekannte XP-Schwelle)");
        }
        var xp = curve.XpFor(req.Level);
        await using (var upd = new NpgsqlCommand(
            "UPDATE characters SET level = @lvl, experience = @xp WHERE character_id = @chr", conn, tx))
        {
            upd.Parameters.AddWithValue("lvl", req.Level);
            upd.Parameters.AddWithValue("xp", xp);
            upd.Parameters.AddWithValue("chr", characterId);
            await upd.ExecuteNonQueryAsync(ct);
        }
        var auditId = await Audit(conn, tx, req, "/setlevel", characterId,
            new { level = current.Value.Level, experience = current.Value.Experience }, new { level = req.Level, experience = xp }, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new { auditId, progress = new CharacterProgress(req.Level, xp, curve.Cap, Duplicate: false) });
    }

    private static async Task<IResult> AdminSetSkill(
        long characterId, string skillCode, AdminSetRequest req, NpgsqlDataSource db, IOptions<ProgressionOptions> options,
        CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await CheckAdmin(conn, tx, req, options.Value.AdminMinLevel, ct) is { } denied)
        {
            return denied;
        }
        if (await LockCharacter(conn, tx, characterId, accountId: null, ct) is null)
        {
            return NotFound();
        }
        var skillId = await SkillId(conn, tx, skillCode, ct);
        if (skillId is null)
        {
            return BadRequest("Unbekannter Skill");
        }
        var state = await LoadOrCreateSkill(conn, tx, characterId, skillId.Value, ct);
        var stage = await SkillLimits.StageFor(conn, tx, req.Level, ct);
        if (stage is null)
        {
            return BadRequest("Für diese Stufe ist keine Skillstufe (31/100/120) bekannt");
        }
        var limits = await SkillLimits.Load(conn, tx, characterId, skillId.Value, stage.Value, options.Value.AllowDevCurves, ct);
        if (req.Level < 1 || req.Level > Math.Min(limits.Curve.Cap, limits.StageMax) || req.Level > limits.TotalBudget)
        {
            return BadRequest("Stufe überschreitet bekannte XP-Kurve, Skillstufe oder Gesamtcap");
        }
        var xp = limits.Curve.XpFor(req.Level);
        await using (var upd = new NpgsqlCommand(
            "UPDATE skill_progress SET level = @lvl, stage_no = @stage, experience = @xp WHERE character_id = @chr AND skill_id = @sk",
            conn, tx))
        {
            upd.Parameters.AddWithValue("lvl", req.Level);
            upd.Parameters.AddWithValue("stage", stage.Value);
            upd.Parameters.AddWithValue("xp", xp);
            upd.Parameters.AddWithValue("chr", characterId);
            upd.Parameters.AddWithValue("sk", skillId.Value);
            await upd.ExecuteNonQueryAsync(ct);
        }
        var auditId = await Audit(conn, tx, req, "/setskill", characterId,
            new { skill = skillCode, level = state.Level, stage = state.Stage },
            new { skill = skillCode, level = req.Level, stage = stage.Value }, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new
        {
            auditId,
            progress = new SkillProgress(skillCode, req.Level, stage.Value, xp, limits.CapFor(req.Level), Duplicate: false),
        });
    }

    // ---- Hilfen ---------------------------------------------------------------------------

    private static IResult? Validate(GrantRequest req, long max)
    {
        if (req.Amount <= 0 || req.Amount > max)
        {
            return BadRequest($"amount muss zwischen 1 und {max} liegen");
        }
        if (req.IdempotencyKey == Guid.Empty)
        {
            return BadRequest("idempotencyKey ist erforderlich");
        }
        if (string.IsNullOrEmpty(req.Source) || req.Source.Length > 64 || string.IsNullOrEmpty(req.ServerId) || req.ServerId.Length > 64)
        {
            return BadRequest("source und serverId sind erforderlich");
        }
        return null;
    }

    internal static async Task<(short Level, long Experience)?> LockCharacter(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, long? accountId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT level, experience FROM characters
            WHERE character_id = @chr AND (@acc::bigint IS NULL OR account_id = @acc) AND deleted_at IS NULL
            FOR UPDATE
            """, conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        cmd.Parameters.AddWithValue("acc", (object?)accountId ?? DBNull.Value);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct) ? (r.GetInt16(0), r.GetInt64(1)) : null;
    }

    private static async Task<bool> RecordGrant(
        NpgsqlConnection conn, NpgsqlTransaction tx, GrantRequest req, long characterId, string kind, short? skillId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            INSERT INTO progression_grants (idempotency_key, character_id, kind, skill_id, amount, source, server_id)
            VALUES (@key, @chr, @kind, @sk, @amount, @source, @server)
            ON CONFLICT (idempotency_key) DO NOTHING
            """, conn, tx);
        cmd.Parameters.AddWithValue("key", req.IdempotencyKey);
        cmd.Parameters.AddWithValue("chr", characterId);
        cmd.Parameters.AddWithValue("kind", kind);
        cmd.Parameters.AddWithValue("sk", (object?)skillId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("amount", req.Amount);
        cmd.Parameters.AddWithValue("source", req.Source!);
        cmd.Parameters.AddWithValue("server", req.ServerId!);
        return await cmd.ExecuteNonQueryAsync(ct) == 1;
    }

    internal static async Task<short?> SkillId(NpgsqlConnection conn, NpgsqlTransaction tx, string code, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("SELECT skill_id FROM skills WHERE code = @code", conn, tx);
        cmd.Parameters.AddWithValue("code", code.ToUpperInvariant());
        return (short?)await cmd.ExecuteScalarAsync(ct);
    }

    /// <summary>Skills ohne Eintrag gelten als Grundstufe 1 mit 0 XP (Startwerte des Originals UNKNOWN).</summary>
    private static async Task<(short Level, short Stage, long Experience)> LoadOrCreateSkill(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, short skillId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            INSERT INTO skill_progress (character_id, skill_id) VALUES (@chr, @sk)
            ON CONFLICT (character_id, skill_id) DO UPDATE SET level = skill_progress.level
            RETURNING level, stage_no, experience
            """, conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        cmd.Parameters.AddWithValue("sk", skillId);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        await r.ReadAsync(ct);
        return (r.GetInt16(0), r.GetInt16(1), r.GetInt64(2));
    }

    internal static async Task<IResult?> CheckAdmin(
        NpgsqlConnection conn, NpgsqlTransaction tx, AdminSetRequest req, short minLevel, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || req.ServerId.Length > 64)
        {
            return BadRequest("serverId ist erforderlich");
        }
        if (req.Ip is not null && !IPAddress.TryParse(req.Ip, out _))
        {
            return BadRequest("ip ist ungültig");
        }
        await using var cmd = new NpgsqlCommand("SELECT admin_level FROM accounts WHERE account_id = @acc", conn, tx);
        cmd.Parameters.AddWithValue("acc", req.AdminAccountId);
        var level = (short?)await cmd.ExecuteScalarAsync(ct);
        return level is null || level < minLevel
            ? Results.Problem(statusCode: StatusCodes.Status403Forbidden, title: "Konto hat keine ausreichenden Adminrechte")
            : null;
    }

    /// <summary>Änderung und Audit-Eintrag in derselben Transaktion: entweder beides oder nichts.</summary>
    internal static async Task<long> Audit(
        NpgsqlConnection conn, NpgsqlTransaction tx, AdminSetRequest req, string command, long characterId,
        object oldValue, object newValue, CancellationToken ct, object? args = null)
    {
        await using var cmd = new NpgsqlCommand(
            """
            INSERT INTO admin_audit_log (admin_account_id, command, target_type, target_id, args, old_value, new_value, session_id, ip, server_id)
            VALUES (@acc, @cmd, 'CHARACTER', @tid, @args, @old, @new, @sid, @ip, @server)
            RETURNING audit_id
            """, conn, tx);
        cmd.Parameters.AddWithValue("acc", req.AdminAccountId);
        cmd.Parameters.AddWithValue("cmd", command);
        cmd.Parameters.AddWithValue("tid", characterId.ToString(System.Globalization.CultureInfo.InvariantCulture));
        cmd.Parameters.Add(GameEventLog.Json("args", args ?? new { level = req.Level }));
        cmd.Parameters.Add(GameEventLog.Json("old", oldValue));
        cmd.Parameters.Add(GameEventLog.Json("new", newValue));
        cmd.Parameters.AddWithValue("sid", (object?)req.SessionId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("ip", req.Ip is null ? DBNull.Value : IPAddress.Parse(req.Ip));
        cmd.Parameters.AddWithValue("server", req.ServerId!);
        return (long)(await cmd.ExecuteScalarAsync(ct))!;
    }

    private static IResult BadRequest(string title) => Results.Problem(statusCode: StatusCodes.Status400BadRequest, title: title);

    private static IResult NotFound() => Results.Problem(statusCode: StatusCodes.Status404NotFound, title: "Charakter nicht gefunden");
}

/// <summary>
/// XP-Kurve: kumulierte Schwellen ab Stufe 1, nur solange lückenlos bekannt.
/// Fehlt die Schwelle einer Stufe, ist die Stufe davor das Cap – es wird nichts geschätzt.
/// </summary>
public sealed class Curve
{
    private readonly long[] _thresholds;

    private Curve(long[] thresholds) => _thresholds = thresholds;

    /// <summary>Höchste erreichbare Stufe; mindestens 1.</summary>
    public short Cap => (short)Math.Max(1, _thresholds.Length);

    public static Curve FromThresholds(IEnumerable<long> thresholds) => new([.. thresholds]);

    public static async Task<Curve> Load(NpgsqlConnection conn, NpgsqlTransaction tx, string table, bool allowDev, CancellationToken ct)
    {
        // Tabellenname ist eine Konstante aus dem Code, nie Nutzereingabe.
        await using var cmd = new NpgsqlCommand(
            $"SELECT level, xp_required FROM {table} WHERE xp_required IS NOT NULL AND (NOT is_dev OR @dev) ORDER BY level",
            conn, tx);
        cmd.Parameters.AddWithValue("dev", allowDev);
        var list = new List<long>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            var level = r.GetInt16(0);
            var xp = r.GetInt64(1);
            if (level != list.Count + 1 || (list.Count > 0 && xp < list[^1]))
            {
                break; // Lücke oder fallende Schwelle: Kurve endet hier
            }
            list.Add(xp);
        }
        return new Curve([.. list]);
    }

    public short LevelFor(long experience)
    {
        short level = 1;
        for (var i = 0; i < _thresholds.Length; i++)
        {
            if (_thresholds[i] <= experience)
            {
                level = (short)(i + 1);
            }
        }
        return level;
    }

    public long XpFor(short level) => level >= 1 && level <= _thresholds.Length ? _thresholds[level - 1] : 0;
}

/// <summary>Grenzen eines Skills: Kurve, Maximum der aktuellen Skillstufe, verbleibendes Gesamtbudget.</summary>
public sealed record SkillLimits(Curve Curve, short StageMax, long TotalBudget)
{
    public short CapFor(short currentLevel) =>
        (short)Math.Max(currentLevel, Math.Min(Math.Min(Curve.Cap, StageMax), TotalBudget));

    public static async Task<SkillLimits> Load(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, short skillId, short stage, bool allowDev, CancellationToken ct)
    {
        var curve = await Curve.Load(conn, tx, "skill_level_table", allowDev, ct);

        short stageMax;
        await using (var cmd = new NpgsqlCommand("SELECT max_level FROM skill_stages WHERE stage_no = @s", conn, tx))
        {
            cmd.Parameters.AddWithValue("s", stage);
            stageMax = (short?)await cmd.ExecuteScalarAsync(ct) ?? 1;
        }

        long budget = long.MaxValue;
        await using (var cmd = new NpgsqlCommand(
            """
            SELECT r.int_value - COALESCE((SELECT sum(level) FROM skill_progress WHERE character_id = @chr AND skill_id <> @sk), 0)
            FROM game_rules r WHERE r.rule_key = 'SKILL_TOTAL_CAP'
            """, conn, tx))
        {
            cmd.Parameters.AddWithValue("chr", characterId);
            cmd.Parameters.AddWithValue("sk", skillId);
            if (await cmd.ExecuteScalarAsync(ct) is long remaining)
            {
                budget = remaining;
            }
        }
        return new SkillLimits(curve, stageMax, budget);
    }

    /// <summary>Kleinste Skillstufe, deren Maximum die gewünschte Stufe enthält.</summary>
    public static async Task<short?> StageFor(NpgsqlConnection conn, NpgsqlTransaction tx, short level, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            "SELECT stage_no FROM skill_stages WHERE max_level >= @lvl ORDER BY stage_no LIMIT 1", conn, tx);
        cmd.Parameters.AddWithValue("lvl", level);
        return (short?)await cmd.ExecuteScalarAsync(ct);
    }
}
