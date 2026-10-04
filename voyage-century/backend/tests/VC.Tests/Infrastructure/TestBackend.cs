using System.Net.Http.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using VC.Auth;
using VC.Common.Security;
using VC.GameData;

namespace VC.Tests.Infrastructure;

/// <summary>Startet Auth- und GameData-Dienst in-process (TestServer) gegen die Testdatenbank.</summary>
public sealed class TestBackend : IAsyncDisposable
{
    public const string ServiceKey = "test-service-key-0123456789abcdef-0123";

    private readonly WebApplication _auth;
    private readonly WebApplication _game;

    private TestBackend(WebApplication auth, WebApplication game)
    {
        _auth = auth;
        _game = game;
        Auth = auth.GetTestClient();
        Game = game.GetTestClient();
        AuthInternal = WithServiceKey(auth.GetTestClient());
        GameInternal = WithServiceKey(game.GetTestClient());
    }

    /// <summary>Client-Sicht auf den Login-Dienst.</summary>
    public HttpClient Auth { get; }

    /// <summary>Client-Sicht auf den GameData-Dienst.</summary>
    public HttpClient Game { get; }

    /// <summary>Zonen-Server-Sicht (mit Service-Key).</summary>
    public HttpClient AuthInternal { get; }

    public HttpClient GameInternal { get; }

    public static async Task<TestBackend> StartAsync(PostgresFixture db, IDictionary<string, string?>? overrides = null)
    {
        var settings = new Dictionary<string, string?>
        {
            ["Logging:LogLevel:Default"] = "Warning",
            ["Database:ConnectionString"] = db.ConnectionString,
            ["ServiceKeys:Keys:0"] = ServiceKey,
            ["Service:InstanceId"] = "test-instance",
            ["Auth:AllowRegistration"] = "true",
            ["Auth:LoginAttemptsPerMinute"] = "10000",
            ["PasswordHash:MemoryKiB"] = "1024",
            ["PasswordHash:Iterations"] = "1",
            ["PasswordHash:Parallelism"] = "1",
            ["Progression:AllowDevCurves"] = "true",
        };
        foreach (var (k, v) in overrides ?? new Dictionary<string, string?>())
        {
            settings[k] = v;
        }

        var auth = await Start("auth", settings, b => AuthApp.ConfigureServices(b), a => AuthApp.Configure(a));
        var game = await Start("gamedata", settings, b => GameDataApp.ConfigureServices(b), a => GameDataApp.Configure(a));
        return new TestBackend(auth, game);
    }

    private static async Task<WebApplication> Start(
        string serviceName, Dictionary<string, string?> settings,
        Action<WebApplicationBuilder> configureServices, Action<WebApplication> configure)
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            EnvironmentName = "Testing",
            ContentRootPath = AppContext.BaseDirectory,
        });
        builder.WebHost.UseTestServer();
        builder.Configuration.AddInMemoryCollection(settings);
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?> { ["Service:Name"] = serviceName });
        configureServices(builder);
        var app = builder.Build();
        configure(app);
        await app.StartAsync();
        return app;
    }

    private static HttpClient WithServiceKey(HttpClient client)
    {
        client.DefaultRequestHeaders.Add(ServiceKeyFilter.Header, ServiceKey);
        return client;
    }

    // ---- Hilfen für den typischen Ablauf -------------------------------------------------

    public async Task<LoginResponse> RegisterAndLoginAsync(string? login = null, string password = "correct horse battery")
    {
        login ??= "u" + Guid.NewGuid().ToString("N")[..12];
        var reg = await Auth.PostAsJsonAsync("/v1/accounts", new RegisterRequest(login, password, null));
        reg.EnsureSuccessStatusCode();
        var res = await Auth.PostAsJsonAsync("/v1/sessions", new LoginRequest(login, password));
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<LoginResponse>())!;
    }

    public static HttpRequestMessage WithTicket(HttpMethod method, string url, string ticket, object? body = null)
    {
        var msg = new HttpRequestMessage(method, url);
        msg.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", ticket);
        if (body is not null)
        {
            msg.Content = JsonContent.Create(body);
        }
        return msg;
    }

    public async Task<CharacterSummary> CreateCharacterAsync(string ticket, string? name = null, string profession = "ROYAL_OFFICER")
    {
        name ??= "Kap" + Guid.NewGuid().ToString("N")[..10];
        var res = await Game.SendAsync(WithTicket(HttpMethod.Post, "/v1/characters", ticket,
            new { name, gender = "FEMALE", professionCode = profession }));
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<CharacterSummary>())!;
    }

    public async ValueTask DisposeAsync()
    {
        foreach (var c in new[] { Auth, Game, AuthInternal, GameInternal })
        {
            c.Dispose();
        }
        await _auth.DisposeAsync();
        await _game.DisposeAsync();
    }
}
