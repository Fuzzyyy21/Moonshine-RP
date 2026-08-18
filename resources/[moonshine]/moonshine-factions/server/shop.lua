--- Fraktionsshop: Nachschub aus der Kasse.

--- Baut die Shopanzeige.
function Factions.BuildShopPayload(faction)
    if not FactionConfig.Shop.enabled then return { enabled = false, items = {} } end

    local discount = faction:GetModifiers().shopDiscount or 0
    local items = {}

    for _, entry in ipairs(FactionConfig.Shop.items) do
        local item = MS.GetItem(entry.name)

        items[#items + 1] = {
            name  = entry.name,
            label = entry.label or (item and item.label) or entry.name,
            price = math.max(1, math.floor(entry.price * (1 - discount))),
            base  = entry.price,
        }
    end

    return {
        enabled  = true,
        discount = discount,
        items    = items,
    }
end

RegisterNetEvent('factions:server:buyItem', function(name, amount)
    local source = source
    if not MS.RateLimit(source, 'factions:server:buyItem', 15, 10) then return end
    local player = MS.GetPlayer(source)
    if not player or not FactionConfig.Shop.enabled then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'shop') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 or amount > 50 then return end

    local definition
    for _, entry in ipairs(FactionConfig.Shop.items) do
        if entry.name == name then definition = entry break end
    end

    if not definition then return end

    local item = MS.GetItem(name)
    if not item then return end

    local discount = faction:GetModifiers().shopDiscount or 0
    local price = math.max(1, math.floor(definition.price * (1 - discount)))
    local total = price * amount

    if not player:CanCarryItem(name, amount) then
        player:Notify('So viel kannst du nicht tragen.', 'error')
        return
    end

    if not faction:RemoveKasse(total, ('Shop: %dx %s'):format(amount, item.label)) then
        player:Notify(('In der Kasse fehlen %s.'):format(
            MS.Utils.FormatMoney(total - faction.kasse)), 'error')
        return
    end

    if not player:AddItem(name, amount) then
        faction:AddKasse(total, 'Shop-Rueckerstattung')
        player:Notify('Das passt nicht in dein Inventar.', 'error')
        return
    end

    faction:Save()
    faction:Log('shop', ('%s %s hat %dx %s gekauft (%s).'):format(
        player.firstname, player.lastname, amount, item.label, MS.Utils.FormatMoney(total)))

    player:Notify(('%dx %s fuer %s aus der Kasse.'):format(
        amount, item.label, MS.Utils.FormatMoney(total)), 'success')

    faction:Sync()
end)
