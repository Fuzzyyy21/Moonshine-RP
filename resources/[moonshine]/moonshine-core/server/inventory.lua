--- Inventarsystem. Das Inventar ist eine Liste aus { slot, name, count, metadata }.

local Player = MS.PlayerMethods

MS.UsableItems = {}

--- Registriert einen Callback fuer ein benutzbares Item.
---@param name string
---@param callback fun(player: table, slot: number, item: table)
function MS.RegisterUsableItem(name, callback)
    if not MS.GetItem(name) then
        MS.Utils.Print('warn', 'RegisterUsableItem: unbekanntes Item "%s"', tostring(name))
        return
    end
    MS.UsableItems[name] = callback
end

-- Hilfsfunktionen ------------------------------------------------------------

local function metadataMatches(a, b)
    local aEmpty = a == nil or next(a) == nil
    local bEmpty = b == nil or next(b) == nil
    if aEmpty and bEmpty then return true end
    if aEmpty ~= bEmpty then return false end
    return json.encode(a) == json.encode(b)
end

local function findFreeSlot(inventory)
    local used = {}
    for _, entry in ipairs(inventory) do used[entry.slot] = true end

    for slot = 1, Config.Inventory.maxSlots do
        if not used[slot] then return slot end
    end
    return nil
end

-- Abfragen -------------------------------------------------------------------

function Player:GetInventory()
    return self.inventory
end

---@return number Gesamtgewicht in Gramm
function Player:GetInventoryWeight()
    local weight = 0
    for _, entry in ipairs(self.inventory) do
        weight = weight + MS.GetItemWeight(entry.name, entry.count)
    end
    return weight
end

---@return number
function Player:GetItemCount(name)
    local count = 0
    for _, entry in ipairs(self.inventory) do
        if entry.name == name then count = count + entry.count end
    end
    return count
end

function Player:HasItem(name, count)
    return self:GetItemCount(name) >= (count or 1)
end

---@return table|nil Eintrag im angegebenen Slot
function Player:GetSlot(slot)
    for _, entry in ipairs(self.inventory) do
        if entry.slot == slot then return entry end
    end
end

--- Prueft ob Gewicht und Slots fuer die Menge ausreichen.
function Player:CanCarryItem(name, count)
    local item = MS.GetItem(name)
    if not item then return false end

    count = count or 1
    if self:GetInventoryWeight() + MS.GetItemWeight(name, count) > Config.Inventory.maxWeight then
        return false
    end

    if item.stack then
        for _, entry in ipairs(self.inventory) do
            if entry.name == name and metadataMatches(entry.metadata, nil) then return true end
        end
        return findFreeSlot(self.inventory) ~= nil
    end

    -- Nicht stapelbare Items brauchen einen Slot pro Stueck.
    local free = Config.Inventory.maxSlots - #self.inventory
    return free >= count
end

-- Aenderungen ----------------------------------------------------------------

--- Fuegt ein Item hinzu.
---@return boolean erfolgreich
function Player:AddItem(name, count, metadata)
    local item = MS.GetItem(name)
    if not item then
        MS.Utils.Print('warn', 'AddItem: unbekanntes Item "%s"', tostring(name))
        return false
    end

    count = math.floor(tonumber(count) or 1)
    if count < 1 then return false end

    if not self:CanCarryItem(name, count) then
        self:Notify('Du kannst nicht mehr tragen.', 'error')
        return false
    end

    if item.stack then
        for _, entry in ipairs(self.inventory) do
            if entry.name == name and metadataMatches(entry.metadata, metadata) then
                entry.count = entry.count + count
                self:Sync()
                TriggerEvent('moonshine:server:itemAdded', self.source, name, count)
                MS.Logger.Log('item', ('%s erhaelt %dx %s'):format(self.fullname, count, item.label), self.license)
                return true
            end
        end
    end

    local remaining = item.stack and 1 or count
    for _ = 1, remaining do
        local slot = findFreeSlot(self.inventory)
        if not slot then break end

        self.inventory[#self.inventory + 1] = {
            slot     = slot,
            name     = name,
            count    = item.stack and count or 1,
            metadata = metadata,
        }
    end

    self:Sync()
    TriggerEvent('moonshine:server:itemAdded', self.source, name, count)
    MS.Logger.Log('item', ('%s erhaelt %dx %s'):format(self.fullname, count, item.label), self.license)
    return true
end

--- Entfernt ein Item. Ohne slot wird aus beliebigen Slots entnommen.
---@return boolean erfolgreich
function Player:RemoveItem(name, count, slot)
    count = math.floor(tonumber(count) or 1)
    if count < 1 then return false end

    -- Vorab pruefen, damit nie teilweise entfernt wird.
    local available = 0
    for _, entry in ipairs(self.inventory) do
        if entry.name == name and (not slot or entry.slot == slot) then
            available = available + entry.count
        end
    end
    if available < count then return false end

    local remaining = count

    for index = #self.inventory, 1, -1 do
        local entry = self.inventory[index]
        if entry.name == name and (not slot or entry.slot == slot) then
            local taken = math.min(entry.count, remaining)
            entry.count = entry.count - taken
            remaining = remaining - taken

            if entry.count <= 0 then
                table.remove(self.inventory, index)
            end
            if remaining <= 0 then break end
        end
    end

    self:Sync()
    TriggerEvent('moonshine:server:itemRemoved', self.source, name, count - remaining)
    return true
end

function Player:ClearInventory()
    self.inventory = {}
    self:Sync()
end

-- Netzwerkevents -------------------------------------------------------------

RegisterNetEvent('moonshine:server:useItem', function(slot)
    local player = MS.Players[source]
    if not player then return end

    slot = tonumber(slot)
    local entry = slot and player:GetSlot(slot)
    if not entry then return end

    local item = MS.GetItem(entry.name)
    if not item or not item.usable then return end

    local callback = MS.UsableItems[entry.name]
    if not callback then
        player:Notify(('%s lässt sich gerade nicht benutzen.'):format(item.label), 'error')
        return
    end

    if item.closeUi then
        TriggerClientEvent('moonshine:client:closeInventory', player.source)
    end
    callback(player, slot, entry)
end)

RegisterNetEvent('moonshine:server:giveItem', function(targetId, slot, count)
    local player = MS.Players[source]
    if not player then return end

    targetId = tonumber(targetId)
    slot     = tonumber(slot)
    count    = math.floor(tonumber(count) or 1)

    local target = targetId and MS.Players[targetId]
    if not target or target.source == player.source or count < 1 then return end

    local distance = #(GetEntityCoords(GetPlayerPed(player.source)) - GetEntityCoords(GetPlayerPed(target.source)))
    if distance > 3.0 then
        player:Notify('Du bist zu weit entfernt.', 'error')
        return
    end

    local entry = player:GetSlot(slot)
    if not entry or entry.count < count then return end

    if not target:CanCarryItem(entry.name, count) then
        player:Notify('Die Person kann nichts mehr tragen.', 'error')
        return
    end

    if player:RemoveItem(entry.name, count, slot) then
        target:AddItem(entry.name, count, entry.metadata)

        local label = MS.GetItem(entry.name).label
        player:Notify(('Du hast %dx %s an %s gegeben.'):format(count, label, target.fullname), 'success')
        target:Notify(('Du hast %dx %s von %s erhalten.'):format(count, label, player.fullname), 'success')
    end
end)

RegisterNetEvent('moonshine:server:moveItem', function(fromSlot, toSlot)
    local player = MS.Players[source]
    if not player then return end

    fromSlot, toSlot = tonumber(fromSlot), tonumber(toSlot)
    if not fromSlot or not toSlot or fromSlot == toSlot then return end
    if toSlot < 1 or toSlot > Config.Inventory.maxSlots then return end

    local from = player:GetSlot(fromSlot)
    if not from then return end

    local to = player:GetSlot(toSlot)
    if to then
        -- Gleiche stapelbare Items zusammenlegen, sonst tauschen.
        local item = MS.GetItem(to.name)
        if item and item.stack and to.name == from.name and metadataMatches(to.metadata, from.metadata) then
            to.count = to.count + from.count
            for index, entry in ipairs(player.inventory) do
                if entry == from then
                    table.remove(player.inventory, index)
                    break
                end
            end
            player:Sync()
            return
        end
        to.slot = fromSlot
    end

    from.slot = toSlot
    player:Sync()
end)

-- Standard-Items -------------------------------------------------------------

MS.RegisterUsableItem('bread', function(player, slot)
    if player:RemoveItem('bread', 1, slot) then
        player:AddStatus('hunger', 25.0)
        player:TriggerEvent('moonshine:client:playConsume', 'eat')
    end
end)

MS.RegisterUsableItem('burger', function(player, slot)
    if player:RemoveItem('burger', 1, slot) then
        player:AddStatus('hunger', 40.0)
        player:TriggerEvent('moonshine:client:playConsume', 'eat')
    end
end)

MS.RegisterUsableItem('water', function(player, slot)
    if player:RemoveItem('water', 1, slot) then
        player:AddStatus('thirst', 35.0)
        player:TriggerEvent('moonshine:client:playConsume', 'drink')
    end
end)

MS.RegisterUsableItem('cola', function(player, slot)
    if player:RemoveItem('cola', 1, slot) then
        player:AddStatus('thirst', 25.0)
        player:AddStatus('hunger', 5.0)
        player:TriggerEvent('moonshine:client:playConsume', 'drink')
    end
end)

MS.RegisterUsableItem('bandage', function(player, slot)
    if player:RemoveItem('bandage', 1, slot) then
        player:TriggerEvent('moonshine:client:heal', 25)
    end
end)

MS.RegisterUsableItem('id_card', function(player)
    player:Notify(('%s | geboren am %s'):format(player.fullname, player.dob), 'info', 8000)
end)
