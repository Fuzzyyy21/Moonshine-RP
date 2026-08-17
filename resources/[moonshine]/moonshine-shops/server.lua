--- Beispiel fuer die Nutzung der Framework-API auf dem Server.

local MS = exports['moonshine-core']:GetCoreObject()

--- Preis eines Artikels aus der Konfiguration.
local function getPrice(itemName)
    for _, entry in ipairs(ShopConfig.Items) do
        if entry.name == itemName then return entry.price end
    end
end

--- Prueft ob der Spieler an einem Ladenstandort steht.
local function isAtShop(source)
    local coords = GetEntityCoords(GetPlayerPed(source))

    for _, shop in ipairs(ShopConfig.Locations) do
        if #(coords - shop) < 5.0 then return true end
    end
    return false
end

MS.RegisterServerCallback('moonshine-shops:buy', function(player, cb, itemName, count)
    if not player then
        cb(false, 'Spieler nicht geladen.')
        return
    end

    count = math.floor(tonumber(count) or 0)
    local price = getPrice(itemName)

    if not price or count < 1 or count > 100 then
        cb(false, 'Ungueltige Bestellung.', player:GetMoney(ShopConfig.Account))
        return
    end

    if not isAtShop(player.source) then
        cb(false, 'Du bist nicht an einem Laden.', player:GetMoney(ShopConfig.Account))
        return
    end

    local total = price * count

    if not player:CanCarryItem(itemName, count) then
        cb(false, 'Du kannst nicht mehr tragen.', player:GetMoney(ShopConfig.Account))
        return
    end

    if not player:RemoveMoney(total, ShopConfig.Account, 'shop:buy') then
        cb(false, ('Dir fehlen %s.'):format(
            MS.Utils.FormatMoney(total - player:GetMoney(ShopConfig.Account))),
            player:GetMoney(ShopConfig.Account))
        return
    end

    if not player:AddItem(itemName, count) then
        -- Sicherheitsnetz: Geld zurueckbuchen falls das Item doch nicht passt.
        player:AddMoney(total, ShopConfig.Account, 'shop:refund')
        cb(false, 'Kauf fehlgeschlagen.', player:GetMoney(ShopConfig.Account))
        return
    end

    cb(true, ('%dx %s fuer %s gekauft.'):format(count, MS.GetItem(itemName).label, MS.Utils.FormatMoney(total)),
        player:GetMoney(ShopConfig.Account))
end)
