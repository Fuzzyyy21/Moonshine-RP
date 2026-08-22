--- Auktionslogik: einstellen, bieten, abrechnen.
---
--- Alle offenen Auktionen liegen im Speicher und werden bei jeder Aenderung
--- geschrieben. Geld wird beim Bieten sofort abgebucht und beim
--- Ueberbotenwerden zurueckgegeben - so kann niemand mit Geld bieten, das er
--- gar nicht mehr hat.

MS = MS or exports['moonshine-core']:GetCoreObject()

Auction.List = {}   -- [id] = Auktion

local function decode(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return nil end

    local ok, value = pcall(json.decode, raw)
    return ok and value or nil
end

local function nameOf(player)
    return ('%s %s'):format(player.firstname or '?', player.lastname or '')
end

--- Alle offenen Auktionen aus der Datenbank holen.
function Auction.LoadAll()
    for _, row in ipairs(Auction.DB.LoadOpen()) do
        Auction.List[row.id] = {
            id         = row.id,
            sellerId   = row.seller_id,
            sellerName = row.seller_name,
            item       = row.item,
            label      = row.label,
            count      = row.count,
            metadata   = decode(row.metadata),
            category   = row.category,
            startPrice = tonumber(row.start_price) or 0,
            buyout     = tonumber(row.buyout),
            bid        = tonumber(row.bid) or 0,
            bidderId   = row.bidder_id,
            bidderName = row.bidder_name,
            endsAt     = tonumber(row.ends_at) or 0,
        }
    end

    local count = 0
    for _ in pairs(Auction.List) do count = count + 1 end

    print(('^2[Auktion]^7 %d offene Auktionen geladen.'):format(count))
end

-- Abholfach ---------------------------------------------------------------------

--- Legt etwas ins Abholfach eines Charakters.
function Auction.Deliver(characterId, entry)
    Auction.DB.AddMail(characterId, entry)

    local source = Auction.GetSourceOf(characterId)
    if source then
        exports['moonshine-core']:Notify(source,
            'Im Auktionshaus wartet etwas auf dich.', 'info', 8000)

        Auction.SyncMail(source)
    end
end

--- Quelle eines Charakters, wenn er online ist.
function Auction.GetSourceOf(characterId)
    for _, player in pairs(MS.GetPlayers()) do
        if player.charId == characterId then return player.source end
    end

    return nil
end

--- Schickt das Abholfach an einen Spieler.
function Auction.SyncMail(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local entries = {}

    for _, row in ipairs(Auction.DB.LoadMail(player.charId)) do
        entries[#entries + 1] = {
            id     = row.id,
            kind   = row.kind,
            item   = row.item,
            label  = row.label,
            count  = row.count,
            amount = tonumber(row.amount) or 0,
            reason = row.reason,
            date   = tostring(row.created_at or ''),
        }
    end

    TriggerClientEvent('auction:client:mail', source, entries)
end

-- Anzeige --------------------------------------------------------------------------

--- Baut die Liste aller laufenden Auktionen.
function Auction.BuildPayload(source)
    local player = MS.GetPlayer(source)
    local characterId = player and player.charId
    local now = os.time()

    local entries = {}

    for _, auction in pairs(Auction.List) do
        entries[#entries + 1] = {
            id         = auction.id,
            item       = auction.item,
            label      = auction.label,
            count      = auction.count,
            category   = auction.category,
            seller     = auction.sellerName,
            isOwn      = auction.sellerId == characterId,
            startPrice = auction.startPrice,
            buyout     = auction.buyout,
            bid        = auction.bid,
            bidder     = auction.bidderName,
            isBidder   = auction.bidderId == characterId,
            minimum    = auction.bid > 0 and Auction.MinimumBid(auction.bid) or auction.startPrice,
            remaining  = math.max(0, auction.endsAt - now),
        }
    end

    table.sort(entries, function(a, b) return a.remaining < b.remaining end)

    return {
        auctions   = entries,
        money      = player and player:GetMoney(AuctionConfig.Account) or 0,
        account    = AuctionConfig.Account,
        fee        = AuctionConfig.Fee,
        listingFee = AuctionConfig.ListingFee,
        durations  = AuctionConfig.Durations,
        categories = AuctionConfig.Categories,
        limits     = AuctionConfig.Limits,
    }
end

function Auction.Sync(source)
    TriggerClientEvent('auction:client:sync', source, Auction.BuildPayload(source))
end

--- Alle, die gerade im Auktionshaus stehen, bekommen die neuen Daten.
function Auction.SyncViewers()
    for source in pairs(Auction.Viewers or {}) do
        if MS.GetPlayer(source) then Auction.Sync(source) end
    end
end

Auction.Viewers = {}

-- Einstellen -------------------------------------------------------------------------

--- Legt eine Auktion an.
---@return boolean ok, string message
--- @rennen Geprueft. Die Wertbewegung dahinter ist eine Ruecknahme: schlaegt
--- das Anlegen fehl, kommen Ware und Gebuehr zurueck. Verdoppeln laesst sich
--- damit nichts - RemoveItem davor entscheidet, und das wartet nicht. Das
--- Rennen um CountOpenOf kann hoechstens eine Auktion ueber dem Limit
--- erlauben; das kostet niemanden etwas.
function Auction.Create(source, slot, count, startPrice, buyout, hours)
    local player = MS.GetPlayer(source)
    if not player then return false, '' end

    slot       = math.floor(tonumber(slot) or 0)
    count      = math.floor(tonumber(count) or 1)
    startPrice = math.floor(tonumber(startPrice) or 0)
    buyout     = buyout and math.floor(tonumber(buyout) or 0) or nil
    hours      = math.floor(tonumber(hours) or 0)

    local limits = AuctionConfig.Limits

    local allowedDuration = false
    for _, entry in ipairs(AuctionConfig.Durations) do
        if entry == hours then allowedDuration = true break end
    end
    if not allowedDuration then return false, 'Diese Laufzeit gibt es nicht.' end

    if count < 1 or count > limits.maxCount then
        return false, 'Diese Menge geht nicht.'
    end

    if startPrice < limits.minPrice or startPrice > limits.maxPrice then
        return false, ('Der Startpreis muss zwischen %s und %s liegen.'):format(
            MS.Utils.FormatMoney(limits.minPrice), MS.Utils.FormatMoney(limits.maxPrice))
    end

    if buyout and buyout > 0 then
        if buyout < startPrice then return false, 'Der Sofortkauf darf nicht unter dem Startpreis liegen.' end
        if buyout > limits.maxPrice then return false, 'Der Sofortkauf ist zu hoch.' end
    else
        buyout = nil
    end

    if Auction.DB.CountOpenOf(player.charId) >= limits.perPlayer then
        return false, ('Du hast schon %d Auktionen laufen.'):format(limits.perPlayer)
    end

    local entry = player:GetSlot(slot)
    if not entry or entry.count < count then return false, 'Das hast du nicht dabei.' end

    if Auction.IsBlocked(entry.name) then
        return false, 'Dieser Gegenstand darf nicht versteigert werden.'
    end

    local item = MS.GetItem(entry.name)
    if not item then return false, 'Unbekannter Gegenstand.' end

    if player:GetMoney(AuctionConfig.Account) < AuctionConfig.ListingFee then
        return false, ('Die Einstellgebuehr betraegt %s.'):format(
            MS.Utils.FormatMoney(AuctionConfig.ListingFee))
    end

    local name, metadata = entry.name, entry.metadata

    if not player:RemoveItem(name, count, slot) then
        return false, 'Der Gegenstand liess sich nicht einlagern.'
    end

    player:RemoveMoney(AuctionConfig.ListingFee, AuctionConfig.Account, 'auktion-gebuehr')

    local endsAt = os.time() + hours * 3600
    local sellerName = nameOf(player)

    local id = Auction.DB.Insert({
        sellerId = player.charId, sellerName = sellerName,
        item = name, label = item.label, count = count, metadata = metadata,
        category = Auction.GetCategory(name),
        startPrice = startPrice, buyout = buyout, endsAt = endsAt,
    })

    if not id then
        player:AddItem(name, count, metadata)
        player:AddMoney(AuctionConfig.ListingFee, AuctionConfig.Account, 'auktion-rueckerstattung')
        return false, 'Die Auktion konnte nicht angelegt werden.'
    end

    Auction.List[id] = {
        id = id, sellerId = player.charId, sellerName = sellerName,
        item = name, label = item.label, count = count, metadata = metadata,
        category = Auction.GetCategory(name),
        startPrice = startPrice, buyout = buyout, bid = 0,
        bidderId = nil, bidderName = nil, endsAt = endsAt,
    }

    MS.Logger.Log('item', ('%s versteigert %dx %s ab %s.'):format(
        sellerName, count, item.label, MS.Utils.FormatMoney(startPrice)), player.license)

    TriggerEvent('auction:server:created', id, player.charId)
    Auction.SyncViewers()

    return true, ('%dx %s steht jetzt zur Auktion.'):format(count, item.label)
end

-- Bieten -----------------------------------------------------------------------------

---@return boolean ok, string message
function Auction.Bid(source, auctionId, amount)
    local player = MS.GetPlayer(source)
    if not player then return false, '' end

    local auction = Auction.List[tonumber(auctionId) or -1]
    if not auction then return false, 'Diese Auktion laeuft nicht mehr.' end

    if auction.sellerId == player.charId then
        return false, 'Auf die eigene Auktion darfst du nicht bieten.'
    end

    if auction.endsAt <= os.time() then return false, 'Diese Auktion ist vorbei.' end

    amount = math.floor(tonumber(amount) or 0)

    local minimum = auction.bid > 0 and Auction.MinimumBid(auction.bid) or auction.startPrice
    if amount < minimum then
        return false, ('Mindestens %s.'):format(MS.Utils.FormatMoney(minimum))
    end

    if amount > AuctionConfig.Limits.maxPrice then return false, 'Das Gebot ist zu hoch.' end

    -- Ab hier gilt: erst den Zustand setzen, dann erstatten.
    --
    -- Die Erstattung schreibt ins Abholfach und wartet dabei auf die
    -- Datenbank - das unterbricht. Stand die Auktion in diesem Moment noch
    -- auf dem alten Bieter, sah ein zweites, gleichzeitiges Gebot ihn immer
    -- noch als Hoechstbietenden und erstattete ihm sein Geld ein zweites
    -- Mal. Aus dem Nichts.
    local vorherBieter = auction.bidderId
    local vorherGebot  = auction.bid
    local selbst       = vorherBieter == player.charId

    -- Geld einziehen. RemoveMoney rechnet im Speicher und unterbricht nicht.
    local abbuchen = selbst and (amount - vorherGebot) or amount

    if not player:RemoveMoney(abbuchen, AuctionConfig.Account, 'auktion-gebot') then
        return false, ('Dir fehlen %s.'):format(MS.Utils.FormatMoney(
            abbuchen - player:GetMoney(AuctionConfig.Account)))
    end

    auction.bid = amount
    auction.bidderId = player.charId
    auction.bidderName = nameOf(player)

    -- Kurz vor Schluss verlaengern, damit niemand im letzten Moment abgreift.
    local snipe = AuctionConfig.AntiSnipe
    if snipe.enabled and auction.endsAt - os.time() <= snipe.within then
        auction.endsAt = auction.endsAt + snipe.extend
    end

    -- Erst jetzt, wo die Auktion niemandem mehr gehoert, wird erstattet.
    if not selbst and vorherBieter and vorherGebot > 0 then
        Auction.Deliver(vorherBieter, {
            kind = 'money', amount = vorherGebot,
            reason = ('Ueberboten: %dx %s'):format(auction.count, auction.label),
        })

        local previous = Auction.GetSourceOf(vorherBieter)
        if previous then
            exports['moonshine-core']:Notify(previous,
                ('Du wurdest bei %dx %s ueberboten.'):format(
                    auction.count, auction.label), 'warning', 8000)
        end
    end

    Auction.DB.SaveBid(auction.id, auction.bid, auction.bidderId,
        auction.bidderName, auction.endsAt)

    TriggerEvent('auction:server:bid', auction.id, player.charId, amount)
    Auction.SyncViewers()

    return true, ('Gebot ueber %s abgegeben.'):format(MS.Utils.FormatMoney(amount))
end

-- Sofortkauf --------------------------------------------------------------------------

---@return boolean ok, string message
function Auction.Buyout(source, auctionId)
    local player = MS.GetPlayer(source)
    if not player then return false, '' end

    local auction = Auction.List[tonumber(auctionId) or -1]
    if not auction then return false, 'Diese Auktion laeuft nicht mehr.' end

    if not auction.buyout or auction.buyout <= 0 then
        return false, 'Fuer diese Auktion gibt es keinen Sofortkauf.'
    end

    if auction.sellerId == player.charId then
        return false, 'Das ist deine eigene Auktion.'
    end

    if auction.endsAt <= os.time() then return false, 'Diese Auktion ist vorbei.' end

    if auction.abgerechnet then return false, 'Diese Auktion laeuft nicht mehr.' end

    -- Wer schon Hoechstbietender ist, zahlt nur die Differenz.
    local vorherBieter = auction.bidderId
    local vorherGebot  = auction.bid

    local due = auction.buyout
    if vorherBieter == player.charId then due = math.max(0, auction.buyout - vorherGebot) end

    if due > 0 and not player:RemoveMoney(due, AuctionConfig.Account, 'auktion-sofortkauf') then
        return false, ('Dir fehlen %s.'):format(MS.Utils.FormatMoney(
            due - player:GetMoney(AuctionConfig.Account)))
    end

    -- Die Auktion gehoert ab hier diesem Kaeufer. Das muss vor dem ersten
    -- Warten auf die Datenbank passieren.
    --
    -- Vorher stand hier zuerst die Erstattung an den alten Bieter, und die
    -- schreibt ins Abholfach. Waehrend sie wartete, konnte ein Zweiter
    -- dieselbe Auktion kaufen: beide zahlten, beide erstatteten demselben
    -- Bieter, und Auction.Settle lief zweimal - die Ware wurde ausgeliefert,
    -- der Verkaeufer zweimal bezahlt.
    auction.abgerechnet = true
    Auction.List[auction.id] = nil

    auction.bid = auction.buyout
    auction.bidderId = player.charId
    auction.bidderName = nameOf(player)

    -- Ein fremdes Gebot wird erstattet.
    if vorherBieter and vorherBieter ~= player.charId and vorherGebot > 0 then
        Auction.Deliver(vorherBieter, {
            kind = 'money', amount = vorherGebot,
            reason = ('Sofortkauf: %dx %s'):format(auction.count, auction.label),
        })
    end

    Auction.Settle(auction, 'verkauft')

    return true, ('%dx %s gekauft.'):format(auction.count, auction.label)
end

-- Abrechnen ----------------------------------------------------------------------------

--- Schliesst eine Auktion ab und verteilt Ware und Geld.
function Auction.Settle(auction, status)
    -- Abgerechnet wird genau einmal.
    --
    -- Die Marke sitzt auf der Auktion selbst und nicht in Auction.List:
    -- wer die Auktion vor einem Warten in eine lokale Variable geholt hat,
    -- haelt sie auch dann noch, wenn sie aus der Liste verschwunden ist.
    if auction.abgerechnetFertig then return false end
    auction.abgerechnetFertig = true
    auction.abgerechnet = true

    Auction.List[auction.id] = nil
    Auction.DB.SetStatus(auction.id, status)

    if auction.bidderId and auction.bid > 0 then
        -- Ware an den Kaeufer.
        Auction.Deliver(auction.bidderId, {
            kind = 'item', item = auction.item, label = auction.label,
            count = auction.count, metadata = auction.metadata,
            reason = ('Ersteigert fuer %s'):format(MS.Utils.FormatMoney(auction.bid)),
        })

        -- Erloes abzueglich Gebuehr an den Verkaeufer.
        local fee = math.floor(auction.bid * AuctionConfig.Fee)
        local payout = auction.bid - fee

        Auction.Deliver(auction.sellerId, {
            kind = 'money', amount = payout,
            reason = ('Verkauft: %dx %s (Gebuehr %s)'):format(
                auction.count, auction.label, MS.Utils.FormatMoney(fee)),
        })

        local seller = Auction.GetSourceOf(auction.sellerId)
        if seller then
            exports['moonshine-core']:Notify(seller,
                ('%dx %s wurde fuer %s verkauft.'):format(
                    auction.count, auction.label, MS.Utils.FormatMoney(auction.bid)),
                'success', 9000)
        end

        local buyer = Auction.GetSourceOf(auction.bidderId)
        if buyer then
            exports['moonshine-core']:Notify(buyer,
                ('Du hast %dx %s ersteigert.'):format(auction.count, auction.label),
                'success', 9000)
        end

        TriggerEvent('auction:server:sold', auction.id, auction.sellerId,
            auction.bidderId, auction.bid)
    else
        -- Ohne Gebot geht die Ware zurueck.
        Auction.Deliver(auction.sellerId, {
            kind = 'item', item = auction.item, label = auction.label,
            count = auction.count, metadata = auction.metadata,
            reason = 'Auktion ohne Gebot beendet',
        })

        local seller = Auction.GetSourceOf(auction.sellerId)
        if seller then
            exports['moonshine-core']:Notify(seller,
                ('%dx %s kam ohne Gebot zurueck.'):format(auction.count, auction.label),
                'warning', 9000)
        end
    end

    Auction.SyncViewers()
    return true
end

--- Der Verkaeufer bricht ab - geht nur ohne Gebot.
---@return boolean ok, string message
function Auction.Cancel(source, auctionId)
    local player = MS.GetPlayer(source)
    if not player then return false, '' end

    local auction = Auction.List[tonumber(auctionId) or -1]
    if not auction then return false, 'Diese Auktion laeuft nicht mehr.' end

    if auction.sellerId ~= player.charId then return false, 'Das ist nicht deine Auktion.' end

    if auction.bidderId then
        return false, 'Es liegt bereits ein Gebot vor.'
    end

    Auction.Settle(auction, 'abgebrochen')
    return true, 'Die Auktion wurde abgebrochen.'
end

-- Abholen -------------------------------------------------------------------------------

--- Gibt ein Fach aus. Nur ueber Auction.ClaimMail aufrufen - die Sperre
--- gegen doppeltes Abholen sitzt dort.
--- @rennen Abgesichert: geloescht wird vor dem Auszahlen, und ausgezahlt
--- nur, wenn das Loeschen wirklich eine Zeile getroffen hat. Dazu haelt
--- Auction.ClaimMail eine Sperre auf der Fachnummer.
local function vergeben(player, source, id)
    local row = Auction.DB.GetMail(id, player.charId)
    if not row then return false, 'Da wartet nichts auf dich.' end

    if row.kind == 'money' then
        local betrag = tonumber(row.amount) or 0

        -- Erst loeschen, dann auszahlen: bleibt das Loeschen ohne Wirkung,
        -- war ein anderer schneller und es gibt nichts mehr auszuzahlen.
        if (Auction.DB.RemoveMail(row.id) or 0) < 1 then
            return false, 'Da wartet nichts auf dich.'
        end

        player:AddMoney(betrag, AuctionConfig.Account, 'auktion-auszahlung')
        Auction.SyncMail(source)

        return true, ('%s erhalten.'):format(MS.Utils.FormatMoney(betrag))
    end

    local count = tonumber(row.count) or 0
    if count < 1 then
        Auction.DB.RemoveMail(row.id)
        return false, 'Der Eintrag war leer.'
    end

    if not player:CanCarryItem(row.item, count) then
        return false, 'So viel kannst du gerade nicht tragen.'
    end

    if (Auction.DB.RemoveMail(row.id) or 0) < 1 then
        return false, 'Da wartet nichts auf dich.'
    end

    -- AddItem rechnet im Speicher und kann nach der bestandenen
    -- Traglastpruefung nicht mehr scheitern. Falls doch, kommt der Eintrag
    -- zurueck ins Fach - verloren geht nichts.
    if not player:AddItem(row.item, count, decode(row.metadata)) then
        Auction.DB.AddMail(player.charId, {
            kind = 'item', item = row.item, label = row.label, count = count,
            metadata = decode(row.metadata), reason = row.reason,
        })

        return false, 'Das passt nicht in dein Inventar.'
    end

    Auction.SyncMail(source)

    return true, ('%dx %s erhalten.'):format(count, row.label or row.item)
end

--- Welche Faecher gerade ausgegeben werden.
---
--- Ohne diese Sperre laesst sich derselbe Eintrag mehrfach abholen: das
--- Lesen aus der Datenbank wartet, und in dieser Zeit kommt der zweite
--- Aufruf durch dieselbe Pruefung. Beide zahlen aus, geloescht wird
--- hinterher - einmal Geld oder Ware aus dem Nichts.
Auction.Claiming = {}

---@return boolean ok, string message
function Auction.ClaimMail(source, mailId)
    local player = MS.GetPlayer(source)
    if not player then return false, '' end

    local id = math.floor(tonumber(mailId) or 0)
    if id < 1 then return false, 'Da wartet nichts auf dich.' end

    if Auction.Claiming[id] then return false, 'Das wird gerade schon abgeholt.' end
    Auction.Claiming[id] = true

    local ok, a, b = pcall(vergeben, player, source, id)

    Auction.Claiming[id] = nil

    if not ok then
        print(('^1[Auktion]^7 Abholen fehlgeschlagen: %s'):format(tostring(a)))
        return false, 'Das hat nicht geklappt.'
    end

    return a, b
end

--- Holt alles ab, was moeglich ist.
function Auction.ClaimAll(source)
    local player = MS.GetPlayer(source)
    if not player then return 0 end

    local claimed = 0

    for _, row in ipairs(Auction.DB.LoadMail(player.charId)) do
        local ok = Auction.ClaimMail(source, row.id)
        if ok then claimed = claimed + 1 end
    end

    return claimed
end

-- Ablauf ----------------------------------------------------------------------------------

CreateThread(function()
    while not Auction.DB.Ready do Wait(500) end

    Auction.LoadAll()

    while true do
        Wait(5000)

        local now = os.time()

        -- Erst sammeln, dann abrechnen.
        --
        -- Auction.Settle wartet auf die Datenbank, und waehrenddessen kann
        -- sich Auction.List aendern - ein Sofortkauf entfernt einen
        -- Eintrag, ein neues Angebot legt einen an. Ueber eine Tabelle zu
        -- laufen, die sich unter einem veraendert, ist in Lua nicht
        -- definiert.
        local faellig = {}

        for _, auction in pairs(Auction.List) do
            if auction.endsAt <= now and not auction.abgerechnet then
                faellig[#faellig + 1] = auction
            end
        end

        for _, auction in ipairs(faellig) do
            local ok, err = pcall(Auction.Settle, auction, 'beendet')
            if not ok then
                print(('^1[Auktion]^7 Abrechnung fehlgeschlagen: %s'):format(tostring(err)))
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(60 * 60000)
        if Auction.DB.Ready then pcall(Auction.DB.Cleanup, 14) end
    end
end)
