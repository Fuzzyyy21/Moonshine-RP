using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

[Collection(DatabaseTestGroup.Name)]
public sealed class CharacterTests(PostgresFixture db)
{
    [Fact]
    public async Task Client_endpoints_require_a_ticket()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var res = await backend.Game.GetAsync("/v1/characters");
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task New_character_has_no_invented_values()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var login = await backend.RegisterAndLoginAsync();
        var created = await backend.CreateCharacterAsync(login.Ticket, profession: "TREASURE_HUNTER");

        Assert.Equal(1, created.Level);
        Assert.Null(created.ZoneId);
        // Startgold ist im Original UNKNOWN → Wallet existiert mit 0
        Assert.Equal(0L, await db.ScalarAsync<long>(
            "SELECT balance FROM character_wallets WHERE character_id = @c AND currency_code = 'GOLD'", ("c", created.CharacterId)));
        // Start-HP/SP sind UNKNOWN → noch keine Statuszeile
        Assert.Equal(0L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM character_stats WHERE character_id = @c", ("c", created.CharacterId)));

        var list = await (await backend.Game.SendAsync(TestBackend.WithTicket(HttpMethod.Get, "/v1/characters", login.Ticket)))
            .Content.ReadFromJsonAsync<List<CharacterSummary>>();
        Assert.Equal("TREASURE_HUNTER", Assert.Single(list!).ProfessionCode);
    }

    [Fact]
    public async Task Names_are_unique_case_insensitively_and_support_chinese()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var a = await backend.RegisterAndLoginAsync();
        var b = await backend.RegisterAndLoginAsync();
        await backend.CreateCharacterAsync(a.Ticket, "航海家");
        await backend.CreateCharacterAsync(a.Ticket, "Seefahrerin");

        var dup = await backend.Game.SendAsync(TestBackend.WithTicket(HttpMethod.Post, "/v1/characters", b.Ticket,
            new { name = "SEEFAHRERIN", gender = "MALE", professionCode = "ROYAL_OFFICER" }));
        Assert.Equal(HttpStatusCode.Conflict, dup.StatusCode);
    }

    [Theory]
    [InlineData("X", "MALE", "ROYAL_OFFICER")]
    [InlineData("Mit Leerzeichen", "MALE", "ROYAL_OFFICER")]
    [InlineData("Gültig", "OTHER", "ROYAL_OFFICER")]
    [InlineData("Gültig", "MALE", "NOT_A_PROFESSION")]
    public async Task Invalid_character_requests_are_rejected(string name, string gender, string profession)
    {
        await using var backend = await TestBackend.StartAsync(db);
        var login = await backend.RegisterAndLoginAsync();
        var res = await backend.Game.SendAsync(TestBackend.WithTicket(HttpMethod.Post, "/v1/characters", login.Ticket,
            new { name, gender, professionCode = profession }));
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }

    [Fact]
    public async Task Character_limit_is_enforced()
    {
        await using var backend = await TestBackend.StartAsync(db, new Dictionary<string, string?> { ["GameData:MaxCharactersPerAccount"] = "2" });
        var login = await backend.RegisterAndLoginAsync();
        await backend.CreateCharacterAsync(login.Ticket);
        await backend.CreateCharacterAsync(login.Ticket);

        var third = await backend.Game.SendAsync(TestBackend.WithTicket(HttpMethod.Post, "/v1/characters", login.Ticket,
            new { name = "Dritter", gender = "MALE", professionCode = "ROYAL_OFFICER" }));
        Assert.Equal(HttpStatusCode.Conflict, third.StatusCode);
    }
}
