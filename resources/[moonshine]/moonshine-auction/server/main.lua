--- Netz-Events, Commands und API des Auktionshauses.

--- Steht der Spieler wirklich an einem Auktionshaus?
local function atAuctionHouse(source)
    local coords = GetEntityCoords(GetPlayerPed(source))

    for _, ped in ipairs(AuctionConfig.Peds) do
        if #(coords - vector3(ped.coords.x, ped.coords.y, ped.coords.z))
            <= AuctionConfig.Range + 2.0 then
            return true
        end
    end

    return false
end

local function reply(source, ok, message)
    if message and message ~= '' then
        exports['moonshine-core']:Notify(source, message, ok and 'success' or 'error', 7000)
    end
end

-- Oeffnen und Schliessen ---------------------------------------------------------

RegisterNetEvent('auction:server:open', function()
    local source = source
    local player = MS.GetPlayer(source)
    if not player or not atAuctionHouse(source) then return end

    Auction.Viewers[source] = true

    Auction.Sync(source)
    Auction.SyncMail(source)
end)

RegisterNetEvent('auction:server:close', function()
    Auction.Viewers[source] = nil
end)

RegisterNetEvent('auction:server:request', function()
    local source = source
    if not MS.GetPlayer(source) then return end

    Auction.Sync(source)
end)

-- Handeln --------------------------------------------------------------------------

RegisterNetEvent('auction:server:create', function(slot, count, startPrice, buyout, hours)
    local source = source
    if not MS.GetPlayer(source) or not atAuctionHouse(source) then return end

    local ok, message = Auction.Create(source, slot, count, startPrice, buyout, hours)
    reply(source, ok, message)

    Auction.Sync(source)
end)

RegisterNetEvent('auction:server:bid', function(auctionId, amount)
    local source = source
    if not MS.GetPlayer(source) or not atAuctionHouse(source) then return end

    local ok, message = Auction.Bid(source, auctionId, amount)
    reply(source, ok, message)

    Auction.Sync(source)
end)

RegisterNetEvent('auction:server:buyout', function(auctionId)
    local source = source
    if not MS.GetPlayer(source) or not atAuctionHouse(source) then return end

    local ok, message = Auction.Buyout(source, auctionId)
    reply(source, ok, message)

    Auction.Sync(source)
    Auction.SyncMail(source)
end)

RegisterNetEvent('auction:server:cancel', function(auctionId)
    local source = source
    if not MS.GetPlayer(source) or not atAuctionHouse(source) then return end

    local ok, message = Auction.Cancel(source, auctionId)
    reply(source, ok, message)

    Auction.Sync(source)
    Auction.SyncMail(source)
end)

-- Abholfach -------------------------------------------------------------------------

RegisterNetEvent('auction:server:claim', function(mailId)
    local source = source
    if not MS.GetPlayer(source) or not atAuctionHouse(source) then return end

    local ok, message = Auction.ClaimMail(source, mailId)
    reply(source, ok, message)

    Auction.Sync(source)
end)

RegisterNetEvent('auction:server:claimAll', function()
    local source = source
    if not MS.GetPlayer(source) or not atAuctionHouse(source) then return end

    local claimed = Auction.ClaimAll(source)

    reply(source, claimed > 0, claimed > 0
        and ('%d Eintraege abgeholt.'):format(claimed)
        or 'Es liess sich nichts abholen.')

    Auction.Sync(source)
end)

-- Inventar fuer die Oberflaeche --------------------------------------------------------

MS.RegisterServerCallback('auction:inventory', function(player, cb)
    if not player then return cb({}) end

    local entries = {}

    for _, entry in ipairs(player.inventory or {}) do
        if entry and entry.name and not Auction.IsBlocked(entry.name) then
            local item = MS.GetItem(entry.name)

            entries[#entries + 1] = {
                slot  = entry.slot,
                name  = entry.name,
                label = item and item.label or entry.name,
                count = entry.count,
            }
        end
    end

    table.sort(entries, function(a, b) return a.label < b.label end)
    cb(entries)
end)

-- Lebenszyklus ---------------------------------------------------------------------------

AddEventHandler('moonshine:server:playerLoaded', function(source, player)
    CreateThread(function()
        Wait(4000)

        if not Auction.DB.Ready then return end

        local mail = Auction.DB.LoadMail(player.charId)
        if #mail > 0 then
            exports['moonshine-core']:Notify(source,
                ('Im Auktionshaus warten %d Eintraege auf dich.'):format(#mail), 'info', 9000)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    Auction.Viewers[source] = nil
end)

-- API --------------------------------------------------------------------------------------

exports('GetAuctionObject', function()
    return Auction
end)

exports('GetOpenAuctions', function()
    local list = {}
    for id, auction in pairs(Auction.List) do list[id] = auction end
    return list
end)

--- Etwas ins Abholfach legen (z. B. aus anderen Systemen).
exports('DeliverToPlayer', function(characterId, entry)
    return Auction.Deliver(characterId, entry)
end)

-- Commands ----------------------------------------------------------------------------------

RegisterCommand('auktionen', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local own, bids = 0, 0

    for _, auction in pairs(Auction.List) do
        if auction.sellerId == player.charId then own = own + 1 end
        if auction.bidderId == player.charId then bids = bids + 1 end
    end

    player:Notify(('%d eigene Auktionen, %d Hoechstgebote.'):format(own, bids), 'info', 8000)
end, false)

RegisterCommand('auktionabbrechen', function(source, args)
    local player = MS.GetPlayer(source)
    if not player or (player.adminLevel or 0) < 3 then return end

    local auction = Auction.List[tonumber(args[1]) or -1]
    if not auction then return end

    -- Gebot erstatten, Ware zurueck an den Verkaeufer.
    if auction.bidderId and auction.bid > 0 then
        Auction.Deliver(auction.bidderId, {
            kind = 'money', amount = auction.bid, reason = 'Auktion durch Admin beendet',
        })
    end

    auction.bidderId = nil
    auction.bid = 0

    Auction.Settle(auction, 'abgebrochen')
end, false)

print('^2[Auktion]^7 Auktionshaus geladen.')
