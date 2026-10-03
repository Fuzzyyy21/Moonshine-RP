using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;
using VC.Common.Security;
using VC.Migrations;
using VC.Tests.Infrastructure;

namespace VC.Tests;

public sealed class PasswordHasherTests
{
    private static readonly PasswordHashOptions Fast = new() { MemoryKiB = 1024, Iterations = 1, Parallelism = 1 };

    [Fact]
    public void Hash_round_trips_and_uses_phc_format()
    {
        var hash = new PasswordHasher(Fast).Hash("geheimes passwort");
        Assert.StartsWith("$argon2id$v=19$m=1024,t=1,p=1$", hash, StringComparison.Ordinal);
        Assert.True(PasswordHasher.Verify("geheimes passwort", hash));
        Assert.False(PasswordHasher.Verify("Geheimes passwort", hash));
    }

    [Fact]
    public void Same_password_gets_different_salts()
    {
        var hasher = new PasswordHasher(Fast);
        Assert.NotEqual(hasher.Hash("pw-1234567890"), hasher.Hash("pw-1234567890"));
    }

    [Theory]
    [InlineData("")]
    [InlineData("klartext")]
    [InlineData("$argon2id$v=19$m=1024,t=1,p=1$nur-salz")]
    [InlineData("$argon2id$v=19$m=abc,t=1,p=1$c2FsdA$aGFzaA")]
    public void Malformed_hashes_never_verify(string stored) => Assert.False(PasswordHasher.Verify("egal", stored));

    [Fact]
    public void Changed_parameters_trigger_rehash()
    {
        var old = new PasswordHasher(Fast).Hash("pw-1234567890");
        Assert.False(new PasswordHasher(Fast).NeedsRehash(old));
        Assert.True(new PasswordHasher(new PasswordHashOptions { MemoryKiB = 2048, Iterations = 1, Parallelism = 1 }).NeedsRehash(old));
    }
}

[Collection(DatabaseTestGroup.Name)]
public sealed class MigratorTests(PostgresFixture db) : IDisposable
{
    private readonly string _dir = Directory.CreateTempSubdirectory("vc-mig-").FullName;

    [Fact]
    public async Task Repository_migrations_are_idempotent()
    {
        var again = await new Migrator(db.DataSource, NullLogger<Migrator>.Instance).RunAsync(
            Path.Combine(PostgresFixture.DatabaseDir, "migrations"), Path.Combine(PostgresFixture.DatabaseDir, "seed"), default);
        Assert.Empty(again);
    }

    [Fact]
    public async Task Changing_an_applied_migration_is_refused()
    {
        var migrator = await FreshMigrator();
        Write("V0001__create.sql", "CREATE TABLE t (id int);");
        await migrator.RunAsync(_dir, null, default);

        Write("V0001__create.sql", "CREATE TABLE t (id bigint);");
        var ex = await Assert.ThrowsAsync<MigrationException>(() => migrator.RunAsync(_dir, null, default));
        Assert.Contains("geändert", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Out_of_order_migrations_are_refused()
    {
        var migrator = await FreshMigrator();
        Write("V0002__second.sql", "SELECT 1;");
        await migrator.RunAsync(_dir, null, default);

        Write("V0001__first.sql", "SELECT 1;");
        await Assert.ThrowsAsync<MigrationException>(() => migrator.RunAsync(_dir, null, default));
    }

    [Fact]
    public async Task Failed_migration_is_rolled_back_completely()
    {
        var (migrator, source) = await FreshMigratorWithSource();
        Write("V0001__broken.sql", "CREATE TABLE half (id int); SELECT * FROM does_not_exist;");
        await Assert.ThrowsAsync<MigrationException>(() => migrator.RunAsync(_dir, null, default));

        await using var cmd = source.CreateCommand("SELECT to_regclass('half') IS NULL");
        Assert.True((bool)(await cmd.ExecuteScalarAsync())!);
    }

    [Fact]
    public async Task Repeatable_scripts_rerun_only_when_changed()
    {
        var seedDir = Directory.CreateDirectory(Path.Combine(_dir, "seed")).FullName;
        var (migrator, _) = await FreshMigratorWithSource();
        Write("V0001__t.sql", "CREATE TABLE r (v int);");
        File.WriteAllText(Path.Combine(seedDir, "R__data.sql"), "INSERT INTO r VALUES (1);");

        Assert.Equal(2, (await migrator.RunAsync(_dir, seedDir, default)).Count);
        Assert.Empty(await migrator.RunAsync(_dir, seedDir, default));

        File.WriteAllText(Path.Combine(seedDir, "R__data.sql"), "INSERT INTO r VALUES (2);");
        var rerun = await migrator.RunAsync(_dir, seedDir, default);
        Assert.Equal("R__data", Assert.Single(rerun).Version);
    }

    public void Dispose() => Directory.Delete(_dir, recursive: true);

    private void Write(string name, string sql) => File.WriteAllText(Path.Combine(_dir, name), sql);

    private async Task<Migrator> FreshMigrator() => (await FreshMigratorWithSource()).Migrator;

    private async Task<(Migrator Migrator, NpgsqlDataSource Source)> FreshMigratorWithSource()
    {
        var source = NpgsqlDataSource.Create(await db.CreateEmptyDatabaseAsync());
        return (new Migrator(source, NullLogger<Migrator>.Instance), source);
    }
}
