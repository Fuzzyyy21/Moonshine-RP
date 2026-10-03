using System.Diagnostics;
using System.Text.Encodings.Web;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common.Logging;
using VC.Common.Security;
using VC.Common.Sessions;

namespace VC.Common.Hosting;

/// <summary>Gemeinsame Grundausstattung aller Backend-Dienste.</summary>
public static class VcHostDefaults
{
    public static WebApplicationBuilder AddVcDefaults(this WebApplicationBuilder builder)
    {
        // Strukturierte JSON-Logs auf stdout; Sammeln übernimmt die Laufzeitumgebung.
        builder.Logging.ClearProviders();
        builder.Logging.AddJsonConsole(o =>
        {
            o.IncludeScopes = true;
            o.UseUtcTimestamp = true;
            o.TimestampFormat = "yyyy-MM-ddTHH:mm:ss.fffZ";
            // Umlaute und chinesische Namen lesbar lassen; die Logs werden nicht in HTML eingebettet.
            o.JsonWriterOptions = new JsonWriterOptions { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };
        });

        builder.Services.AddOptions<ServiceIdentityOptions>()
            .Bind(builder.Configuration.GetSection(ServiceIdentityOptions.Section)).ValidateDataAnnotations().ValidateOnStart();
        builder.Services.AddOptions<DatabaseOptions>()
            .Bind(builder.Configuration.GetSection(DatabaseOptions.Section)).ValidateDataAnnotations().ValidateOnStart();
        builder.Services.AddOptions<ServiceKeyOptions>()
            .Bind(builder.Configuration.GetSection(ServiceKeyOptions.Section)).ValidateDataAnnotations()
            .Validate(o => o.Keys.All(k => k.Length >= ServiceKeyOptions.MinimumLength),
                $"Jeder Service-Key braucht mindestens {ServiceKeyOptions.MinimumLength} Zeichen")
            .Validate(o => builder.Environment.IsDevelopment()
                    || !o.Keys.Any(k => k.StartsWith(ServiceKeyOptions.DevelopmentPrefix, StringComparison.Ordinal)),
                "Entwicklungs-Service-Keys sind außerhalb von Development verboten")
            .ValidateOnStart();

        builder.Services.AddSingleton(sp =>
            NpgsqlDataSource.Create(sp.GetRequiredService<IOptions<DatabaseOptions>>().Value.ConnectionString));
        builder.Services.AddSingleton<SessionStore>();
        builder.Services.AddSingleton<ServiceKeyFilter>();
        builder.Services.AddSingleton<SessionFilter>();
        builder.Services.AddProblemDetails();
        return builder;
    }

    public static WebApplication UseVcDefaults(this WebApplication app)
    {
        var identity = app.Services.GetRequiredService<IOptions<ServiceIdentityOptions>>().Value;
        var log = app.Services.GetRequiredService<ILoggerFactory>().CreateLogger("VC.Http");

        app.UseExceptionHandler();
        app.Use(async (http, next) =>
        {
            using var scope = Log.BeginServiceScope(log, identity.Name, identity.InstanceId);
            var watch = Stopwatch.StartNew();
            await next(http);
            // Keine Query-Strings, Header oder Bodies loggen: dort können Tickets und Passwörter stehen.
            Log.HttpRequest(log, http.Request.Method, http.Request.Path.Value, http.Response.StatusCode, watch.ElapsedMilliseconds);
        });

        app.MapGet("/health", async (NpgsqlDataSource db, CancellationToken ct) =>
        {
            await using var cmd = db.CreateCommand("SELECT 1");
            await cmd.ExecuteScalarAsync(ct);
            return Results.Ok(new { status = "ok", service = identity.Name, server = identity.InstanceId });
        });
        return app;
    }

    public static RouteGroupBuilder RequireServiceKey(this RouteGroupBuilder group) =>
        group.AddEndpointFilter<ServiceKeyFilter>();

    public static RouteGroupBuilder RequireSession(this RouteGroupBuilder group) =>
        group.AddEndpointFilter<SessionFilter>();
}
