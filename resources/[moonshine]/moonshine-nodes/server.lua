--- Steinadern: Serverseitige Verwaltung und Ausbeute.

local MS = exports['moonshine-core']:GetCoreObject()

--- [index] = { charges = number, depletedUntil = number|nil, miner = source|nil }
local nodes = {}

-- Werkzeug registrieren ------------------------------------------------------

CreateThread(function()
    for _ = 1, 10 do
        local ok = pcall(function()
            exports['moonshine-core']:RegisterItem(NodeConfig.Tool.item, {
                label       = NodeConfig.Tool.label,
                weight      = 2500,
                stack       = true,
                usable      = false,
                description = 'Meissel aus altem Eisen. Bricht Ritualsteine aus dem Fels.',
            })
        end)
        if ok then break end
        Wait(1000)
    end
end)

-- Zustand --------------------------------------------------------------------

local function randomCharges()
    return math.random(NodeConfig.Mining.chargesMin, NodeConfig.Mining.chargesMax)
end

CreateThread(function()
    for index in ipairs(NodeConfig.Nodes) do
        nodes[index] = { charges = randomCharges() }
    end
end)

--- Zustand aller Adern fuer den Client (nur was er sehen darf).
local function buildState()
    local state = {}
    local now = os.time()

    for index, node in pairs(nodes) do
        state[index] = {
            depleted = node.charges <= 0 and (not node.depletedUntil or now < node.depletedUntil),
            busy     = node.miner ~= nil,
        }
    end

    return state
end

local function broadcast()
    TriggerClientEvent('nodes:client:sync', -1, buildState())
end

AddEventHandler('moonshine:server:playerLoaded', function(source)
    SetTimeout(3000, function()
        TriggerClientEvent('nodes:client:sync', source, buildState())
    end)
end)

--- Erschoepfte Adern erholen sich.
CreateThread(function()
    while true do
        Wait(30000)

        local now = os.time()
        local changed = false

        for index, node in pairs(nodes) do
            if node.charges <= 0 and node.depletedUntil and now >= node.depletedUntil then
                node.charges = randomCharges()
                node.depletedUntil = nil
                changed = true
            end
        end

        if changed then broadcast() end
    end
end)

-- Ausbeute -------------------------------------------------------------------

--- Klassenstein des Spielers, falls moonshine-mystic laeuft.
local function classStone(source)
    local stone

    pcall(function()
        local race = exports['moonshine-mystic']:GetRace(source)
        if not race then return end

        local mystic = exports['moonshine-mystic']:GetMysticObject()
        stone = mystic and mystic.RaceStones and mystic.RaceStones[race] or nil
    end)

    return stone
end

--- Zieht einen gewichteten Eintrag aus der Lootliste des Adertyps.
local function rollLoot(nodeType, source)
    local entries, total = {}, 0

    for _, entry in ipairs(nodeType.loot) do
        total = total + entry.weight
        entries[#entries + 1] = entry
    end

    -- Klassenader wirft zusaetzlich den Stein der eigenen Klasse aus.
    if nodeType.classStone then
        local stone = classStone(source)
        if stone then
            local weight = nodeType.classWeight or 25
            total = total + weight
            entries[#entries + 1] = { item = stone, count = 1, weight = weight }
        end
    end

    local roll = math.random() * total
    local sum = 0

    for _, entry in ipairs(entries) do
        sum = sum + entry.weight
        if roll <= sum then return entry end
    end

    return entries[1]
end

-- Abbau ----------------------------------------------------------------------

RegisterNetEvent('nodes:server:startMining', function(index)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    index = tonumber(index)
    local definition = index and NodeConfig.Nodes[index]
    local node = index and nodes[index]
    if not definition or not node then return end

    local nodeType = NodeConfig.Types[definition.type]
    if not nodeType then return end

    if node.miner then
        player:Notify('Hier arbeitet bereits jemand.', 'warning')
        return
    end

    if node.charges <= 0 then
        player:Notify('Diese Ader ist erschoepft.', 'warning')
        return
    end

    local distance = #(GetEntityCoords(GetPlayerPed(source)) - definition.coords)
    if distance > NodeConfig.Mining.range + 1.5 then return end

    if NodeConfig.Tool.required and not player:HasItem(NodeConfig.Tool.item, 1) then
        player:Notify(('Du brauchst einen %s.'):format(NodeConfig.Tool.label), 'error')
        return
    end

    node.miner = source
    broadcast()
    TriggerClientEvent('nodes:client:mining', source, index, NodeConfig.Mining.duration, nodeType.damage)

    SetTimeout(NodeConfig.Mining.duration * 1000, function()
        node.miner = nil

        if not MS.GetPlayer(source) then
            broadcast()
            return
        end

        local check = #(GetEntityCoords(GetPlayerPed(source)) - definition.coords)
        if check > NodeConfig.Mining.range + 2.0 then
            player:Notify('Du hast den Abbau abgebrochen.', 'error')
            broadcast()
            return
        end

        if NodeConfig.Tool.required and not player:HasItem(NodeConfig.Tool.item, 1) then
            broadcast()
            return
        end

        local loot = rollLoot(nodeType, source)
        local item = MS.GetItem(loot.item)

        if player:AddItem(loot.item, loot.count) then
            player:Notify(('%dx %s abgebaut.'):format(loot.count, item and item.label or loot.item), 'success')
        else
            player:Notify('Du kannst nichts mehr tragen.', 'error')
        end

        -- Werkzeugverschleiss
        if NodeConfig.Tool.breakChance > 0 and math.random() < NodeConfig.Tool.breakChance then
            if player:RemoveItem(NodeConfig.Tool.item, 1) then
                player:Notify(('Dein %s ist zerbrochen.'):format(NodeConfig.Tool.label), 'warning')
            end
        end

        node.charges = node.charges - 1
        if node.charges <= 0 then
            node.depletedUntil = os.time() + NodeConfig.Mining.respawn
            player:Notify('Die Ader ist versiegt.', 'info')
        end

        broadcast()
        TriggerEvent('moonshine-nodes:server:mined', source, definition.type, loot.item, loot.count)
    end)
end)

AddEventHandler('playerDropped', function()
    local dropped = source

    for _, node in pairs(nodes) do
        if node.miner == dropped then node.miner = nil end
    end
end)

-- Admin ----------------------------------------------------------------------

RegisterCommand('adern', function(source)
    if source ~= 0 then
        local player = MS.GetPlayer(source)
        if not player or player.adminLevel < 3 then return end
    end

    local active, depleted = 0, 0
    for _, node in pairs(nodes) do
        if node.charges > 0 then active = active + 1 else depleted = depleted + 1 end
    end

    local message = ('Steinadern: %d aktiv, %d erschoepft.'):format(active, depleted)
    if source == 0 then
        print('[Nodes] ' .. message)
    else
        TriggerClientEvent('moonshine:client:notify', source, message, 'info', 6000)
    end
end, false)
