using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 3, Iteration 2 (Backend-Seite): Die Hotbar überdauert Ausloggen und Neustart, nur bekannte und
/// freigegebene Fähigkeiten dürfen darauf, und nur der Besitzer-Account kann sie ändern.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class HotbarTests(PostgresFixture db)
{
    [Fact]
    public async Task Hotbar_is_saved_replaced_and_loaded_with_state()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await NewCharacter(backend);
        Assert.Empty((await LoadState(backend, p)).Hotbar!);

        var res = await Save(backend, p, new HotbarSlot(3, "DEV_FIRST_AID"), new HotbarSlot(0, "DEV_POWER_STRIKE"));
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        Assert.Equal([new HotbarSlot(0, "DEV_POWER_STRIKE"), new HotbarSlot(3, "DEV_FIRST_AID")],
            (await LoadState(backend, p)).Hotbar!);

        // Ersetzen statt anhängen: dieselbe Fähigkeit darf auf einen anderen Platz wandern.
        Assert.Equal(HttpStatusCode.OK, (await Save(backend, p, new HotbarSlot(9, "DEV_POWER_STRIKE"))).StatusCode);
        Assert.Equal([new HotbarSlot(9, "DEV_POWER_STRIKE")], (await LoadState(backend, p)).Hotbar!);

        Assert.Equal(HttpStatusCode.OK, (await Save(backend, p)).StatusCode);
        Assert.Empty((await LoadState(backend, p)).Hotbar!);
    }

    [Theory]
    [InlineData(-1, "DEV_POWER_STRIKE")]
    [InlineData(10, "DEV_POWER_STRIKE")]
    [InlineData(0, "")]
    [InlineData(0, "NO_SUCH_ABILITY")]
    public async Task Invalid_slots_are_rejected(int slot, string code)
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await NewCharacter(backend);
        Assert.Equal(HttpStatusCode.BadRequest, (await Save(backend, p, new HotbarSlot(slot, code))).StatusCode);
    }

    [Fact]
    public async Task Duplicates_are_rejected_and_nothing_changes()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await NewCharacter(backend);
        await Save(backend, p, new HotbarSlot(1, "DEV_SUNDER"));

        var sameSlot = await Save(backend, p, new HotbarSlot(0, "DEV_POWER_STRIKE"), new HotbarSlot(0, "DEV_SUNDER"));
        Assert.Equal(HttpStatusCode.BadRequest, sameSlot.StatusCode);
        var sameAbility = await Save(backend, p, new HotbarSlot(0, "DEV_SUNDER"), new HotbarSlot(1, "DEV_SUNDER"));
        Assert.Equal(HttpStatusCode.BadRequest, sameAbility.StatusCode);
        var partlyUnknown = await Save(backend, p, new HotbarSlot(0, "DEV_POWER_STRIKE"), new HotbarSlot(2, "NOPE"));
        Assert.Equal(HttpStatusCode.BadRequest, partlyUnknown.StatusCode);

        Assert.Equal([new HotbarSlot(1, "DEV_SUNDER")], (await LoadState(backend, p)).Hotbar!);
    }

    [Fact]
    public async Task Only_the_owning_account_can_change_the_hotbar()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var owner = await NewCharacter(backend);
        var other = await NewCharacter(backend);
        var res = await backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{owner.CharacterId}/hotbar",
            new SaveHotbarRequest(other.AccountId, [new HotbarSlot(0, "DEV_POWER_STRIKE")]));
        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
        Assert.Equal(0L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM character_hotbar WHERE character_id = @c", ("c", owner.CharacterId)));
    }

    [Fact]
    public async Task Development_abilities_are_locked_without_dev_content()
    {
        Player p;
        await using (var dev = await TestBackend.StartAsync(db))
        {
            p = await NewCharacter(dev);
            Assert.Equal(HttpStatusCode.OK, (await Save(dev, p, new HotbarSlot(0, "DEV_POWER_STRIKE"))).StatusCode);
        }
        await using var prod = await TestBackend.StartAsync(db, new Dictionary<string, string?> { ["Content:AllowDevContent"] = "false" });
        Assert.Equal(HttpStatusCode.BadRequest, (await Save(prod, p, new HotbarSlot(1, "DEV_SUNDER"))).StatusCode);
        // Bereits gespeicherte Entwicklungsfähigkeiten werden in Produktion nicht ausgeliefert.
        Assert.Empty((await LoadState(prod, p)).Hotbar!);
    }

    [Fact]
    public async Task Hotbar_requires_service_key()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var p = await NewCharacter(backend);
        var res = await backend.Game.PutAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/hotbar",
            new SaveHotbarRequest(p.AccountId, []));
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Player(long AccountId, long CharacterId);

    private static async Task<Player> NewCharacter(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        return new Player(login.AccountId, (await backend.CreateCharacterAsync(login.Ticket)).CharacterId);
    }

    private static Task<HttpResponseMessage> Save(TestBackend backend, Player p, params HotbarSlot[] slots) =>
        backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/hotbar", new SaveHotbarRequest(p.AccountId, slots));

    private static async Task<CharacterState> LoadState(TestBackend backend, Player p) =>
        (await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{p.CharacterId}/state?accountId={p.AccountId}"))!;
}
