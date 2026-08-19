--- Der Takt: Werte sammeln, an die Oberflaeche schicken, GTA-Anzeige zaehmen.

local MS = exports['moonshine-core']:GetCoreObject()

--- Ist gerade eine andere Oberflaeche offen? Dann tritt die Anzeige zurueck.
local verdeckt = false

--- Zuletzt geschickte Kontostaende, um Aenderungen hervorzuheben.
local letztesGeld = nil

--- Soll die Anzeige gerade ueberhaupt laufen?
---
--- Nicht abgefragt wird IsNuiFocused: das waere zwar bequem, trifft aber
--- auch die Chateingabe - und dabei soll die Anzeige stehen bleiben.
local function laeuft()
    if not MS.IsPlayerLoaded or not Hud.Settings.an then return false end
    if verdeckt or IsPauseMenuActive() then return false end

    return true
end

--- Welche Kontoaenderung sich seit dem letzten Takt ergeben hat.
local function geldDelta(geld)
    if not letztesGeld then
        letztesGeld = geld
        return nil
    end

    local delta = nil

    for _, konto in ipairs({ 'bargeld', 'bank', 'schwarz' }) do
        local unterschied = (geld[konto] or 0) - (letztesGeld[konto] or 0)

        if unterschied ~= 0 then
            delta = delta or {}
            delta[konto] = unterschied
        end
    end

    letztesGeld = geld
    return delta
end

-- Takt --------------------------------------------------------------------------

CreateThread(function()
    Hud.LoadSettings()

    Wait(1200)
    SendNUIMessage({ action = 'hud:setup', data = {
        elemente = HudConfig.Elements,
        auswahl  = HudConfig.Choices,
        grenzen  = HudConfig.Limits,
        gruppen  = Hud.Groups(),
        schwellen = HudConfig.Schwellen,
    } })
    SendNUIMessage({ action = 'hud:settings', data = Hud.Settings })

    while true do
        if laeuft() then
            local daten = Hud.Collect()
            daten.delta = geldDelta(daten.geld)

            SendNUIMessage({ action = 'hud:update', data = daten })
            SendNUIMessage({ action = 'hud:visible', value = true })
        else
            SendNUIMessage({ action = 'hud:visible', value = false })
        end

        Wait(HudConfig.Tick)
    end
end)

--- Fahrzeugwerte laufen schneller, sonst springt der Tacho.
CreateThread(function()
    Wait(2000)

    while true do
        local wait = 600

        if laeuft() and Hud.InVehicle() then
            SendNUIMessage({ action = 'hud:vehicle',
                data = Hud.CollectVehicle(Hud.Settings.einheit) })

            wait = HudConfig.VehicleTick
        else
            SendNUIMessage({ action = 'hud:vehicle', data = nil })
        end

        Wait(wait)
    end
end)

-- Ein und aus -----------------------------------------------------------------------

RegisterCommand('hud', function()
    local neu = Hud.Settings
    neu.an = not neu.an

    Hud.ApplySettings(neu, true)
    MS.Notify(neu.an and 'Anzeige an.' or 'Anzeige aus.', 'info', 2500)
end, false)

RegisterKeyMapping('hud', 'Anzeige ein-/ausblenden', 'keyboard', HudConfig.Keys.toggle)

--- Solange eine andere Oberflaeche offen ist, verschwindet die Anzeige.
AddEventHandler('moonshine:client:nuiOpen', function(state)
    verdeckt = state == true
end)

AddEventHandler('moonshine:client:playerUnloaded', function()
    letztesGeld = nil
    SendNUIMessage({ action = 'hud:visible', value = false })
end)

-- GTA-Anzeige zaehmen ------------------------------------------------------------------

CreateThread(function()
    while true do
        if MS.IsPlayerLoaded then
            HideHudComponentThisFrame(1)   -- Waffenrad
            HideHudComponentThisFrame(2)   -- Munition im Waffenrad
            HideHudComponentThisFrame(3)   -- Bargeld
            HideHudComponentThisFrame(4)   -- Mehrspieler-Bargeld
            HideHudComponentThisFrame(13)  -- Geldaenderung
            HideHudComponentThisFrame(20)  -- Waffensymbol

            -- Der eigene Tacho ersetzt die Fahrzeuganzeige des Spiels.
            if Hud.Settings.an and Hud.Shows('tacho') then
                HideHudComponentThisFrame(6)
                HideHudComponentThisFrame(7)
                HideHudComponentThisFrame(8)
                HideHudComponentThisFrame(9)
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SendNUIMessage({ action = 'hud:visible', value = false })
end)
