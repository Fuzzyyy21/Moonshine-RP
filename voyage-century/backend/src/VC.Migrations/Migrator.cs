using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace VC.Migrations;

public sealed class MigrationException(string message) : Exception(message);

public sealed record AppliedScript(string Version, string Description, string Kind);

/// <summary>
/// Wendet versionierte Migrationen (<c>V0001__name.sql</c>) genau einmal und in Reihenfolge an und
/// wiederholbare Skripte (<c>R__name.sql</c>) immer dann, wenn sich ihr Inhalt geändert hat.
/// Jede Datei läuft in einer eigenen Transaktion. Eine bereits angewendete Migration darf sich nicht
/// mehr ändern (Prüfsumme); neue Änderungen gehören in eine neue Datei.
/// </summary>
public sealed partial class Migrator(NpgsqlDataSource db, ILogger<Migrator> log)
{
    // Fester Schlüssel für pg_advisory_lock, damit nie zwei Migratoren gleichzeitig laufen.
    private const long LockKey = 0x5643_4D49_4752; // "VCMIGR"

    [GeneratedRegex(@"^V(\d{4})__([A-Za-z0-9_]+)\.sql$")]
    private static partial Regex VersionedName();

    [GeneratedRegex(@"^R__([A-Za-z0-9_]+)\.sql$")]
    private static partial Regex RepeatableName();

    public async Task<IReadOnlyList<AppliedScript>> RunAsync(string migrationsDir, string? seedDir, CancellationToken ct)
    {
        var versioned = LoadVersioned(migrationsDir);
        var repeatable = seedDir is null ? [] : LoadRepeatable(seedDir);
        var applied = new List<AppliedScript>();

        await using var lockConn = await db.OpenConnectionAsync(ct);
        await Exec(lockConn, null, $"SELECT pg_advisory_lock({LockKey})", ct);
        try
        {
            await Exec(lockConn, null,
                """
                CREATE TABLE IF NOT EXISTS schema_migrations (
                    version     TEXT PRIMARY KEY,
                    description TEXT NOT NULL,
                    kind        TEXT NOT NULL CHECK (kind IN ('VERSIONED', 'REPEATABLE')),
                    checksum    TEXT NOT NULL,
                    applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
                )
                """, ct);
            var history = await LoadHistory(lockConn, ct);
            var highestApplied = history.Where(h => h.Value.Kind == "VERSIONED").Select(h => h.Key).DefaultIfEmpty("").Max(StringComparer.Ordinal)!;

            foreach (var script in versioned)
            {
                if (history.TryGetValue(script.Version, out var done))
                {
                    if (done.Checksum != script.Checksum)
                    {
                        throw new MigrationException(
                            $"Migration {script.FileName} wurde nach dem Anwenden geändert. Änderungen gehören in eine neue Migration.");
                    }
                    continue;
                }
                if (string.CompareOrdinal(script.Version, highestApplied) < 0)
                {
                    throw new MigrationException(
                        $"Migration {script.FileName} liegt vor der bereits angewendeten Version {highestApplied}.");
                }
                await Apply(script, ct);
                applied.Add(new AppliedScript(script.Version, script.Description, script.Kind));
            }

            foreach (var script in repeatable)
            {
                if (history.TryGetValue(script.Version, out var done) && done.Checksum == script.Checksum)
                {
                    continue;
                }
                await Apply(script, ct);
                applied.Add(new AppliedScript(script.Version, script.Description, script.Kind));
            }
        }
        finally
        {
            await Exec(lockConn, null, $"SELECT pg_advisory_unlock({LockKey})", CancellationToken.None);
        }

        if (applied.Count == 0)
        {
            LogUpToDate(log);
        }
        return applied;
    }

    private async Task Apply(Script script, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        try
        {
            await Exec(conn, tx, script.Sql, ct);
        }
        catch (PostgresException ex)
        {
            throw new MigrationException($"{script.FileName}: {ex.SqlState} {ex.MessageText} (Position {ex.Position})");
        }
        await using (var cmd = new NpgsqlCommand(
            """
            INSERT INTO schema_migrations (version, description, kind, checksum) VALUES (@v, @d, @k, @c)
            ON CONFLICT (version) DO UPDATE SET checksum = EXCLUDED.checksum, applied_at = now()
            """, conn, tx))
        {
            cmd.Parameters.AddWithValue("v", script.Version);
            cmd.Parameters.AddWithValue("d", script.Description);
            cmd.Parameters.AddWithValue("k", script.Kind);
            cmd.Parameters.AddWithValue("c", script.Checksum);
            await cmd.ExecuteNonQueryAsync(ct);
        }
        await tx.CommitAsync(ct);
        LogApplied(log, script.FileName);
    }

    private static async Task Exec(NpgsqlConnection conn, NpgsqlTransaction? tx, string sql, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(sql, conn, tx);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    private static async Task<Dictionary<string, (string Kind, string Checksum)>> LoadHistory(NpgsqlConnection conn, CancellationToken ct)
    {
        var result = new Dictionary<string, (string, string)>(StringComparer.Ordinal);
        await using var cmd = new NpgsqlCommand("SELECT version, kind, checksum FROM schema_migrations", conn);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            result[reader.GetString(0)] = (reader.GetString(1), reader.GetString(2));
        }
        return result;
    }

    private static List<Script> LoadVersioned(string dir)
    {
        var scripts = new List<Script>();
        foreach (var path in Directory.GetFiles(dir, "*.sql"))
        {
            var name = Path.GetFileName(path);
            var m = VersionedName().Match(name);
            if (!m.Success)
            {
                throw new MigrationException($"{name}: Dateiname entspricht nicht V0000__beschreibung.sql");
            }
            scripts.Add(Script.Load(path, m.Groups[1].Value, m.Groups[2].Value, "VERSIONED"));
        }
        var duplicate = scripts.GroupBy(s => s.Version).FirstOrDefault(g => g.Count() > 1);
        if (duplicate is not null)
        {
            throw new MigrationException($"Version {duplicate.Key} ist mehrfach vergeben");
        }
        return [.. scripts.OrderBy(s => s.Version, StringComparer.Ordinal)];
    }

    private static List<Script> LoadRepeatable(string dir)
    {
        if (!Directory.Exists(dir))
        {
            return [];
        }
        var scripts = new List<Script>();
        foreach (var path in Directory.GetFiles(dir, "*.sql"))
        {
            var name = Path.GetFileName(path);
            var m = RepeatableName().Match(name);
            if (!m.Success)
            {
                throw new MigrationException($"{name}: Dateiname entspricht nicht R__beschreibung.sql");
            }
            scripts.Add(Script.Load(path, $"R__{m.Groups[1].Value}", m.Groups[1].Value, "REPEATABLE"));
        }
        return [.. scripts.OrderBy(s => s.Version, StringComparer.Ordinal)];
    }

    [LoggerMessage(EventId = 2000, Level = LogLevel.Information, Message = "Angewendet: {FileName}")]
    private static partial void LogApplied(ILogger logger, string fileName);

    [LoggerMessage(EventId = 2001, Level = LogLevel.Information, Message = "Datenbank ist aktuell, nichts anzuwenden")]
    private static partial void LogUpToDate(ILogger logger);

    private sealed record Script(string FileName, string Version, string Description, string Kind, string Sql, string Checksum)
    {
        public static Script Load(string path, string version, string description, string kind)
        {
            // Zeilenenden normalisieren, damit Windows- und Linux-Checkouts dieselbe Prüfsumme ergeben.
            var sql = File.ReadAllText(path, Encoding.UTF8).Replace("\r\n", "\n", StringComparison.Ordinal);
            var checksum = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(sql)));
            return new Script(Path.GetFileName(path), version, description, kind, sql, checksum);
        }
    }
}
