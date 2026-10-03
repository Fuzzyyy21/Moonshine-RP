using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;
using VC.Migrations;

namespace VC.Tests.Infrastructure;

/// <summary>
/// Legt pro Testlauf eine frische Datenbank auf dem Server aus <c>VC_TEST_PG</c> an und spielt
/// alle Migrationen und Seeds ein. Bereitgestellt von tools/test_backend.sh oder in CI.
/// </summary>
public sealed class PostgresFixture : IAsyncLifetime
{
    private readonly List<string> _databases = [];
    private string _adminConnectionString = "";

    public string ConnectionString { get; private set; } = "";
    public NpgsqlDataSource DataSource { get; private set; } = null!;

    public static string DatabaseDir { get; } = FindDatabaseDir();

    public async Task InitializeAsync()
    {
        _adminConnectionString = Environment.GetEnvironmentVariable("VC_TEST_PG")
            ?? throw new InvalidOperationException(
                "VC_TEST_PG ist nicht gesetzt. Tests mit tools/test_backend.sh starten (startet eine Wegwerf-PostgreSQL).");
        ConnectionString = await CreateEmptyDatabaseAsync();
        DataSource = NpgsqlDataSource.Create(ConnectionString);
        await new Migrator(DataSource, NullLogger<Migrator>.Instance).RunAsync(
            Path.Combine(DatabaseDir, "migrations"), Path.Combine(DatabaseDir, "seed"), CancellationToken.None);
    }

    /// <summary>Weitere leere Datenbank, z. B. für Migrator-Tests mit eigenen Skripten.</summary>
    public async Task<string> CreateEmptyDatabaseAsync()
    {
        var name = "vc_test_" + Guid.NewGuid().ToString("N")[..12];
        await using (var admin = NpgsqlDataSource.Create(_adminConnectionString))
        await using (var cmd = admin.CreateCommand($"CREATE DATABASE {name}"))
        {
            await cmd.ExecuteNonQueryAsync();
        }
        _databases.Add(name);
        return new NpgsqlConnectionStringBuilder(_adminConnectionString) { Database = name }.ConnectionString;
    }

    public async Task<T> ScalarAsync<T>(string sql, params (string Name, object Value)[] parameters)
    {
        await using var cmd = DataSource.CreateCommand(sql);
        foreach (var (n, v) in parameters)
        {
            cmd.Parameters.AddWithValue(n, v);
        }
        return (T)(await cmd.ExecuteScalarAsync())!;
    }

    public async Task ExecAsync(string sql, params (string Name, object Value)[] parameters)
    {
        await using var cmd = DataSource.CreateCommand(sql);
        foreach (var (n, v) in parameters)
        {
            cmd.Parameters.AddWithValue(n, v);
        }
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DisposeAsync()
    {
        if (DataSource is not null)
        {
            await DataSource.DisposeAsync();
        }
        NpgsqlConnection.ClearAllPools();
        await using var admin = NpgsqlDataSource.Create(_adminConnectionString);
        foreach (var name in _databases)
        {
            await using var cmd = admin.CreateCommand($"DROP DATABASE IF EXISTS {name} WITH (FORCE)");
            await cmd.ExecuteNonQueryAsync();
        }
    }

    private static string FindDatabaseDir()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
        {
            var candidate = Path.Combine(dir.FullName, "database");
            if (Directory.Exists(Path.Combine(candidate, "migrations")))
            {
                return candidate;
            }
        }
        throw new DirectoryNotFoundException("database/migrations nicht gefunden");
    }
}

[CollectionDefinition(Name)]
public sealed class DatabaseTestGroup : ICollectionFixture<PostgresFixture>
{
    public const string Name = "database";
}
