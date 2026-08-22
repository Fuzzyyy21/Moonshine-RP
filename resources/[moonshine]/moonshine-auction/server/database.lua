--- Datenbank des Auktionshauses.

Auction.DB = {}
Auction.DB.Ready = false

local SCHEMA = {
    [[
    CREATE TABLE IF NOT EXISTS `ms_auctions` (
        `id`           INT          NOT NULL AUTO_INCREMENT,
        `seller_id`    INT          NOT NULL,
        `seller_name`  VARCHAR(64)  NOT NULL,
        `item`         VARCHAR(48)  NOT NULL,
        `label`        VARCHAR(64)  NOT NULL,
        `count`        INT          NOT NULL DEFAULT 1,
        `metadata`     LONGTEXT     DEFAULT NULL,
        `category`     VARCHAR(24)  NOT NULL DEFAULT 'sonstiges',
        `start_price`  BIGINT       NOT NULL,
        `buyout`       BIGINT       DEFAULT NULL,
        `bid`          BIGINT       NOT NULL DEFAULT 0,
        `bidder_id`    INT          DEFAULT NULL,
        `bidder_name`  VARCHAR(64)  DEFAULT NULL,
        `ends_at`      INT          NOT NULL,
        `status`       VARCHAR(16)  NOT NULL DEFAULT 'offen',
        `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `status` (`status`),
        KEY `seller_id` (`seller_id`),
        KEY `bidder_id` (`bidder_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],

    [[
    CREATE TABLE IF NOT EXISTS `ms_auction_mail` (
        `id`           INT          NOT NULL AUTO_INCREMENT,
        `character_id` INT          NOT NULL,
        `kind`         VARCHAR(12)  NOT NULL,
        `item`         VARCHAR(48)  DEFAULT NULL,
        `label`        VARCHAR(64)  DEFAULT NULL,
        `count`        INT          NOT NULL DEFAULT 0,
        `metadata`     LONGTEXT     DEFAULT NULL,
        `amount`       BIGINT       NOT NULL DEFAULT 0,
        `reason`       VARCHAR(128) NOT NULL DEFAULT '',
        `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `character_id` (`character_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],
}

MySQL.ready(function()
    local ok, err = pcall(function()
        for _, statement in ipairs(SCHEMA) do MySQL.query.await(statement) end
    end)

    if not ok then
        print(('^1[Auktion]^7 Schema konnte nicht angelegt werden: %s'):format(tostring(err)))
        return
    end

    Auction.DB.Ready = true
    print('^2[Auktion]^7 Datenbank bereit.')
end)

-- Auktionen -------------------------------------------------------------------

function Auction.DB.LoadOpen()
    return MySQL.query.await([[
        SELECT * FROM ms_auctions WHERE status = 'offen' ORDER BY ends_at ASC
    ]]) or {}
end

function Auction.DB.Insert(payload)
    return MySQL.insert.await([[
        INSERT INTO ms_auctions
            (seller_id, seller_name, item, label, count, metadata, category,
             start_price, buyout, bid, ends_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
    ]], {
        payload.sellerId, payload.sellerName, payload.item, payload.label,
        payload.count, payload.metadata and json.encode(payload.metadata) or nil,
        payload.category, payload.startPrice, payload.buyout, payload.endsAt,
    })
end

function Auction.DB.SaveBid(id, bid, bidderId, bidderName, endsAt)
    return MySQL.update.await([[
        UPDATE ms_auctions SET bid = ?, bidder_id = ?, bidder_name = ?, ends_at = ?
        WHERE id = ?
    ]], { bid, bidderId, bidderName, endsAt, id })
end

function Auction.DB.SetStatus(id, status)
    return MySQL.update.await('UPDATE ms_auctions SET status = ? WHERE id = ?', { status, id })
end

function Auction.DB.CountOpenOf(characterId)
    local row = MySQL.single.await([[
        SELECT COUNT(*) AS total FROM ms_auctions
        WHERE seller_id = ? AND status = 'offen'
    ]], { characterId })

    return row and tonumber(row.total) or 0
end

--- Aeltere abgeschlossene Auktionen aufraeumen.
function Auction.DB.Cleanup(days)
    return MySQL.update.await([[
        DELETE FROM ms_auctions
        WHERE status <> 'offen' AND created_at < DATE_SUB(NOW(), INTERVAL ? DAY)
    ]], { days or 14 })
end

-- Abholfach --------------------------------------------------------------------

function Auction.DB.AddMail(characterId, entry)
    return MySQL.insert.await([[
        INSERT INTO ms_auction_mail
            (character_id, kind, item, label, count, metadata, amount, reason)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        characterId, entry.kind, entry.item, entry.label, entry.count or 0,
        entry.metadata and json.encode(entry.metadata) or nil,
        entry.amount or 0, entry.reason or '',
    })
end

function Auction.DB.LoadMail(characterId)
    return MySQL.query.await([[
        SELECT * FROM ms_auction_mail WHERE character_id = ? ORDER BY id ASC
    ]], { characterId }) or {}
end

function Auction.DB.GetMail(mailId, characterId)
    return MySQL.single.await([[
        SELECT * FROM ms_auction_mail WHERE id = ? AND character_id = ?
    ]], { mailId, characterId })
end

--- Loescht ein Fach.
---@return number Wie viele Zeilen betroffen waren - 0 heisst: war schon weg.
function Auction.DB.RemoveMail(mailId)
    return MySQL.update.await('DELETE FROM ms_auction_mail WHERE id = ?', { mailId }) or 0
end
