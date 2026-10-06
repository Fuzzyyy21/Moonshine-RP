using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 7, Iteration 1 (Backend-Seite): Chat über Server hinweg (WORLD, WHISPER), LOCAL bleibt in der Zone, Ignorieren,
/// Rate-Limit, Stummschalten und Ankündigungen durch Admins mit Audit, Freunde mit Online-Status, Melden mit Kontext.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class SocialTests(PostgresFixture db)
{
    [Fact]
    public async Task Whispers_reach_only_the_server_of_the_recipient_and_respect_ignores()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var a = await Online(backend);
        var b = await Online(backend);
        var start = await Baseline(backend, a);

        var sent = await ReadSent(await Say(backend, a, "WHISPER", "Hallo  B", b.Name.ToUpperInvariant()));
        Assert.Equal(("Hallo B", b.CharacterId, a.Name), (sent.Message, sent.TargetCharacterId, sent.SenderName));
        Assert.Contains((await Poll(backend, b.ServerId, start)).Messages, m => m.MessageId == sent.MessageId);
        Assert.DoesNotContain((await Poll(backend, a.ServerId, start)).Messages, m => m.MessageId == sent.MessageId);

        await Add(backend, b, "ignores", a.Name);
        Assert.Equal(HttpStatusCode.Conflict, (await Say(backend, a, "WHISPER", "Hörst du mich?", b.Name)).StatusCode);
        Assert.Equal([a.CharacterId], (await State(backend, b)).Ignores);

        await db.ExecAsync("DELETE FROM character_presence WHERE character_id = @c", ("c", b.CharacterId));
        await (await backend.GameInternal.DeleteAsync($"/internal/v1/characters/{b.CharacterId}/ignores/{a.CharacterId}?accountId={b.AccountId}"))
            .Content.ReadAsStringAsync();
        Assert.Equal(HttpStatusCode.Conflict, (await Say(backend, a, "WHISPER", "Noch da?", b.Name)).StatusCode); // offline
        Assert.Equal(HttpStatusCode.NotFound, (await Say(backend, a, "WHISPER", "Hallo", "Niemand")).StatusCode);
    }

    [Fact]
    public async Task World_chat_reaches_every_server_local_stays_and_rate_is_limited()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var a = await Online(backend);
        var b = await Online(backend);
        var start = await Baseline(backend, a);

        var world = await ReadSent(await Say(backend, a, "WORLD", "Kauft Wolle!"));
        var local = await ReadSent(await Say(backend, a, "LOCAL", "Hier bin ich"));
        foreach (var server in new[] { a.ServerId, b.ServerId })
        {
            var poll = await Poll(backend, server, start);
            Assert.Contains(poll.Messages, m => m.MessageId == world.MessageId && m.SenderName == a.Name);
            Assert.DoesNotContain(poll.Messages, m => m.MessageId == local.MessageId); // LOCAL stellt der Server selbst zu
            Assert.True(poll.LastId >= local.MessageId);
        }

        Assert.Equal(HttpStatusCode.OK, (await Say(backend, a, "WORLD", "zweite")).StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, (await Say(backend, a, "WORLD", "dritte")).StatusCode); // 2 je 10 s
        Assert.Equal(HttpStatusCode.OK, (await Say(backend, a, "LOCAL", "lokal geht noch")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Say(backend, a, "SYSTEM", "Ich bin der Admin")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Say(backend, a, "LOCAL", " \u0007 ")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Say(backend, a, "LOCAL", new string('x', 201))).StatusCode);
    }

    [Fact]
    public async Task Admins_mute_and_announce_with_audit()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var a = await Online(backend);
        var admin = await Admin(backend);
        var start = await Baseline(backend, a);

        var notAdmin = await backend.GameInternal.PostAsJsonAsync("/internal/v1/admin/mutes",
            new AdminMuteRequest(a.AccountId, a.Name, 10, null, "Spam", null, "203.0.113.9", "zone-test"));
        Assert.Equal(HttpStatusCode.Forbidden, notAdmin.StatusCode);
        var mute = await backend.GameInternal.PostAsJsonAsync("/internal/v1/admin/mutes",
            new AdminMuteRequest(admin, a.Name, 10, "WORLD", "Spam", null, "203.0.113.9", "zone-test"));
        Assert.Equal(HttpStatusCode.OK, mute.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await Say(backend, a, "WORLD", "Ich darf nicht")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await Say(backend, a, "LOCAL", "Hier schon")).StatusCode); // nur WORLD stumm

        var announce = await backend.GameInternal.PostAsJsonAsync("/internal/v1/admin/announce",
            new AdminAnnounceRequest(admin, "Wartung in 10 Minuten", null, "203.0.113.9", "zone-test"));
        Assert.Equal(HttpStatusCode.OK, announce.StatusCode);
        var system = (await Poll(backend, a.ServerId, start)).Messages.Single(m => m.Channel == "SYSTEM" && m.Message == "Wartung in 10 Minuten");
        Assert.Null(system.SenderCharacterId);
        Assert.Equal(2L, await db.ScalarAsync<long>(
            "SELECT count(*) FROM admin_audit_log WHERE admin_account_id = @a AND command IN ('/mute', '/announce')", ("a", admin)));
    }

    [Fact]
    public async Task Friends_show_online_status_and_reports_keep_context()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var a = await Online(backend);
        var b = await Online(backend);

        var friends = await Add(backend, a, "friends", b.Name.ToLowerInvariant());
        var entry = Assert.Single(friends);
        Assert.Equal((b.CharacterId, b.Name, true, "DEV_TESTZONE"), (entry.CharacterId, entry.Name, entry.Online, entry.ZoneId));
        Assert.Single(await Add(backend, a, "friends", b.Name)); // doppelt hinzufügen ändert nichts
        Assert.Equal(HttpStatusCode.NotFound, (await AddRaw(backend, a, "friends", a.Name)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await AddRaw(backend, a, "friends", "Niemand")).StatusCode);

        await db.ExecAsync("DELETE FROM character_presence WHERE character_id = @c", ("c", b.CharacterId));
        var offline = (await backend.GameInternal.GetFromJsonAsync<List<SocialEntry>>(
            $"/internal/v1/characters/{a.CharacterId}/friends?accountId={a.AccountId}"))!;
        Assert.Equal((false, (string?)null), (offline[0].Online, offline[0].ZoneId));
        var removed = await backend.GameInternal.DeleteAsync($"/internal/v1/characters/{a.CharacterId}/friends/{b.CharacterId}?accountId={a.AccountId}");
        Assert.Empty((await removed.Content.ReadFromJsonAsync<List<SocialEntry>>())!);

        await Say(backend, a, "LOCAL", "Beleidigung");
        var report = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{b.CharacterId}/reports",
            new ReportRequest(b.AccountId, b.ServerId, a.Name, "Beleidigt andere"));
        Assert.Equal(HttpStatusCode.OK, report.StatusCode);
        Assert.Equal("Beleidigung", await db.ScalarAsync<string>(
            "SELECT context->'recentMessages'->0->>'message' FROM player_reports WHERE reported_character_id = @c", ("c", a.CharacterId)));
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Who(long AccountId, long CharacterId, string Name, string ServerId);

    private static async Task<Who> Online(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        var created = await backend.CreateCharacterAsync(login.Ticket);
        var server = await backend.EnterZoneAsync(created.CharacterId, login.AccountId);
        var state = (await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{created.CharacterId}/state?accountId={login.AccountId}"))!;
        return new Who(login.AccountId, created.CharacterId, state.Name, server);
    }

    private async Task<long> Admin(TestBackend backend)
    {
        var login = await backend.RegisterAndLoginAsync();
        await db.ExecAsync("UPDATE accounts SET admin_level = 1 WHERE account_id = @a", ("a", login.AccountId));
        return login.AccountId;
    }

    private static Task<HttpResponseMessage> Say(TestBackend backend, Who p, string channel, string message, string? target = null) =>
        backend.GameInternal.PostAsJsonAsync("/internal/v1/chat", new ChatSendRequest(p.CharacterId, p.AccountId, p.ServerId, channel, message, target));

    private static async Task<ChatSent> ReadSent(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<ChatSent>())!;
    }

    private static async Task<long> Baseline(TestBackend backend, Who p) =>
        (await backend.GameInternal.GetFromJsonAsync<ChatPoll>($"/internal/v1/chat?serverId={p.ServerId}&after=-1"))!.LastId;

    private static async Task<ChatPoll> Poll(TestBackend backend, string server, long after) =>
        (await backend.GameInternal.GetFromJsonAsync<ChatPoll>($"/internal/v1/chat?serverId={server}&after={after}"))!;

    private static Task<HttpResponseMessage> AddRaw(TestBackend backend, Who p, string list, string name) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/{list}", new NameRequest(p.AccountId, name));

    private static async Task<List<SocialEntry>> Add(TestBackend backend, Who p, string list, string name)
    {
        var res = await AddRaw(backend, p, list, name);
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<List<SocialEntry>>())!;
    }

    private static async Task<CharacterState> State(TestBackend backend, Who p) =>
        (await backend.GameInternal.GetFromJsonAsync<CharacterState>(
            $"/internal/v1/characters/{p.CharacterId}/state?accountId={p.AccountId}"))!;
}
