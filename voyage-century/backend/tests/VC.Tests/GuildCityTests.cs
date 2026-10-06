using System.Net;
using System.Net.Http.Json;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Abnahme Phase 7, Iteration 3 (Backend-Seite): Gildenkasse (einzahlen alle, auszahlen nur mit Recht, genau einmal), Stadt aus der
/// Kasse kaufen (nur mit Recht, nur freie Städte), Steueranteil aus dem Handel im Hafen, Steuersatz in Grenzen, Auflösen gibt frei.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class GuildCityTests(PostgresFixture db)
{
    private static readonly Dictionary<string, string?> InAthens = new() { ["World:StartZoneId"] = "CITY_ATHENS" };

    [Fact]
    public async Task Members_deposit_and_only_the_leader_withdraws()
    {
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var leader = await Online(backend, gold: 2000);
        var member = await Online(backend, gold: 600);
        var guild = await FoundWith(backend, leader, member);

        var key = Guid.NewGuid();
        var after = await Read(await Post(backend, member, "guild/treasury/deposit", new TreasuryRequest(member.AccountId, member.ServerId, 500, key)));
        Assert.Equal(500, after.TreasuryGold);
        Assert.Equal(500, (await Read(await Post(backend, member, "guild/treasury/deposit",
            new TreasuryRequest(member.AccountId, member.ServerId, 500, key)))).TreasuryGold); // gleicher Schlüssel: einmal
        Assert.Equal(100L, await Gold(member));
        Assert.Equal(500L, await db.ScalarAsync<long>("SELECT contribution FROM guild_members WHERE character_id = @c", ("c", member.CharacterId)));

        Assert.Equal(HttpStatusCode.Forbidden, (await Post(backend, member, "guild/treasury/withdraw",
            new TreasuryRequest(member.AccountId, member.ServerId, 100, Guid.NewGuid()))).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await Post(backend, leader, "guild/treasury/withdraw",
            new TreasuryRequest(leader.AccountId, leader.ServerId, 501, Guid.NewGuid()))).StatusCode);
        var withdrawn = await Read(await Post(backend, leader, "guild/treasury/withdraw",
            new TreasuryRequest(leader.AccountId, leader.ServerId, 200, Guid.NewGuid())));
        Assert.Equal(300, withdrawn.TreasuryGold);
        Assert.Equal(1200L, await Gold(leader)); // 2000 − 1000 Gründung + 200
        Assert.Equal(["GUILD_DEPOSIT/TRANSFER/500", "GUILD_WITHDRAW/TRANSFER/-200"], await db.ScalarAsync<string[]>(
            "SELECT array_agg(reason || '/' || flow || '/' || delta ORDER BY ledger_id) FROM guild_ledger WHERE guild_id = @g", ("g", guild.GuildId)));
    }

    [Fact]
    public async Task Cities_are_bought_from_the_treasury_and_earn_a_share_of_the_trade_tax()
    {
        await db.ExecAsync("UPDATE territories SET owner_guild_id = NULL, tax_rate = NULL, captured_at = NULL");
        await db.ExecAsync("UPDATE markets SET stock = target_stock, updated_at = now()");
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var leader = await Online(backend, gold: 20000);
        var member = await Online(backend, gold: 0);
        var guild = await FoundWith(backend, leader, member);
        await Read(await Post(backend, leader, "guild/treasury/deposit", new TreasuryRequest(leader.AccountId, leader.ServerId, 16000, Guid.NewGuid())));

        Assert.Equal(HttpStatusCode.Forbidden, (await Post(backend, member, "guild/cities/ATHENS/buy",
            new CityBuyRequest(member.AccountId, member.ServerId, Guid.NewGuid()))).StatusCode); // Mitglied ohne Recht CITY
        var key = Guid.NewGuid();
        var owned = await Read(await Post(backend, leader, "guild/cities/athens/buy", new CityBuyRequest(leader.AccountId, leader.ServerId, key)));
        Assert.Equal(1000L, owned.TreasuryGold);
        Assert.Equal(["ATHENS"], owned.Cities!);
        Assert.Equal(1000, (await Read(await Post(backend, leader, "guild/cities/ATHENS/buy",
            new CityBuyRequest(leader.AccountId, leader.ServerId, key)))).TreasuryGold); // gleicher Schlüssel: einmal
        Assert.Equal(HttpStatusCode.Conflict, (await Post(backend, leader, "guild/cities/LONDON/buy",
            new CityBuyRequest(leader.AccountId, leader.ServerId, Guid.NewGuid()))).StatusCode); // Kasse reicht nicht

        var rival = await Online(backend, gold: 20000);
        await Read(await Found(backend, rival, Unique("Rivalen")));
        await Read(await Post(backend, rival, "guild/treasury/deposit", new TreasuryRequest(rival.AccountId, rival.ServerId, 16000, Guid.NewGuid())));
        Assert.Equal(HttpStatusCode.Conflict, (await Post(backend, rival, "guild/cities/ATHENS/buy",
            new CityBuyRequest(rival.AccountId, rival.ServerId, Guid.NewGuid()))).StatusCode); // schon besetzt
        var cities = (await backend.GameInternal.GetFromJsonAsync<List<CityInfo>>("/internal/v1/cities"))!;
        Assert.Equal(guild.GuildId, cities.Single(c => c.CityCode == "ATHENS").OwnerGuildId);
        Assert.Null(cities.Single(c => c.CityCode == "LONDON").OwnerGuildId);

        // Handel in Athen: ein Teil der Steuer geht an die Gilde.
        var trader = await Trader(backend);
        var trade = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{trader.CharacterId}/trade",
            new TradeRequest(trader.AccountId, trader.ServerId, "DEV_ATHENS_MERCHANT", "DEV_GOOD_OIL", "BUY", 20, Guid.NewGuid()));
        Assert.True(trade.IsSuccessStatusCode, await trade.Content.ReadAsStringAsync());
        var share = await db.ScalarAsync<long>("SELECT coalesce(sum(delta), 0)::bigint FROM guild_ledger WHERE guild_id = @g AND reason = 'CITY_TAX'",
            ("g", guild.GuildId));
        Assert.True(share > 0);
        Assert.Equal(1000 + share, await db.ScalarAsync<long>("SELECT treasury_gold FROM guilds WHERE guild_id = @g", ("g", guild.GuildId)));

        // Steuersatz in Grenzen setzen; er gilt sofort für die Preise im Hafen.
        var before = await OilBuyPrice(backend, trader);
        Assert.Equal(HttpStatusCode.BadRequest, (await Post(backend, leader, "guild/cities/ATHENS/tax",
            new CityTaxRequest(leader.AccountId, leader.ServerId, 151))).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await Post(backend, member, "guild/cities/ATHENS/tax",
            new CityTaxRequest(member.AccountId, member.ServerId, 0))).StatusCode);
        await Read(await Post(backend, leader, "guild/cities/ATHENS/tax", new CityTaxRequest(leader.AccountId, leader.ServerId, 150)));
        Assert.True(await OilBuyPrice(backend, trader) > before);

        var summary = (await backend.GameInternal.GetFromJsonAsync<EconomySummary>("/internal/v1/economy/summary?days=1"))!;
        Assert.Contains(summary.Rows, r => r.Reason == "CITY_BUY" && r.Flow == "SINK");
        Assert.Contains(summary.Rows, r => r.Reason == "CITY_TAX" && r.Flow == "SOURCE");
    }

    [Fact]
    public async Task Disbanding_frees_the_cities_and_pays_the_treasury_to_the_leader()
    {
        await db.ExecAsync("UPDATE territories SET owner_guild_id = NULL, tax_rate = NULL, captured_at = NULL");
        await using var backend = await TestBackend.StartAsync(db, InAthens);
        var leader = await Online(backend, gold: 40000);
        var guild = await Read(await Found(backend, leader, Unique("Kurzlebig")));
        await Read(await Post(backend, leader, "guild/treasury/deposit", new TreasuryRequest(leader.AccountId, leader.ServerId, 30000, Guid.NewGuid())));
        await Read(await Post(backend, leader, "guild/cities/LONDON/buy", new CityBuyRequest(leader.AccountId, leader.ServerId, Guid.NewGuid())));
        await Read(await Post(backend, leader, "guild/cities/LONDON/tax", new CityTaxRequest(leader.AccountId, leader.ServerId, 100)));

        Assert.Equal(HttpStatusCode.NoContent,
            (await Post(backend, leader, "guild/disband", new GuildActionRequest(leader.AccountId, leader.ServerId))).StatusCode);
        Assert.True(await db.ScalarAsync<bool>(
            "SELECT t.owner_guild_id IS NULL AND t.tax_rate IS NULL FROM territories t JOIN cities c USING (city_id) WHERE c.code = 'LONDON'"));
        Assert.Equal(0L, await db.ScalarAsync<long>("SELECT treasury_gold FROM guilds WHERE guild_id = @g", ("g", guild.GuildId)));
        Assert.Equal(19000L, await Gold(leader)); // 40000 − 1000 Gründung − 30000 Einzahlung + 10000 Rest der Kasse
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Who(long AccountId, long CharacterId, string Name, string ServerId);

    private static string Unique(string prefix) => $"{prefix} {Random.Shared.Next(100000, 999999)}";

    private async Task<Who> Online(TestBackend backend, long gold)
    {
        var login = await backend.RegisterAndLoginAsync();
        var created = await backend.CreateCharacterAsync(login.Ticket);
        var server = await backend.EnterZoneAsync(created.CharacterId, login.AccountId, "CITY_ATHENS");
        if (gold > 0)
        {
            var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{created.CharacterId}/gold",
                new AdminGoldRequest(await Admin(backend), gold, Guid.NewGuid(), null, "203.0.113.9", "zone-test"));
            res.EnsureSuccessStatusCode();
        }
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

    /// <summary>Händler in Athen mit Anfängerschiff und Gold.</summary>
    private async Task<Who> Trader(TestBackend backend)
    {
        var p = await Online(backend, gold: 5000);
        var res = await backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/ships",
            new BuyShipRequest(p.AccountId, p.ServerId, "ATHENS_SHIPYARD", "DEV_STARTER_SHIP", Guid.NewGuid()));
        res.EnsureSuccessStatusCode();
        return p;
    }

    private static async Task<long> OilBuyPrice(TestBackend backend, Who p) =>
        (await backend.GameInternal.GetFromJsonAsync<MarketResponse>(
            $"/internal/v1/characters/{p.CharacterId}/market?accountId={p.AccountId}&serverId={p.ServerId}&npcCode=DEV_ATHENS_MERCHANT"))!
        .Goods.Single(g => g.Code == "DEV_GOOD_OIL").BuyPrice!.Value;

    private static Task<HttpResponseMessage> Found(TestBackend backend, Who p, string name) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/guild",
            new GuildFoundRequest(p.AccountId, p.ServerId, name, null, 0, 0, 1, Guid.NewGuid()));

    /// <summary>Gilde mit Leiter und einem einfachen Mitglied.</summary>
    private static async Task<GuildInfo> FoundWith(TestBackend backend, Who leader, Who member)
    {
        var guild = await Read(await Found(backend, leader, Unique("Kasse")));
        await Read(await Post(backend, leader, "guild/invite", new GuildTargetRequest(leader.AccountId, leader.ServerId, member.Name)));
        await Read(await Post(backend, member, $"guild-invites/{guild.GuildId}/accept", new GuildActionRequest(member.AccountId, member.ServerId)));
        return guild;
    }

    private static Task<HttpResponseMessage> Post<T>(TestBackend backend, Who p, string path, T body) =>
        backend.GameInternal.PostAsJsonAsync($"/internal/v1/characters/{p.CharacterId}/{path}", body);

    private static async Task<GuildInfo> Read(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<GuildInfo>())!;
    }

    private Task<long> Gold(Who p) =>
        db.ScalarAsync<long>("SELECT balance FROM character_wallets WHERE character_id = @c AND currency_code = 'GOLD'", ("c", p.CharacterId));
}
