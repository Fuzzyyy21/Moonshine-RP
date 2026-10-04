using Microsoft.Extensions.Options;
using Npgsql;

namespace VC.GameData;

public sealed record HotbarSlot(int Slot, string AbilityCode);

/// <summary>Ersetzt die ganze Hotbar (idempotent). Leere Liste = Hotbar leeren.</summary>
public sealed record SaveHotbarRequest(long AccountId, IReadOnlyList<HotbarSlot>? Slots);

/// <summary>
/// Hotbar-Belegung je Charakter. Der Zonen-Server schreibt sie, wenn ein Spieler sie ändert, und bekommt sie mit dem
/// Charakterzustand zurück. Ob eine Fähigkeit eingesetzt werden darf (Skillstufe, Waffe, Abklingzeit), prüft der
/// Zonen-Server beim Einsatz; hier wird nur geprüft, dass es die Fähigkeit gibt und sie freigegeben ist.
/// </summary>
public static class HotbarEndpoints
{
    /// <summary>Anzahl Plätze; muss zum CHECK in V0007 passen (Designentscheidung, Original UNKNOWN).</summary>
    public const int SlotCount = 10;

    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapPut("/characters/{characterId:long}/hotbar", SaveHotbar);
    }

    /// <summary>Belegung nach Platz sortiert. Nicht (mehr) freigegebene Fähigkeiten werden ausgelassen.</summary>
    public static async Task<List<HotbarSlot>> LoadHotbar(NpgsqlConnection conn, long characterId, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            """
            SELECT h.slot, a.code
            FROM character_hotbar h JOIN abilities a USING (ability_id)
            WHERE h.character_id = @chr AND (NOT a.is_dev OR @dev)
            ORDER BY h.slot
            """, conn);
        cmd.Parameters.AddWithValue("chr", characterId);
        cmd.Parameters.AddWithValue("dev", allowDev);
        var list = new List<HotbarSlot>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            list.Add(new HotbarSlot(r.GetInt16(0), r.GetString(1)));
        }
        return list;
    }

    private static async Task<IResult> SaveHotbar(
        long characterId, SaveHotbarRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content, CancellationToken ct)
    {
        if (req.Slots is null || req.Slots.Count > SlotCount)
        {
            return BadRequest($"slots: höchstens {SlotCount} Einträge");
        }
        if (req.Slots.Any(s => s is null || s.Slot is < 0 or >= SlotCount || string.IsNullOrEmpty(s.AbilityCode) || s.AbilityCode.Length > 64))
        {
            return BadRequest($"slot muss zwischen 0 und {SlotCount - 1} liegen, abilityCode ist erforderlich");
        }
        if (req.Slots.Select(s => s.Slot).Distinct().Count() != req.Slots.Count
            || req.Slots.Select(s => s.AbilityCode).Distinct(StringComparer.Ordinal).Count() != req.Slots.Count)
        {
            return BadRequest("Jeder Platz und jede Fähigkeit darf nur einmal vorkommen");
        }

        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Results.Problem(statusCode: StatusCodes.Status404NotFound, title: "Charakter nicht gefunden");
        }

        var abilityIds = new Dictionary<string, int>(StringComparer.Ordinal);
        await using (var cmd = new NpgsqlCommand(
            "SELECT code, ability_id FROM abilities WHERE code = ANY(@codes) AND ability_kind = 'ACTIVE' AND (NOT is_dev OR @dev)",
            conn, tx))
        {
            cmd.Parameters.AddWithValue("codes", req.Slots.Select(s => s.AbilityCode).ToArray());
            cmd.Parameters.AddWithValue("dev", content.Value.AllowDevContent);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            while (await r.ReadAsync(ct))
            {
                abilityIds[r.GetString(0)] = r.GetInt32(1);
            }
        }
        if (req.Slots.FirstOrDefault(s => !abilityIds.ContainsKey(s.AbilityCode)) is { } unknown)
        {
            return BadRequest($"Fähigkeit unbekannt oder nicht freigegeben: {unknown.AbilityCode}");
        }

        await using (var clear = new NpgsqlCommand("DELETE FROM character_hotbar WHERE character_id = @chr", conn, tx))
        {
            clear.Parameters.AddWithValue("chr", characterId);
            await clear.ExecuteNonQueryAsync(ct);
        }
        foreach (var slot in req.Slots)
        {
            await using var insert = new NpgsqlCommand(
                "INSERT INTO character_hotbar (character_id, slot, ability_id) VALUES (@chr, @slot, @ability)", conn, tx);
            insert.Parameters.AddWithValue("chr", characterId);
            insert.Parameters.AddWithValue("slot", (short)slot.Slot);
            insert.Parameters.AddWithValue("ability", abilityIds[slot.AbilityCode]);
            await insert.ExecuteNonQueryAsync(ct);
        }
        await tx.CommitAsync(ct);
        return Results.Ok(req.Slots.OrderBy(s => s.Slot).ToList());
    }

    private static IResult BadRequest(string title) => Results.Problem(statusCode: StatusCodes.Status400BadRequest, title: title);
}
