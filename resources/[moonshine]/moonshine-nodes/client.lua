--- Steinadern: Marker, Fortschrittsbalken und Abbau.

local MS = exports['moonshine-core']:GetCoreObject()

local nodeState = {}      -- [index] = { depleted = bool, busy = bool }
local mining = nil        -- { index, endTime, damage }

RegisterNetEvent('nodes:client:sync', function(state)
    nodeState = state or {}
end)

-- Fortschrittsbalken ---------------------------------------------------------

local function drawProgress(label, progress)
    local width, height = 0.22, 0.022
    local x, y = 0.5, 0.86

    DrawRect(x, y, width + 0.006, height + 0.008, 0, 0, 0, 190)
    DrawRect(x - width / 2 + (width * progress) / 2, y, width * progress, height, 190, 150, 70, 235)

    SetTextFont(4)
    SetTextScale(0.34, 0.34)
    SetTextColour(235, 232, 240, 220)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(label)
    DrawText(x, y - 0.032)
end

RegisterNetEvent('nodes:client:mining', function(index, duration, damage)
    if mining then return end

    mining = {
        index   = index,
        endTime = GetGameTimer() + duration * 1000,
        damage  = damage,
    }

    local ped = PlayerPedId()
    local dict = 'melee@hatchet@streamed_core'

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end

    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, 'plyr_front_takedown', 4.0, -4.0, duration * 1000, 1, 0.0, false, false, false)
    end

    -- Verfluchte Adern zehren waehrend des Abbaus an der Gesundheit.
    if damage and damage > 0 then
        CreateThread(function()
            while mining do
                Wait(2000)
                local health = GetEntityHealth(PlayerPedId())
                if health > 20 then
                    SetEntityHealth(PlayerPedId(), health - math.ceil(damage / 3))
                    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.18)
                end
            end
        end)
    end
end)

--- Bricht den Abbau ab, wenn der Spieler weglaeuft oder stirbt.
CreateThread(function()
    while true do
        if mining then
            local definition = NodeConfig.Nodes[mining.index]
            local ped = PlayerPedId()

            if not definition then
                mining = nil
            else
                local distance = #(GetEntityCoords(ped) - definition.coords)
                local remaining = mining.endTime - GetGameTimer()

                if remaining <= 0 or distance > NodeConfig.Mining.range + 2.0 or IsEntityDead(ped) then
                    ClearPedTasks(ped)
                    mining = nil
                else
                    local total = NodeConfig.Mining.duration * 1000
                    drawProgress(('%s wird abgebaut'):format(
                        NodeConfig.Types[definition.type] and NodeConfig.Types[definition.type].label or 'Ader'),
                        1.0 - (remaining / total))
                    DisableControlAction(0, 22, true)   -- Springen
                end
            end

            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- Marker und Interaktion -----------------------------------------------------

CreateThread(function()
    if not NodeConfig.Blips.enabled then return end

    for _, definition in ipairs(NodeConfig.Nodes) do
        local blip = AddBlipForCoord(definition.coords.x, definition.coords.y, definition.coords.z)
        SetBlipSprite(blip, NodeConfig.Blips.sprite)
        SetBlipColour(blip, NodeConfig.Blips.color)
        SetBlipScale(blip, NodeConfig.Blips.scale)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Steinader')
        EndTextCommandSetBlipName(blip)
    end
end)

CreateThread(function()
    while true do
        local sleep = 900

        if MS.IsPlayerLoaded and not mining then
            local coords = GetEntityCoords(PlayerPedId())

            for index, definition in ipairs(NodeConfig.Nodes) do
                local distance = #(coords - definition.coords)

                if distance < NodeConfig.Mining.drawDistance then
                    sleep = 0

                    local nodeType = NodeConfig.Types[definition.type]
                    local state = nodeState[index] or {}
                    local color = nodeType and nodeType.color or { 180, 180, 180 }
                    local alpha = state.depleted and 60 or 170

                    DrawMarker(23, definition.coords.x, definition.coords.y, definition.coords.z - 0.95,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.1, 1.1, 0.6,
                        color[1], color[2], color[3], alpha,
                        false, false, 2, false, nil, nil, false)

                    if distance < NodeConfig.Mining.range then
                        if state.depleted then
                            MS.DrawText3D(definition.coords + vector3(0.0, 0.0, 0.5), 'Ader erschoepft')
                        elseif state.busy then
                            MS.DrawText3D(definition.coords + vector3(0.0, 0.0, 0.5), 'Hier arbeitet jemand')
                        else
                            MS.DrawText3D(definition.coords + vector3(0.0, 0.0, 0.5),
                                nodeType and nodeType.label or 'Steinader')
                            MS.DrawHelpText('Druecke ~INPUT_CONTEXT~ zum Abbauen')

                            if IsControlJustReleased(0, 38) then
                                TriggerServerEvent('nodes:server:startMining', index)
                            end
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
