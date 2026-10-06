using Microsoft.Extensions.Options;
using Npgsql;
using VC.Common;
using VC.Common.Logging;

namespace VC.GameData;

public sealed record GuildMemberInfo(long CharacterId, string Name, short RankNo, string RankName, bool Online, string? ZoneId);
public sealed record GuildInfo(
    long GuildId, string Name, string? Tag, int BannerSymbol, int BannerColor1, int BannerColor2, short MyRank, string MyRankName,
    IReadOnlyList<string> MyPermissions, int MaxMembers, List<GuildMemberInfo> Members);
public sealed record GuildFoundRequest(
    long AccountId, string? ServerId, string? Name, string? Tag, int BannerSymbol, int BannerColor1, int BannerColor2, Guid Key);
public sealed record GuildTargetRequest(long AccountId, string? ServerId, string? Name, short RankNo = 0);
public sealed record GuildActionRequest(long AccountId, string? ServerId);
public sealed record GuildInviteInfo(long GuildId, string GuildName, string? Tag, string InvitedBy, DateTime ExpiresAt);

/// <summary>
/// Gilden [DESIGN] bis auf das Belegte (SYS-GUILD). Jede Änderung der Mitgliedschaft sperrt die Gildenzeile, damit Mitgliederzahl
/// und Ränge auch bei gleichzeitigen Aktionen stimmen. Rechte kommen aus den Rängen der Gilde (Vorlage guild_rank_defaults).
/// </summary>
public static class GuildEndpoints
{
    public static void Map(RouteGroupBuilder internalApi)
    {
        internalApi.MapGet("/characters/{characterId:long}/guild", Get);
        internalApi.MapPost("/characters/{characterId:long}/guild", Found);
        internalApi.MapPost("/characters/{characterId:long}/guild/invite", Invite);
        internalApi.MapPost("/characters/{characterId:long}/guild/kick", Kick);
        internalApi.MapPost("/characters/{characterId:long}/guild/rank", SetRank);
        internalApi.MapPost("/characters/{characterId:long}/guild/leave", Leave);
        internalApi.MapPost("/characters/{characterId:long}/guild/disband", Disband);
        internalApi.MapGet("/characters/{characterId:long}/guild-invites", Invites);
        internalApi.MapPost("/characters/{characterId:long}/guild-invites/{guildId:long}/accept", Accept);
        internalApi.MapPost("/characters/{characterId:long}/guild-invites/{guildId:long}/decline", Decline);
    }

    private sealed record Config(long FoundCost, int MaxMembers, int InviteHours);

    private sealed record Membership(long GuildId, GuildRank Rank);

    // ---- Ansehen ------------------------------------------------------------------------------

    private static async Task<IResult> Get(long characterId, long accountId, NpgsqlDataSource db, IOptions<ContentOptions> content,
        CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, accountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        var info = await Load(conn, tx, characterId, content.Value.AllowDevContent, ct);
        await tx.CommitAsync(ct);
        return info is null ? Problem(StatusCodes.Status404NotFound, "Keine Gilde") : Results.Ok(info);
    }

    private static async Task<IResult> Invites(long characterId, long accountId, NpgsqlDataSource db, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, accountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        await using var cmd = new NpgsqlCommand(
            """
            SELECT g.guild_id, g.name, g.tag, c.name, i.expires_at
            FROM guild_invites i JOIN guilds g USING (guild_id) JOIN characters c ON c.character_id = i.invited_by
            WHERE i.character_id = @chr AND i.expires_at > now() AND g.disbanded_at IS NULL
            ORDER BY i.expires_at
            """, conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        var list = new List<GuildInviteInfo>();
        await using (var r = await cmd.ExecuteReaderAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                list.Add(new GuildInviteInfo(r.GetInt64(0), r.GetString(1), r.IsDBNull(2) ? null : r.GetString(2), r.GetString(3), r.GetDateTime(4)));
            }
        }
        await tx.CommitAsync(ct);
        return Results.Ok(list);
    }

    // ---- Gründen ------------------------------------------------------------------------------

    private static async Task<IResult> Found(
        long characterId, GuildFoundRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        var tag = string.IsNullOrWhiteSpace(req.Tag) ? null : req.Tag.Trim();
        if (!GuildRules.IsValidName(req.Name?.Trim()) || !GuildRules.IsValidTag(tag)
            || !GuildRules.IsValidBanner(req.BannerSymbol, req.BannerColor1, req.BannerColor2) || req.Key == Guid.Empty)
        {
            return Problem(StatusCodes.Status400BadRequest,
                $"Name (3–20 Zeichen), Kürzel (2–4 Großbuchstaben/Ziffern, optional), Banner (Symbol 0–{GuildRules.BannerSymbols - 1}, Farben 0–{GuildRules.BannerColors - 1}) und key sind erforderlich");
        }
        var name = req.Name!.Trim();
        var allowDev = content.Value.AllowDevContent;
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await Begin(conn, tx, characterId, req.AccountId, req.ServerId, ct) is { } denied)
        {
            return denied;
        }
        await using (var dup = new NpgsqlCommand("SELECT 1 FROM guilds WHERE found_key = @key AND leader_character_id = @chr", conn, tx))
        {
            dup.Parameters.AddWithValue("key", req.Key);
            dup.Parameters.AddWithValue("chr", characterId);
            if (await dup.ExecuteScalarAsync(ct) is not null)
            {
                var existing = await Load(conn, tx, characterId, allowDev, ct);
                await tx.CommitAsync(ct);
                return Results.Ok(existing);
            }
        }
        if (await LoadConfig(conn, tx, allowDev, ct) is not { } config)
        {
            return Problem(StatusCodes.Status400BadRequest, "Gilden sind nicht verfügbar (Werte fehlen)");
        }
        if (await MembershipOf(conn, tx, characterId, ct) is not null)
        {
            return Problem(StatusCodes.Status409Conflict, "Du bist schon in einer Gilde");
        }
        await using (var taken = new NpgsqlCommand(
            "SELECT 1 FROM guilds WHERE disbanded_at IS NULL AND (lower(name) = lower(@name) OR (@tag::text IS NOT NULL AND tag = @tag))", conn, tx))
        {
            taken.Parameters.AddWithValue("name", name);
            taken.Parameters.AddWithValue("tag", (object?)tag ?? DBNull.Value);
            if (await taken.ExecuteScalarAsync(ct) is not null)
            {
                return Problem(StatusCodes.Status409Conflict, "Name oder Kürzel ist vergeben");
            }
        }
        var gold = await ShipEndpoints.LoadGold(conn, tx, characterId, ct);
        if (gold < config.FoundCost)
        {
            return Problem(StatusCodes.Status409Conflict, $"Nicht genug Gold für die Gründung ({gold} von {config.FoundCost})");
        }
        if (config.FoundCost > 0)
        {
            await ShipEndpoints.Book(conn, tx, characterId, -config.FoundCost, "GUILD_FOUND", "SINK", req.Key, req.ServerId!, ct);
        }
        long guildId;
        await using (var insert = new NpgsqlCommand(
            """
            INSERT INTO guilds (name, tag, leader_character_id, banner, found_key)
            VALUES (@name, @tag, @chr, jsonb_build_object('symbol', @s, 'color1', @c1, 'color2', @c2), @key)
            RETURNING guild_id
            """, conn, tx))
        {
            insert.Parameters.AddWithValue("name", name);
            insert.Parameters.AddWithValue("tag", (object?)tag ?? DBNull.Value);
            insert.Parameters.AddWithValue("chr", characterId);
            insert.Parameters.AddWithValue("s", req.BannerSymbol);
            insert.Parameters.AddWithValue("c1", req.BannerColor1);
            insert.Parameters.AddWithValue("c2", req.BannerColor2);
            insert.Parameters.AddWithValue("key", req.Key);
            guildId = (long)(await insert.ExecuteScalarAsync(ct))!;
        }
        // Ohne Rang-Vorlagen (mindestens Leiter und ein weiterer Rang) keine Gilde – nichts wird gebucht (kein Commit).
        if (await Exec(conn, tx,
                """
                INSERT INTO guild_ranks (guild_id, rank_no, name, permissions)
                SELECT @g, rank_no, name, permissions FROM guild_rank_defaults WHERE NOT is_dev OR @dev
                """, ct, ("g", guildId), ("dev", allowDev)) < 2)
        {
            return Problem(StatusCodes.Status400BadRequest, "Gilden sind nicht verfügbar (Rang-Vorlagen fehlen)");
        }
        await Exec(conn, tx, "INSERT INTO guild_members (guild_id, character_id, rank_no) VALUES (@g, @chr, 0)", ct,
            ("g", guildId), ("chr", characterId));
        await Exec(conn, tx, "DELETE FROM guild_invites WHERE character_id = @chr", ct, ("chr", characterId));
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("GUILD_FOUND", req.AccountId, characterId,
            NewValue: new { guild = guildId, name, tag, cost = config.FoundCost }), identity.Value.InstanceId, ct);
        var info = await Load(conn, tx, characterId, allowDev, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(info);
    }

    // ---- Einladen, Annehmen, Ablehnen ---------------------------------------------------------

    private static async Task<IResult> Invite(
        long characterId, GuildTargetRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content, CancellationToken ct)
    {
        var allowDev = content.Value.AllowDevContent;
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await Begin(conn, tx, characterId, req.AccountId, req.ServerId, ct) is { } denied)
        {
            return denied;
        }
        if (await LoadConfig(conn, tx, allowDev, ct) is not { } config)
        {
            return Problem(StatusCodes.Status400BadRequest, "Gilden sind nicht verfügbar (Werte fehlen)");
        }
        if (await MembershipOf(conn, tx, characterId, ct, lockGuild: true) is not { } me || !GuildRules.Has(me.Rank, GuildRules.Invite))
        {
            return Problem(StatusCodes.Status403Forbidden, "Einladen darf nur, wer in einer Gilde das Recht dazu hat");
        }
        if (await FindCharacter(conn, tx, req.Name, ct) is not { } target || target.Id == characterId)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter unbekannt");
        }
        if (await MembershipOf(conn, tx, target.Id, ct) is not null)
        {
            return Problem(StatusCodes.Status409Conflict, $"{target.Name} ist schon in einer Gilde");
        }
        if (await MemberCount(conn, tx, me.GuildId, ct) >= config.MaxMembers)
        {
            return Problem(StatusCodes.Status409Conflict, $"Die Gilde ist voll ({config.MaxMembers})");
        }
        await Exec(conn, tx,
            """
            INSERT INTO guild_invites (guild_id, character_id, invited_by, expires_at)
            VALUES (@g, @t, @me, now() + make_interval(hours => @h))
            ON CONFLICT (guild_id, character_id) DO UPDATE SET invited_by = EXCLUDED.invited_by, expires_at = EXCLUDED.expires_at
            """, ct, ("g", me.GuildId), ("t", target.Id), ("me", characterId), ("h", config.InviteHours));
        var info = await Load(conn, tx, characterId, allowDev, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(info);
    }

    private static async Task<IResult> Accept(
        long characterId, long guildId, GuildActionRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        var allowDev = content.Value.AllowDevContent;
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await Begin(conn, tx, characterId, req.AccountId, req.ServerId, ct) is { } denied)
        {
            return denied;
        }
        if (await LoadConfig(conn, tx, allowDev, ct) is not { } config)
        {
            return Problem(StatusCodes.Status400BadRequest, "Gilden sind nicht verfügbar (Werte fehlen)");
        }
        if (await MembershipOf(conn, tx, characterId, ct) is not null)
        {
            return Problem(StatusCodes.Status409Conflict, "Du bist schon in einer Gilde");
        }
        await using (var guild = new NpgsqlCommand(
            """
            SELECT 1 FROM guilds g JOIN guild_invites i USING (guild_id)
            WHERE g.guild_id = @g AND g.disbanded_at IS NULL AND i.character_id = @chr AND i.expires_at > now()
            FOR UPDATE OF g
            """, conn, tx))
        {
            guild.Parameters.AddWithValue("g", guildId);
            guild.Parameters.AddWithValue("chr", characterId);
            if (await guild.ExecuteScalarAsync(ct) is null)
            {
                return Problem(StatusCodes.Status404NotFound, "Keine gültige Einladung dieser Gilde");
            }
        }
        if (await MemberCount(conn, tx, guildId, ct) >= config.MaxMembers)
        {
            return Problem(StatusCodes.Status409Conflict, $"Die Gilde ist voll ({config.MaxMembers})");
        }
        await Exec(conn, tx,
            "INSERT INTO guild_members (guild_id, character_id, rank_no) SELECT @g, @chr, max(rank_no) FROM guild_ranks WHERE guild_id = @g",
            ct, ("g", guildId), ("chr", characterId));
        await Exec(conn, tx, "DELETE FROM guild_invites WHERE character_id = @chr", ct, ("chr", characterId));
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("GUILD_JOIN", req.AccountId, characterId, NewValue: new { guild = guildId }),
            identity.Value.InstanceId, ct);
        var info = await Load(conn, tx, characterId, allowDev, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(info);
    }

    private static async Task<IResult> Decline(long characterId, long guildId, GuildActionRequest req, NpgsqlDataSource db, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await ProgressionEndpoints.LockCharacter(conn, tx, characterId, req.AccountId, ct) is null)
        {
            return Problem(StatusCodes.Status404NotFound, "Charakter nicht gefunden");
        }
        await Exec(conn, tx, "DELETE FROM guild_invites WHERE guild_id = @g AND character_id = @chr", ct, ("g", guildId), ("chr", characterId));
        await tx.CommitAsync(ct);
        return Results.NoContent();
    }

    // ---- Mitglieder verwalten -----------------------------------------------------------------

    private static async Task<IResult> Kick(
        long characterId, GuildTargetRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        var allowDev = content.Value.AllowDevContent;
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await Begin(conn, tx, characterId, req.AccountId, req.ServerId, ct) is { } denied)
        {
            return denied;
        }
        if (await MembershipOf(conn, tx, characterId, ct, lockGuild: true) is not { } me)
        {
            return Problem(StatusCodes.Status404NotFound, "Keine Gilde");
        }
        if (await TargetInGuild(conn, tx, me.GuildId, req.Name, ct) is not { } target)
        {
            return Problem(StatusCodes.Status404NotFound, "Kein Mitglied dieser Gilde");
        }
        if (!GuildRules.CanKick(me.Rank, target.Rank, target.Id == characterId))
        {
            return Problem(StatusCodes.Status403Forbidden, "Entfernen nur mit Recht und nur bei niedrigerem Rang");
        }
        await Exec(conn, tx, "DELETE FROM guild_members WHERE guild_id = @g AND character_id = @t", ct, ("g", me.GuildId), ("t", target.Id));
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("GUILD_KICK", req.AccountId, characterId,
            NewValue: new { guild = me.GuildId, kicked = target.Id }), identity.Value.InstanceId, ct);
        var info = await Load(conn, tx, characterId, allowDev, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(info);
    }

    /// <summary>Rang setzen; RankNo 0 übergibt die Leitung (der bisherige Leiter wird Rang 1).</summary>
    private static async Task<IResult> SetRank(
        long characterId, GuildTargetRequest req, NpgsqlDataSource db, IOptions<ContentOptions> content,
        IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        var allowDev = content.Value.AllowDevContent;
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await Begin(conn, tx, characterId, req.AccountId, req.ServerId, ct) is { } denied)
        {
            return denied;
        }
        if (await MembershipOf(conn, tx, characterId, ct, lockGuild: true) is not { } me)
        {
            return Problem(StatusCodes.Status404NotFound, "Keine Gilde");
        }
        if (await TargetInGuild(conn, tx, me.GuildId, req.Name, ct) is not { } target)
        {
            return Problem(StatusCodes.Status404NotFound, "Kein Mitglied dieser Gilde");
        }
        await using (var exists = new NpgsqlCommand("SELECT 1 FROM guild_ranks WHERE guild_id = @g AND rank_no = @r", conn, tx))
        {
            exists.Parameters.AddWithValue("g", me.GuildId);
            exists.Parameters.AddWithValue("r", req.RankNo);
            if (await exists.ExecuteScalarAsync(ct) is null)
            {
                return Problem(StatusCodes.Status400BadRequest, "Diesen Rang gibt es in der Gilde nicht");
            }
        }
        if (!GuildRules.CanSetRank(me.Rank, target.Rank, req.RankNo, target.Id == characterId))
        {
            return Problem(StatusCodes.Status403Forbidden, "Ränge nur unterhalb des eigenen; die Leitung gibt nur der Leiter ab");
        }
        if (req.RankNo == GuildRules.LeaderRank)
        {
            // Übergabe: erst der bisherige Leiter auf Rang 1, dann der neue auf 0 (es gibt immer genau einen Leiter).
            await Exec(conn, tx, "UPDATE guild_members SET rank_no = 1 WHERE guild_id = @g AND character_id = @me", ct,
                ("g", me.GuildId), ("me", characterId));
            await Exec(conn, tx, "UPDATE guilds SET leader_character_id = @t WHERE guild_id = @g", ct, ("t", target.Id), ("g", me.GuildId));
        }
        await Exec(conn, tx, "UPDATE guild_members SET rank_no = @r WHERE guild_id = @g AND character_id = @t", ct,
            ("r", req.RankNo), ("g", me.GuildId), ("t", target.Id));
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("GUILD_RANK", req.AccountId, characterId,
            OldValue: new { member = target.Id, rank = target.Rank }, NewValue: new { member = target.Id, rank = req.RankNo, guild = me.GuildId }),
            identity.Value.InstanceId, ct);
        var info = await Load(conn, tx, characterId, allowDev, ct);
        await tx.CommitAsync(ct);
        return Results.Ok(info);
    }

    /// <summary>Austreten. Der Leiter muss erst die Leitung übergeben; ist er allein, wird die Gilde aufgelöst.</summary>
    private static async Task<IResult> Leave(
        long characterId, GuildActionRequest req, NpgsqlDataSource db, IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await Begin(conn, tx, characterId, req.AccountId, req.ServerId, ct) is { } denied)
        {
            return denied;
        }
        if (await MembershipOf(conn, tx, characterId, ct, lockGuild: true) is not { } me)
        {
            return Problem(StatusCodes.Status404NotFound, "Keine Gilde");
        }
        if (me.Rank.RankNo == GuildRules.LeaderRank)
        {
            if (await MemberCount(conn, tx, me.GuildId, ct) > 1)
            {
                return Problem(StatusCodes.Status409Conflict, "Erst die Leitung übergeben (Rang 0 an ein anderes Mitglied)");
            }
            await DisbandGuild(conn, tx, me.GuildId, ct);
        }
        else
        {
            await Exec(conn, tx, "DELETE FROM guild_members WHERE guild_id = @g AND character_id = @chr", ct, ("g", me.GuildId), ("chr", characterId));
        }
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("GUILD_LEAVE", req.AccountId, characterId, NewValue: new { guild = me.GuildId }),
            identity.Value.InstanceId, ct);
        await tx.CommitAsync(ct);
        return Results.NoContent();
    }

    private static async Task<IResult> Disband(
        long characterId, GuildActionRequest req, NpgsqlDataSource db, IOptions<ServiceIdentityOptions> identity, CancellationToken ct)
    {
        await using var conn = await db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        if (await Begin(conn, tx, characterId, req.AccountId, req.ServerId, ct) is { } denied)
        {
            return denied;
        }
        if (await MembershipOf(conn, tx, characterId, ct, lockGuild: true) is not { } me || me.Rank.RankNo != GuildRules.LeaderRank)
        {
            return Problem(StatusCodes.Status403Forbidden, "Auflösen darf nur der Gildenleiter");
        }
        await DisbandGuild(conn, tx, me.GuildId, ct);
        await GameEventLog.WriteAsync(conn, tx, new GameEvent("GUILD_DISBAND", req.AccountId, characterId, NewValue: new { guild = me.GuildId }),
            identity.Value.InstanceId, ct);
        await tx.CommitAsync(ct);
        return Results.NoContent();
    }

    // ---- Hilfen ------------------------------------------------------------------------------

    /// <summary>Gilde, in der der Charakter ist (für Gildenchat und Zustand).</summary>
    internal static async Task<long?> GuildIdOf(NpgsqlConnection conn, NpgsqlTransaction? tx, long characterId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("SELECT guild_id FROM guild_members WHERE character_id = @chr", conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        return await cmd.ExecuteScalarAsync(ct) as long?;
    }

    private static async Task DisbandGuild(NpgsqlConnection conn, NpgsqlTransaction tx, long guildId, CancellationToken ct)
    {
        // Name und Kürzel werden wieder frei (eindeutig nur unter nicht aufgelösten Gilden); die Zeile bleibt als Verlauf.
        await Exec(conn, tx, "DELETE FROM guild_members WHERE guild_id = @g", ct, ("g", guildId));
        await Exec(conn, tx, "DELETE FROM guild_invites WHERE guild_id = @g", ct, ("g", guildId));
        await Exec(conn, tx, "UPDATE guilds SET disbanded_at = now() WHERE guild_id = @g", ct, ("g", guildId));
    }

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

    private static async Task<Config?> LoadConfig(NpgsqlConnection conn, NpgsqlTransaction tx, bool allowDev, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand(
            "SELECT rule_key, int_value FROM game_rules WHERE rule_key LIKE 'GUILD\\_%' AND (NOT is_dev OR @dev)", conn, tx);
        cmd.Parameters.AddWithValue("dev", allowDev);
        var v = new Dictionary<string, long>();
        await using (var r = await cmd.ExecuteReaderAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                v[r.GetString(0)] = r.GetInt64(1);
            }
        }
        return v.TryGetValue("GUILD_FOUND_COST", out var cost) && v.TryGetValue("GUILD_MAX_MEMBERS", out var max)
            && v.TryGetValue("GUILD_INVITE_HOURS", out var hours)
            ? new Config(cost, (int)max, (int)hours)
            : null;
    }

    /// <summary>Mitgliedschaft mit Rang und Rechten; lockGuild sperrt die Gildenzeile für Änderungen an Mitgliedern.</summary>
    private static async Task<Membership?> MembershipOf(
        NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, CancellationToken ct, bool lockGuild = false)
    {
        await using var cmd = new NpgsqlCommand(
            $"""
            SELECT m.guild_id, m.rank_no, r.name, r.permissions
            FROM guild_members m JOIN guild_ranks r USING (guild_id, rank_no) JOIN guilds g USING (guild_id)
            WHERE m.character_id = @chr AND g.disbanded_at IS NULL
            {(lockGuild ? "FOR UPDATE OF g" : "")}
            """, conn, tx);
        cmd.Parameters.AddWithValue("chr", characterId);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct)
            ? new Membership(r.GetInt64(0), new GuildRank(r.GetInt16(1), r.GetString(2), r.GetFieldValue<string[]>(3).ToHashSet()))
            : null;
    }

    private static async Task<(long Id, short Rank)?> TargetInGuild(
        NpgsqlConnection conn, NpgsqlTransaction tx, long guildId, string? name, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            return null;
        }
        await using var cmd = new NpgsqlCommand(
            """
            SELECT m.character_id, m.rank_no FROM guild_members m JOIN characters c USING (character_id)
            WHERE m.guild_id = @g AND lower(c.name) = lower(@n)
            """, conn, tx);
        cmd.Parameters.AddWithValue("g", guildId);
        cmd.Parameters.AddWithValue("n", name.Trim());
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct) ? (r.GetInt64(0), r.GetInt16(1)) : null;
    }

    private static async Task<(long Id, string Name)?> FindCharacter(NpgsqlConnection conn, NpgsqlTransaction tx, string? name, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(name) || name.Length > 24)
        {
            return null;
        }
        await using var cmd = new NpgsqlCommand(
            "SELECT character_id, name FROM characters WHERE lower(name) = lower(@n) AND deleted_at IS NULL", conn, tx);
        cmd.Parameters.AddWithValue("n", name.Trim());
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct) ? (r.GetInt64(0), r.GetString(1)) : null;
    }

    private static async Task<int> MemberCount(NpgsqlConnection conn, NpgsqlTransaction tx, long guildId, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("SELECT count(*)::int FROM guild_members WHERE guild_id = @g", conn, tx);
        cmd.Parameters.AddWithValue("g", guildId);
        return (int)(await cmd.ExecuteScalarAsync(ct))!;
    }

    private static async Task<GuildInfo?> Load(NpgsqlConnection conn, NpgsqlTransaction tx, long characterId, bool allowDev, CancellationToken ct)
    {
        if (await MembershipOf(conn, tx, characterId, ct) is not { } me)
        {
            return null;
        }
        var max = (await LoadConfig(conn, tx, allowDev, ct))?.MaxMembers ?? 0;
        string name;
        string? tag;
        int symbol, color1, color2;
        await using (var g = new NpgsqlCommand(
            """
            SELECT name, tag, coalesce((banner->>'symbol')::int, 0), coalesce((banner->>'color1')::int, 0), coalesce((banner->>'color2')::int, 0)
            FROM guilds WHERE guild_id = @g
            """, conn, tx))
        {
            g.Parameters.AddWithValue("g", me.GuildId);
            await using var r = await g.ExecuteReaderAsync(ct);
            await r.ReadAsync(ct);
            (name, tag, symbol, color1, color2) = (r.GetString(0), r.IsDBNull(1) ? null : r.GetString(1), r.GetInt32(2), r.GetInt32(3), r.GetInt32(4));
        }
        var members = new List<GuildMemberInfo>();
        await using (var m = new NpgsqlCommand(
            """
            SELECT c.character_id, c.name, m.rank_no, r.name, p.zone_id
            FROM guild_members m JOIN characters c USING (character_id) JOIN guild_ranks r USING (guild_id, rank_no)
            LEFT JOIN character_presence p ON p.character_id = c.character_id AND p.state = 'ONLINE'
            WHERE m.guild_id = @g ORDER BY m.rank_no, lower(c.name)
            """, conn, tx))
        {
            m.Parameters.AddWithValue("g", me.GuildId);
            await using var r = await m.ExecuteReaderAsync(ct);
            while (await r.ReadAsync(ct))
            {
                members.Add(new GuildMemberInfo(r.GetInt64(0), r.GetString(1), r.GetInt16(2), r.GetString(3), !r.IsDBNull(4),
                    r.IsDBNull(4) ? null : r.GetString(4)));
            }
        }
        var permissions = me.Rank.RankNo == GuildRules.LeaderRank ? GuildRules.KnownPermissions : me.Rank.Permissions;
        return new GuildInfo(me.GuildId, name, tag, symbol, color1, color2, me.Rank.RankNo, me.Rank.Name, permissions.Order().ToList(), max, members);
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
