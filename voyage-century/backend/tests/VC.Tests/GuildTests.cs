using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 7, Iteration 2 (Backend-Seite): Gilde gründen (Gold-Senke, genau einmal), einladen und annehmen, Rechte der Ränge,
/// Leitung übergeben, austreten und auflösen, Gildenchat nur für Mitglieder.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class GuildTests(PostgresFixture db)
{
    [Fact]
    public async Task Founding_costs_gold_once_and_names_are_unique()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var a = await Online(backend, gold: 2500);
        var name = Unique("Seefahrer");
        var tag = $"S{Random.Shared.Next(100, 999)}";
        var key = Guid.NewGuid();

        var guild = await Read(await Found(backend, a, name, tag, key));
        Assert.Equal((name, tag, (short)0, "Gildenleiter"), (guild.Name, guild.Tag, guild.MyRank, guild.MyRankName));
        Assert.Equal(["CITY", "INVITE", "KICK", "PROMOTE", "TREASURY"], guild.MyPermissions);
        Assert.Equal(50, guild.MaxMembers);
        Assert.Single(guild.Members);
        var again = await Read(await Found(backend, a, name, tag, key));
        Assert.Equal(guild.GuildId, again.GuildId);
        Assert.Equal(["ADMIN_GRANT/SOURCE/2500", "GUILD_FOUND/SINK/-1000"], await Ledger(a));

        Assert.Equal(HttpStatusCode.Conflict, (await Found(backend, a, Unique("Zweite"), null)).StatusCode);   // schon in einer Gilde
        var b = await Online(backend, gold: 2500);
        Assert.Equal(HttpStatusCode.Conflict, (await Found(backend, b, name.ToUpperInvariant(), null)).StatusCode); // Name vergeben
        Assert.Equal(HttpStatusCode.Conflict, (await Found(backend, b, Unique("Andere"), tag)).StatusCode);       // Kürzel vergeben
        Assert.Equal(HttpStatusCode.BadRequest, (await Found(backend, b, "x!", null)).StatusCode);
        var poor = await Online(backend, gold: 10);
        Assert.Equal(HttpStatusCode.Conflict, (await Found(backend, poor, Unique("Arme"), null)).StatusCode);
    }

    [Fact]
    public async Task Members_join_by_invitation_and_ranks_limit_what_they_may_do()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var leader = await Online(backend, gold: 2000);
        var b = await Online(backend, gold: 0);
        var c = await Online(backend, gold: 0);
        var name = Unique("Gilde");
        var guild = await Read(await Found(backend, leader, name, null));

        await Read(await Act(backend, leader, "guild/invite", new GuildTargetRequest(leader.AccountId, leader.ServerId, b.Name)));
        var invites = (await backend.GameInternal.GetFromJsonAsync<List<GuildInviteInfo>>(
            $"/internal/v1/characters/{b.CharacterId}/guild-invites?accountId={b.AccountId}"))!;
        Assert.Equal((guild.GuildId, name, leader.Name), (invites.Single().GuildId, invites.Single().GuildName, invites.Single().InvitedBy));
        var joined = await Read(await Act(backend, b, $"guild-invites/{guild.GuildId}/accept", new GuildActionRequest(b.AccountId, b.ServerId)));
        Assert.Equal(((short)2, "Mitglied"), (joined.MyRank, joined.MyRankName));
        Assert.Equal(HttpStatusCode.Forbidden,
            (await Act(backend, b, "guild/invite", new GuildTargetRequest(b.AccountId, b.ServerId, c.Name))).StatusCode); // Mitglied darf nicht

        await Read(await Act(backend, leader, "guild/rank", new GuildTargetRequest(leader.AccountId, leader.ServerId, b.Name, 1)));
        await Read(await Act(backend, b, "guild/invite", new GuildTargetRequest(b.AccountId, b.ServerId, c.Name))); // Offizier darf
        Assert.Equal(HttpStatusCode.NoContent,
            (await Act(backend, c, $"guild-invites/{guild.GuildId}/decline", new GuildActionRequest(c.AccountId, c.ServerId))).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await Act(backend, c, $"guild-invites/{guild.GuildId}/accept", new GuildActionRequest(c.AccountId, c.ServerId))).StatusCode);
        await Read(await Act(backend, b, "guild/invite", new GuildTargetRequest(b.AccountId, b.ServerId, c.Name)));
        await Read(await Act(backend, c, $"guild-invites/{guild.GuildId}/accept", new GuildActionRequest(c.AccountId, c.ServerId)));

        Assert.Equal(HttpStatusCode.Forbidden,
            (await Act(backend, b, "guild/kick", new GuildTargetRequest(b.AccountId, b.ServerId, leader.Name))).StatusCode); // nach oben nie
        Assert.Equal(HttpStatusCode.Forbidden,
            (await Act(backend, b, "guild/rank", new GuildTargetRequest(b.AccountId, b.ServerId, c.Name, 0))).StatusCode); // Leitung nur vom Leiter
        var kicked = await Read(await Act(backend, b, "guild/kick", new GuildTargetRequest(b.AccountId, b.ServerId, c.Name)));
        Assert.DoesNotContain(kicked.Members, m => m.CharacterId == c.CharacterId);
        Assert.Equal(HttpStatusCode.NotFound, (await backend.GameInternal.GetAsync(
            $"/internal/v1/characters/{c.CharacterId}/guild?accountId={c.AccountId}")).StatusCode);
    }

    [Fact]
    public async Task Leadership_is_handed_over_before_leaving_and_the_last_member_disbands()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var leader = await Online(backend, gold: 2000);
        var b = await Online(backend, gold: 0);
        var name = Unique("Erben");
        var guild = await Read(await Found(backend, leader, name, null));
        await Read(await Act(backend, leader, "guild/invite", new GuildTargetRequest(leader.AccountId, leader.ServerId, b.Name)));
        await Read(await Act(backend, b, $"guild-invites/{guild.GuildId}/accept", new GuildActionRequest(b.AccountId, b.ServerId)));

        Assert.Equal(HttpStatusCode.Conflict,
            (await Act(backend, leader, "guild/leave", new GuildActionRequest(leader.AccountId, leader.ServerId))).StatusCode);
        var handed = await Read(await Act(backend, leader, "guild/rank", new GuildTargetRequest(leader.AccountId, leader.ServerId, b.Name, 0)));
        Assert.Equal((short)1, handed.MyRank);
        Assert.Equal(b.CharacterId, await db.ScalarAsync<long>("SELECT leader_character_id FROM guilds WHERE guild_id = @g", ("g", guild.GuildId)));
        Assert.Equal(HttpStatusCode.NoContent,
            (await Act(backend, leader, "guild/leave", new GuildActionRequest(leader.AccountId, leader.ServerId))).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent,
            (await Act(backend, b, "guild/leave", new GuildActionRequest(b.AccountId, b.ServerId))).StatusCode); // allein: aufgelöst

        Assert.True(await db.ScalarAsync<bool>("SELECT disbanded_at IS NOT NULL FROM guilds WHERE guild_id = @g", ("g", guild.GuildId)));
        var successor = await Online(backend, gold: 2000);
        Assert.Equal(HttpStatusCode.OK, (await Found(backend, successor, name, null)).StatusCode); // Name wieder frei
    }

    [Fact]
    public async Task Guild_chat_reaches_only_members()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var a = await Online(backend, gold: 2000);
        var b = await Online(backend, gold: 0);
        var outsider = await Online(backend, gold: 0);
        var guild = await Read(await Found(backend, a, Unique("Funker"), null));
        await Read(await Act(backend, a, "guild/invite", new GuildTargetRequest(a.AccountId, a.ServerId, b.Name)));
        await Read(await Act(backend, b, $"guild-invites/{guild.GuildId}/accept", new GuildActionRequest(b.AccountId, b.ServerId)));
        var start = (await backend.GameInternal.GetFromJsonAsync<ChatPoll>($"/internal/v1/chat?serverId={a.ServerId}&after=-1"))!.LastId;

        var sent = await backend.GameInternal.PostAsJsonAsync("/internal/v1/chat",
            new ChatSendRequest(a.CharacterId, a.AccountId, a.ServerId, "GUILD", "Treffen um acht"));
        var id = (await sent.Content.ReadFromJsonAsync<ChatSent>())!.MessageId;
        var atB = (await backend.GameInternal.GetFromJsonAsync<ChatPoll>($"/internal/v1/chat?serverId={b.ServerId}&after={start}"))!;
        Assert.Equal([b.CharacterId], atB.Messages.Single(m => m.MessageId == id).Recipients!);
        var atOutsider = (await backend.GameInternal.GetFromJsonAsync<ChatPoll>($"/internal/v1/chat?serverId={outsider.ServerId}&after={start}"))!;
        Assert.DoesNotContain(atOutsider.Messages, m => m.MessageId == id);

        var notMember = await backend.GameInternal.PostAsJsonAsync("/internal/v1/chat",
            new ChatSendRequest(outsider.CharacterId, outsider.AccountId, outsider.ServerId, "GUILD", "Hallo?"));
        Assert.Equal(HttpStatusCode.Conflict, notMember.StatusCode);
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Who(long AccountId, long CharacterId, string Name, string ServerId);

    private static string Unique(string prefix) => $"{prefix} {Random.Shared.Next(100000, 999999)}";

    private async Task<Who> Online(TestBackend backend, long gold)
    {
        var login = await backend.RegisterAndLoginAsync();
        var created = await backend.CreateCharacterAsync(login.Ticket);
        var server = await backend.EnterZoneAsync(created.CharacterId, login.AccountId);
        if (gold > 0)
        {
            var admin = await backend.RegisterAndLoginAsync();
            await db.ExecAsync("UPDATE accounts SET admin_level = 1 WHERE account_id = @a", ("a", admin.AccountId));
            var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{created.CharacterId}/gold",
                new AdminGoldRequest(admin.AccountId, gold, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
            res.EnsureSuccessStatusCode();
        }
        var state = (await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{created.CharacterId}/state?accountId={login.AccountId}"))!;
        return new Who(login.AccountId, created.CharacterId, state.Name, server);
    }

    private static Task<HttpResponseMessage> Found(TestBackend backend, Who p, string name, string? tag, Guid? key = null) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/guild",
            new GuildFoundRequest(p.AccountId, p.ServerId, name, tag, 3, 1, 7, key ?? Guid.NewGuid()));

    private static Task<HttpResponseMessage> Act<T>(TestBackend backend, Who p, string path, T body) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/{path}", body);

    private static async Task<GuildInfo> Read(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<GuildInfo>())!;
    }

    private Task<string[]> Ledger(Who p) =>
        db.ScalarAsync<string[]>(
            "SELECT array_agg(reason || '/' || flow || '/' || delta ORDER BY ledger_id) FROM currency_ledger WHERE character_id = @c",
            ("c", p.CharacterId));
}
