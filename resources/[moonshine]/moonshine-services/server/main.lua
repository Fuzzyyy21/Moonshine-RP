--- API und Commands der Dienstleistungen.

exports('GetServicesObject', function()
    return Services
end)

--- Preis einer Reparatur (fuer andere Resources).
exports('GetRepairPrice', function(engine, body, discount)
    return Services.RepairPrice(engine, body, discount)
end)

--- Sprit gutschreiben, ohne dass jemand bezahlt.
exports('GrantFuel', function(source, plate, amount)
    TriggerClientEvent('services:client:fuelGranted', source, plate,
        math.max(0, math.min(100, math.floor(tonumber(amount) or 0))))

    return true
end)

--- Fahrzeug ohne Bezahlung reparieren.
exports('GrantRepair', function(source, plate, duration)
    TriggerClientEvent('services:client:repairGranted', source, plate,
        math.max(1, math.floor(tonumber(duration) or 5)), false)

    return true
end)

-- Commands --------------------------------------------------------------------

local function permission(source, level)
    if source == 0 then return true end

    local player = MS.GetPlayer(source)
    return player ~= nil and (player.adminLevel or 0) >= level
end

RegisterCommand('kontostand', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    player:Notify(('Bar %s · Bank %s · Schwarz %s'):format(
        MS.Utils.FormatMoney(player:GetMoney('cash')),
        MS.Utils.FormatMoney(player:GetMoney('bank')),
        MS.Utils.FormatMoney(player:GetMoney('black'))), 'info', 9000)
end, false)

RegisterCommand('ueberweisen', function(source, args)
    local player = MS.GetPlayer(source)
    if not player then return end

    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])

    if not targetId or not amount then
        player:Notify('Verwendung: /ueberweisen [id] [betrag] - nur in der Filiale.',
            'info', 8000)
        return
    end

    Services.Transfer(source, targetId, amount)
end, false)

RegisterCommand('schwarzmarkt', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    if not Services.MarketAt then
        player:Notify('Vom Schwarzmarkt hoert man derzeit nichts.', 'info')
        return
    end

    local minutes = math.ceil(math.max(0,
        (Services.MarketSince + ServiceConfig.BlackMarket.moveInterval * 60)
        - os.time()) / 60)

    player:Notify(('Der Markt steht bei "%s" - noch etwa %d Minuten.'):format(
        Services.MarketAt.label, minutes), 'info', 9000)
end, false)

RegisterCommand('marktumzug', function(source)
    if not permission(source, 3) then return end
    exports[GetCurrentResourceName()]:MoveBlackMarket()
end, false)

print('^2[Dienste]^7 Tankstellen, Werkstaetten, Bank und Schwarzmarkt geladen.')
