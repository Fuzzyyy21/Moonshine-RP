--- Oberflaeche der Fraktionen.

local isOpen   = false
local data     = nil
local list     = nil
local hasInvite = false

--- Die Bausteine der Wappen kennt das NUI aus dem Shared-Script.
CreateThread(function()
    Wait(500)
    SendNUIMessage({ action = 'factions:options', data = Factions.GetEmblemOptions() })
end)

local function push()
    SendNUIMessage({ action = 'factions:data', data = data })
end

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'factions:close' })
end

local function open()
    if isOpen then return end

    TriggerServerEvent('factions:server:request')
    TriggerServerEvent('factions:server:requestList')
    Wait(250)

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'factions:open' })
    push()
end

--- Merkt sich die eigene Fraktion fuer andere Skripte.
function GetFactionData()
    return data
end

exports('GetFactionData', GetFactionData)

-- Server -> Client -----------------------------------------------------------------

RegisterNetEvent('factions:client:sync', function(payload)
    data = payload or nil
    if isOpen then push() end
end)

RegisterNetEvent('factions:client:list', function(payload)
    list = payload or {}
    SendNUIMessage({ action = 'factions:list', data = list })
end)

RegisterNetEvent('factions:client:log', function(entries)
    SendNUIMessage({ action = 'factions:log', data = entries or {} })
end)

RegisterNetEvent('factions:client:invite', function(payload)
    hasInvite = true
    SendNUIMessage({ action = 'factions:invite', data = payload })

    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)

    SetTimeout((payload.seconds or 60) * 1000, function() hasInvite = false end)
end)

--- Willkommensbild beim Beitritt bzw. beim Einloggen.
RegisterNetEvent('factions:client:welcome', function(payload)
    SendNUIMessage({ action = 'factions:welcome', data = payload })
end)

-- NUI -> Client ----------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

--- Einfache Weiterleitungen an den Server.
local FORWARD = {
    create           = 'factions:server:create',
    invite           = 'factions:server:invite',
    kick             = 'factions:server:kick',
    leave            = 'factions:server:leave',
    setGrade         = 'factions:server:setGrade',
    transferOwner    = 'factions:server:transferOwner',
    disband          = 'factions:server:disband',
    setEmblem        = 'factions:server:setEmblem',
    rename           = 'factions:server:rename',
    setRanks         = 'factions:server:setRanks',
    upgradeSkill     = 'factions:server:upgradeSkill',
    resetSkills      = 'factions:server:resetSkills',
    deposit          = 'factions:server:deposit',
    withdraw         = 'factions:server:withdraw',
    vaultPut         = 'factions:server:vaultPut',
    vaultTake        = 'factions:server:vaultTake',
    buyItem          = 'factions:server:buyItem',
    buyVehicle       = 'factions:server:buyVehicle',
    takeVehicle      = 'factions:server:takeVehicle',
    sellVehicle      = 'factions:server:sellVehicle',
    setVehicleGrade  = 'factions:server:setVehicleGrade',
    claimMission     = 'factions:server:claimMission',
    acceptInvite     = 'factions:server:acceptInvite',
    declineInvite    = 'factions:server:declineInvite',
    requestLog       = 'factions:server:requestLog',
}

for name, event in pairs(FORWARD) do
    local target = event

    RegisterNUICallback(name, function(payload, cb)
        payload = payload or {}

        if target == 'factions:server:create' then
            TriggerServerEvent(target, payload.name, payload.tag)
        elseif target == 'factions:server:rename' then
            TriggerServerEvent(target, payload.name, payload.tag)
        elseif target == 'factions:server:setEmblem' then
            TriggerServerEvent(target, payload.emblem)
        elseif target == 'factions:server:setRanks' then
            TriggerServerEvent(target, payload.ranks)
        elseif target == 'factions:server:setGrade' then
            TriggerServerEvent(target, payload.characterId, payload.grade)
        elseif target == 'factions:server:vaultPut' then
            TriggerServerEvent(target, payload.slot, payload.count)
        elseif target == 'factions:server:vaultTake' then
            TriggerServerEvent(target, payload.index, payload.count)
        elseif target == 'factions:server:buyItem' then
            TriggerServerEvent(target, payload.name, payload.amount)
        elseif target == 'factions:server:takeVehicle' then
            TriggerServerEvent(target, payload.id, payload.point)
        elseif target == 'factions:server:setVehicleGrade' then
            TriggerServerEvent(target, payload.id, payload.grade)
        elseif target == 'factions:server:disband' then
            TriggerServerEvent(target, payload.confirmation)
        elseif payload.value ~= nil then
            TriggerServerEvent(target, payload.value)
        elseif payload.id ~= nil then
            TriggerServerEvent(target, payload.id)
        elseif payload.characterId ~= nil then
            TriggerServerEvent(target, payload.characterId)
        elseif payload.amount ~= nil then
            TriggerServerEvent(target, payload.amount)
        else
            TriggerServerEvent(target)
        end

        cb('ok')
    end)
end

--- Das eigene Inventar fuer den Tresor.
RegisterNUICallback('requestInventory', function(_, cb)
    local core = exports['moonshine-core']:GetPlayerData()
    cb(core and core.inventory or {})
end)

-- Steuerung ----------------------------------------------------------------------------

RegisterCommand(FactionConfig.Command, function(_, args)
    if args[1] == 'annehmen' then
        TriggerServerEvent('factions:server:acceptInvite')
        return
    end

    if isOpen then close() else open() end
end, false)

RegisterKeyMapping(FactionConfig.Command, 'Fraktion oeffnen', 'keyboard', FactionConfig.OpenKey)

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

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
end)
