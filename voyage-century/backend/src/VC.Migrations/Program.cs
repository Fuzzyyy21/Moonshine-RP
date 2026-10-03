using Microsoft.Extensions.Logging;
using Npgsql;
using VC.Migrations;

// Aufruf:
//   VC_DB="Host=...;Username=...;Password=...;Database=..." dotnet run --project src/VC.Migrations
//   optional: --migrations <ordner> --seed <ordner>
// Ohne Ordnerangaben wird von hier aus nach oben database/migrations und database/seed gesucht.
// Die Verbindung kommt nur aus der Umgebung, damit Passwörter nicht in der Prozessliste stehen.

using var loggerFactory = LoggerFactory.Create(b => b.AddJsonConsole(o =>
{
    o.UseUtcTimestamp = true;
    o.TimestampFormat = "yyyy-MM-ddTHH:mm:ss.fffZ";
    o.JsonWriterOptions = new System.Text.Json.JsonWriterOptions
    {
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };
}));

var connectionString = Environment.GetEnvironmentVariable("VC_DB");
if (string.IsNullOrWhiteSpace(connectionString))
{
    await Console.Error.WriteLineAsync("Umgebungsvariable VC_DB (Npgsql-Verbindungszeichenfolge) fehlt.");
    return 2;
}

string? Arg(string name)
{
    var i = Array.IndexOf(args, name);
    return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
}

var databaseDir = FindDatabaseDir(Directory.GetCurrentDirectory());
var migrationsDir = Arg("--migrations") ?? (databaseDir is null ? null : Path.Combine(databaseDir, "migrations"));
var seedDir = Arg("--seed") ?? (databaseDir is null ? null : Path.Combine(databaseDir, "seed"));
if (migrationsDir is null || !Directory.Exists(migrationsDir))
{
    await Console.Error.WriteLineAsync("Migrationsordner nicht gefunden; --migrations angeben.");
    return 2;
}

await using var dataSource = NpgsqlDataSource.Create(connectionString);
var migrator = new Migrator(dataSource, loggerFactory.CreateLogger<Migrator>());
try
{
    var applied = await migrator.RunAsync(migrationsDir, seedDir, CancellationToken.None);
    Console.WriteLine($"{applied.Count} Skript(e) angewendet.");
    return 0;
}
catch (MigrationException ex)
{
    await Console.Error.WriteLineAsync($"Migration fehlgeschlagen: {ex.Message}");
    return 1;
}

static string? FindDatabaseDir(string start)
{
    for (var dir = new DirectoryInfo(start); dir is not null; dir = dir.Parent)
    {
        var candidate = Path.Combine(dir.FullName, "database", "migrations");
        if (Directory.Exists(candidate))
        {
            return Path.Combine(dir.FullName, "database");
        }
    }
    return null;
}
