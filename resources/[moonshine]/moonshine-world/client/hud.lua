--- Kleines Widget mit Uhrzeit, Mondphase und laufendem Ereignis.

local visible = WorldConfig.Hud.enabled

CreateThread(function()
    Wait(1200)
    SendNUIMessage({ action = 'world:setup', data = {
        showClock = WorldConfig.Hud.showClock,
        showMoon  = WorldConfig.Hud.showMoon,
        visible   = visible,
    } })
end)

RegisterCommand(WorldConfig.Hud.toggleCommand, function()
    visible = not visible
    SendNUIMessage({ action = 'world:visible', value = visible })
end, false)

RegisterKeyMapping(WorldConfig.Hud.toggleCommand, 'Weltanzeige ein-/ausblenden',
    'keyboard', '')

--- Das Widget verschwindet, solange eine andere Oberflaeche offen ist.
AddEventHandler('moonshine:client:nuiOpen', function(state)
    SendNUIMessage({ action = 'world:visible', value = visible and not state })
end)

exports('SetWorldHudVisible', function(state)
    SendNUIMessage({ action = 'world:visible', value = state == true })
end)
