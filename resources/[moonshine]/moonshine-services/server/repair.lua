--- Werkstaetten: Reparatur gegen Geld, Reparaturkit fuer unterwegs.

--- Steht der Spieler an einer Werkstatt?
function Services.AtWorkshop(source)
    local coords = GetEntityCoords(GetPlayerPed(source))

    for _, shop in ipairs(Services.Workshops) do
        if #(coords - shop.coords) <= ServiceConfig.Range + 4.0 then return shop end
    end

    return nil
end

--- Rabatt fuer den Spieler.
local function discountFor(player)
    local config = ServiceConfig.Repair

    if player.job and player.job.name == config.mechanicJob then
        return config.mechanicDiscount
    end

    return 0
end

--- Der Client fragt nach dem Preis.
MS.RegisterServerCallback('services:repairQuote', function(player, cb, engine, body)
    if not player then return cb(nil) end

    if not Services.AtWorkshop(player.source) then return cb(nil) end

    local discount = discountFor(player)

    cb({
        price    = Services.RepairPrice(engine, body, discount),
        discount = discount,
        duration = ServiceConfig.Repair.duration,
        balance  = player:GetMoney(ServiceConfig.Repair.account),
    })
end)

--- Reparatur beauftragen.
RegisterNetEvent('services:server:repair', function(plate, engine, body)
    local source = source
    local player = MS.GetPlayer(source)
    if not player or not ServiceConfig.Repair.enabled then return end

    local shop = Services.AtWorkshop(source)
    if not shop then
        player:Notify('Du stehst an keiner Werkstatt.', 'error')
        return
    end

    engine = math.max(0, math.min(100, math.floor(tonumber(engine) or 100)))
    body   = math.max(0, math.min(100, math.floor(tonumber(body) or 100)))

    if engine >= 100 and body >= 100 then
        player:Notify('Das Fahrzeug ist in Ordnung.', 'info')
        return
    end

    local discount = discountFor(player)
    local price = Services.RepairPrice(engine, body, discount)
    local account = ServiceConfig.Repair.account

    if not player:RemoveMoney(price, account, 'werkstatt') then
        player:Notify(('Die Reparatur kostet %s.'):format(
            MS.Utils.FormatMoney(price)), 'error')
        return
    end

    TriggerClientEvent('services:client:repairGranted', source, plate,
        ServiceConfig.Repair.duration, false)

    player:Notify(('Reparatur fuer %s beauftragt.'):format(
        MS.Utils.FormatMoney(price)), 'success')

    TriggerEvent('services:server:vehicleRepaired', source, plate, price)
end)

--- Reparaturkit aus dem Inventar.
CreateThread(function()
    Wait(3000)

    local config = ServiceConfig.Repair.kit

    MS.RegisterUsableItem(config.item, function(player, slot)
        TriggerClientEvent('services:client:useKit', player.source, slot)
    end)
end)

RegisterNetEvent('services:server:kitUsed', function(slot, plate)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local config = ServiceConfig.Repair.kit

    if not player:RemoveItem(config.item, 1, tonumber(slot)) then return end

    TriggerClientEvent('services:client:repairGranted', source, plate,
        config.duration, true)
end)
