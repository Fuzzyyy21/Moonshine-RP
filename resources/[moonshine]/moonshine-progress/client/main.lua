--- Oberflaeche des Fortschrittssystems.

--- Kistenitems auch clientseitig bekannt machen (fuer das Inventar).
CreateThread(function()
    for _ = 1, 20 do
        if Progress.RegisterCaseItems() then break end
        Wait(500)
    end
end)

local isOpen  = false
local payload = nil
local loaded  = false

--- Schickt den aktuellen Zustand an die Oberflaeche.
local function push()
    if not payload then return end

    SendNUIMessage({ action = 'progress:data', data = payload })
end

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'progress:close' })
end

local function open()
    if isOpen or not loaded then return end
    if not payload then
        TriggerServerEvent('progress:server:request')
        Wait(300)
    end

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'progress:open' })
    push()
end

-- Server -> Client -----------------------------------------------------------

RegisterNetEvent('progress:client:sync', function(data)
    payload = data
    loaded  = true

    if isOpen then push() end
end)

RegisterNetEvent('progress:client:milestoneReady', function(minutes)
    SendNUIMessage({ action = 'progress:milestone', minutes = minutes })
end)

RegisterNetEvent('progress:client:missionDone', function(missionId)
    SendNUIMessage({ action = 'progress:missionDone', id = missionId })

    PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
end)

RegisterNetEvent('progress:client:battlePassLevel', function(level)
    SendNUIMessage({ action = 'progress:levelUp', level = level })

    PlaySoundFrontend(-1, 'MEDAL_UP', 'HUD_MINI_GAME_SOUNDSET', true)
end)

RegisterNetEvent('progress:client:caseResult', function(data)
    SendNUIMessage({ action = 'progress:caseResult', data = data })

    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
end)

-- NUI -> Client --------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('claimMilestone', function(data, cb)
    TriggerServerEvent('progress:server:claimMilestone', data.minutes)
    cb('ok')
end)

RegisterNUICallback('claimMission', function(data, cb)
    TriggerServerEvent('progress:server:claimMission', data.id)
    cb('ok')
end)

RegisterNUICallback('claimTier', function(data, cb)
    TriggerServerEvent('progress:server:claimTier', data.level, data.track)
    cb('ok')
end)

RegisterNUICallback('claimAll', function(_, cb)
    TriggerServerEvent('progress:server:claimAllTiers')
    cb('ok')
end)

RegisterNUICallback('buyPremium', function(_, cb)
    TriggerServerEvent('progress:server:buyPremium')
    cb('ok')
end)

RegisterNUICallback('openCase', function(data, cb)
    TriggerServerEvent('progress:server:openCase', data.name)
    cb('ok')
end)

RegisterNUICallback('packCase', function(data, cb)
    TriggerServerEvent('progress:server:packCase', data.name, data.amount)
    cb('ok')
end)

-- Steuerung -------------------------------------------------------------------

RegisterCommand(ProgressConfig.Command, function()
    if isOpen then close() else open() end
end, false)

RegisterKeyMapping(ProgressConfig.Command, 'Fortschritt oeffnen', 'keyboard', ProgressConfig.OpenKey)

--- ESC schliesst das Fenster.
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

--- Regelmaessig aktualisieren, damit Timer und Zaehler stimmen.
CreateThread(function()
    while true do
        Wait(ProgressConfig.SyncInterval * 1000)
        if isOpen then TriggerServerEvent('progress:server:request') end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
end)
