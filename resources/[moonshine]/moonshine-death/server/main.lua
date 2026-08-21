--- Serverseitige Verwaltung der Bewusstlosigkeit.

local MS = exports['moonshine-core']:GetCoreObject()

--- [source] = { since = os.time(), coords = {...}, calledAt = number|nil }
local downed = {}

-- Items ----------------------------------------------------------------------

CreateThread(function()
    if not DeathConfig.Revive.item then return end

    for _ = 1, 10 do
        local ok = pcall(function()
            exports['moonshine-core']:RegisterItem(DeathConfig.Revive.item, {
                label       = 'Medikit',
                weight      = 1200,
                stack       = true,
                usable      = false,
                description = 'Notfallset zur Wiederbelebung.',
            })
        end)
        if ok then return end
        Wait(1000)
    end
end)

-- Hilfsfunktionen ------------------------------------------------------------

local function hasJob(player, jobs)
    for _, name in ipairs(jobs or {}) do
        if player.job.name == name then return true end
    end
    return false
end

--- Klasse eines Spielers, falls moonshine-mystic laeuft.
local function getClass(source)
    local ok, race = pcall(function()
        return exports['moonshine-mystic']:GetRace(source)
    end)
    return ok and race or nil
end

local function isInList(value, list)
    for _, entry in ipairs(list or {}) do
        if entry == value then return true end
    end
    return false
end

---@return boolean
function IsPlayerDowned(source)
    return downed[source] ~= nil
end

-- Bewusstlos werden ----------------------------------------------------------

local function setDowned(source, restored, killer)
    local player = MS.GetPlayer(source)
    if not player or downed[source] then return end

    local coords = GetEntityCoords(GetPlayerPed(source))

    downed[source] = {
        since  = restored and (os.time() - (restored.elapsed or 0)) or os.time(),
        coords = { x = coords.x, y = coords.y, z = coords.z },
    }

    player:SetMetadata('downed', true)
    player:SetMetadata('downedSince', downed[source].since)

    local remaining = DeathConfig.BleedoutTime - (os.time() - downed[source].since)
    -- Hat der Spieler einen Zufluchtsort, darf er dorthin statt ins
    -- Krankenhaus (moonshine-refuge, optional).
    local refuge = nil
    pcall(function() refuge = exports['moonshine-refuge']:GetRespawnPoint(source) end)

    TriggerClientEvent('death:client:setDowned', source, math.max(5, remaining),
        DeathConfig.RespawnAfter, refuge and refuge.label or nil)
    TriggerEvent('moonshine-death:server:playerDowned', source, killer)

    MS.Logger.Log('character', ('%s ist bewusstlos.'):format(player.fullname), player.license)
end

AddEventHandler('moonshine:server:playerDeath', function(source, _, killer)
    setDowned(source, nil, killer)
end)

--- Nach einem Relog bleibt die Bewusstlosigkeit bestehen.
AddEventHandler('moonshine:server:playerLoaded', function(source, player)
    if not DeathConfig.DisableCombatLog then return end
    if not player:GetMetadata('downed') then return end

    local since = tonumber(player:GetMetadata('downedSince')) or os.time()
    SetTimeout(4000, function()
        if not MS.GetPlayer(source) then return end
        setDowned(source, { elapsed = os.time() - since })
        TriggerClientEvent('moonshine:client:notify', source,
            'Du bist immer noch bewusstlos.', 'error', 8000)
    end)
end)

-- Wiederbelebung -------------------------------------------------------------

local function clearDowned(source, health, medic)
    local player = MS.GetPlayer(source)
    downed[source] = nil

    if player then
        player:SetMetadata('downed', false)
        player:SetMetadata('downedSince', nil)
    end

    TriggerClientEvent('death:client:revive', source, health or DeathConfig.Revive.health)
    TriggerEvent('moonshine-death:server:playerRevived', source, medic)
end

--- Von aussen (z.B. Klassenskill oder Admin) wiederbeleben.
function RevivePlayer(source, health, medic)
    if not downed[source] then return false end

    clearDowned(source, health, medic)
    return true
end

exports('RevivePlayer', RevivePlayer)
exports('IsPlayerDowned', IsPlayerDowned)

RegisterNetEvent('death:server:requestRevive', function(targetId)
    if not MS.RateLimit(source, 'death:revive', 10, 10) then return end
    local source = source
    local player = MS.GetPlayer(source)
    targetId = tonumber(targetId)
    local target = targetId and MS.GetPlayer(targetId)

    if not player or not target or not downed[targetId] then return end

    local distance = #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(targetId)))
    if distance > DeathConfig.Revive.range + 1.5 then
        player:Notify('Du bist zu weit entfernt.', 'error')
        return
    end

    local allowed = hasJob(player, DeathConfig.Revive.jobs)
    local item = DeathConfig.Revive.item

    if not allowed and DeathConfig.Revive.anyoneWithItem then
        allowed = item == nil or player:HasItem(item, 1)
    end

    if not allowed then
        player:Notify('Dafuer fehlt dir die Ausbildung.', 'error')
        return
    end

    if item and not player:HasItem(item, 1) then
        player:Notify('Dir fehlt ein Medikit.', 'error')
        return
    end

    -- Der Client spielt die Animation, der Server prueft danach erneut.
    TriggerClientEvent('death:client:playRevive', source, targetId, DeathConfig.ReviveTime)

    SetTimeout(DeathConfig.ReviveTime * 1000, function()
        if not MS.GetPlayer(source) or not MS.GetPlayer(targetId) or not downed[targetId] then return end

        local check = #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(targetId)))
        if check > DeathConfig.Revive.range + 1.5 then
            player:Notify('Die Behandlung wurde abgebrochen.', 'error')
            return
        end

        if item and not player:RemoveItem(item, 1) then return end

        clearDowned(targetId, DeathConfig.Revive.health, source)
        player:Notify(('%s wurde stabilisiert.'):format(target.fullname), 'success')
        target:Notify('Du wurdest wiederbelebt.', 'success')

        MS.Logger.Log('character',
            ('%s hat %s wiederbelebt.'):format(player.fullname, target.fullname), player.license)
    end)
end)

--- Wiederbelebung durch einen Klassenskill (moonshine-mystic).
RegisterNetEvent('death:server:skillRevive', function(targetId, health)
    local source = source
    targetId = tonumber(targetId)
    if not targetId or not downed[targetId] then return end

    -- Nur aus der Naehe.
    local distance = #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(targetId)))
    if distance > 12.0 then return end

    clearDowned(targetId, tonumber(health) or DeathConfig.Revive.health)
end)

-- Notruf ---------------------------------------------------------------------

RegisterNetEvent('death:server:call', function()
    local source = source
    local player = MS.GetPlayer(source)
    local state = downed[source]
    if not player or not state then return end

    if state.calledAt and os.time() - state.calledAt < DeathConfig.Call.cooldown then
        player:Notify('Du hast bereits um Hilfe gerufen.', 'warning')
        return
    end

    state.calledAt = os.time()
    local coords = GetEntityCoords(GetPlayerPed(source))
    local receivers = 0

    for _, other in ipairs(MS.GetPlayers()) do
        if other.source ~= source then
            local reachable = hasJob(other, DeathConfig.Call.jobs)
                or isInList(getClass(other.source), DeathConfig.Call.classes)

            if reachable then
                TriggerClientEvent('death:client:incomingCall', other.source, {
                    name   = player.fullname,
                    coords = { x = coords.x, y = coords.y, z = coords.z },
                    time   = DeathConfig.Call.blipTime,
                })
                receivers = receivers + 1
            end
        end
    end

    player:Notify(receivers > 0
        and ('Notruf abgesetzt, %d Helfer benachrichtigt.'):format(receivers)
        or 'Niemand konnte deinen Ruf hoeren.', receivers > 0 and 'success' or 'warning')
end)

-- Aufgeben und Respawn -------------------------------------------------------

local function respawn(source, paid, zuflucht)
    local player = MS.GetPlayer(source)
    if not player then return end

    -- Nach Hause statt ins Krankenhaus.
    if zuflucht then
        downed[source] = nil
        player:SetMetadata('downed', false)
        player:SetMetadata('downedSince', nil)

        pcall(function() exports['moonshine-refuge']:MarkRefugeUsed(source) end)

        TriggerClientEvent('death:client:respawn', source, {
            coords   = zuflucht.coords,
            label    = zuflucht.label,
            weakness = DeathConfig.Weakness,
        })

        TriggerEvent('moonshine-death:server:playerRespawned', source, 0)
        player:Notify(('Du wachst in %s auf.'):format(zuflucht.label), 'info', 8000)

        return
    end

    local hospital = DeathConfig.Hospitals[math.random(#DeathConfig.Hospitals)]
    local nearest, nearestDistance = hospital, math.huge
    local coords = GetEntityCoords(GetPlayerPed(source))

    for _, entry in ipairs(DeathConfig.Hospitals) do
        local distance = #(coords - vector3(entry.coords.x, entry.coords.y, entry.coords.z))
        if distance < nearestDistance then
            nearest, nearestDistance = entry, distance
        end
    end

    downed[source] = nil
    player:SetMetadata('downed', false)
    player:SetMetadata('downedSince', nil)

    TriggerClientEvent('death:client:respawn', source, {
        coords   = nearest.coords,
        label    = nearest.label,
        weakness = DeathConfig.Weakness,
    })
    TriggerEvent('moonshine-death:server:playerRespawned', source, paid)

    if paid and paid > 0 then
        player:Notify(('Behandlungskosten: %s'):format(MS.Utils.FormatMoney(paid)), 'info', 7000)
    end
end

--- Aufgeben: Behandlungskosten zahlen und im Krankenhaus aufwachen.
---@param zumZufluchtsort boolean|nil nach Hause statt ins Krankenhaus
local function requestRespawn(source, zumZufluchtsort)
    local player = MS.GetPlayer(source)
    local state = downed[source]
    if not player or not state then return end

    if os.time() - state.since < DeathConfig.RespawnAfter then
        player:Notify('Noch kannst du nicht aufgeben.', 'warning')
        return
    end

    -- Der Server fragt selbst nach, ob es die Zuflucht wirklich gibt - der
    -- Client sagt nur, dass er dorthin will.
    if zumZufluchtsort then
        local refuge = nil
        pcall(function() refuge = exports['moonshine-refuge']:GetRespawnPoint(source) end)

        if not refuge then
            player:Notify('Deine Zuflucht ist gerade nicht erreichbar.', 'error')
            return
        end

        -- Wer nach Hause kriecht, zahlt keine Behandlung.
        if refuge.kostenlos then
            respawn(source, 0, refuge)
            return
        end
    end

    local cost = DeathConfig.RespawnCost
    local paid = 0

    if cost and cost.amount > 0 then
        if player:RemoveMoney(cost.amount, cost.account, 'krankenhaus') then
            paid = cost.amount
        else
            -- Wer nicht zahlen kann, geht mit Schulden raus.
            player:Notify('Du konntest die Behandlung nicht bezahlen.', 'warning')
        end
    end

    respawn(source, paid)
end

RegisterNetEvent('death:server:respawn', function(zumZufluchtsort)
    requestRespawn(source, zumZufluchtsort == true)
end)

-- Ausbluten ------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(5000)

        local now = os.time()
        for source, state in pairs(downed) do
            if not MS.GetPlayer(source) then
                downed[source] = nil
            elseif now - state.since >= DeathConfig.BleedoutTime then
                TriggerClientEvent('moonshine:client:notify', source,
                    'Du bist deinen Verletzungen erlegen.', 'error', 8000)
                respawn(source, 0)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    downed[source] = nil
end)

-- Admin ----------------------------------------------------------------------

--- Der /revive-Command des Cores soll die Bewusstlosigkeit ebenfalls aufheben.
AddEventHandler('moonshine:server:adminRevive', function(target)
    RevivePlayer(target, 200)
end)

RegisterCommand('respawn', function(source)
    if source == 0 then return end
    requestRespawn(source)
end, false)
