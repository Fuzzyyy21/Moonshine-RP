using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Logging;

namespace VC.GameData;

public sealed record CityInfo(string CityCode, string? NameDe, long? Price, long? OwnerGuildId, string? OwnerName, string? OwnerTag, int? TaxPermille);
public sealed record TreasuryRequest(long AccountId, string? ServerId, long Amount, Guid Key);
public sealed record CityBuyRequest(long AccountId, string? ServerId, Guid Key);
public sealed record CityTaxRequest(long AccountId, string? ServerId, int TaxPermille);

/// <summary>
/// Gildenkasse und Städtebesitz. Belegt (SYS-GUILD): Gildenoffiziere kaufen und besetzen Städte und erhalten Belohnungen und
/// Verwaltungsrechte. [DESIGN]: Kauf aus der Gildenkasse (Senke CITY_BUY), Belohnung = Anteil der Handelssteuer im Hafen der Stadt
/// (Quelle CITY_TAX), Verwaltungsrecht = Steuersatz in Grenzen. Einzahlen dürfen alle Mitglieder (zählt als Beitrag), auszahlen nur
/// wer das Recht TREASURY hat. Jede Bewegung der Kasse steht im guild_ledger.
/// </summary>
public static class GuildCityEndpoints
{
    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapGet("/cities", Cities);
        internalApi.MapPost("/characters/{characterId:long}/guild/treasury/deposit", (long characterId, TreasuryRequest req,
            NpgsqlDataSource db, IOptions<ContentOptions> content, CancellationToken ct) => Treasury(characterId, req, deposit: true, db, content.Value, ct));
        internalApi.MapPost("/characters/{characterId:long}/guild/treasury/withdraw", (long characterId, TreasuryRequest req,
            NpgsqlDataSource db, IOptions<ContentOptions> content, CancellationToken ct) => Treasury(characterId, req, deposit: false, db, content.Value, ct));
        internalApi.MapPost("/characters/{characterId:long}/guild/cities/{cityCode}/buy", Buy);
        internalApi.MapPost("/characters/{characterId:long}/guild/cities/{cityCode}/tax", SetTax);
    }

    // ---- Städte -------------------------------------------------------------------------------

    private static async Task<IResult> Cities(NpgsqlDataSource db, IOptions<ContentOptions> content, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var cmd = new NpgsqlCommand(
            """
            SELECT c.code, c.name_de, t.purchase_price, g.guild_id, g.name, g.tag, round(t.tax_rate * 1000)::int
            FROM territories t JOIN cities c USING (city_id)
            LEFT JOIN guilds g ON g.guild_id = t.owner_guild_id AND g.disbanded_at IS NULL
            WHERE NOT t.is_dev OR @dev
            ORDER BY c.code
            """, conn);
        cmd.Parameters.AddWithValue("dev", content.Value.AllowDevContent);
        var list = new List<CityInfo>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            list.Add(new CityInfo(r.GetString(0), r.IsDBNull(1) ? null : r.GetString(1), r.IsDBNull(2) ? null : r.GetInt64(2),
                r.IsDBNull(3) ? null : r.GetInt64(3), r.IsDBNull(4) ? null : r.GetString(4), r.IsDBNull(5) ? null : r.GetString(5),
                r.IsDBNull(3) || r.IsDBNull(6) ? null : r.GetInt32(6)));
        }
        return Results.Ok(list);
    }

    /// <summary>Freie Stadt aus der Gildenkasse kaufen (Recht CITY; belegt: Gildenoffiziere kaufen Städte).</summary>
    private static async Task<IResult> Buy(
        long characterId, string cityCode, CityBuyRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (req.Key == Guid.Empty)
        {
            return Problem(StatusCodes.Status400BadRequest, "key ist erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await GuildEndpoints.BeginMember(conn, tx, characterId, req.AccountId, req.ServerId, ct) is not { } me)
        {
            return Problem(StatusCodes.Status409Conflict, "Nur Gildenmitglieder auf diesem Server");
        }
        if (await Booked(conn, tx, req.Key, ct))
        {
            var done = await GuildEndpoints.LoadInfo(conn, tx, characterId, content.Value.AllowDevContent, ct);
            await tx.CommitAsync(ct);
            return Results.Ok(done);
        }
        if (!GuildRules.Has(me.Rank, GuildRules.City))
        {
            return Problem(StatusCodes.Status403Forbidden, "Städte kaufen darf nur, wer das Recht dazu hat");
        }
        long territoryId, price;
        await using (var t = new NpgsqlCommand(
            """
            SELECT t.territory_id, t.purchase_price FROM territories t JOIN cities c USING (city_id)
            LEFT JOIN guilds g ON g.guild_id = t.owner_guild_id AND g.disbanded_at IS NULL
            WHERE c.code = @code AND g.guild_id IS NULL AND t.purchase_price IS NOT NULL AND (NOT t.is_dev OR @dev)
            FOR UPDATE OF t
            """, conn, tx))
        {
            t.Parameters.AddWithValue("code", cityCode.ToUpperInvariant());
            t.Parameters.AddWithValue("dev", content.Value.AllowDevContent);
            await using var r = await t.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
            {
                return Problem(StatusCodes.Status409Conflict, "Stadt unbekannt, schon besetzt oder nicht käuflich (Preis UNKNOWN)");
            }
            (territoryId, price) = (r.GetInt64(0), r.GetInt64(1));
        }
        if (await Treasury(conn, tx, me.GuildId, ct) < price)
        {
            return Problem(StatusCodes.Status409Conflict, $"Zu wenig in der Gildenkasse ({price} nötig)");
        }
        await BookGuild(conn, tx, me.GuildId, characterId, -price, "CITY_BUY", "SINK", req.Key, req.ServerId!, ct);
        await Exec(conn, tx, "UPDATE territories SET owner_guild_id = @g, captured_at = now(), tax_rate = NULL WHERE territory_id = @t", ct,
            ("g", me.GuildId), ("t", territoryId));
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("CITY_BUY", req.AccountId, characterId,
            NewValue: new { guild = me.GuildId, city = cityCode.ToUpperInvariant(), price }), identity.Value.InstanceId, ct);
        var info = await GuildEndpoints.LoadInfo(conn, tx, characterId, content.Value.AllowDevContent, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(info);
    }

    /// <summary>Steuersatz einer eigenen Stadt setzen (Recht CITY, Grenzen aus CITY_TAX_*); er ersetzt die Marktsteuer im Hafen.</summary>
    private static async Task<IResult> SetTax(
        long characterId, string cityCode, CityTaxRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await GuildEndpoints.BeginMember(conn, tx, characterId, req.AccountId, req.ServerId, ct) is not { } me)
        {
            return Problem(StatusCodes.Status409Conflict, "Nur Gildenmitglieder auf diesem Server");
        }
        if (!GuildRules.Has(me.Rank, GuildRules.City))
        {
            return Problem(StatusCodes.Status403Forbidden, "Städte verwalten darf nur, wer das Recht dazu hat");
        }
        if (await LoadTuning(conn, tx, content.Value.AllowDevContent, ct) is not { } tuning || !CityRules.IsValidTaxRate(req.TaxPermille, tuning))
        {
            return Problem(StatusCodes.Status400BadRequest, "Steuersatz außerhalb der Grenzen (oder Stadtwerte fehlen)");
        }
        if (await Exec(conn, tx,
                """
                UPDATE territories t SET tax_rate = @rate FROM cities c
                WHERE c.city_id = t.city_id AND c.code = @code AND t.owner_guild_id = @g
                """, ct, ("rate", req.TaxPermille / 1000m), ("code", cityCode.ToUpperInvariant()), ("g", me.GuildId)) != 1)
        {
            return Problem(StatusCodes.Status404NotFound, "Diese Stadt gehört nicht deiner Gilde");
        }
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("CITY_TAX", req.AccountId, characterId,
            NewValue: new { guild = me.GuildId, city = cityCode.ToUpperInvariant(), taxPermille = req.TaxPermille }), identity.Value.InstanceId, ct);
        var info = await GuildEndpoints.LoadInfo(conn, tx, characterId, content.Value.AllowDevContent, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(info);
    }

    // ---- Gildenkasse --------------------------------------------------------------------------

    private static async Task<IResult> Treasury(
        long characterId, TreasuryRequest req, bool deposit, NpgsqlDataSource db, ContentOptions content, CancellationToken ct)
    {
        if (req.Amount is < 1 or > 1_000_000_000 || req.Key == Guid.Empty)
        {
            return Problem(StatusCodes.Status400BadRequest, "amount (1 … 1.000.000.000) und key sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await GuildEndpoints.BeginMember(conn, tx, characterId, req.AccountId, req.ServerId, ct) is not { } me)
        {
            return Problem(StatusCodes.Status409Conflict, "Nur Gildenmitglieder auf diesem Server");
        }
        if (await Booked(conn, tx, req.Key, ct))
        {
            var done = await GuildEndpoints.LoadInfo(conn, tx, characterId, content.AllowDevContent, ct);
            await tx.CommitAsync(ct);
            return Results.Ok(done);
        }
        if (deposit)
        {
            if (await ShipEndpoints.LoadGold(conn, tx, characterId, ct) < req.Amount)
            {
                return Problem(StatusCodes.Status409Conflict, "Nicht genug Gold");
            }
            await ShipEndpoints.Book(conn, tx, characterId, -req.Amount, "GUILD_DEPOSIT", "TRANSFER", AuctionRules.DeriveKey(req.Key, "char"),
                req.ServerId!, ct);
            await BookGuild(conn, tx, me.GuildId, characterId, req.Amount, "GUILD_DEPOSIT", "TRANSFER", req.Key, req.ServerId!, ct);
            await Exec(conn, tx, "UPDATE guild_members SET contribution = contribution + @a WHERE guild_id = @g AND character_id = @chr", ct,
                ("a", req.Amount), ("g", me.GuildId), ("chr", characterId));
        }
        else
        {
            if (!GuildRules.Has(me.Rank, GuildRules.Treasury))
            {
                return Problem(StatusCodes.Status403Forbidden, "Auszahlen darf nur, wer das Recht dazu hat");
            }
            if (await Treasury(conn, tx, me.GuildId, ct) < req.Amount)
            {
                return Problem(StatusCodes.Status409Conflict, "So viel ist nicht in der Gildenkasse");
            }
            await BookGuild(conn, tx, me.GuildId, characterId, -req.Amount, "GUILD_WITHDRAW", "TRANSFER", req.Key, req.ServerId!, ct);
            await ShipEndpoints.Book(conn, tx, characterId, req.Amount, "GUILD_WITHDRAW", "TRANSFER", AuctionRules.DeriveKey(req.Key, "char"),
                req.ServerId!, ct);
        }
        var info = await GuildEndpoints.LoadInfo(conn, tx, characterId, content.AllowDevContent, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(info);
    }

    // ---- Für Handel und Auflösen --------------------------------------------------------------

    /// <summary>Besitzer der Stadt dieses Hafens und sein Steuersatz (Promille, null = Marktsteuer); null, wenn frei.</summary>
    internal static async Task<(long GuildId, int? TaxPermille)?> OwnerOfPort(
        NpgsqlConnection conn, NpgsqlTransaction tx, int portId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT g.guild_id, round(t.tax_rate * 1000)::int
            FROM ports p JOIN territories t USING (city_id) JOIN guilds g ON g.guild_id = t.owner_guild_id AND g.disbanded_at IS NULL
            WHERE p.port_id = @port
            """, conn, tx);
        cmd.Parameters.AddWithValue("port", portId);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct) ? (r.GetInt64(0), r.IsDBNull(1) ? null : r.GetInt32(1)) : null;
    }

    internal static async Task<CityTuning?> LoadTuning(NpgsqlConnection conn, NpgsqlTransaction tx, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            "SELECT rule_key, int_value FROM game_rules WHERE rule_key LIKE 'CITY\\_TAX\\_%' AND (NOT is_dev OR @dev)", conn, tx);
        cmd.Parameters.AddWithValue("dev", allowDev);
        var v = new Dictionary<string, long>();
        await using (var r = await cmd.ExecuteReaderAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                v[r.GetString(0)] = r.GetInt64(1);
            }
        }
        if (!v.TryGetValue("CITY_TAX_SHARE_PERMILLE", out var share) || !v.TryGetValue("CITY_TAX_MIN_PERMILLE", out var min)
            || !v.TryGetValue("CITY_TAX_MAX_PERMILLE", out var max))
        {
            return null;
        }
        var tuning = new CityTuning((int)share, (int)min, (int)max);
        return CityRules.IsValidTuning(tuning) ? tuning : null;
    }

    /// <summary>Kasse ändern und im guild_ledger buchen. Der CHECK treasury_gold &gt;= 0 fängt jede Überziehung ab.</summary>
    internal static async Task<long> BookGuild(
        NpgsqlConnection conn, NpgsqlTransaction tx, long guildId, long? characterId, long delta, string reason, string flow, Guid key,
        string serverId, CancellationToken ct)
    {
        long balance;
        await using (var upd = new NpgsqlCommand(
            "UPDATE guilds SET treasury_gold = treasury_gold + @d WHERE guild_id = @g RETURNING treasury_gold", conn, tx))
        {
            upd.Parameters.AddWithValue("d", delta);
            upd.Parameters.AddWithValue("g", guildId);
            balance = (long)(await upd.ExecuteScalarAsync(ct))!;
        }
        await Exec(conn, tx,
            """
            INSERT INTO guild_ledger (guild_id, character_id, delta, balance_after, reason, flow, idempotency_key, server_id)
            VALUES (@g, @chr, @d, @b, @reason, @flow, @key, @server)
            """, ct, ("g", guildId), ("chr", (object?)characterId ?? DBNull.Value), ("d", delta), ("b", balance), ("reason", reason),
            ("flow", flow), ("key", key), ("server", serverId));
        return balance;
    }

    /// <summary>Beim Auflösen: Städte werden frei, das Restgeld der Kasse geht an den Leiter.</summary>
    internal static async Task Release(NpgsqlConnection conn, NpgsqlTransaction tx, long guildId, long leaderId, string serverId, CancellationToken ct)
    {
        await SiegeEndpoints.CancelForGuild(conn, tx, guildId, ct);
        await Exec(conn, tx, "UPDATE territories SET owner_guild_id = NULL, captured_at = NULL, tax_rate = NULL WHERE owner_guild_id = @g", ct,
            ("g", guildId));
        var rest = await Treasury(conn, tx, guildId, ct);
        if (rest > 0)
        {
            var key = Guid.NewGuid();
            await BookGuild(conn, tx, guildId, leaderId, -rest, "GUILD_DISBAND", "TRANSFER", key, serverId, ct);
            await ShipEndpoints.Book(conn, tx, leaderId, rest, "GUILD_DISBAND", "TRANSFER", AuctionRules.DeriveKey(key, "char"), serverId, ct);
        }
    }

    internal static async Task<long> Treasury(NpgsqlConnection conn, NpgsqlTransaction tx, long guildId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("SELECT treasury_gold FROM guilds WHERE guild_id = @g", conn, tx);
        cmd.Parameters.AddWithValue("g", guildId);
        return (long)(await cmd.ExecuteScalarAsync(ct))!;
    }

    private static async Task<bool> Booked(NpgsqlConnection conn, NpgsqlTransaction tx, Guid key, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("SELECT 1 FROM guild_ledger WHERE idempotency_key = @key", conn, tx);
        cmd.Parameters.AddWithValue("key", key);
        return await cmd.ExecuteScalarAsync(ct) is not null;
    }

    private static async Task<int> Exec(
        NpgsqlConnection conn, NpgsqlTransaction tx, string sql, CancellationToken ct, params (string Name, object Value)[] parameters)
    {
        await using var cmd = new NpgsqlCommand(sql, conn, tx);
        foreach (var (name, value) in parameters)
        {
            cmd.Parameters.AddWithValue(name, value);
        }
        return await cmd.ExecuteNonQueryAsync(ct);
    }

    private static IResult Problem(int status, string title) => Results.Problem(statusCode: status, title: title);
}
