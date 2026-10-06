using System.Text.Json;
using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Logging;

namespace VC.GameData;

/// <summary>Status OPEN, SOLD, CANCELLED, EXPIRED (offen, aber abgelaufen, wird beim Abholen zurückgegeben).</summary>
public sealed record AuctionListing(
    long ListingId, string ItemCode, string? NameDe, int Quantity, long Price, string Seller, DateTime ExpiresAt, bool Mine, string Status);
public sealed record AuctionListRequest(long AccountId, string? ServerId, string? NpcCode, long InstanceId, int Quantity, long Price, Guid Key);
public sealed record AuctionListResponse(bool Duplicate, long ListingId, long Fee, long Gold, DateTime ExpiresAt, InventoryResponse Inventory);
public sealed record AuctionActionRequest(long AccountId, string? ServerId, string? NpcCode, Guid Key);
/// <summary>Kauf oder Rückgabe: was ins Inventar kam; Price/Gold beim Kauf.</summary>
public sealed record AuctionItemResponse(
    bool Duplicate, long ListingId, string ItemCode, string? NameDe, int Quantity, long Price, long Gold, InventoryResponse Inventory);
public sealed record AuctionCollectResponse(int Returned, int Pending, InventoryResponse Inventory);

/// <summary>
/// Auktionshaus für alle Häfen [DESIGN] beim Auktionator der eigenen Zone. Einstellen kostet eine Gebühr (Senke AUCTION_FEE); das
/// Item liegt bis zum Verkauf als MARKET im Register. Beim Kauf zahlt der Käufer den Preis: der Verkäufer erhält ihn abzüglich Steuer
/// (TRANSFER AUCTION_BUY/AUCTION_SALE), die Steuer verlässt das Spiel (SINK AUCTION_TAX). Abgelaufenes holt der Verkäufer zurück.
/// </summary>
public static class AuctionEndpoints
{
    private const int PageSize = 100;

    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapGet("/auction", Search);
        internalApi.MapGet("/characters/{characterId:long}/auction", Mine);
        internalApi.MapPost("/characters/{characterId:long}/auction/list", List);
        internalApi.MapPost("/characters/{characterId:long}/auction/{listingId:long}/buy", Buy);
        internalApi.MapPost("/characters/{characterId:long}/auction/{listingId:long}/cancel", Cancel);
        internalApi.MapPost("/characters/{characterId:long}/auction/collect", Collect);
    }

    // ---- Ansehen ------------------------------------------------------------------------------

    /// <summary>Offene, nicht abgelaufene Angebote, billigste zuerst; optional nur eine Ware.</summary>
    private static async Task<IResult> Search(
        long characterId, long accountId, string? itemCode, NpgsqlDataSource db, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, accountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        var list = await Query(conn, tx, characterId,
            "l.status = 'OPEN' AND l.closed_at IS NULL AND l.expires_at > now() AND (@code::text IS NULL OR i.code = @code)",
            "l.price, l.listing_id", ("code", (object?)itemCode?.ToUpperInvariant() ?? DBNull.Value), ct);
        await tx.CommitAsync(ct);
        return Results.Ok(list);
    }

    /// <summary>Eigene Angebote der letzten Zeit mit Status (abgelaufene als EXPIRED).</summary>
    private static async Task<IResult> Mine(long characterId, long accountId, NpgsqlDataSource db, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, accountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        var list = await Query(conn, tx, characterId, "l.seller_character_id = @chr", "l.listing_id DESC", null, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(list);
    }

    // ---- Einstellen ---------------------------------------------------------------------------

    private static async Task<IResult> List(
        long characterId, AuctionListRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || string.IsNullOrEmpty(req.NpcCode) || req.Key == Guid.Empty || req.Quantity < 1
            || !AuctionRules.IsValidPrice(req.Price))
        {
            return Problem(StatusCodes.Status400BadRequest, $"npcCode, key, quantity ≥ 1 und price (1 … {AuctionRules.MaxPrice}) sind erforderlich");
        }
        var allowDev = content.Value.AllowDevContent;
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        await using (var dup = new NpgsqlCommand(
            "SELECT listing_id, listing_fee, expires_at FROM market_listings WHERE listing_key = @key AND seller_character_id = @chr", conn, tx))
        {
            dup.Parameters.AddWithValue("key", req.Key);
            dup.Parameters.AddWithValue("chr", characterId);
            await using var r = await dup.ExecuteReaderAsync(ct);
            if (await r.ReadAsync(ct))
            {
                var (id, paid, expires) = (r.GetInt64(0), r.GetInt64(1), r.GetDateTime(2));
                await r.DisposeAsync();
                return Results.Ok(new AuctionListResponse(true, id, paid, await ShipEndpoints.LoadGold(conn, tx, characterId, ct), expires,
                    await InventoryEndpoints.Load(conn, tx, characterId, allowDev, ct)));
            }
        }
        if (await Prepare(conn, tx, characterId, req.ServerId, req.NpcCode, allowDev, ct) is not { } tuning)
        {
            return Problem(StatusCodes.Status400BadRequest, "Hier gibt es keinen Auktionator (oder das Auktionshaus ist nicht verfügbar)");
        }
        await using (var count = new NpgsqlCommand(
            "SELECT count(*) FROM market_listings WHERE seller_character_id = @chr AND status = 'OPEN' AND closed_at IS NULL", conn, tx))
        {
            count.Parameters.AddWithValue("chr", characterId);
            if ((long)(await count.ExecuteScalarAsync(ct))! >= tuning.MaxListings)
            {
                return Problem(StatusCodes.Status409Conflict, $"Höchstens {tuning.MaxListings} Angebote gleichzeitig (Abgelaufenes erst abholen)");
            }
        }

        int itemId, have;
        string code;
        await using (var item = new NpgsqlCommand(
            """
            SELECT ii.item_id, ii.quantity, i.code FROM item_instances ii JOIN items i USING (item_id)
            WHERE ii.item_instance_id = @id AND ii.owner_character_id = @chr AND ii.location_type = 'INVENTORY'
              AND i.tradeable AND NOT ii.bound
            FOR UPDATE OF ii
            """, conn, tx))
        {
            item.Parameters.AddWithValue("id", req.InstanceId);
            item.Parameters.AddWithValue("chr", characterId);
            await using var r = await item.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
            {
                return Problem(StatusCodes.Status400BadRequest, "Kein handelbares Item dieses Charakters im Inventar");
            }
            (itemId, have, code) = (r.GetInt32(0), r.GetInt32(1), r.GetString(2));
        }
        if (have < req.Quantity)
        {
            return Problem(StatusCodes.Status409Conflict, $"Nur {have} vorhanden");
        }
        var fee = AuctionRules.ListingFee(req.Price, tuning);
        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        if (gold < fee)
        {
            return Problem(StatusCodes.Status409Conflict, $"Nicht genug Gold für die Einstellgebühr ({gold} von {fee})");
        }
        if (fee > 0)
        {
            gold = await ShipEndpoints.Book(conn, tx, characterId, -fee, "AUCTION_FEE", "SINK", req.Key, req.ServerId, ct);
        }

        // Ganzer Stapel wandert auf den Markt; ein Teil wird abgespalten (Herkunft SPLIT).
        long marketInstance;
        if (have == req.Quantity)
        {
            await InventoryEndpoints.Exec(conn, tx, "UPDATE item_instances SET location_type = 'MARKET', slot = NULL WHERE item_instance_id = @id",
                ct, ("id", req.InstanceId));
            marketInstance = req.InstanceId;
        }
        else
        {
            await InventoryEndpoints.Exec(conn, tx, "UPDATE item_instances SET quantity = quantity - @q WHERE item_instance_id = @id", ct,
                ("q", req.Quantity), ("id", req.InstanceId));
            await using var split = new NpgsqlCommand(
                """
                INSERT INTO item_instances (item_id, quantity, location_type, owner_character_id, origin, origin_ref)
                VALUES (@item, @q, 'MARKET', @chr, 'SPLIT', @ref) RETURNING item_instance_id
                """, conn, tx);
            split.Parameters.AddWithValue("item", itemId);
            split.Parameters.AddWithValue("q", req.Quantity);
            split.Parameters.AddWithValue("chr", characterId);
            split.Parameters.AddWithValue("ref", req.InstanceId.ToString(System.Globalization.CultureInfo.InvariantCulture));
            marketInstance = (long)(await split.ExecuteScalarAsync(ct))!;
        }
        long listingId;
        DateTime expiresAt;
        await using (var insert = new NpgsqlCommand(
            """
            INSERT INTO market_listings (seller_character_id, item_instance_id, currency_code, price, listing_fee, expires_at, listing_key,
                                         item_id, quantity)
            VALUES (@chr, @inst, 'GOLD', @price, @fee, now() + make_interval(hours => @hours), @key, @item, @q)
            RETURNING listing_id, expires_at
            """, conn, tx))
        {
            insert.Parameters.AddWithValue("chr", characterId);
            insert.Parameters.AddWithValue("inst", marketInstance);
            insert.Parameters.AddWithValue("price", req.Price);
            insert.Parameters.AddWithValue("fee", fee);
            insert.Parameters.AddWithValue("hours", tuning.DurationHours);
            insert.Parameters.AddWithValue("key", req.Key);
            insert.Parameters.AddWithValue("item", itemId);
            insert.Parameters.AddWithValue("q", req.Quantity);
            await using var r = await insert.ExecuteReaderAsync(ct);
            await r.ReadAsync(ct);
            (listingId, expiresAt) = (r.GetInt64(0), r.GetDateTime(1));
        }
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("AUCTION_LIST", req.AccountId, characterId,
            NewValue: new { listing = listingId, item = code, quantity = req.Quantity, price = req.Price, fee }), identity.Value.InstanceId, ct);
        var inventory = await InventoryEndpoints.Load(conn, tx, characterId, allowDev, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new AuctionListResponse(false, listingId, fee, gold, expiresAt, inventory));
    }

    // ---- Kaufen -------------------------------------------------------------------------------

    private static async Task<IResult> Buy(
        long characterId, long listingId, AuctionActionRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || string.IsNullOrEmpty(req.NpcCode) || req.Key == Guid.Empty)
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId, npcCode und key sind erforderlich");
        }
        var allowDev = content.Value.AllowDevContent;
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);

        // Käufer und Verkäufer immer in der Reihenfolge ihrer IDs sperren (gleichzeitige Käufe zwischen zwei Spielern verklemmen nicht).
        long seller;
        await using (var who = new NpgsqlCommand("SELECT seller_character_id FROM market_listings WHERE listing_id = @id", conn, tx))
        {
            who.Parameters.AddWithValue("id", listingId);
            if (await who.ExecuteScalarAsync(ct) is not long s)
            {
                return Problem(StatusCodes.Status404NotFound, "Angebot nicht gefunden");
            }
            seller = s;
        }
        foreach (var id in new[] { characterId, seller }.Distinct().Order())
        {
            if (await ProgressionEndpoints.LockCharacter(conn, tx, id, id == characterId ? req.AccountId : null, ct) is null)
            {
                return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
            }
        }
        if (await Duplicate(conn, tx, characterId, req.Key, allowDev, ct) is { } duplicate)
        {
            return duplicate;
        }
        if (seller == characterId)
        {
            return Problem(StatusCodes.Status409Conflict, "Eigene Angebote zieht man zurück, statt sie zu kaufen");
        }
        if (await Prepare(conn, tx, characterId, req.ServerId, req.NpcCode, allowDev, ct) is not { } tuning)
        {
            return Problem(StatusCodes.Status400BadRequest, "Hier gibt es keinen Auktionator (oder das Auktionshaus ist nicht verfügbar)");
        }
        if (await OpenListing(conn, tx, listingId, sellerId: null, mustBeUnexpired: true, ct) is not { } listing)
        {
            return Problem(StatusCodes.Status409Conflict, "Angebot ist verkauft, zurückgezogen oder abgelaufen");
        }
        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        if (gold < listing.Price)
        {
            return Problem(StatusCodes.Status409Conflict, $"Nicht genug Gold ({gold} von {listing.Price})");
        }
        if (!await Place(conn, tx, characterId, listing.InstanceId, allowDev, ct))
        {
            return Problem(StatusCodes.Status409Conflict, "Inventar voll");
        }

        var sale = AuctionRules.Sale(listing.Price, tuning);
        if (sale.Proceeds > 0)
        {
            gold = await ShipEndpoints.Book(conn, tx, characterId, -sale.Proceeds, "AUCTION_BUY", "TRANSFER", req.Key, req.ServerId, ct);
            await ShipEndpoints.Book(conn, tx, seller, sale.Proceeds, "AUCTION_SALE", "TRANSFER", AuctionRules.DeriveKey(req.Key, "seller"),
                req.ServerId, ct);
        }
        if (sale.Tax > 0)
        {
            gold = await ShipEndpoints.Book(conn, tx, characterId, -sale.Tax, "AUCTION_TAX", "SINK", AuctionRules.DeriveKey(req.Key, "tax"),
                req.ServerId, ct);
        }
        await InventoryEndpoints.Exec(conn, tx,
            """
            UPDATE market_listings SET status = 'SOLD', buyer_character_id = @buyer, sale_tax = @tax, sold_at = now(), closed_at = now()
            WHERE listing_id = @id
            """, ct, ("buyer", characterId), ("tax", sale.Tax), ("id", listingId));
        await InventoryEndpoints.RecordOperation(conn, tx, req.Key, characterId, "AUCTION_BUY",
            new Stored(listingId, listing.Code, listing.NameDe, listing.Quantity, listing.Price), req.ServerId, ct);
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("AUCTION_BUY", req.AccountId, characterId,
            NewValue: new { listing = listingId, seller, item = listing.Code, quantity = listing.Quantity, price = listing.Price, tax = sale.Tax }),
            identity.Value.InstanceId, ct);
        var inventory = await InventoryEndpoints.Load(conn, tx, characterId, allowDev, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new AuctionItemResponse(false, listingId, listing.Code, listing.NameDe, listing.Quantity, listing.Price, gold, inventory));
    }

    // ---- Zurückziehen und Abholen -------------------------------------------------------------

    /// <summary>Eigenes Angebot zurückziehen (auch abgelaufene); die Gebühr bleibt verbraucht.</summary>
    private static async Task<IResult> Cancel(
        long characterId, long listingId, AuctionActionRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || string.IsNullOrEmpty(req.NpcCode) || req.Key == Guid.Empty)
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId, npcCode und key sind erforderlich");
        }
        var allowDev = content.Value.AllowDevContent;
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await Duplicate(conn, tx, characterId, req.Key, allowDev, ct) is { } duplicate)
        {
            return duplicate;
        }
        if (await Prepare(conn, tx, characterId, req.ServerId, req.NpcCode, allowDev, ct) is null)
        {
            return Problem(StatusCodes.Status400BadRequest, "Hier gibt es keinen Auktionator (oder das Auktionshaus ist nicht verfügbar)");
        }
        if (await OpenListing(conn, tx, listingId, sellerId: characterId, mustBeUnexpired: false, ct) is not { } listing)
        {
            return Problem(StatusCodes.Status409Conflict, "Kein offenes eigenes Angebot");
        }
        if (!await Place(conn, tx, characterId, listing.InstanceId, allowDev, ct))
        {
            return Problem(StatusCodes.Status409Conflict, "Inventar voll");
        }
        await InventoryEndpoints.Exec(conn, tx,
            "UPDATE market_listings SET status = CASE WHEN expires_at > now() THEN 'CANCELLED' ELSE 'EXPIRED' END, closed_at = now() WHERE listing_id = @id",
            ct, ("id", listingId));
        await InventoryEndpoints.RecordOperation(conn, tx, req.Key, characterId, "AUCTION_CANCEL",
            new Stored(listingId, listing.Code, listing.NameDe, listing.Quantity, 0), req.ServerId, ct);
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("AUCTION_CANCEL", req.AccountId, characterId,
            NewValue: new { listing = listingId, item = listing.Code, quantity = listing.Quantity }), identity.Value.InstanceId, ct);
        var inventory = await InventoryEndpoints.Load(conn, tx, characterId, allowDev, ct);
        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new AuctionItemResponse(false, listingId, listing.Code, listing.NameDe, listing.Quantity, 0, gold, inventory));
    }

    /// <summary>Alle abgelaufenen eigenen Angebote zurück ins Inventar, soweit Platz ist (wiederholbar ohne Schaden).</summary>
    private static async Task<IResult> Collect(
        long characterId, AuctionActionRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ServerId) || string.IsNullOrEmpty(req.NpcCode))
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId und npcCode sind erforderlich");
        }
        var allowDev = content.Value.AllowDevContent;
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await Prepare(conn, tx, characterId, req.ServerId, req.NpcCode, allowDev, ct) is null)
        {
            return Problem(StatusCodes.Status400BadRequest, "Hier gibt es keinen Auktionator (oder das Auktionshaus ist nicht verfügbar)");
        }
        var expired = new List<(long ListingId, long InstanceId)>();
        await using (var cmd = new NpgsqlCommand(
            """
            SELECT listing_id, item_instance_id FROM market_listings
            WHERE seller_character_id = @chr AND status = 'OPEN' AND closed_at IS NULL AND expires_at <= now()
            ORDER BY listing_id FOR UPDATE
            """, conn, tx))
        {
            cmd.Parameters.AddWithValue("chr", characterId);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            while (await r.ReadAsync(ct))
            {
                expired.Add((r.GetInt64(0), r.GetInt64(1)));
            }
        }
        var returned = 0;
        foreach (var (listingId, instanceId) in expired)
        {
            if (!await Place(conn, tx, characterId, instanceId, allowDev, ct))
            {
                break; // Rest bleibt abholbereit
            }
            await InventoryEndpoints.Exec(conn, tx, "UPDATE market_listings SET status = 'EXPIRED', closed_at = now() WHERE listing_id = @id",
                ct, ("id", listingId));
            returned++;
        }
        var inventory = await InventoryEndpoints.Load(conn, tx, characterId, allowDev, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new AuctionCollectResponse(returned, expired.Count - returned, inventory));
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private sealed record Listing(long InstanceId, string Code, string? NameDe, int Quantity, long Price);

    private sealed record Stored(long ListingId, string ItemCode, string? NameDe, int Quantity, long Price);

    private static async Task<IResult?> Duplicate(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, Guid key, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT result::text FROM inventory_operations
            WHERE op_key = @key AND character_id = @chr AND kind IN ('AUCTION_BUY', 'AUCTION_CANCEL')
            """, conn, tx);
        cmd.Parameters.AddWithValue("key", key);
        cmd.Parameters.AddWithValue("chr", characterId);
        if (await cmd.ExecuteScalarAsync(ct) is not string json || JsonSerializer.Deserialize<Stored>(json) is not { } s)
        {
            return null;
        }
        return Results.Ok(new AuctionItemResponse(true, s.ListingId, s.ItemCode, s.NameDe, s.Quantity, s.Price,
            await ShipEndpoints.LoadGold(conn, tx, characterId, ct), await InventoryEndpoints.Load(conn, tx, characterId, allowDev, ct)));
    }

    /// <summary>Auktionator in der Zone des Charakters und vollständige Parameter; sonst null (nie Ersatzwerte).</summary>
    private static async Task<AuctionTuning?> Prepare(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, string serverId, string npcCode, bool allowDev, CancellationToken ct)
    {
        var zone = await WorldEndpoints.PresenceZone(conn, tx, characterId, serverId, ct);
        if (zone is null)
        {
            return null;
        }
        await using (var npc = new NpgsqlCommand(
            "SELECT 1 FROM npcs WHERE code = @code AND npc_role = 'AUCTION' AND zone_id = @zone AND (NOT is_dev OR @dev)", conn, tx))
        {
            npc.Parameters.AddWithValue("code", npcCode);
            npc.Parameters.AddWithValue("zone", zone);
            npc.Parameters.AddWithValue("dev", allowDev);
            if (await npc.ExecuteScalarAsync(ct) is null)
            {
                return null;
            }
        }
        await using var cmd = new NpgsqlCommand(
            "SELECT rule_key, int_value FROM game_rules WHERE rule_key LIKE 'AUCTION\\_%' AND (NOT is_dev OR @dev)", conn, tx);
        cmd.Parameters.AddWithValue("dev", allowDev);
        var v = new Dictionary<string, long>();
        await using (var r = await cmd.ExecuteReaderAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                v[r.GetString(0)] = r.GetInt64(1);
            }
        }
        if (!v.TryGetValue("AUCTION_FEE_PERMILLE", out var fee) || !v.TryGetValue("AUCTION_MIN_FEE", out var minFee)
            || !v.TryGetValue("AUCTION_TAX_PERMILLE", out var tax) || !v.TryGetValue("AUCTION_DURATION_HOURS", out var hours)
            || !v.TryGetValue("AUCTION_MAX_LISTINGS", out var max))
        {
            return null;
        }
        var tuning = new AuctionTuning((int)fee, minFee, (int)tax, (int)hours, (int)max);
        return AuctionRules.IsValidTuning(tuning) ? tuning : null;
    }

    private static async Task<Listing?> OpenListing(
        NpgsqlConnection conn, NpgsqlTransaction tx, long listingId, long? sellerId, bool mustBeUnexpired, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT l.item_instance_id, i.code, i.name_de, l.quantity, l.price
            FROM market_listings l JOIN items i ON i.item_id = l.item_id
            WHERE l.listing_id = @id AND l.status = 'OPEN' AND l.closed_at IS NULL AND l.item_instance_id IS NOT NULL
              AND (@seller::bigint IS NULL OR l.seller_character_id = @seller) AND (NOT @fresh OR l.expires_at > now())
            FOR UPDATE OF l
            """, conn, tx);
        cmd.Parameters.AddWithValue("id", listingId);
        cmd.Parameters.AddWithValue("seller", (object?)sellerId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("fresh", mustBeUnexpired);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct)
            ? new Listing(r.GetInt64(0), r.GetString(1), r.IsDBNull(2) ? null : r.GetString(2), r.GetInt32(3), r.GetInt64(4))
            : null;
    }

    /// <summary>
    /// Ein Markt-Exemplar ins Inventar von CharacterId legen – ganz oder gar nicht. Stapelbares geht in vorhandenen Stapeln auf
    /// (das Markt-Exemplar wird gelöscht), Einzelstücke behalten ihr Exemplar (Haltbarkeit, Sockel) und wechseln den Besitzer.
    /// </summary>
    private static async Task<bool> Place(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, long instanceId, bool allowDev, CancellationToken ct)
    {
        int itemId, quantity, maxStack;
        bool stackable;
        await using (var cmd = new NpgsqlCommand(
            """
            SELECT ii.item_id, ii.quantity, i.stackable, i.max_stack FROM item_instances ii JOIN items i USING (item_id)
            WHERE ii.item_instance_id = @id AND ii.location_type = 'MARKET' FOR UPDATE OF ii
            """, conn, tx))
        {
            cmd.Parameters.AddWithValue("id", instanceId);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
            {
                return false;
            }
            (itemId, quantity, stackable, maxStack) = (r.GetInt32(0), r.GetInt32(1), r.GetBoolean(2), r.GetInt32(3));
        }
        var plan = InventoryRules.PlanAdd(await InventoryEndpoints.Slots(conn, tx, characterId, ct), itemId, quantity, stackable, maxStack,
            await InventoryEndpoints.Capacity(conn, tx, allowDev, ct));
        if (plan.Overflow > 0)
        {
            return false;
        }
        if (stackable)
        {
            await InventoryEndpoints.AddItems(conn, tx, characterId, itemId, quantity, "MARKET", instanceId.ToString(
                System.Globalization.CultureInfo.InvariantCulture), allowDev, ct);
            await InventoryEndpoints.Exec(conn, tx, "DELETE FROM item_instances WHERE item_instance_id = @id", ct, ("id", instanceId));
        }
        else
        {
            await InventoryEndpoints.Exec(conn, tx,
                "UPDATE item_instances SET location_type = 'INVENTORY', owner_character_id = @chr, slot = @slot WHERE item_instance_id = @id",
                ct, ("chr", characterId), ("slot", plan.NewStacks[0].Slot.ToString(System.Globalization.CultureInfo.InvariantCulture)),
                ("id", instanceId));
        }
        return true;
    }

    private static async Task<List<AuctionListing>> Query(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, string where, string orderBy, (string, object)? extra,
        CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            $"""
            SELECT l.listing_id, i.code, i.name_de, l.quantity, l.price, c.name, l.expires_at, l.seller_character_id = @chr,
                   CASE WHEN l.status = 'OPEN' AND l.closed_at IS NULL AND l.expires_at <= now() THEN 'EXPIRED' ELSE l.status END
            FROM market_listings l JOIN items i ON i.item_id = l.item_id JOIN characters c ON c.character_id = l.seller_character_id
            WHERE {where}
            ORDER BY {orderBy}
            LIMIT {PageSize}
            """, conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        if (extra is { } p)
        {
            cmd.Parameters.AddWithValue(p.Item1, p.Item2);
        }
        var list = new List<AuctionListing>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            list.Add(new AuctionListing(r.GetInt64(0), r.GetString(1), r.IsDBNull(2) ? null : r.GetString(2), r.GetInt32(3), r.GetInt64(4),
                r.GetString(5), r.GetDateTime(6), r.GetBoolean(7), r.GetString(8)));
        }
        return list;
    }

    private static IResult Problem(int status, string title) => Results.Problem(statusCode: status, title: title);
}
