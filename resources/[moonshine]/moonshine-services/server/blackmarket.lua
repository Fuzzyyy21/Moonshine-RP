--- Schwarzmarkt: wandernder Haendler, Schwarzgeld, Geldwaesche.
---
--- Der Markt steht immer nur an einem Ort und zieht regelmaessig um. Wo er
--- gerade steht, erfaehrt man erst, wenn man in der Naehe ist - der Blip
--- erscheint nur im Umkreis.

Services.MarketAt = nil     -- laufender Standort
Services.MarketSince = 0

--- Sucht einen neuen Standort (nie zweimal denselben hintereinander).
local function moveMarket(announce)
    local pool = {}

    for _, entry in ipairs(Services.BlackMarkets) do
        if not Services.MarketAt or entry.id ~= Services.MarketAt.id then
            pool[#pool + 1] = entry
        end
    end

    if #pool == 0 then pool = Services.BlackMarkets end

    Services.MarketAt = pool[math.random(#pool)]
    Services.MarketSince = os.time()

    TriggerClientEvent('services:client:market', -1, {
        id      = Services.MarketAt.id,
        label   = Services.MarketAt.label,
        coords  = { x = Services.MarketAt.coords.x, y = Services.MarketAt.coords.y,
                    z = Services.MarketAt.coords.z },
        heading = Services.MarketAt.heading or 0.0,
    })

    if announce and ServiceConfig.BlackMarket.announce then
        for _, player in pairs(MS.GetPlayers()) do
            player:Notify('Der Schwarzmarkt hat den Standort gewechselt.',
                'info', 8000)
        end
    end

    TriggerEvent('services:server:marketMoved', Services.MarketAt.id)
end

--- Steht der Spieler beim Schwarzmarkt?
function Services.AtMarket(source)
    if not Services.MarketAt then return false end

    local coords = GetEntityCoords(GetPlayerPed(source))
    return #(coords - Services.MarketAt.coords) <= ServiceConfig.Range + 3.0
end

--- Zustand fuer die Oberflaeche.
function Services.MarketPayload(source)
    local player = MS.GetPlayer(source)
    if not player then return nil end

    local config = ServiceConfig.BlackMarket

    local sells = {}
    for _, entry in ipairs(config.items) do
        local item = MS.GetItem(entry.name)
        sells[#sells + 1] = {
            name  = entry.name,
            label = entry.label or (item and item.label) or entry.name,
            price = entry.price,
        }
    end

    local buys = {}
    for _, entry in ipairs(config.buys) do
        local item = MS.GetItem(entry.name)
        buys[#buys + 1] = {
            name  = entry.name,
            label = entry.label or (item and item.label) or entry.name,
            price = entry.price,
            count = player:GetItemCount(entry.name),
        }
    end

    return {
        label   = Services.MarketAt and Services.MarketAt.label or 'Schwarzmarkt',
        black   = player:GetMoney('black'),
        cash    = player:GetMoney('cash'),
        sells   = sells,
        buys    = buys,
        laundering = config.laundering.enabled and {
            rate    = config.laundering.rate,
            maximum = config.laundering.maximum,
        } or nil,
        movesIn = math.max(0, (Services.MarketSince + config.moveInterval * 60) - os.time()),
    }
end

function Services.SyncMarket(source)
    local payload = Services.MarketPayload(source)
    if payload then
        TriggerClientEvent('services:client:blackmarket', source, payload)
    end
end

RegisterNetEvent('services:server:openMarket', function()
    local source = source
    if not MS.GetPlayer(source) or not Services.AtMarket(source) then return end

    Services.SyncMarket(source)
end)

-- Kaufen -------------------------------------------------------------------------

RegisterNetEvent('services:server:marketBuy', function(name, count)
    local source = source
    if not MS.RateLimit(source, 'services:server:marketBuy', 15, 10) then return end
    local player = MS.GetPlayer(source)
    if not player or not Services.AtMarket(source) then return end

    count = math.max(1, math.min(50, math.floor(tonumber(count) or 1)))

    local definition
    for _, entry in ipairs(ServiceConfig.BlackMarket.items) do
        if entry.name == name then definition = entry break end
    end

    if not definition then return end

    local item = MS.GetItem(name)
    if not item then return end

    local total = definition.price * count
    local account = ServiceConfig.BlackMarket.account

    if not player:CanCarryItem(name, count) then
        player:Notify('So viel kannst du nicht tragen.', 'error')
        return
    end

    if not player:RemoveMoney(total, account, 'schwarzmarkt') then
        player:Notify(('Dir fehlen %s Schwarzgeld.'):format(
            MS.Utils.FormatMoney(total - player:GetMoney(account))), 'error')
        return
    end

    player:AddItem(name, count)
    player:Notify(('%dx %s fuer %s.'):format(count, item.label,
        MS.Utils.FormatMoney(total)), 'success')

    Services.SyncMarket(source)
end)

-- Verkaufen -----------------------------------------------------------------------

RegisterNetEvent('services:server:marketSell', function(name, count)
    local source = source
    if not MS.RateLimit(source, 'services:server:marketSell', 15, 10) then return end
    local player = MS.GetPlayer(source)
    if not player or not Services.AtMarket(source) then return end

    count = math.max(1, math.min(500, math.floor(tonumber(count) or 1)))

    local definition
    for _, entry in ipairs(ServiceConfig.BlackMarket.buys) do
        if entry.name == name then definition = entry break end
    end

    if not definition then return end

    local item = MS.GetItem(name)
    if not item then return end

    if not player:RemoveItem(name, count) then
        player:Notify('So viel hast du nicht.', 'error')
        return
    end

    local total = definition.price * count
    player:AddMoney(total, ServiceConfig.BlackMarket.account, 'schwarzmarkt')

    player:Notify(('%dx %s verkauft: %s Schwarzgeld.'):format(
        count, item.label, MS.Utils.FormatMoney(total)), 'success')

    Services.SyncMarket(source)
end)

-- Geldwaesche ------------------------------------------------------------------------

RegisterNetEvent('services:server:launder', function(amount)
    local source = source
    if not MS.RateLimit(source, 'services:server:launder', 5, 10) then return end
    local player = MS.GetPlayer(source)
    if not player or not Services.AtMarket(source) then return end

    local config = ServiceConfig.BlackMarket.laundering
    if not config.enabled then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return end

    if amount > config.maximum then
        player:Notify(('Hoechstens %s auf einmal.'):format(
            MS.Utils.FormatMoney(config.maximum)), 'error')
        return
    end

    if not player:RemoveMoney(amount, 'black', 'geldwaesche') then
        player:Notify('So viel Schwarzgeld hast du nicht.', 'error')
        return
    end

    local clean = math.floor(amount * config.rate)
    player:AddMoney(clean, 'cash', 'geldwaesche')

    player:Notify(('%s gewaschen, %s ausgezahlt.'):format(
        MS.Utils.FormatMoney(amount), MS.Utils.FormatMoney(clean)), 'success', 9000)

    MS.Logger.Log('money', ('%s %s waescht %s.'):format(
        player.firstname, player.lastname, MS.Utils.FormatMoney(amount)),
        player.license)

    Services.SyncMarket(source)
end)

-- Standortwechsel -------------------------------------------------------------------

CreateThread(function()
    Wait(5000)
    moveMarket(false)

    while true do
        Wait(ServiceConfig.BlackMarket.moveInterval * 60000)

        if ServiceConfig.BlackMarket.enabled then moveMarket(true) end
    end
end)

--- Wer joint, erfaehrt den Standort.
AddEventHandler('moonshine:server:playerLoaded', function(source)
    CreateThread(function()
        Wait(4000)

        if Services.MarketAt then
            TriggerClientEvent('services:client:market', source, {
                id      = Services.MarketAt.id,
                label   = Services.MarketAt.label,
                coords  = { x = Services.MarketAt.coords.x,
                            y = Services.MarketAt.coords.y,
                            z = Services.MarketAt.coords.z },
                heading = Services.MarketAt.heading or 0.0,
            })
        end
    end)
end)

exports('GetBlackMarket', function()
    return Services.MarketAt and Services.MarketAt.id or nil
end)

exports('MoveBlackMarket', function()
    moveMarket(true)
    return Services.MarketAt and Services.MarketAt.id or nil
end)
