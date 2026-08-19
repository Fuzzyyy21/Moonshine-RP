--- Anzeige des Klassenbeduerfnisses.

local MS = exports['moonshine-core']:GetCoreObject()

Needs.Current = nil

local sichtbar = NeedsConfig.Hud.immerSichtbar
local erzwungen = nil

--- Soll der Balken gerade zu sehen sein?
local function berechneSichtbarkeit()
    if not NeedsConfig.Hud.enabled then return false end
    if erzwungen ~= nil then return erzwungen end
    if NeedsConfig.Hud.immerSichtbar then return true end
    if not Needs.Current then return false end

    return Needs.Current.value <= NeedsConfig.Hud.zeigenAb
end

local function anzeigen()
    SendNUIMessage({
        action  = 'needs:sync',
        data    = Needs.Current,
        visible = berechneSichtbarkeit(),
    })
end

RegisterNetEvent('needs:client:sync', function(payload)
    Needs.Current = payload or nil
    anzeigen()
end)

--- Bei null zieht es Leben.
RegisterNetEvent('needs:client:drain', function(amount)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end

    SetEntityHealth(ped, math.max(1, GetEntityHealth(ped) - (amount or 4)))

    AnimpostfxPlay('MinigameEndNeutral', 900, false)
    SendNUIMessage({ action = 'needs:drain' })
end)

RegisterNetEvent('needs:client:consumed', function()
    local ped = PlayerPedId()

    RequestAnimDict('mp_player_inteat@burger')
    local tries = 0
    while not HasAnimDictLoaded('mp_player_inteat@burger') and tries < 30 do
        Wait(50)
        tries = tries + 1
    end

    if HasAnimDictLoaded('mp_player_inteat@burger') then
        TaskPlayAnim(ped, 'mp_player_inteat@burger', 'mp_player_int_eat_burger',
            2.0, -2.0, 2500, 49, 0, false, false, false)
    end
end)

-- Anzeige umschalten ---------------------------------------------------------

RegisterCommand(NeedsConfig.Hud.toggleCommand, function()
    if erzwungen == nil then
        erzwungen = not berechneSichtbarkeit()
    else
        erzwungen = not erzwungen
    end

    anzeigen()

    MS.Notify(erzwungen and 'Beduerfnis wird angezeigt.'
        or 'Beduerfnis wird ausgeblendet.', 'info', 3000)
end, false)

RegisterKeyMapping(NeedsConfig.Hud.toggleCommand, 'Beduerfnis ein-/ausblenden',
    'keyboard', '')

--- Der Balken taucht von selbst auf, wenn es knapp wird.
CreateThread(function()
    local zuletzt = nil

    while true do
        Wait(2000)

        local jetzt = berechneSichtbarkeit()
        if jetzt ~= zuletzt then
            zuletzt = jetzt
            anzeigen()
        end
    end
end)

--- Andere Oberflaechen blenden den Balken aus.
AddEventHandler('moonshine:client:nuiOpen', function(state)
    SendNUIMessage({ action = 'needs:visible', value = not state })
end)

CreateThread(function()
    Wait(4000)
    TriggerServerEvent('needs:server:request')
end)

exports('GetNeed', function()
    return Needs.Current and Needs.Current.value or nil
end)

exports('GetNeedData', function()
    return Needs.Current
end)
