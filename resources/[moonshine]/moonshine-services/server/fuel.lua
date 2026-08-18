--- Tankstellen: Tanken und Kanister.
---
--- Der Tankstand selbst liegt in moonshine-vehicles. Hier wird nur bezahlt
--- und die Freigabe erteilt.

--- Steht der Spieler an einer Zapfsaeule?
---@return table|nil station
function Services.AtPump(source)
    local coords = GetEntityCoords(GetPlayerPed(source))

    for _, station in ipairs(Services.FuelStations) do
        for _, pump in ipairs(station.pumps) do
            if #(coords - pump) <= ServiceConfig.Fuel.nozzleRange + 1.5 then
                return station
            end
        end
    end

    return nil
end

--- Tankt ein Fahrzeug.
RegisterNetEvent('services:server:refuel', function(plate, amount)
    local source = source
    local player = MS.GetPlayer(source)
    if not player or not ServiceConfig.Fuel.enabled then return end

    if not Services.AtPump(source) then
        player:Notify('Du stehst an keiner Zapfsaeule.', 'error')
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > 100 then return end

    local cost = amount * ServiceConfig.Fuel.price
    local account = ServiceConfig.Fuel.account

    if not player:RemoveMoney(cost, account, 'tanken') then
        player:Notify(('Dir fehlen %s.'):format(MS.Utils.FormatMoney(
            cost - player:GetMoney(account))), 'error')
        return
    end

    -- Der Fahrzeugsystem-Client fuellt auf, der Server merkt sich den Stand.
    TriggerClientEvent('services:client:fuelGranted', source, plate, amount)

    player:Notify(('%d Prozent getankt fuer %s.'):format(
        amount, MS.Utils.FormatMoney(cost)), 'success')
end)

--- Kanister kaufen.
RegisterNetEvent('services:server:buyCanister', function(count)
    local source = source
    local player = MS.GetPlayer(source)
    if not player or not ServiceConfig.Fuel.enabled then return end

    if not Services.AtPump(source) then
        player:Notify('Du stehst an keiner Tankstelle.', 'error')
        return
    end

    local config = ServiceConfig.Fuel.canister
    count = math.max(1, math.min(5, math.floor(tonumber(count) or 1)))

    local cost = config.price * count

    if not player:CanCarryItem(config.item, count) then
        player:Notify('So viel kannst du nicht tragen.', 'error')
        return
    end

    if not player:RemoveMoney(cost, ServiceConfig.Fuel.account, 'kanister') then
        player:Notify(('Dir fehlen %s.'):format(MS.Utils.FormatMoney(
            cost - player:GetMoney(ServiceConfig.Fuel.account))), 'error')
        return
    end

    player:AddItem(config.item, count)
    player:Notify(('%dx Benzinkanister fuer %s.'):format(
        count, MS.Utils.FormatMoney(cost)), 'success')
end)

--- Kanister benutzen: fuellt das Fahrzeug davor auf.
CreateThread(function()
    local config = ServiceConfig.Fuel.canister

    -- Auf den Core warten und das Item anlegen.
    for _ = 1, 20 do
        local ok = pcall(function()
            exports['moonshine-core']:RegisterItem(config.item, {
                label       = 'Benzinkanister',
                weight      = 5000,
                stack       = true,
                usable      = true,
                description = ('Fuellt etwa %d Prozent in einen Tank.'):format(config.amount),
            })
        end)

        if ok then break end
        Wait(500)
    end

    Wait(1000)

    MS.RegisterUsableItem(config.item, function(player, slot)
        TriggerClientEvent('services:client:useCanister', player.source, slot)
    end)
end)

--- Der Client bestaetigt, dass er den Kanister an einem Fahrzeug benutzt hat.
RegisterNetEvent('services:server:canisterUsed', function(slot, plate)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local config = ServiceConfig.Fuel.canister

    if not player:RemoveItem(config.item, 1, tonumber(slot)) then return end

    TriggerClientEvent('services:client:fuelGranted', source, plate, config.amount)
    player:Notify('Kanister geleert.', 'success')
end)
