--- Das Einstellungsmenue.

local MS = exports['moonshine-core']:GetCoreObject()

local offen = false

local function oeffnen()
    if offen then return end

    offen = true
    SetNuiFocus(true, true)

    SendNUIMessage({ action = 'hud:menu', data = Hud.Settings })
    TriggerEvent('moonshine:client:nuiOpen', true)
end

local function schliessen()
    if not offen then return end

    offen = false
    SetNuiFocus(false, false)

    SendNUIMessage({ action = 'hud:menuClose' })
    TriggerEvent('moonshine:client:nuiOpen', false)
end

RegisterCommand('hudmenu', function()
    if offen then schliessen() else oeffnen() end
end, false)

RegisterKeyMapping('hudmenu', 'Anzeige einstellen', 'keyboard', HudConfig.Keys.menu)

-- NUI ---------------------------------------------------------------------------

--- Aendert eine Einstellung. `sofort` zeigt sie an, ohne zu sichern - so
--- sieht man am Regler direkt, was passiert.
RegisterNUICallback('hudSet', function(data, cb)
    local neu = Hud.Settings

    if type(data.feld) == 'string' then
        if data.feld == 'element' and type(data.key) == 'string' then
            neu.elemente[data.key] = data.wert == true
        else
            neu[data.feld] = data.wert
        end
    end

    Hud.ApplySettings(neu, data.sofort ~= true)
    cb({ settings = Hud.Settings })
end)

RegisterNUICallback('hudReset', function(_, cb)
    Hud.ResetSettings()
    MS.Notify('Anzeige zurückgesetzt.', 'info', 3000)

    cb({ settings = Hud.Settings })
end)

RegisterNUICallback('hudMenuClose', function(_, cb)
    -- Was nur zur Ansicht geaendert wurde, wird jetzt festgeschrieben.
    Hud.SaveSettings()
    schliessen()

    cb('ok')
end)

CreateThread(function()
    while true do
        if offen then
            if IsControlJustReleased(0, 322) then
                Hud.SaveSettings()
                schliessen()
            end

            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if offen then SetNuiFocus(false, false) end
end)
