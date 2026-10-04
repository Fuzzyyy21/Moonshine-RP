using System.Text.Json;
using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Logging;

namespace VC.GameData;

/// <summary>Location INVENTORY (Slot = Platznummer) oder EQUIPMENT (Slot = z. B. WEAPON).</summary>
public sealed record InventoryItem(
    long InstanceId, string Code, string? NameDe, string ItemType, string? WeaponClass, int Quantity, string Location, string? Slot,
    long? NpcPrice);
/// <summary>Capacity 0 = Inventargröße unbekannt (kein Inventar, nie Ersatzwerte).</summary>
public sealed record InventoryResponse(int Capacity, List<InventoryItem> Items);
public sealed record ItemCommandRequest(long AccountId, string? ServerId, long InstanceId);
public sealed record ItemAmountRequest(long AccountId, string? ServerId, long InstanceId, int Quantity, Guid Key, string? NpcCode = null);
public sealed record AdminItemRequest(
    long AdminAccountId, string? ItemCode, int Quantity, Guid Key, Guid? SessionId, string? Ip, string? ServerId);
/// <summary>Ergebnis von Verkauf, Wegwerfen und Admin-Vergabe. Placed/Lost nur bei Vergabe.</summary>
public sealed record ItemOperationResponse(bool Duplicate, long Gold, long Total, int Placed, int Lost, InventoryResponse Inventory);
public sealed record LootDrop(string Code, string? NameDe, int Quantity, int Lost);

/// <summary>
/// Inventar [DESIGN]: Plätze 0 … INVENTORY_SLOTS−1 im Item-Register (item_instances, location INVENTORY), ausgerüstete Waffe
/// als EQUIPMENT/WEAPON. Der Zonen-Server nennt nur Item-Exemplar und Menge; Besitz, Art, Platz und Preis prüft das Backend.
/// </summary>
public static class InventoryEndpoints
{
    public const string WeaponSlot = "WEAPON";
    private const int MaxQuantity = 10_000;

    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapGet("/characters/{characterId:long}/inventory", Get);
        internalApi.MapPost("/characters/{characterId:long}/inventory/equip", Equip);
        internalApi.MapPost("/characters/{characterId:long}/inventory/unequip", Unequip);
        internalApi.MapPost("/characters/{characterId:long}/inventory/discard", Discard);
        internalApi.MapPost("/characters/{characterId:long}/inventory/sell", Sell);
        internalApi.MapPost("/characters/{characterId:long}/inventory/grant", AdminGrant);
    }

    // ---- Endpunkte ----------------------------------------------------------------------------

    private static async Task<IResult> Get(long characterId, long accountId, NpgsqlDataSource db, IOptions<ContentOptions> content,
        CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, accountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        var inventory = await Load(conn, tx, characterId, content.Value.AllowDevContent, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(inventory);
    }

    /// <summary>Waffe aus dem Inventar ausrüsten; eine vorher ausgerüstete Waffe nimmt ihren Platz ein (Tausch).</summary>
    private static async Task<IResult> Equip(
        long characterId, ItemCommandRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await Begin(conn, tx, characterId, req.AccountId, req.ServerId, ct) is { } denied)
        {
            return denied;
        }
        string? slot;
        await using (var cmd = new NpgsqlCommand(
            """
            SELECT ii.slot FROM item_instances ii JOIN items i USING (item_id)
            WHERE ii.item_instance_id = @id AND ii.owner_character_id = @chr AND ii.location_type = 'INVENTORY'
              AND i.item_type = 'WEAPON' AND (NOT i.is_dev OR @dev)
            """, conn, tx))
        {
            cmd.Parameters.AddWithValue("id", req.InstanceId);
            cmd.Parameters.AddWithValue("chr", characterId);
            cmd.Parameters.AddWithValue("dev", content.Value.AllowDevContent);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
            {
                return Problem(StatusCodes.Status400BadRequest, "Keine Waffe dieses Charakters im Inventar");
            }
            slot = r.IsDBNull(0) ? null : r.GetString(0);
        }
        // Reihenfolge wegen ux_item_slot: neue Waffe vom Platz lösen, alte auf den Platz, neue ausrüsten.
        await Exec(conn, tx, "UPDATE item_instances SET slot = NULL WHERE item_instance_id = @id", ct, ("id", req.InstanceId));
        await Exec(conn, tx,
            """
            UPDATE item_instances SET location_type = 'INVENTORY', slot = @slot
            WHERE owner_character_id = @chr AND location_type = 'EQUIPMENT' AND slot = 'WEAPON'
            """, ct, ("slot", (object?)slot ?? DBNull.Value), ("chr", characterId));
        await Exec(conn, tx, "UPDATE item_instances SET location_type = 'EQUIPMENT', slot = 'WEAPON' WHERE item_instance_id = @id", ct,
            ("id", req.InstanceId));
        var inventory = await Load(conn, tx, characterId, content.Value.AllowDevContent, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(inventory);
    }

    private static async Task<IResult> Unequip(
        long characterId, ItemCommandRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await Begin(conn, tx, characterId, req.AccountId, req.ServerId, ct) is { } denied)
        {
            return denied;
        }
        var capacity = await Capacity(conn, tx, content.Value.AllowDevContent, ct);
        var free = FirstFree(await Slots(conn, tx, characterId, ct), capacity);
        if (free is null)
        {
            return Problem(StatusCodes.Status409Conflict, "Inventar voll");
        }
        if (await Exec(conn, tx,
                """
                UPDATE item_instances SET location_type = 'INVENTORY', slot = @slot
                WHERE owner_character_id = @chr AND location_type = 'EQUIPMENT' AND slot = 'WEAPON'
                """, ct, ("slot", free.Value.ToString()), ("chr", characterId)) == 0)
        {
            return Problem(StatusCodes.Status409Conflict, "Keine Waffe ausgerüstet");
        }
        var inventory = await Load(conn, tx, characterId, content.Value.AllowDevContent, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(inventory);
    }

    private static Task<IResult> Discard(
        long characterId, ItemAmountRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct) =>
        RemoveFromInventory(characterId, req, sell: false, db, content.Value, identity.Value, ct);

    /// <summary>Item an den Händler der eigenen Zone verkaufen (items.npc_price; NULL = UNKNOWN → nicht verkäuflich).</summary>
    private static Task<IResult> Sell(
        long characterId, ItemAmountRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct) =>
        RemoveFromInventory(characterId, req, sell: true, db, content.Value, identity.Value, ct);

    private static async Task<IResult> RemoveFromInventory(
        long characterId, ItemAmountRequest req, bool sell, NpgsqlDataSource db, ContentOptions content, ServiceIdentityOptions identity,
        CancellationToken ct)
    {
        if (req.Quantity is < 1 or > MaxQuantity || req.Key == Guid.Empty || (sell && string.IsNullOrEmpty(req.NpcCode)))
        {
            return Problem(StatusCodes.Status400BadRequest, $"quantity (1 … {MaxQuantity}), key{(sell ? " und npcCode" : "")} sind erforderlich");
        }
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await Duplicate(conn, tx, characterId, req.Key, content.AllowDevContent, ct) is { } duplicate)
        {
            return duplicate;
        }
        if (string.IsNullOrEmpty(req.ServerId) || await WorldEndpoints.PresenceZone(conn, tx, characterId, req.ServerId, ct) is not { } zone)
        {
            return Problem(StatusCodes.Status409Conflict, "Charakter ist nicht auf diesem Server");
        }
        if (sell)
        {
            await using var npc = new NpgsqlCommand(
                "SELECT 1 FROM npcs WHERE code = @code AND npc_role = 'MERCHANT' AND zone_id = @zone AND (NOT is_dev OR @dev)", conn, tx);
            npc.Parameters.AddWithValue("code", req.NpcCode!);
            npc.Parameters.AddWithValue("zone", zone);
            npc.Parameters.AddWithValue("dev", content.AllowDevContent);
            if (await npc.ExecuteScalarAsync(ct) is null)
            {
                return Problem(StatusCodes.Status400BadRequest, "Hier gibt es keinen Händler mit diesem Code");
            }
        }

        int quantity;
        long? price;
        string code;
        await using (var cmd = new NpgsqlCommand(
            """
            SELECT ii.quantity, i.npc_price, i.code FROM item_instances ii JOIN items i USING (item_id)
            WHERE ii.item_instance_id = @id AND ii.owner_character_id = @chr AND ii.location_type = 'INVENTORY'
            FOR UPDATE OF ii
            """, conn, tx))
        {
            cmd.Parameters.AddWithValue("id", req.InstanceId);
            cmd.Parameters.AddWithValue("chr", characterId);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
            {
                return Problem(StatusCodes.Status400BadRequest, "Item nicht im Inventar (ausgerüstete Items erst ablegen)");
            }
            (quantity, price, code) = (r.GetInt32(0), r.IsDBNull(1) ? null : r.GetInt64(1), r.GetString(2));
        }
        if (quantity < req.Quantity)
        {
            return Problem(StatusCodes.Status409Conflict, $"Nur {quantity} vorhanden");
        }
        if (sell && price is null)
        {
            return Problem(StatusCodes.Status400BadRequest, "Der Händler kauft dieses Item nicht (Preis unbekannt)");
        }
        // Weg ist weg: ganze Stapel werden gelöscht, Teilmengen abgezogen (Spur im Ereignisprotokoll).
        if (quantity == req.Quantity)
        {
            await Exec(conn, tx, "DELETE FROM item_instances WHERE item_instance_id = @id", ct, ("id", req.InstanceId));
        }
        else
        {
            await Exec(conn, tx, "UPDATE item_instances SET quantity = quantity - @q WHERE item_instance_id = @id", ct,
                ("q", req.Quantity), ("id", req.InstanceId));
        }
        var total = sell ? price!.Value * req.Quantity : 0;
        var gold = total > 0
            ? await ShipEndpoints.Book(conn, tx, characterId, total, "ITEM_SELL", "SOURCE", req.Key, req.ServerId, ct)
            : await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        var kind = sell ? "SELL" : "DISCARD";
        await RecordOperation(conn, tx, req.Key, characterId, kind, new { item = code, quantity = req.Quantity, total }, req.ServerId, ct);
        await GameEventLog.WriteAsync(conn, tx, new GameEvent(sell ? "ITEM_SELL" : "ITEM_DISCARD", req.AccountId, characterId,
            NewValue: new { item = code, instance = req.InstanceId, quantity = req.Quantity, total, npc = req.NpcCode }), identity.InstanceId, ct);
        var inventory = await Load(conn, tx, characterId, content.AllowDevContent, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new ItemOperationResponse(false, gold, total, 0, 0, inventory));
    }

    /// <summary>Admin: Item ins Inventar legen (zum Testen; Herkunft ADMIN). Rechte, Vergabe und Audit in einer Transaktion.</summary>
    private static async Task<IResult> AdminGrant(
        long characterId, AdminItemRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ProgressionOptions> options, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.ItemCode) || req.Quantity is < 1 or > MaxQuantity || req.Key == Guid.Empty)
        {
            return Problem(StatusCodes.Status400BadRequest, $"itemCode, quantity (1 … {MaxQuantity}) und key sind erforderlich");
        }
        var admin = new AdminSetRequest(req.AdminAccountId, 0, req.SessionId, req.Ip, req.ServerId);
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.CheckAdmin(conn, tx, admin, options.Value.AdminMinLevel, ct) is { } denied)
        {
            return denied;
        }
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, accountId: null, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        if (await Duplicate(conn, tx, characterId, req.Key, content.Value.AllowDevContent, ct) is { } duplicate)
        {
            return duplicate;
        }
        int itemId;
        await using (var item = new NpgsqlCommand("SELECT item_id FROM items WHERE code = @code AND (NOT is_dev OR @dev)", conn, tx))
        {
            item.Parameters.AddWithValue("code", req.ItemCode);
            item.Parameters.AddWithValue("dev", content.Value.AllowDevContent);
            if (await item.ExecuteScalarAsync(ct) is not int id)
            {
                return Problem(StatusCodes.Status400BadRequest, "Item unbekannt oder nicht freigegeben");
            }
            itemId = id;
        }
        var placed = await AddItems(conn, tx, characterId, itemId, req.Quantity, "ADMIN", req.Key.ToString(),
            content.Value.AllowDevContent, ct);
        var auditId = await ProgressionEndpoints.Audit(conn, tx, admin, "/giveitem", characterId, new { }, new { item = req.ItemCode, placed },
            ct, args: new { item = req.ItemCode, quantity = req.Quantity });
        await RecordOperation(conn, tx, req.Key, characterId, "ADMIN_GRANT",
            new { item = req.ItemCode, placed, lost = req.Quantity - placed, auditId }, req.ServerId!, ct);
        var inventory = await Load(conn, tx, characterId, content.Value.AllowDevContent, ct);
        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(new ItemOperationResponse(false, gold, 0, placed, req.Quantity - placed, inventory));
    }

    // ---- Für andere Endpunkte (Beute) -------------------------------------------------------

    /// <summary>
    /// Items ins Inventar legen (InventoryRules.PlanAdd). Gibt die untergebrachte Menge zurück; der Rest geht verloren – der
    /// Aufrufer meldet ihn. Die Charakterzeile muss gesperrt sein.
    /// </summary>
    internal static async Task<int> AddItems(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, int itemId, int quantity, string origin, string? originRef,
        bool allowDev, CancellationToken ct)
    {
        bool stackable;
        int maxStack;
        await using (var item = new NpgsqlCommand("SELECT stackable, max_stack FROM items WHERE item_id = @id", conn, tx))
        {
            item.Parameters.AddWithValue("id", itemId);
            await using var r = await item.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
            {
                return 0;
            }
            (stackable, maxStack) = (r.GetBoolean(0), r.GetInt32(1));
        }
        var capacity = await Capacity(conn, tx, allowDev, ct);
        var plan = InventoryRules.PlanAdd(await Slots(conn, tx, characterId, ct), itemId, quantity, stackable, maxStack, capacity);
        foreach (var (instanceId, newQuantity) in plan.TopUps)
        {
            await Exec(conn, tx, "UPDATE item_instances SET quantity = @q WHERE item_instance_id = @id", ct,
                ("q", newQuantity), ("id", instanceId));
        }
        foreach (var (slot, amount) in plan.NewStacks)
        {
            await Exec(conn, tx,
                """
                INSERT INTO item_instances (item_id, quantity, location_type, owner_character_id, slot, origin, origin_ref)
                VALUES (@item, @q, 'INVENTORY', @chr, @slot, @origin, @ref)
                """, ct, ("item", itemId), ("q", amount), ("chr", characterId), ("slot", slot.ToString()), ("origin", origin),
                ("ref", (object?)originRef ?? DBNull.Value));
        }
        return plan.Placed(quantity);
    }

    /// <summary>Code der ausgerüsteten Waffe (für den Zustand beim Login); null = unbewaffnet.</summary>
    internal static async Task<string?> EquippedWeapon(NpgsqlConnection conn, long characterId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT i.code FROM item_instances ii JOIN items i USING (item_id)
            WHERE ii.owner_character_id = @chr AND ii.location_type = 'EQUIPMENT' AND ii.slot = 'WEAPON'
            """, conn);
        cmd.Parameters.AddWithValue("chr", characterId);
        return await cmd.ExecuteScalarAsync(ct) as string;
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    private static async Task<IResult?> Begin(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, long accountId, string? serverId, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(serverId))
        {
            return Problem(StatusCodes.Status400BadRequest, "serverId ist erforderlich");
        }
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, accountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        return await WorldEndpoints.PresenceZone(conn, tx, characterId, serverId, ct) is null
            ? Problem(StatusCodes.Status409Conflict, "Charakter ist nicht auf diesem Server")
            : null;
    }

    private static async Task<IResult?> Duplicate(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, Guid key, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            "SELECT result::text FROM inventory_operations WHERE op_key = @key AND character_id = @chr", conn, tx);
        cmd.Parameters.AddWithValue("key", key);
        cmd.Parameters.AddWithValue("chr", characterId);
        if (await cmd.ExecuteScalarAsync(ct) is not string json)
        {
            return null;
        }
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        long Get(string name) => root.TryGetProperty(name, out var v) ? v.GetInt64() : 0;
        return Results.Ok(new ItemOperationResponse(true, await ShipEndpoints.LoadGold(conn, tx, characterId, ct), Get("total"),
            (int)Get("placed"), (int)Get("lost"), await Load(conn, tx, characterId, allowDev, ct)));
    }

    internal static async Task RecordOperation(
        NpgsqlConnection conn, NpgsqlTransaction tx, Guid key, long characterId, string kind, object result, string serverId,
        CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            INSERT INTO inventory_operations (op_key, character_id, kind, result, server_id)
            VALUES (@key, @chr, @kind, @result::jsonb, @server)
            """, conn, tx);
        cmd.Parameters.AddWithValue("key", key);
        cmd.Parameters.AddWithValue("chr", characterId);
        cmd.Parameters.AddWithValue("kind", kind);
        cmd.Parameters.AddWithValue("result", JsonSerializer.Serialize(result));
        cmd.Parameters.AddWithValue("server", serverId);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    internal static async Task<InventoryResponse> Load(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, bool allowDev, CancellationToken ct)
    {
        var capacity = await Capacity(conn, tx, allowDev, ct);
        await using var cmd = new NpgsqlCommand(
            """
            SELECT ii.item_instance_id, i.code, i.name_de, i.item_type, i.weapon_class, ii.quantity, ii.location_type::text, ii.slot,
                   i.npc_price
            FROM item_instances ii JOIN items i USING (item_id)
            WHERE ii.owner_character_id = @chr AND ii.location_type IN ('INVENTORY', 'EQUIPMENT')
            ORDER BY ii.location_type, length(ii.slot), ii.slot
            """, conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        var items = new List<InventoryItem>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            items.Add(new InventoryItem(r.GetInt64(0), r.GetString(1), r.IsDBNull(2) ? null : r.GetString(2), r.GetString(3),
                r.IsDBNull(4) ? null : r.GetString(4), r.GetInt32(5), r.GetString(6), r.IsDBNull(7) ? null : r.GetString(7),
                r.IsDBNull(8) ? null : r.GetInt64(8)));
        }
        return new InventoryResponse(capacity, items);
    }

    /// <summary>Inventargröße aus game_rules (INVENTORY_SLOTS, im Original UNKNOWN); fehlt sie, 0 = kein Platz.</summary>
    private static async Task<int> Capacity(NpgsqlConnection conn, NpgsqlTransaction tx, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            "SELECT int_value FROM game_rules WHERE rule_key = 'INVENTORY_SLOTS' AND (NOT is_dev OR @dev)", conn, tx);
        cmd.Parameters.AddWithValue("dev", allowDev);
        return await cmd.ExecuteScalarAsync(ct) is long n ? (int)Math.Clamp(n, 0, 1000) : 0;
    }

    internal static async Task<List<InventorySlot>> Slots(NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT slot, item_instance_id, item_id, quantity FROM item_instances
            WHERE owner_character_id = @chr AND location_type = 'INVENTORY' AND slot ~ '^[0-9]{1,4}$'
            """, conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        var slots = new List<InventorySlot>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            slots.Add(new InventorySlot(int.Parse(r.GetString(0)), r.GetInt64(1), r.GetInt32(2), r.GetInt32(3)));
        }
        return slots;
    }

    private static int? FirstFree(List<InventorySlot> slots, int capacity)
    {
        var used = slots.Select(s => s.Slot).ToHashSet();
        for (var slot = 0; slot < capacity; slot++)
        {
            if (!used.Contains(slot))
            {
                return slot;
            }
        }
        return null;
    }

    internal static async Task<int> Exec(
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
