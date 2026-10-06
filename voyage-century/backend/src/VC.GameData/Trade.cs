using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Logging;

namespace VC.GameData;

/// <summary>Ware am Markt: Preise der nächsten Einheit (Kauf/Verkauf), Bestand und eigene Ladung.</summary>
public sealed record MarketGood(string Code, string? NameDe, int Stock, int TargetStock, long? BuyPrice, long SellPrice, int InCargo);
public sealed record MarketResponse(string NpcCode, List<MarketGood> Goods, long? ShipInstanceId, int CargoUsed, int CargoCapacity, long Gold);
/// <summary>Side BUY/SELL. LimitGold: höchster Gesamtpreis (BUY) bzw. niedrigster Erlös (SELL); null = ohne Grenze.</summary>
public sealed record TradeRequest(
    long AccountId, string? ServerId, string? NpcCode, string? ItemCode, string? Side, int Quantity, Guid Key, long? LimitGold = null);
public sealed record TradeResponse(
    bool Duplicate, string Side, string ItemCode, int Quantity, long Total, long Gold, int Stock, int InCargo, int CargoUsed, int CargoCapacity);
public sealed record EconomyRow(DateOnly Day, string Reason, string Flow, long Bookings, long Gold);
public sealed record EconomySummary(int Days, long Sources, long Sinks, long Net, List<EconomyRow> Rows);

/// <summary>
/// Hafenhandel beim Händler der eigenen Zone (Händler und Waren sind Entwicklungsinhalt, SYS-TRADE: Preismodell UNKNOWN).
/// Waren liegen als ein Stapel je Ware im Laderaum des aktiven Schiffs (item_instances SHIP_CARGO), eine Einheit = ein Platz
/// [DESIGN]. Gold fließt über den Ledger: Kauf beim NPC ist eine Senke, Verkauf eine Quelle. Preise rechnet nur das Backend
/// (<see cref="TradePricing"/>); der Zonen-Server nennt Ware, Seite und Menge.
/// </summary>
public static class TradeEndpoints
{
    private const int MaxQuantity = 10_000;

    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapGet("/characters/{characterId:long}/market", View);
        internalApi.MapPost("/characters/{characterId:long}/trade", Trade);
        internalApi.MapGet("/economy/summary", Summary);
    }

    private sealed record Merchant(int PortId);

    private sealed record Ship(long InstanceId, int Capacity, int Used);

    private sealed record Market(int ItemId, string Code, string? NameDe, long BasePrice, int Stock, int TargetStock, int RestockPerHour,
        double TaxRate, DateTime UpdatedAt);

    private static async Task<IResult> View(
        long characterId, long accountId, string? serverId, string? npcCode, NpgsqlDataSource db, IOptions<ContentOptions> content,
        CancellationToken ct)
    {
        if (string.IsNullOrEmpty(serverId) || string.IsNullOrEmpty(npcCode))
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId und npcCode sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, accountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await FindMerchant(conn, tx, characterId, serverId, npcCode, content.Value.AllowDevContent, ct) is not { } merchant)
        {
            return Problem(StatusCodes.Status400BadRequest, "Hier gibt es keinen Händler mit diesem Code");
        }
        if (await LoadTuning(conn, tx, content.Value.AllowDevContent, ct) is not { } tuning)
        {
            return Problem(StatusCodes.Status400BadRequest, "Preismodell unbekannt – Handel nicht verfügbar");
        }
        var ship = await LoadActiveShip(conn, tx, characterId, forUpdate: false, ct);
        var now = await DbNow(conn, tx, ct);
        var ownerTax = (await GuildCityEndpoints.OwnerOfPort(conn, tx, merchant.PortId, ct))?.TaxPermille;
        var goods = new List<MarketGood>();
        foreach (var m in await LoadMarkets(conn, tx, merchant.PortId, null, content.Value.AllowDevContent, forUpdate: false, ct))
        {
            // Nur anzeigen: der Bestand wird erst beim Handel fortgeschrieben.
            var stock = TradePricing.Restock(m.Stock, m.TargetStock, m.RestockPerHour, now - m.UpdatedAt).Stock;
            var tax = CityRules.EffectiveTaxRate(m.TaxRate, ownerTax);
            goods.Add(new MarketGood(m.Code, m.NameDe, stock, m.TargetStock,
                stock > 0 ? TradePricing.BuyUnit(m.BasePrice, stock - 1, m.TargetStock, tax, tuning) : null,
                TradePricing.SellUnit(m.BasePrice, stock + 1, m.TargetStock, tax, tuning),
                ship is null ? 0 : await CargoOf(conn, tx, ship.InstanceId, m.ItemId, ct)));
        }
        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new MarketResponse(npcCode, goods, ship?.InstanceId, ship?.Used ?? 0, ship?.Capacity ?? 0, gold));
    }

    private static async Task<IResult> Trade(
        long characterId, TradeRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || string.IsNullOrEmpty(req.NpcCode) || string.IsNullOrEmpty(req.ItemCode)
            || req.Side is not ("BUY" or "SELL") || req.Quantity is < 1 or > MaxQuantity || req.Key == Guid.Empty || req.LimitGold < 0)
        {
            return Problem(StatusCodes.Status400BadRequest, $"npcCode, itemCode, side (BUY, SELL), quantity (1 … {MaxQuantity}) und key sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }

        // Wiederholung mit demselben Schlüssel: Ergebnis des ersten Handels, nichts doppelt.
        await using (var dup = new NpgsqlCommand(
            """
            SELECT t.side, i.code, t.quantity, t.total_gold, t.port_id, t.item_id, t.ship_instance_id
            FROM trade_transactions t JOIN items i USING (item_id)
            WHERE t.trade_key = @key AND t.character_id = @chr
            """, conn, tx))
        {
            dup.Parameters.AddWithValue("key", req.Key);
            dup.Parameters.AddWithValue("chr", characterId);
            await using var r = await dup.ExecuteReaderAsync(ct);
            if (await r.ReadAsync(ct))
            {
                var (side, code, qty, total, portId, itemId, shipId) =
                    (r.GetString(0), r.GetString(1), r.GetInt32(2), r.GetInt64(3), r.GetInt32(4), r.GetInt32(5), r.GetInt64(6));
                await r.DisposeAsync();
                var stockNow = await StockOf(conn, tx, portId, itemId, ct);
                var cargoShip = await LoadShip(conn, tx, characterId, shipId, forUpdate: false, ct);
                return Results.Ok(new TradeResponse(true, side, code, qty, total, await ShipEndpoints.LoadGold(conn, tx, characterId, ct),
                    stockNow, await CargoOf(conn, tx, shipId, itemId, ct), cargoShip?.Used ?? 0, cargoShip?.Capacity ?? 0));
            }
        }

        if (await FindMerchant(conn, tx, characterId, req.ServerId, req.NpcCode, content.Value.AllowDevContent, ct) is not { } merchant)
        {
            return Problem(StatusCodes.Status400BadRequest, "Hier gibt es keinen Händler mit diesem Code (oder Charakter nicht auf diesem Server)");
        }
        if (await LoadTuning(conn, tx, content.Value.AllowDevContent, ct) is not { } tuning)
        {
            return Problem(StatusCodes.Status400BadRequest, "Preismodell unbekannt – Handel nicht verfügbar");
        }
        if (await LoadActiveShip(conn, tx, characterId, forUpdate: true, ct) is not { } ship)
        {
            return Problem(StatusCodes.Status409Conflict, "Handel braucht ein aktives Schiff mit Laderaum");
        }
        var market = (await LoadMarkets(conn, tx, merchant.PortId, req.ItemCode, content.Value.AllowDevContent, forUpdate: true, ct))
            .FirstOrDefault();
        if (market is null)
        {
            return Problem(StatusCodes.Status400BadRequest, "Diese Ware wird hier nicht gehandelt");
        }

        var now = await DbNow(conn, tx, ct);
        var (stock, used) = TradePricing.Restock(market.Stock, market.TargetStock, market.RestockPerHour, now - market.UpdatedAt);
        // Besitzt eine Gilde die Stadt, gilt ihr Steuersatz, und sie erhält einen Anteil der Steuer (SYS-GUILD: Belohnungen).
        var owner = await GuildCityEndpoints.OwnerOfPort(conn, tx, merchant.PortId, ct);
        var taxRate = CityRules.EffectiveTaxRate(market.TaxRate, owner?.TaxPermille);
        var updatedAt = market.UpdatedAt + used;
        var inCargo = await CargoOf(conn, tx, ship.InstanceId, market.ItemId, ct);
        var buy = req.Side == "BUY";
        TradeQuote? quote;
        if (buy)
        {
            if (ship.Used + req.Quantity > ship.Capacity)
            {
                return Problem(StatusCodes.Status409Conflict, $"Laderaum reicht nicht ({ship.Used} von {ship.Capacity} belegt)");
            }
            quote = TradePricing.QuoteBuy(market.BasePrice, stock, market.TargetStock, taxRate, req.Quantity, tuning);
            if (quote is null)
            {
                return Problem(StatusCodes.Status409Conflict, $"Nur {stock} vorrätig");
            }
            if (req.LimitGold is { } max && quote.Total > max)
            {
                return Problem(StatusCodes.Status409Conflict, $"Preis gestiegen ({quote.Total} statt höchstens {max})");
            }
        }
        else
        {
            if (inCargo < req.Quantity)
            {
                return Problem(StatusCodes.Status409Conflict, $"Nur {inCargo} an Bord");
            }
            quote = TradePricing.QuoteSell(market.BasePrice, stock, market.TargetStock, taxRate, req.Quantity, tuning);
            if (quote is null)
            {
                return Problem(StatusCodes.Status409Conflict, "Der Markt nimmt nicht mehr an");
            }
            if (req.LimitGold is { } min && quote.Total < min)
            {
                return Problem(StatusCodes.Status409Conflict, $"Erlös gefallen ({quote.Total} statt mindestens {min})");
            }
        }

        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        if (buy && gold < quote.Total)
        {
            return Problem(StatusCodes.Status409Conflict, $"Nicht genug Gold ({gold} von {quote.Total})");
        }
        if (quote.Total > 0)
        {
            // Der Händler ist kein Spieler: Kauf nimmt Gold aus dem Spiel, Verkauf bringt neues hinein.
            gold = await ShipEndpoints.Book(conn, tx, characterId, buy ? -quote.Total : quote.Total, buy ? "TRADE_BUY" : "TRADE_SELL",
                buy ? "SINK" : "SOURCE", req.Key, req.ServerId, ct);
        }
        if (owner is { } city && await GuildCityEndpoints.LoadTuning(conn, tx, content.Value.AllowDevContent, ct) is { } cityTuning
            && CityRules.OwnerShare(quote.Tax, cityTuning) is var share and > 0)
        {
            await GuildCityEndpoints.BookGuild(conn, tx, city.GuildId, null, share, "CITY_TAX", "SOURCE", AuctionRules.DeriveKey(req.Key, "city"),
                req.ServerId, ct);
        }
        inCargo = buy ? inCargo + req.Quantity : inCargo - req.Quantity;
        await SetCargo(conn, tx, characterId, ship.InstanceId, market.ItemId, inCargo, ct);
        await using (var upd = new NpgsqlCommand(
            "UPDATE markets SET stock = @stock, updated_at = @at WHERE port_id = @port AND item_id = @item", conn, tx))
        {
            upd.Parameters.AddWithValue("stock", quote.StockAfter);
            upd.Parameters.AddWithValue("at", updatedAt);
            upd.Parameters.AddWithValue("port", merchant.PortId);
            upd.Parameters.AddWithValue("item", market.ItemId);
            await upd.ExecuteNonQueryAsync(ct);
        }
        await using (var log = new NpgsqlCommand(
            """
            INSERT INTO trade_transactions (trade_key, character_id, port_id, item_id, ship_instance_id, side, quantity, total_gold, server_id)
            VALUES (@key, @chr, @port, @item, @ship, @side, @qty, @total, @server)
            """, conn, tx))
        {
            log.Parameters.AddWithValue("key", req.Key);
            log.Parameters.AddWithValue("chr", characterId);
            log.Parameters.AddWithValue("port", merchant.PortId);
            log.Parameters.AddWithValue("item", market.ItemId);
            log.Parameters.AddWithValue("ship", ship.InstanceId);
            log.Parameters.AddWithValue("side", req.Side);
            log.Parameters.AddWithValue("qty", req.Quantity);
            log.Parameters.AddWithValue("total", quote.Total);
            log.Parameters.AddWithValue("server", req.ServerId);
            await log.ExecuteNonQueryAsync(ct);
        }
        await GameEventLog.WriteAsync(conn, tx, new GameEvent(buy ? "TRADE_BUY" : "TRADE_SELL", req.AccountId, characterId,
            NewValue: new { item = req.ItemCode, quantity = req.Quantity, total = quote.Total, npc = req.NpcCode, stock = quote.StockAfter }),
            identity.Value.InstanceId, ct);
        var cargoUsed = ship.Used + (buy ? req.Quantity : -req.Quantity);
        await tx.CommitAsync(ct);
        return Results.Ok(new TradeResponse(false, req.Side, req.ItemCode, req.Quantity, quote.Total, gold, quote.StockAfter, inCargo,
            cargoUsed, ship.Capacity));
    }

    /// <summary>
    /// Wirtschaftsübersicht (Inflationskontrolle, GDD 13): Gold-Quellen und -Senken der letzten Tage aus dem Ledger, je Tag und
    /// Grund. Transfers zwischen Spielern zählen weder als Quelle noch als Senke.
    /// </summary>
    private static async Task<IResult> Summary(int? days, NpgsqlDataSource db, CancellationToken ct)
    {
        var span = days ?? 7;
        if (span is < 1 or > 366)
        {
            return Problem(StatusCodes.Status400BadRequest, "days 1 … 366");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var cmd = new NpgsqlCommand(
            """
            SELECT (created_at AT TIME ZONE 'UTC')::date AS day, reason, flow, count(*), sum(delta)
            FROM (SELECT created_at, reason, flow, delta FROM currency_ledger WHERE currency_code = 'GOLD'
                  UNION ALL
                  SELECT created_at, reason, flow, delta FROM guild_ledger) l   -- Gildenkassen zählen mit (z. B. CITY_BUY, CITY_TAX)
            WHERE created_at >= (date_trunc('day', now() AT TIME ZONE 'UTC') - make_interval(days => @days - 1)) AT TIME ZONE 'UTC'
            GROUP BY 1, 2, 3 ORDER BY 1, 3, 2
            """, conn);
        cmd.Parameters.AddWithValue("days", span);
        var rows = new List<EconomyRow>();
        await using (var r = await cmd.ExecuteReaderAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                rows.Add(new EconomyRow(r.GetFieldValue<DateOnly>(0), r.GetString(1), r.GetString(2), r.GetInt64(3),
                    (long)r.GetDecimal(4)));
            }
        }
        var sources = rows.Where(x => x.Flow == "SOURCE").Sum(x => x.Gold);
        var sinks = -rows.Where(x => x.Flow == "SINK").Sum(x => x.Gold);
        return Results.Ok(new EconomySummary(span, sources, sinks, sources - sinks, rows));
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private static async Task<Merchant?> FindMerchant(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, string serverId, string npcCode, bool allowDev, CancellationToken ct)
    {
        var zone = await WorldEndpoints.PresenceZone(conn, tx, characterId, serverId, ct);
        if (zone is null)
        {
            return null;
        }
        await using var cmd = new NpgsqlCommand(
            """
            SELECT port_id FROM npcs
            WHERE code = @code AND npc_role = 'MERCHANT' AND zone_id = @zone AND port_id IS NOT NULL AND (NOT is_dev OR @dev)
            """, conn, tx);
        cmd.Parameters.AddWithValue("code", npcCode);
        cmd.Parameters.AddWithValue("zone", zone);
        cmd.Parameters.AddWithValue("dev", allowDev);
        return await cmd.ExecuteScalarAsync(ct) is int portId ? new Merchant(portId) : null;
    }

    /// <summary>Alle vier Parameter oder keiner: ohne vollständiges Preismodell kein Handel (nie Ersatzwerte).</summary>
    private static async Task<TradeTuning?> LoadTuning(NpgsqlConnection conn, NpgsqlTransaction tx, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            "SELECT rule_key, int_value FROM game_rules WHERE rule_key LIKE 'TRADE\\_%' AND (NOT is_dev OR @dev)", conn, tx);
        cmd.Parameters.AddWithValue("dev", allowDev);
        var values = new Dictionary<string, double>();
        await using (var r = await cmd.ExecuteReaderAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                values[r.GetString(0)] = r.GetInt64(1) / 1000.0;
            }
        }
        return values.TryGetValue("TRADE_ELASTICITY_PERMILLE", out var e) && values.TryGetValue("TRADE_MIN_FACTOR_PERMILLE", out var lo)
            && values.TryGetValue("TRADE_MAX_FACTOR_PERMILLE", out var hi) && values.TryGetValue("TRADE_SPREAD_PERMILLE", out var s)
            ? new TradeTuning(e, lo, hi, s)
            : null;
    }

    private static async Task<List<Market>> LoadMarkets(
        NpgsqlConnection conn, NpgsqlTransaction tx, int portId, string? itemCode, bool allowDev, bool forUpdate, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            $"""
            SELECT m.item_id, i.code, i.name_de, m.base_price, m.stock, m.target_stock, m.restock_per_hour, m.tax_rate, m.updated_at
            FROM markets m JOIN items i USING (item_id)
            WHERE m.port_id = @port AND m.base_price IS NOT NULL AND (@code::text IS NULL OR i.code = @code)
              AND ((NOT m.is_dev AND NOT i.is_dev) OR @dev)
            ORDER BY i.code
            {(forUpdate ? "FOR UPDATE OF m" : "")}
            """, conn, tx);
        cmd.Parameters.AddWithValue("port", portId);
        cmd.Parameters.AddWithValue("code", (object?)itemCode ?? DBNull.Value);
        cmd.Parameters.AddWithValue("dev", allowDev);
        var list = new List<Market>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            list.Add(new Market(r.GetInt32(0), r.GetString(1), r.IsDBNull(2) ? null : r.GetString(2), r.GetInt64(3), r.GetInt32(4),
                r.GetInt32(5), r.GetInt32(6), (double)r.GetDecimal(7), r.GetDateTime(8)));
        }
        return list;
    }

    private static async Task<Ship?> LoadActiveShip(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, bool forUpdate, CancellationToken ct) =>
        await LoadShip(conn, tx, characterId, null, forUpdate, ct);

    /// <summary>Schiff mit Laderaum (cargo_capacity NULL = UNKNOWN → kein Laderaum). instanceId null = aktives Schiff.</summary>
    private static async Task<Ship?> LoadShip(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, long? instanceId, bool forUpdate, CancellationToken ct)
    {
        long id;
        int capacity;
        await using (var cmd = new NpgsqlCommand(
            $"""
            SELECT i.ship_instance_id, s.cargo_capacity
            FROM ship_instances i JOIN ships s USING (ship_id)
            WHERE i.owner_character_id = @chr AND (@id::bigint IS NULL AND i.is_active OR i.ship_instance_id = @id)
              AND s.cargo_capacity IS NOT NULL
            {(forUpdate ? "FOR UPDATE OF i" : "")}
            """, conn, tx))
        {
            cmd.Parameters.AddWithValue("chr", characterId);
            cmd.Parameters.AddWithValue("id", (object?)instanceId ?? DBNull.Value);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
            {
                return null;
            }
            (id, capacity) = (r.GetInt64(0), r.GetInt32(1));
        }
        await using var used = new NpgsqlCommand(
            "SELECT coalesce(sum(quantity), 0)::int FROM item_instances WHERE location_type = 'SHIP_CARGO' AND container_ref = @ship", conn, tx);
        used.Parameters.AddWithValue("ship", id);
        return new Ship(id, capacity, (int)(await used.ExecuteScalarAsync(ct))!);
    }

    private static async Task<int> CargoOf(NpgsqlConnection conn, NpgsqlTransaction tx, long shipId, int itemId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            "SELECT quantity FROM item_instances WHERE location_type = 'SHIP_CARGO' AND container_ref = @ship AND item_id = @item",
            conn, tx);
        cmd.Parameters.AddWithValue("ship", shipId);
        cmd.Parameters.AddWithValue("item", itemId);
        return await cmd.ExecuteScalarAsync(ct) as int? ?? 0;
    }

    private static async Task SetCargo(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, long shipId, int itemId, int quantity, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(quantity > 0
            ? """
              INSERT INTO item_instances (item_id, quantity, location_type, owner_character_id, container_ref, origin)
              VALUES (@item, @qty, 'SHIP_CARGO', @chr, @ship, 'NPC_SHOP')
              ON CONFLICT (container_ref, item_id) WHERE location_type = 'SHIP_CARGO' DO UPDATE SET quantity = EXCLUDED.quantity
              """
            : "DELETE FROM item_instances WHERE location_type = 'SHIP_CARGO' AND container_ref = @ship AND item_id = @item", conn, tx);
        cmd.Parameters.AddWithValue("item", itemId);
        cmd.Parameters.AddWithValue("qty", quantity);
        cmd.Parameters.AddWithValue("chr", characterId);
        cmd.Parameters.AddWithValue("ship", shipId);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    private static async Task<int> StockOf(NpgsqlConnection conn, NpgsqlTransaction tx, int portId, int itemId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("SELECT stock FROM markets WHERE port_id = @port AND item_id = @item", conn, tx);
        cmd.Parameters.AddWithValue("port", portId);
        cmd.Parameters.AddWithValue("item", itemId);
        return await cmd.ExecuteScalarAsync(ct) as int? ?? 0;
    }

    private static async Task<DateTime> DbNow(NpgsqlConnection conn, NpgsqlTransaction tx, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("SELECT now()", conn, tx);
        return (DateTime)(await cmd.ExecuteScalarAsync(ct))!;
    }

    private static IResult Problem(int status, string title) => Results.Problem(statusCode: status, title: title);
}
