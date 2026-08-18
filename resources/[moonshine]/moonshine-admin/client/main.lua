--- Adminpanel.

local MS = exports['moonshine-core']:GetCoreObject()

local isOpen = false

--- Ob der Spieler das Panel oeffnen darf. Setzt der Server beim ersten Sync.
Admin.Allowed = false

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'admin:close' })
end

RegisterNetEvent('admin:client:open', function(payload)
    Admin.Allowed = true

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'admin:open', data = payload })
end)

RegisterNetEvent('admin:client:data', function(payload)
    Admin.Allowed = true
    SendNUIMessage({ action = 'admin:data', data = payload })
end)

-- NUI ----------------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('action', function(data, cb)
    TriggerServerEvent('admin:server:action', data.action, data.target,
        data.value, data.extra)

    if data.action == 'tpTo' or data.action == 'spectate' then close() end

    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('admin:server:refresh')
    cb('ok')
end)

RegisterNUICallback('unban', function(data, cb)
    TriggerServerEvent('admin:server:unban', data.license)
    cb('ok')
end)

RegisterNUICallback('log', function(data, cb)
    MS.TriggerServerCallback('admin:log', function(rows)
        cb(rows or {})
    end, data.kind)
end)

RegisterNUICallback('noclip', function(_, cb)
    ExecuteCommand('noclip')
    close()
    cb('ok')
end)

RegisterNUICallback('invisible', function(_, cb)
    ExecuteCommand('unsichtbar')
    cb('ok')
end)

RegisterNUICallback('waypoint', function(data, cb)
    if data.coords then
        SetNewWaypoint(data.coords.x + 0.0, data.coords.y + 0.0)
        MS.Notify('Wegpunkt gesetzt.', 'info', 4000)
    end

    cb('ok')
end)

-- Steuerung -------------------------------------------------------------------------

RegisterCommand(AdminConfig.Command, function()
    if isOpen then
        close()
    else
        TriggerServerEvent('admin:server:open')
    end
end, false)

RegisterKeyMapping(AdminConfig.Command, 'Adminpanel', 'keyboard', AdminConfig.OpenKey)

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

--- Solange das Panel offen ist, alle 5 Sekunden aktualisieren.
CreateThread(function()
    while true do
        Wait(5000)
        if isOpen then TriggerServerEvent('admin:server:refresh') end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
end)
