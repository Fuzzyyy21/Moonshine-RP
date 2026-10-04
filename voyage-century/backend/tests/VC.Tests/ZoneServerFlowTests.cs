using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using VC.Auth;
using VC.GameData;
using VC.Tests.Infrastructure;

namespace VC.Tests;

/// <summary>
/// Backend-Seite der Phase-1-Abnahme: genau die Aufrufe, die Client und Zonen-Server nacheinander machen.
/// Login → Charakter → Ticketprüfung → Zustand laden → speichern → Dienst-Neustart → Zustand wieder da → Admin-Audit.
/// </summary>
[Collection(DatabaseTestGroup.Name)]
public sealed class ZoneServerFlowTests(PostgresFixture db)
{
    [Fact]
    public async Task Position_survives_backend_restart_and_admin_command_is_audited()
    {
        long accountId;
        long characterId;
        string ticket;

        await using (var backend = await TestBackend.StartAsync(db))
        {
            // Client: einloggen und Charakter anlegen
            var login = await backend.RegisterAndLoginAsync();
            ticket = login.Ticket;
            accountId = login.AccountId;
            characterId = (await backend.CreateCharacterAsync(ticket)).CharacterId;

            // Zonen-Server: Ticket aus der Verbindungs-URL prüfen
            var validated = await Validate(backend, ticket);
            Assert.Equal(accountId, validated.AccountId);
            Assert.Equal(0, validated.AdminLevel);

            // Neuer Charakter hat noch keine Position → Server nutzt den PlayerStart der Zone
            var fresh = await backend.GameInternal.GetFromJsonAsync<CharacterState>(
                $"/internal/v1/characters/{characterId}/state?accountId={accountId}");
            Assert.Null(fresh!.Position);
            Assert.Null(fresh.ZoneId);

            // Zonen-Server meldet den Charakter im World Directory an (neue Charaktere: Startzone) …
            var serverId = await backend.EnterZoneAsync(characterId, accountId);

            // … und speichert beim Logout oder periodisch
            var save = await backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{characterId}/state",
                new SaveStateRequest(accountId, "DEV_TESTZONE", 100.5, -20.25, 300, 90f, ServerId: serverId));
            Assert.Equal(HttpStatusCode.NoContent, save.StatusCode);
        }

        // Neustart der Dienste: Zustand muss aus der Datenbank kommen
        await using (var backend = await TestBackend.StartAsync(db))
        {
            var loaded = await backend.GameInternal.GetFromJsonAsync<CharacterState>(
                $"/internal/v1/characters/{characterId}/state?accountId={accountId}");
            Assert.Equal("DEV_TESTZONE", loaded!.ZoneId);
            Assert.Equal(new Position(100.5, -20.25, 300, 90f), loaded.Position);

            // Konto wird Admin; die Ticketprüfung liefert das neue Level sofort
            await db.ExecAsync("UPDATE accounts SET admin_level = 1 WHERE account_id = @a", ("a", accountId));
            var validated = await Validate(backend, ticket);
            Assert.Equal(1, validated.AdminLevel);

            // Zonen-Server führt /teleport aus und protokolliert alt/neu
            var audit = await backend.GameInternal.PostAsJsonAsync("/internal/v1/admin-audit", new
            {
                adminAccountId = accountId,
                command = "/teleport",
                targetType = "CHARACTER",
                targetId = characterId.ToString(System.Globalization.CultureInfo.InvariantCulture),
                args = new { x = 0, y = 0, z = 500 },
                oldValue = new { x = 100.5, y = -20.25, z = 300 },
                newValue = new { x = 0, y = 0, z = 500 },
                sessionId = validated.SessionId,
                ip = "203.0.113.7",
                serverId = "zone-dev-1",
            });
            Assert.Equal(HttpStatusCode.Created, audit.StatusCode);
            var auditId = (await audit.Content.ReadFromJsonAsync<AdminAuditResponse>())!.AuditId;

            var stored = await db.ScalarAsync<string>(
                "SELECT new_value::text FROM admin_audit_log WHERE audit_id = @id", ("id", auditId));
            Assert.Equal(500, JsonDocument.Parse(stored).RootElement.GetProperty("z").GetInt32());
        }

        // Alle Schritte stehen im Spielereignis-Log
        var actions = await db.ScalarAsync<string[]>(
            "SELECT array_agg(action ORDER BY log_id) FROM game_event_log WHERE account_id = @a", ("a", accountId));
        Assert.Equal(["ACCOUNT_CREATE", "ACCOUNT_LOGIN", "CHARACTER_CREATE", "ZONE_ENTER"], actions);
    }

    [Fact]
    public async Task Zone_server_cannot_read_or_write_a_character_of_another_account()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var owner = await backend.RegisterAndLoginAsync();
        var other = await backend.RegisterAndLoginAsync();
        var character = await backend.CreateCharacterAsync(owner.Ticket);

        var read = await backend.GameInternal.GetAsync(
            $"/internal/v1/characters/{character.CharacterId}/state?accountId={other.AccountId}");
        Assert.Equal(HttpStatusCode.NotFound, read.StatusCode);

        var write = await backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{character.CharacterId}/state",
            new SaveStateRequest(other.AccountId, "DEV_TESTZONE", 1, 2, 3, 0, ServerId: "zone-other"));
        Assert.Equal(HttpStatusCode.NotFound, write.StatusCode);
    }

    [Theory]
    [InlineData("NO_SUCH_ZONE", 1.0, HttpStatusCode.Conflict)]   // nicht die Zone, in der der Charakter angemeldet ist
    [InlineData("DEV_TESTZONE", 1e9, HttpStatusCode.BadRequest)]
    [InlineData("", 1.0, HttpStatusCode.BadRequest)]
    public async Task Invalid_positions_are_rejected(string zone, double x, HttpStatusCode expected)
    {
        await using var backend = await TestBackend.StartAsync(db);
        var login = await backend.RegisterAndLoginAsync();
        var character = await backend.CreateCharacterAsync(login.Ticket);
        var serverId = await backend.EnterZoneAsync(character.CharacterId, login.AccountId);

        var res = await backend.GameInternal.PutAsJsonAsync($"/internal/v1/characters/{character.CharacterId}/state",
            new SaveStateRequest(login.AccountId, zone, x, 0, 0, 0, ServerId: serverId));
        Assert.Equal(expected, res.StatusCode);
    }

    [Fact]
    public async Task Admin_audit_is_refused_for_accounts_without_admin_level()
    {
        await using var backend = await TestBackend.StartAsync(db);
        var login = await backend.RegisterAndLoginAsync();
        var res = await backend.GameInternal.PostAsJsonAsync("/internal/v1/admin-audit",
            new { adminAccountId = login.AccountId, command = "/teleport", serverId = "zone-dev-1" });
        Assert.Equal(HttpStatusCode.Forbidden, res.StatusCode);
    }

    private static async Task<ValidateResponse> Validate(TestBackend backend, string ticket)
    {
        var res = await backend.AuthInternal.PostAsJsonAsync("/internal/v1/sessions/validate", new ValidateRequest(ticket));
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<ValidateResponse>())!;
    }
}
