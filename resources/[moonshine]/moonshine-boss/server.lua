--- Weltbosse: Spawn, Teilnahme und Belohnung.

local MS = exports['moonshine-core']:GetCoreObject()

--- Aktueller Boss oder nil.
--- { entity, netId, definition, spawn, spawnedAt, hits = { [source] = anzahl } }
local current = nil
local lastHit = {}

-- Hilfsfunktionen ------------------------------------------------------------

local function announce(message, type)
    for _, player in ipairs(MS.GetPlayers()) do
        player:Notify(message, type or 'info', 10000)
    end
end

local function playerCount()
    local count = 0
    for _ in pairs(MS.Players) do count = count + 1 end
    return count
end

-- Spawn ----------------------------------------------------------------------

local function despawn(reason)
    if not current then return end

    if current.entity and DoesEntityExist(current.entity) then
        DeleteEntity(current.entity)
    end

    TriggerClientEvent('boss:client:despawn', -1)
    TriggerEvent('moonshine-boss:server:despawned', reason)
    current = nil
    lastHit = {}
end

local function spawnBoss()
    if current then return end
    if playerCount() < BossConfig.MinPlayers then return end

    local definition = BossConfig.Bosses[math.random(#BossConfig.Bosses)]
    local spawn = BossConfig.Spawns[math.random(#BossConfig.Spawns)]
    local coords = spawn.coords

    local entity = CreatePed(4, definition.model, coords.x, coords.y, coords.z, coords.w, true, true)
    if not entity or entity == 0 then
        print('^1[Boss]^7 Ped konnte nicht erstellt werden.')
        return
    end

    -- Der Zustand wandert per Statebag zu den Clients, die daraus die KI bauen.
    local state = Entity(entity).state
    state:set('mysticBoss', {
        name     = definition.name,
        health   = definition.health,
        armour   = definition.armour,
        weapon   = definition.weapon,
        accuracy = definition.accuracy,
    }, true)

    current = {
        entity     = entity,
        netId      = NetworkGetNetworkIdFromEntity(entity),
        definition = definition,
        spawn      = spawn,
        spawnedAt  = os.time(),
        hits       = {},
    }

    TriggerClientEvent('boss:client:spawn', -1, {
        netId  = current.netId,
        name   = definition.name,
        health = definition.health,
        blip   = definition.blip,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        showBlip = BossConfig.ShowBlip,
    })

    if BossConfig.Announce then
        announce(('%s ist erschienen: %s'):format(definition.name, spawn.label), 'warning')
    end

    TriggerEvent('moonshine-boss:server:spawned', definition.name, spawn.label)
    print(('^2[Boss]^7 %s bei %s gespawnt.'):format(definition.name, spawn.label))
end

-- Teilnahme ------------------------------------------------------------------

RegisterNetEvent('boss:server:hit', function()
    local source = source
    if not current or not MS.GetPlayer(source) then return end

    -- Einfache Ratenbegrenzung gegen gefaelschte Treffer.
    local now = GetGameTimer()
    if lastHit[source] and now - lastHit[source] < 250 then return end
    lastHit[source] = now

    -- Nur wer wirklich in der Naehe ist, zaehlt mit.
    if DoesEntityExist(current.entity) then
        local distance = #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(current.entity))
        if distance > 150.0 then return end
    end

    current.hits[source] = (current.hits[source] or 0) + 1
end)

-- Belohnung ------------------------------------------------------------------

local function rewardParticipants()
    if not current then return end

    local bossCoords = DoesEntityExist(current.entity)
        and GetEntityCoords(current.entity)
        or vector3(current.spawn.coords.x, current.spawn.coords.y, current.spawn.coords.z)

    local rewarded, topSource, topHits = 0, nil, 0

    for source, hits in pairs(current.hits) do
        local player = MS.GetPlayer(source)

        if player and hits >= BossConfig.MinHits then
            local distance = #(GetEntityCoords(GetPlayerPed(source)) - bossCoords)

            if distance <= BossConfig.RewardRadius then
                local parts = {}

                -- Glueck aus dem persoenlichen Skillbaum.
                local luck, extra = 0, 0
                pcall(function()
                    local mods = exports['moonshine-mystic']:GetModifiers(source)
                    if mods then
                        luck  = mods.lootChance or 0
                        extra = mods.lootAmount or 0
                    end
                end)

                for _, reward in ipairs(BossConfig.Rewards) do
                    local amount = math.random(reward.min, reward.max)

                    if luck > 0 and math.random() < luck then
                        amount = amount + 1 + math.floor(extra)
                    end

                    if player:AddItem(reward.item, amount) then
                        local item = MS.GetItem(reward.item)
                        parts[#parts + 1] = ('%dx %s'):format(amount, item and item.label or reward.item)
                    end
                end

                if #parts > 0 then
                    player:Notify(('Beute vom Boss: %s'):format(table.concat(parts, ', ')), 'success', 10000)
                    rewarded = rewarded + 1
                end

                -- Fuer Missionen und Statistiken.
                TriggerEvent('boss:server:participantRewarded', source, current.definition and current.definition.name)

                if hits > topHits then
                    topSource, topHits = source, hits
                end
            else
                player:Notify('Du warst zu weit weg fuer deinen Anteil.', 'warning')
            end
        end
    end

    -- Wer am meisten ausgeteilt hat, bekommt einen Zuschlag.
    local bonus = BossConfig.TopDamageBonus
    if topSource and bonus and bonus.amount > 0 then
        local player = MS.GetPlayer(topSource)
        if player and player:AddItem(bonus.item, bonus.amount) then
            local item = MS.GetItem(bonus.item)
            player:Notify(('Groesster Anteil am Kampf: %dx %s extra.'):format(
                bonus.amount, item and item.label or bonus.item), 'success', 10000)
        end
    end

    if BossConfig.Announce then
        announce(('%s wurde besiegt. %d Kaempfer erhalten ihren Anteil.'):format(
            current.definition.name, rewarded), 'success')
    end

    TriggerEvent('moonshine-boss:server:defeated', current.definition.name, rewarded)
end

--- Der Boss ist tot: Belohnung verteilen und aufraeumen.
local function onDefeated()
    rewardParticipants()

    TriggerClientEvent('boss:client:defeated', -1)
    SetTimeout(8000, function() despawn('besiegt') end)
end

-- Ablaufsteuerung ------------------------------------------------------------

CreateThread(function()
    Wait(BossConfig.FirstDelay * 60000)

    while true do
        if not current then spawnBoss() end
        Wait(BossConfig.Interval * 60000)
    end
end)

--- Zustand des laufenden Bosses ueberwachen.
CreateThread(function()
    while true do
        Wait(2000)

        if current then
            local entity = current.entity

            if not DoesEntityExist(entity) then
                despawn('verschwunden')
            elseif GetEntityHealth(entity) <= 0 then
                -- Nur einmal ausschuetten, die Leiche bleibt kurz liegen.
                if not current.defeated then
                    current.defeated = true
                    onDefeated()
                end
            elseif not current.defeated and os.time() - current.spawnedAt > BossConfig.Lifetime * 60 then
                if BossConfig.Announce then
                    announce(('%s hat sich zurueckgezogen.'):format(current.definition.name), 'info')
                end
                despawn('abgelaufen')
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    despawn('resource-stop')
end)

AddEventHandler('playerDropped', function()
    lastHit[source] = nil
end)

-- Admin ----------------------------------------------------------------------

local function hasPermission(source)
    if source == 0 then return true end

    local player = MS.GetPlayer(source)
    return player ~= nil and player.adminLevel >= 3
end

RegisterCommand('bossspawn', function(source)
    if not hasPermission(source) then return end

    if current then
        TriggerClientEvent('moonshine:client:notify', source, 'Es laeuft bereits ein Boss.', 'warning', 5000)
        return
    end

    spawnBoss()
end, false)

RegisterCommand('bossweg', function(source)
    if not hasPermission(source) then return end
    despawn('admin')
end, false)

RegisterCommand('bossinfo', function(source)
    if not hasPermission(source) then return end

    local message = current
        and ('%s bei %s, %d Kaempfer beteiligt.'):format(
            current.definition.name, current.spawn.label, MS.Utils.TableLength(current.hits))
        or 'Aktuell laeuft kein Boss.'

    if source == 0 then
        print('[Boss] ' .. message)
    else
        TriggerClientEvent('moonshine:client:notify', source, message, 'info', 8000)
    end
end, false)
