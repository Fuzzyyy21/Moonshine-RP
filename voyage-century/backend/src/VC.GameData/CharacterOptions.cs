using System.Text.Json;
using Npgsql;
using VC.Common.Hosting;

namespace VC.GameData;

public sealed record ProfessionOption(string Code, string? NameZh, string? NameEn, string? NameDe, string Confidence);
public sealed record AppearanceSlot(string Slot, short OptionCount);
public sealed record CharacterOptionsResponse(
    IReadOnlyList<ProfessionOption> Professions, IReadOnlyList<string> Genders, IReadOnlyList<AppearanceSlot> AppearanceSlots);

/// <summary>
/// Auswahl für die Charaktererstellung. Die Oberfläche baut sich ausschließlich hieraus auf, damit Client
/// und Server dieselben Regeln kennen und neue Berufe oder Optionen ohne Client-Update erscheinen.
/// </summary>
public static class CharacterOptions
{
    public static readonly IReadOnlyList<string> Genders = ["MALE", "FEMALE"];

    public static void Map(RouteGroupBuilder client) => client.MapGet("/character-options", Get);

    public static async Task<List<AppearanceSlot>> LoadSlots(NpgsqlConnection conn, NpgsqlTransaction? tx, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("SELECT slot, option_count FROM appearance_slots ORDER BY sort_order, slot", conn, tx);
        var list = new List<AppearanceSlot>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            list.Add(new AppearanceSlot(r.GetString(0), r.GetInt16(1)));
        }
        return list;
    }

    /// <summary>
    /// Prüft das Erscheinungsbild gegen die Slots: nur bekannte Merkmale, ganzzahlige Indizes im erlaubten Bereich.
    /// Fehlende Merkmale werden mit 0 belegt. Ergebnis ist ein vollständiges, normalisiertes JSON-Objekt.
    /// </summary>
    public static (string? Json, string? Error) Normalize(JsonElement? input, IReadOnlyList<AppearanceSlot> slots)
    {
        var values = slots.ToDictionary(s => s.Slot, _ => 0, StringComparer.Ordinal);
        if (input is { ValueKind: not (JsonValueKind.Undefined or JsonValueKind.Null) } element)
        {
            if (element.ValueKind != JsonValueKind.Object)
            {
                return (null, "Erscheinungsbild muss ein JSON-Objekt sein");
            }
            foreach (var prop in element.EnumerateObject())
            {
                var slot = slots.FirstOrDefault(s => s.Slot == prop.Name);
                if (slot is null)
                {
                    return (null, $"Unbekanntes Merkmal: {prop.Name}");
                }
                if (prop.Value.ValueKind != JsonValueKind.Number || !prop.Value.TryGetInt32(out var index)
                    || index < 0 || index >= slot.OptionCount)
                {
                    return (null, $"{prop.Name}: Wert 0 bis {slot.OptionCount - 1}");
                }
                values[prop.Name] = index;
            }
        }
        return (JsonSerializer.Serialize(values), null);
    }

    private static async Task<IResult> Get(NpgsqlDataSource db, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        var professions = new List<ProfessionOption>();
        await using (var cmd = new NpgsqlCommand(
            "SELECT code, name_zh, name_en, name_de, confidence::text FROM professions WHERE recon_id IS NOT NULL ORDER BY code", conn))
        await using (var r = await cmd.ExecuteReaderAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                professions.Add(new ProfessionOption(r.GetString(0), r.IsDBNull(1) ? null : r.GetString(1),
                    r.IsDBNull(2) ? null : r.GetString(2), r.IsDBNull(3) ? null : r.GetString(3), r.GetString(4)));
            }
        }
        return Results.Ok(new CharacterOptionsResponse(professions, Genders, await LoadSlots(conn, null, ct)));
    }
}
