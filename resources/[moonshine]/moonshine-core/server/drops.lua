--- Bodenitems: fallen gelassene Gegenstaende leben nur zur Laufzeit.

MS.Drops = {}

local nextDropId = 0
local DROP_LIFETIME = 10 * 60   -- Sekunden

local function syncDrops(target)
    TriggerClientEvent('moonshine:client:syncDrops', target or -1, MS.Drops)
end

RegisterNetEvent('moonshine:server:dropItem', function(slot, count, coords)
    local player = MS.Players[source]
    if not player then return end
    if type(coords) ~= 'table' or type(coords.x) ~= 'number' then return end

    slot  = tonumber(slot)
    count = math.floor(tonumber(count) or 1)

    local entry = slot and player:GetSlot(slot)
    if not entry or count < 1 or entry.count < count then return end

    local item = MS.GetItem(entry.name)
    if not item then return end

    -- Nur in der Naehe des Spielers ablegen (Schutz vor manipulierten Koordinaten).
    local playerCoords = GetEntityCoords(GetPlayerPed(player.source))
    if #(playerCoords - vector3(coords.x, coords.y, coords.z)) > 5.0 then return end

    if not player:RemoveItem(entry.name, count, slot) then return end

    nextDropId = nextDropId + 1
    MS.Drops[nextDropId] = {
        id        = nextDropId,
        name      = entry.name,
        label     = item.label,
        count     = count,
        metadata  = entry.metadata,
        coords    = { x = coords.x, y = coords.y, z = coords.z },
        createdAt = os.time(),
    }

    syncDrops()
    MS.Logger.Log('item', ('%s legt %dx %s ab'):format(player.fullname, count, item.label), player.license)
end)

RegisterNetEvent('moonshine:server:pickupDrop', function(dropId)
    local player = MS.Players[source]
    if not player then return end

    dropId = tonumber(dropId)
    local drop = dropId and MS.Drops[dropId]
    if not drop then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(player.source))
    if #(playerCoords - vector3(drop.coords.x, drop.coords.y, drop.coords.z)) > 3.0 then return end

    if not player:CanCarryItem(drop.name, drop.count) then
        player:Notify('Du kannst nicht mehr tragen.', 'error')
        return
    end

    if player:AddItem(drop.name, drop.count, drop.metadata) then
        MS.Drops[dropId] = nil
        syncDrops()
    end
end)

--- Neue Spieler bekommen die aktuelle Liste.
AddEventHandler('moonshine:server:playerLoaded', function(source)
    syncDrops(source)
end)

CreateThread(function()
    while true do
        Wait(60000)

        local now, removed = os.time(), false
        for id, drop in pairs(MS.Drops) do
            if now - drop.createdAt > DROP_LIFETIME then
                MS.Drops[id] = nil
                removed = true
            end
        end

        if removed then syncDrops() end
    end
end)
