using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using VC.Auth;
using VC.Tests.Infrastructure;

namespace VC.Tests;

[Collection(DatabaseTestGroup.Name)]
public sealed class AuthTests(PostgresFixture db)
{
    [Fact]
    public async Task Wrong_password_and_unknown_login_get_the_same_answer()
    {
        await using var backend = await TestBackend.StartAsync(db);
        await backend.RegisterAndLoginAsync("known_user_1", "correct horse battery");

        var wrong = await backend.Auth.PostAsJsonAsync("/v1/sessions", new LoginRequest("known_user_1", "wrong password!"));
        var unknown = await backend.Auth.PostAsJsonAsync("/v1/sessions", new LoginRequest("nobody_here_1", "wrong password!"));

        Assert.Equal(HttpStatusCode.Unauthorized, wrong.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, unknown.StatusCode);
        // Gleiche Meldung, damit sich nicht erkennen lässt, ob ein Login existiert (traceId ist pro Anfrage verschieden).
        using var a = JsonDocument.Parse(await wrong.Content.ReadAsStringAsync());
        using var b = JsonDocument.Parse(await unknown.Content.ReadAsStringAsync());
        Assert.Equal(a.RootElement.GetProperty("title").GetString(), b.RootElement.GetProperty("title").GetString());
    }

    [Fact]
    public async Task Login_is_case_insensitive_and_duplicate_logins_are_rejected()
    {
        await using var backend = await TestBackend.StartAsync(db);
        await backend.RegisterAndLoginAsync("Captain_Case", "correct horse battery");

        var dup = await backend.Auth.PostAsJsonAsync("/v1/accounts", new RegisterRequest("captain_case", "correct horse battery", null));
        Assert.Equal(HttpStatusCode.Conflict, dup.StatusCode);

        var login = await backend.Auth.PostAsJsonAsync("/v1/sessions", new LoginRequest("CAPTAIN_CASE", "correct horse battery"));
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
    }

    [Theory]
    [InlineData("ab", "long enough pw")]
    [InlineData("has space", "long enough pw")]
    [InlineData("valid_name", "short")]
    public async Task Registration_validates_input(string login, string password)
    {
        await using var backend = await TestBackend.StartAsync(db);
        var res = await backend.Auth.PostAsJsonAsync("/v1/accounts", new RegisterRequest(login, password, null));
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }

    [Fact]
    public async Task Registration_can_be_disabled()
    {
        await using var backend = await TestBackend.StartAsync(db, new Dictionary<string, string?> { ["Auth:AllowRegistration"] = "false" });
        var res = await backend.Auth.PostAsJsonAsync("/v1/accounts", new RegisterRequest("blocked_user", "correct horse battery", null));
        Assert.Equal(HttpStatusCode.Forbidden, res.StatusCode);
    }

    [Fact]
    public async Task Logout_revokes_the_ticket_for_zone_servers()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var login = await backend.RegisterAndLoginAsync();

        var logout = await backend.Auth.SendAsync(TestBackend.WithTicket(HttpMethod.Delete, "/v1/sessions/current", login.Ticket));
        Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);

        var validate = await backend.AuthInternal.PostAsJsonAsync("/internal/v1/sessions/validate", new ValidateRequest(login.Ticket));
        Assert.Equal(HttpStatusCode.Unauthorized, validate.StatusCode);
    }

    [Fact]
    public async Task Expired_tickets_are_rejected()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var login = await backend.RegisterAndLoginAsync();
        await db.ExecAsync("UPDATE account_sessions SET expires_at = now() - interval '1 second' WHERE session_id = @s",
            ("s", login.SessionId));

        var validate = await backend.AuthInternal.PostAsJsonAsync("/internal/v1/sessions/validate", new ValidateRequest(login.Ticket));
        Assert.Equal(HttpStatusCode.Unauthorized, validate.StatusCode);
    }

    [Fact]
    public async Task Only_the_hash_of_a_ticket_is_stored()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var login = await backend.RegisterAndLoginAsync();
        var stored = await db.ScalarAsync<byte[]>("SELECT token_hash FROM account_sessions WHERE session_id = @s", ("s", login.SessionId));
        Assert.Equal(VC.Common.Sessions.SessionStore.HashTicket(login.Ticket), stored);
        Assert.Equal(32, stored.Length);
    }

    [Fact]
    public async Task Banned_accounts_cannot_log_in_and_lose_existing_tickets()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var login = await backend.RegisterAndLoginAsync("banned_user_1", "correct horse battery");
        await db.ExecAsync("UPDATE accounts SET status = 'BANNED', banned_until = now() + interval '1 day' WHERE account_id = @a",
            ("a", login.AccountId));

        var again = await backend.Auth.PostAsJsonAsync("/v1/sessions", new LoginRequest("banned_user_1", "correct horse battery"));
        Assert.Equal(HttpStatusCode.Forbidden, again.StatusCode);

        var validate = await backend.AuthInternal.PostAsJsonAsync("/internal/v1/sessions/validate", new ValidateRequest(login.Ticket));
        Assert.Equal(HttpStatusCode.Unauthorized, validate.StatusCode);
    }

    [Fact]
    public async Task Expired_ban_is_lifted_on_next_login()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var login = await backend.RegisterAndLoginAsync("unbanned_user", "correct horse battery");
        await db.ExecAsync("UPDATE accounts SET status = 'BANNED', banned_until = now() - interval '1 minute' WHERE account_id = @a",
            ("a", login.AccountId));

        var again = await backend.Auth.PostAsJsonAsync("/v1/sessions", new LoginRequest("unbanned_user", "correct horse battery"));
        Assert.Equal(HttpStatusCode.OK, again.StatusCode);
        Assert.Equal("ACTIVE", await db.ScalarAsync<string>("SELECT status FROM accounts WHERE account_id = @a", ("a", login.AccountId)));
    }

    [Fact]
    public async Task Login_attempts_are_rate_limited()
    {
        await using var backend = await TestBackend.StartAsync(db, new Dictionary<string, string?> { ["Auth:LoginAttemptsPerMinute"] = "3" });
        var codes = new List<HttpStatusCode>();
        for (var i = 0; i < 4; i++)
        {
            var res = await backend.Auth.PostAsJsonAsync("/v1/sessions", new LoginRequest("rate_limited", "whatever password"));
            codes.Add(res.StatusCode);
        }
        Assert.Equal(HttpStatusCode.TooManyRequests, codes[^1]);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("wrong-key-wrong-key-wrong-key-wrong-key")]
    public async Task Internal_endpoints_require_the_service_key(string? key)
    {
        await using var backend = await TestBackend.StartAsync(db);
        using var req = new HttpRequestMessage(HttpMethod.Post, "/internal/v1/sessions/validate")
        {
            Content = JsonContent.Create(new ValidateRequest("anything")),
        };
        if (key is not null)
        {
            req.Headers.Add("X-Service-Key", key);
        }
        var res = await backend.Auth.SendAsync(req);
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }
}
