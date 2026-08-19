--- Clientseitiger Einstiegspunkt: Spielerdaten, Benachrichtigungen, Basisevents.

MS.PlayerData     = {}
MS.IsPlayerLoaded = false

-- Datenabgleich --------------------------------------------------------------

RegisterNetEvent('moonshine:client:syncData', function(data)
    MS.PlayerData = data
    TriggerEvent('moonshine:client:dataChanged', data)
end)

RegisterNetEvent('moonshine:client:playerLoaded', function(data, position)
    MS.PlayerData = data
    MS.IsPlayerLoaded = true

    MS.SpawnPlayer(position)
    TriggerEvent('moonshine:client:dataChanged', data)
    TriggerEvent('moonshine:client:playerLoaded', data)

    MS.Notify(('Willkommen zurueck, %s.'):format(data.firstname), 'success', 6000)
end)

RegisterNetEvent('moonshine:client:returnToSelection', function()
    MS.IsPlayerLoaded = false
    MS.PlayerData = {}
    TriggerEvent('moonshine:client:playerUnloaded')
end)

-- Benachrichtigungen ---------------------------------------------------------

function MS.Notify(message, type, duration)
    SendNUIMessage({
        action = 'notify',
        data = { message = message, type = type or 'info', duration = duration or 5000 },
    })
end

RegisterNetEvent('moonshine:client:notify', function(message, type, duration)
    MS.Notify(message, type, duration)
end)

--- Text am unteren Bildschirmrand (z.B. "Druecke E zum Aufheben").
function MS.DrawHelpText(text)
    SetTextComponentFormat('STRING')
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

--- 3D-Text an Weltkoordinaten.
function MS.DrawText3D(coords, text, scale)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end

    scale = scale or 0.35
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Spielerzustand -------------------------------------------------------------

RegisterNetEvent('moonshine:client:heal', function(amount)
    local ped = PlayerPedId()
    local maxHealth = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.min(maxHealth, GetEntityHealth(ped) + (amount or 100)))
end)

RegisterNetEvent('moonshine:client:revive', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
end)

RegisterNetEvent('moonshine:client:teleport', function(x, y, z)
    local ped = PlayerPedId()
    DoScreenFadeOut(300)

    while not IsScreenFadedOut() do Wait(0) end

    SetEntityCoords(ped, x + 0.0, y + 0.0, z + 0.0, false, false, false, false)
    Wait(300)
    DoScreenFadeIn(300)
end)

RegisterNetEvent('moonshine:client:applyStatusDamage', function(amount)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end

    SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - (amount or 5)))
end)

RegisterNetEvent('moonshine:client:playConsume', function(kind)
    local ped = PlayerPedId()
    local dict = kind == 'drink' and 'mp_player_intdrink' or 'mp_player_inteat@burger'
    local anim = kind == 'drink' and 'loop_bottle' or 'mp_player_int_eat_burger'

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end

    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, 3000, 49, 0.0, false, false, false)
    end
end)

-- Position an den Server melden ----------------------------------------------

CreateThread(function()
    while true do
        Wait(30000)

        if MS.IsPlayerLoaded then
            local coords = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('moonshine:server:updatePosition',
                coords.x, coords.y, coords.z, GetEntityHeading(PlayerPedId()))
        end
    end
end)

-- Tod melden -----------------------------------------------------------------

--- Wer war es? Liefert die Server-Id des Toeters, sonst nil.
local function findKiller(ped)
    local source = GetPedSourceOfDeath(ped)
    if not source or source == 0 or source == ped then return nil end

    -- Aus einem Fahrzeug heraus zaehlt der Fahrer.
    if IsEntityAVehicle(source) then
        local driver = GetPedInVehicleSeat(source, -1)
        if driver and driver ~= 0 then source = driver end
    end

    if not IsEntityAPed(source) or not IsPedAPlayer(source) then return nil end

    local index = NetworkGetPlayerIndexFromPed(source)
    if not index or index == -1 then return nil end

    local serverId = GetPlayerServerId(index)
    if not serverId or serverId <= 0 then return nil end

    return serverId
end

CreateThread(function()
    local wasDead = false

    while true do
        Wait(500)

        if MS.IsPlayerLoaded then
            local ped = PlayerPedId()
            local dead = IsEntityDead(ped)

            if dead and not wasDead then
                local killer = findKiller(ped)
                local cause = GetPedCauseOfDeath(ped)

                TriggerServerEvent('moonshine:server:playerDied', killer, cause)
                TriggerEvent('moonshine:client:playerDied', killer, cause)
            end

            wasDead = dead
        end
    end
end)
