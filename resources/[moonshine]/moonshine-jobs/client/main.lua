--- Jobcenter, Anmeldepunkte und Blips.

local MS = exports['moonshine-core']:GetCoreObject()

local isOpen = false
local centerPed = nil

-- Oberflaeche ------------------------------------------------------------------

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'work:close' })
end

RegisterNetEvent('work:client:center', function(payload)
    if isOpen then
        SendNUIMessage({ action = 'work:center', data = payload })
        return
    end

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'work:open', data = payload })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('setJob', function(data, cb)
    TriggerServerEvent('work:server:setJob', data.name)
    cb('ok')
end)

RegisterNUICallback('start', function(data, cb)
    TriggerServerEvent('work:server:start', data.id)
    close()
    cb('ok')
end)

RegisterNUICallback('stop', function(_, cb)
    TriggerServerEvent('work:server:stop')
    cb('ok')
end)

--- Route zum Anmeldepunkt setzen.
RegisterNUICallback('route', function(data, cb)
    if data.coords then
        SetNewWaypoint(data.coords.x + 0.0, data.coords.y + 0.0)
        MS.Notify('Wegpunkt gesetzt.', 'info', 4000)
    end

    close()
    cb('ok')
end)

RegisterNUICallback('leaderboard', function(data, cb)
    MS.TriggerServerCallback('work:leaderboard', function(rows)
        cb(rows or {})
    end, data.id)
end)

-- Jobcenter --------------------------------------------------------------------

CreateThread(function()
    Wait(2000)

    local config = WorkConfig.JobCenter
    if not config.enabled then return end

    -- Blip
    if config.blip then
        local blip = AddBlipForCoord(config.coords.x, config.coords.y, config.coords.z)
        SetBlipSprite(blip, config.blip.sprite)
        SetBlipColour(blip, config.blip.colour)
        SetBlipScale(blip, config.blip.scale)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(config.label)
        EndTextCommandSetBlipName(blip)
    end

    -- Sachbearbeiterin
    local hash = joaat(config.ped)
    RequestModel(hash)

    local tries = 0
    while not HasModelLoaded(hash) and tries < 100 do
        Wait(50)
        tries = tries + 1
    end

    if HasModelLoaded(hash) then
        centerPed = CreatePed(4, hash, config.coords.x, config.coords.y,
            config.coords.z - 1.0, config.heading or 0.0, false, true)

        SetEntityInvincible(centerPed, true)
        SetBlockingOfNonTemporaryEvents(centerPed, true)
        FreezeEntityPosition(centerPed, true)
        TaskStartScenarioInPlace(centerPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)

        SetModelAsNoLongerNeeded(hash)
    end
end)

--- Anmeldepunkte der Auftraege als Blip.
CreateThread(function()
    Wait(2500)

    for _, id in ipairs(Work.Order) do
        local definition = Work.GetJob(id)
        local coords = definition.start.coords

        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 566)
        SetBlipColour(blip, 47)
        SetBlipScale(blip, 0.65)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(definition.start.label)
        EndTextCommandSetBlipName(blip)
    end
end)

-- Marker und Interaktion --------------------------------------------------------

CreateThread(function()
    while true do
        local wait = 900
        local coords = GetEntityCoords(PlayerPedId())

        -- Jobcenter
        if WorkConfig.JobCenter.enabled then
            local distance = #(coords - WorkConfig.JobCenter.coords)

            if distance < 20.0 then
                wait = 0

                if distance <= WorkConfig.Range + 2.0 and not isOpen then
                    MS.DrawText3D(WorkConfig.JobCenter.coords + vector3(0.0, 0.0, 1.0),
                        '~b~E~s~  Jobcenter', 0.42)

                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent('work:server:openCenter')
                    end
                end
            end
        end

        -- Anmeldepunkte der Auftraege
        if not (Work.IsWorking and Work.IsWorking()) then
            for _, id in ipairs(Work.Order) do
                local definition = Work.GetJob(id)
                local distance = #(coords - definition.start.coords)

                if distance < 25.0 then
                    wait = 0

                    DrawMarker(36, definition.start.coords.x, definition.start.coords.y,
                        definition.start.coords.z + 0.8,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.85, 0.85, 0.85,
                        95, 201, 138, 150, false, true, 2, false, nil, nil, false)

                    if distance <= WorkConfig.Range + 4.0 then
                        MS.DrawText3D(definition.start.coords + vector3(0.0, 0.0, 1.2),
                            ('~b~E~s~  %s %s'):format(definition.icon, definition.label), 0.42)

                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('work:server:start', id)
                        end
                    end
                end
            end
        end

        Wait(wait)
    end
end)

RegisterCommand('jobcenter', function()
    if isOpen then
        close()
    else
        TriggerServerEvent('work:server:openCenter')
    end
end, false)

CreateThread(function()
    while true do
        if isOpen then
            if IsControlJustReleased(0, 322) then close() end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    Wait(4000)
    TriggerServerEvent('work:server:request')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if isOpen then SetNuiFocus(false, false) end
    if centerPed and DoesEntityExist(centerPed) then DeletePed(centerPed) end
end)
