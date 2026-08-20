--- Bewusstlosigkeit auf dem Client: Animation, Steuerung, Wiederbelebung.

local MS = exports['moonshine-core']:GetCoreObject()

Death = {
    downed      = false,
    downedUntil = 0,
    respawnAt   = 0,
    reviving    = false,
    weakUntil   = 0,
    weakness    = nil,
}

local DOWNED_DICT = 'dead'
local DOWNED_ANIM = 'dead_a'

--- Ist der lokale Spieler bewusstlos?
function Death.IsDowned()
    return Death.downed
end

exports('IsDowned', Death.IsDowned)

-- Zustand --------------------------------------------------------------------

local function playDownedAnimation()
    local ped = PlayerPedId()

    RequestAnimDict(DOWNED_DICT)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(DOWNED_DICT) and GetGameTimer() < timeout do Wait(10) end

    if HasAnimDictLoaded(DOWNED_DICT) then
        TaskPlayAnim(ped, DOWNED_DICT, DOWNED_ANIM, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    else
        SetPedToRagdoll(ped, 60000, 60000, 0, true, true, false)
    end
end

RegisterNetEvent('death:client:setDowned', function(remaining, respawnAfter, refuge)
    if Death.downed then return end

    Death.downed = true
    Death.downedUntil = GetGameTimer() + remaining * 1000
    Death.respawnAt = GetGameTimer() + (respawnAfter or 120) * 1000

    -- Name der eigenen Zuflucht, falls es eine gibt (moonshine-refuge).
    Death.refuge = refuge

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    -- Statt echtem Tod bleibt der Spieler am Boden liegen.
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, 120)
    SetEntityInvincible(ped, false)
    ClearPedTasksImmediately(ped)
    playDownedAnimation()

    SetPedCanRagdoll(ped, true)
    AnimpostfxPlay('DeathFailOut', 0, true)
    Death.ShowUi(true)
end)

RegisterNetEvent('death:client:revive', function(health)
    if not Death.downed then return end

    Death.downed = false
    Death.refuge = nil
    local ped = PlayerPedId()

    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, health or 130)
    ClearPedBloodDamage(ped)
    AnimpostfxStopAll()
    Death.ShowUi(false)

    MS.Notify('Du kommst wieder zu dir.', 'success', 6000)
end)

RegisterNetEvent('death:client:respawn', function(data)
    Death.downed = false
    Death.weakness = data.weakness
    Death.weakUntil = GetGameTimer() + (data.weakness and data.weakness.duration or 0) * 1000

    Death.ShowUi(false)
    DoScreenFadeOut(800)
    while not IsScreenFadedOut() do Wait(0) end

    local ped = PlayerPedId()
    local target = data.coords

    NetworkResurrectLocalPlayer(target.x, target.y, target.z, target.w or 0.0, true, false)
    SetEntityCoords(ped, target.x, target.y, target.z, false, false, false, false)
    SetEntityHeading(ped, target.w or 0.0)
    ClearPedTasksImmediately(ped)
    ClearPedBloodDamage(ped)
    SetPedArmour(ped, 0)
    AnimpostfxStopAll()

    if data.weakness then
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), data.weakness.healthCap))
    end

    Wait(600)
    DoScreenFadeIn(1000)
    MS.Notify(('Du wachst im Krankenhaus auf (%s).'):format(data.label or 'Klinik'), 'info', 8000)
end)

--- Der Admin-Befehl des Cores hebt die Bewusstlosigkeit ebenfalls auf.
RegisterNetEvent('moonshine:client:revive', function()
    if not Death.downed then return end

    Death.downed = false
    Death.ShowUi(false)
    AnimpostfxStopAll()
    ClearPedTasksImmediately(PlayerPedId())
end)

-- Schwaeche nach dem Respawn -------------------------------------------------

CreateThread(function()
    while true do
        Wait(1000)

        if Death.weakness and GetGameTimer() < Death.weakUntil then
            local ped = PlayerPedId()
            SetPedMoveRateOverride(ped, Death.weakness.speedMult or 0.92)

            if GetEntityHealth(ped) > Death.weakness.healthCap then
                SetEntityHealth(ped, Death.weakness.healthCap)
            end
        elseif Death.weakness then
            Death.weakness = nil
            SetPedMoveRateOverride(PlayerPedId(), 1.0)
            MS.Notify('Du fuehlst dich wieder bei Kraeften.', 'success')
        end
    end
end)

-- Steuerung waehrend der Bewusstlosigkeit ------------------------------------

CreateThread(function()
    while true do
        if Death.downed then
            local ped = PlayerPedId()

            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)    -- Maus X
            EnableControlAction(0, 2, true)    -- Maus Y
            EnableControlAction(0, 245, true)  -- Chat
            EnableControlAction(0, 249, true)  -- Push to talk

            -- Animation notfalls neu starten.
            if not IsEntityPlayingAnim(ped, DOWNED_DICT, DOWNED_ANIM, 3) and not IsPedRagdoll(ped) then
                playDownedAnimation()
            end

            if GetEntityHealth(ped) < 110 then
                SetEntityHealth(ped, 120)
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Tasten ---------------------------------------------------------------------

RegisterCommand('notruf', function()
    if not Death.downed then return end
    TriggerServerEvent('death:server:call')
end, false)

RegisterKeyMapping('notruf', 'Notruf absetzen (bewusstlos)', 'keyboard', DeathConfig.Keys.call)

RegisterCommand('aufgeben', function()
    if not Death.downed then return end

    if GetGameTimer() < Death.respawnAt then
        MS.Notify('Noch kannst du nicht aufgeben.', 'warning')
        return
    end

    TriggerServerEvent('death:server:respawn')
end, false)

RegisterKeyMapping('aufgeben', 'Aufgeben (bewusstlos)', 'keyboard', DeathConfig.Keys.respawn)

--- Wer einen Zufluchtsort hat, kriecht nach Hause statt ins Krankenhaus.
RegisterCommand('zuflucht_kriechen', function()
    if not Death.downed then return end

    if GetGameTimer() < Death.respawnAt then
        MS.Notify('Noch kannst du nicht aufgeben.', 'warning')
        return
    end

    TriggerServerEvent('death:server:respawn', true)
end, false)

RegisterKeyMapping('zuflucht_kriechen', 'In die eigene Zuflucht (bewusstlos)',
    'keyboard', DeathConfig.Keys.refuge)

-- Wiederbeleben --------------------------------------------------------------

--- Naechster bewusstloser Spieler in Reichweite.
local function nearestDowned()
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local best, bestDistance = nil, DeathConfig.Revive.range + 1.0

    for _, index in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(index)

        if ped ~= myPed and DoesEntityExist(ped) then
            local distance = #(myCoords - GetEntityCoords(ped))
            -- Bewusstlose liegen; das reicht als Vorfilter.
            if distance < bestDistance and (IsPedRagdoll(ped) or IsEntityPlayingAnim(ped, DOWNED_DICT, DOWNED_ANIM, 3)) then
                best, bestDistance = index, distance
            end
        end
    end

    return best
end

RegisterCommand('wiederbeleben', function()
    if Death.downed or Death.reviving then return end

    local target = nearestDowned()
    if not target then
        MS.Notify('Niemand in Reichweite.', 'error')
        return
    end

    TriggerServerEvent('death:server:requestRevive', GetPlayerServerId(target))
end, false)

RegisterNetEvent('death:client:playRevive', function(_, duration)
    Death.reviving = true

    local dict = 'amb@medic@standing@kneel@base'
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end

    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(PlayerPedId(), dict, 'base', 8.0, -8.0, duration * 1000, 1, 0.0, false, false, false)
    end

    MS.Notify('Du behandelst den Verletzten...', 'info', duration * 1000)

    SetTimeout(duration * 1000, function()
        Death.reviving = false
        ClearPedTasks(PlayerPedId())
    end)
end)

-- Notruf-Markierung ----------------------------------------------------------

RegisterNetEvent('death:client:incomingCall', function(data)
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, 153)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.1)
    SetBlipFlashes(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('Notruf: %s'):format(data.name))
    EndTextCommandSetBlipName(blip)

    MS.Notify(('Notruf von %s. Markierung auf der Karte.'):format(data.name), 'error', 10000)
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', true)

    SetTimeout((data.time or 120) * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

-- Hilfe fuer Umstehende ------------------------------------------------------

CreateThread(function()
    while true do
        local sleep = 800

        if MS.IsPlayerLoaded and not Death.downed and not Death.reviving then
            local target = nearestDowned()

            if target then
                sleep = 0
                local coords = GetEntityCoords(GetPlayerPed(target))
                MS.DrawText3D(coords + vector3(0.0, 0.0, 0.4), 'Bewusstlos')
                MS.DrawHelpText('Druecke ~INPUT_DETONATE~ zum Wiederbeleben')

                if IsControlJustReleased(0, 47) then   -- G
                    ExecuteCommand('wiederbeleben')
                end
            end
        end

        Wait(sleep)
    end
end)
