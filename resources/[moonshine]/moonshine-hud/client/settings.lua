--- Einstellungen laden, sichern, zuruecksetzen.
---
--- Sie liegen im KVP-Speicher des Spielers, nicht in der Datenbank. Wie
--- jemand seine Anzeige haben will, ist eine Sache seines Rechners und
--- nicht seines Charakters - und so braucht es dafuer keinen Serverweg.

local SCHLUESSEL = 'moonshine:hud:einstellungen'

Hud.Settings = Hud.DefaultSettings()

--- Liest die gespeicherten Einstellungen.
function Hud.LoadSettings()
    local roh = GetResourceKvpString(SCHLUESSEL)

    if type(roh) == 'string' and roh ~= '' then
        local ok, gespeichert = pcall(json.decode, roh)

        if ok and type(gespeichert) == 'table' then
            Hud.Settings = Hud.Sanitize(gespeichert)
            return Hud.Settings
        end
    end

    Hud.Settings = Hud.DefaultSettings()
    return Hud.Settings
end

--- Schreibt sie zurueck.
function Hud.SaveSettings()
    local ok, roh = pcall(json.encode, Hud.Settings)
    if not ok then return false end

    SetResourceKvp(SCHLUESSEL, roh)
    return true
end

--- Uebernimmt eine geaenderte Einstellung.
---@param neu table
---@param speichern boolean|nil false = nur ausprobieren
function Hud.ApplySettings(neu, speichern)
    Hud.Settings = Hud.Sanitize(neu)

    if speichern ~= false then Hud.SaveSettings() end

    SendNUIMessage({ action = 'hud:settings', data = Hud.Settings })
    TriggerEvent('hud:client:settingsChanged', Hud.Settings)

    return Hud.Settings
end

--- Setzt alles auf den Auslieferungszustand.
function Hud.ResetSettings()
    return Hud.ApplySettings(Hud.DefaultSettings(), true)
end

--- Ein einzelnes Element schalten.
function Hud.ToggleElement(key, state)
    if not Hud.GetElement(key) then return false end

    local neu = Hud.Settings

    if state == nil then
        neu.elemente[key] = not neu.elemente[key]
    else
        neu.elemente[key] = state == true
    end

    Hud.ApplySettings(neu, true)
    return neu.elemente[key]
end

--- Ist dieses Element eingeschaltet?
function Hud.Shows(key)
    return Hud.Settings.elemente[key] == true
end

-- Schnittstelle -------------------------------------------------------------------

exports('GetSettings', function()
    return Hud.Settings
end)

exports('IsVisible', function()
    return Hud.Settings.an == true
end)

exports('SetVisible', function(state)
    local neu = Hud.Settings
    neu.an = state == true

    Hud.ApplySettings(neu, true)
    return neu.an
end)

exports('ToggleElement', function(key, state)
    return Hud.ToggleElement(key, state)
end)
