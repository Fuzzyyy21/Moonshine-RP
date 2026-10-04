using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

[Collection(DatabaseTestGroup.Name)]
public sealed class AppearanceTests(PostgresFixture db)
{
    [Fact]
    public async Task Options_come_from_the_database_for_the_creation_screen()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var login = await backend.RegisterAndLoginAsync();
        var res = await backend.Game.SendAsync(TestBackend.WithTicket(HttpMethod.Get, "/v1/character-options", login.Ticket));
        var options = (await res.Content.ReadFromJsonAsync<CharacterOptionsResponse>())!;

        Assert.Equal(5, options.Professions.Count);                    // aus der Reconstruction Database
        Assert.Contains(options.Professions, p => p is { Code: "TREASURE_HUNTER", Confidence: "UNCERTAIN" });
        Assert.Equal(["MALE", "FEMALE"], options.Genders);
        Assert.Equal(["face", "hair", "hairColor", "skin", "body", "outfit"], options.AppearanceSlots.Select(s => s.Slot));
    }

    [Fact]
    public async Task Options_require_a_ticket()
    {
        await using var backend = await TestBackend.StartAsync(db);
        Assert.Equal(HttpStatusCode.Unauthorized, (await backend.Game.GetAsync("/v1/character-options")).StatusCode);
    }

    [Fact]
    public async Task Appearance_is_normalized_and_reaches_the_zone_server()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var login = await backend.RegisterAndLoginAsync();
        var res = await backend.Game.SendAsync(TestBackend.WithTicket(HttpMethod.Post, "/v1/characters", login.Ticket,
            new { name = "Lotsin" + Guid.NewGuid().ToString("N")[..6], gender = "FEMALE", professionCode = "ARMED_MERCHANT",
                  appearance = new { hairColor = 5, body = 2 } }));
        res.EnsureSuccessStatusCode();
        var created = (await res.Content.ReadFromJsonAsync<CharacterSummary>())!;

        var state = (await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{created.CharacterId}/state?accountId={login.AccountId}"))!;
        Assert.Equal("FEMALE", state.Gender);
        Assert.Equal(6, state.Appearance.Count);   // alle Merkmale vorhanden, fehlende = 0
        Assert.Equal(5, state.Appearance["hairColor"]);
        Assert.Equal(2, state.Appearance["body"]);
        Assert.Equal(0, state.Appearance["face"]);
    }

    [Theory]
    [InlineData("{\"hairColor\": 6}")]       // außerhalb 0..5
    [InlineData("{\"hairColor\": -1}")]
    [InlineData("{\"hairColor\": 1.5}")]
    [InlineData("{\"wings\": 1}")]           // unbekanntes Merkmal
    [InlineData("[1, 2]")]                   // kein Objekt
    public async Task Invalid_appearance_is_rejected(string appearanceJson)
    {
        await using var backend = await TestBackend.StartAsync(db);
        var login = await backend.RegisterAndLoginAsync();
        var body = $"{{\"name\":\"Probe{Guid.NewGuid().ToString("N")[..6]}\",\"gender\":\"MALE\",\"professionCode\":\"ROYAL_OFFICER\",\"appearance\":{appearanceJson}}}";
        using var req = TestBackend.WithTicket(HttpMethod.Post, "/v1/characters", login.Ticket);
        req.Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json");
        Assert.Equal(HttpStatusCode.BadRequest, (await backend.Game.SendAsync(req)).StatusCode);
    }

    [Fact]
    public void Normalize_fills_missing_slots_with_zero()
    {
        var (json, error) = CharacterOptions.Normalize(null, [new AppearanceSlot("face", 2), new AppearanceSlot("skin", 3)]);
        Assert.Null(error);
        Assert.Equal("{\"face\":0,\"skin\":0}", json);
    }
}
