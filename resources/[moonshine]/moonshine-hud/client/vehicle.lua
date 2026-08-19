--- Fahrzeugwerte fuer die Anzeige - und der Gurt.
---
--- Der Gurt steht hier, weil die Anzeige sonst etwas anzeigen wuerde, das es
--- gar nicht gibt. Ein Gurtsymbol ohne Gurt ist Dekoration; mit Gurt ist es
--- eine Entscheidung, die beim naechsten Baum spuerbar wird.

local MS = exports['moonshine-core']:GetCoreObject()

Hud.Vehicle = { angeschnallt = false, tempomat = nil }

--- Letzte Geschwindigkeit, um einen Aufprall zu erkennen.
local letzteGeschwindigkeit = 0.0

--- Umrechnung aus Metern je Sekunde.
local function tempo(entity, einheit)
    local ms = GetEntitySpeed(entity)
    return math.floor(ms * (einheit == 'mph' and 2.23694 or 3.6))
end

--- Sitzt der Spieler als Fahrer oder Beifahrer in einem Auto?
---@return number|nil vehicle, boolean fahrer
function Hud.InVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil, false end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then return nil, false end

    return vehicle, GetPedInVehicleSeat(vehicle, -1) == ped
end

--- Tank aus moonshine-vehicles, sonst der Wert des Spiels.
local function tank(vehicle)
    local wert = nil

    pcall(function()
        local plate = GetVehicleNumberPlateText(vehicle)
        wert = exports['moonshine-vehicles']:GetFuel(plate)
    end)

    if type(wert) ~= 'number' then wert = GetVehicleFuelLevel(vehicle) end

    return math.max(0, math.min(100, math.floor(wert or 0)))
end

--- Motorzustand in Prozent.
local function motor(vehicle)
    local wert = GetVehicleEngineHealth(vehicle)
    return math.max(0, math.min(100, math.floor((wert or 0) / 10)))
end

--- Blinker: links, rechts, beide oder nichts.
local function blinker(vehicle)
    local links, rechts = GetVehicleIndicatorLights(vehicle)

    if links == 1 and rechts == 1 then return 'warn' end
    if links == 1 then return 'links' end
    if rechts == 1 then return 'rechts' end

    return nil
end

--- Licht: aus, Standlicht, Abblendlicht, Fernlicht.
local function licht(vehicle)
    local _, an, fern = GetVehicleLightsState(vehicle)

    if fern == 1 then return 'fern' end
    if an == 1 then return 'an' end

    return nil
end

--- Alle Fahrzeugwerte.
function Hud.CollectVehicle(einheit)
    local vehicle, fahrer = Hud.InVehicle()
    if not vehicle then return nil end

    return {
        fahrer      = fahrer,
        tempo       = tempo(vehicle, einheit),
        einheit     = einheit == 'mph' and 'mph' or 'km/h',
        drehzahl    = math.max(0.0, math.min(1.0, GetVehicleCurrentRpm(vehicle))),
        gang        = GetVehicleCurrentGear(vehicle),
        tank        = tank(vehicle),
        motor       = motor(vehicle),
        blinker     = blinker(vehicle),
        licht       = licht(vehicle),
        gurt        = Hud.Vehicle.angeschnallt,
        tempomat    = Hud.Vehicle.tempomat,
    }
end

-- Gurt -----------------------------------------------------------------------------

local function setGurt(state)
    local vehicle, fahrer = Hud.InVehicle()
    if not vehicle then return end

    Hud.Vehicle.angeschnallt = state == true

    -- Angeschnallt fliegt niemand durch die Scheibe.
    SetPedConfigFlag(PlayerPedId(), 32, not Hud.Vehicle.angeschnallt)

    MS.Notify(Hud.Vehicle.angeschnallt and 'Angeschnallt.' or 'Gurt gelöst.',
        Hud.Vehicle.angeschnallt and 'success' or 'warning', 2500)

    TriggerEvent('hud:client:belt', Hud.Vehicle.angeschnallt, fahrer)
end

RegisterCommand('gurt', function()
    local vehicle = Hud.InVehicle()
    if not vehicle then return end

    setGurt(not Hud.Vehicle.angeschnallt)
end, false)

RegisterKeyMapping('gurt', 'Gurt an-/ablegen', 'keyboard', HudConfig.Keys.belt)

--- Aussteigen loest den Gurt.
CreateThread(function()
    while true do
        Wait(500)

        if Hud.Vehicle.angeschnallt and not Hud.InVehicle() then
            Hud.Vehicle.angeschnallt = false
            Hud.Vehicle.tempomat = nil
            SetPedConfigFlag(PlayerPedId(), 32, true)
        end
    end
end)

--- Ohne Gurt geht es bei einem harten Aufprall durch die Scheibe.
CreateThread(function()
    while true do
        local vehicle = Hud.InVehicle()

        if vehicle then
            local jetzt = GetEntitySpeed(vehicle) * 3.6

            if not Hud.Vehicle.angeschnallt
                and letzteGeschwindigkeit > 90.0
                and (letzteGeschwindigkeit - jetzt) > 55.0 then

                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)

                SetEntityCoords(ped, coords.x, coords.y, coords.z - 0.4,
                    true, true, true, false)
                SetEntityVelocity(ped,
                    GetEntityVelocity(vehicle).x * 3.0,
                    GetEntityVelocity(vehicle).y * 3.0,
                    2.0)

                SetPedToRagdoll(ped, 3000, 3000, 0, false, false, false)
                ApplyDamageToPed(ped, 22, false)

                MS.Notify('Du fliegst durch die Scheibe.', 'error', 5000)
            end

            letzteGeschwindigkeit = jetzt
            Wait(80)
        else
            letzteGeschwindigkeit = 0.0
            Wait(700)
        end
    end
end)

--- Warnton, solange der Fahrer ueber 40 km/h ohne Gurt faehrt.
CreateThread(function()
    while true do
        local wait = 1500

        if Hud.Settings.gurtWarnung then
            local vehicle, fahrer = Hud.InVehicle()

            if vehicle and fahrer and not Hud.Vehicle.angeschnallt
                and GetEntitySpeed(vehicle) * 3.6 > 40.0
                and GetVehicleClass(vehicle) ~= 8 then

                PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
                wait = 3000
            end
        end

        Wait(wait)
    end
end)

-- Tempomat ---------------------------------------------------------------------------

RegisterCommand('tempomat', function()
    local vehicle, fahrer = Hud.InVehicle()
    if not vehicle or not fahrer then return end

    if Hud.Vehicle.tempomat then
        Hud.Vehicle.tempomat = nil
        SetEntityMaxSpeed(vehicle, GetVehicleModelMaxSpeed(GetEntityModel(vehicle)))
        MS.Notify('Tempomat aus.', 'info', 2500)
        return
    end

    local ms = GetEntitySpeed(vehicle)
    if ms < 8.0 then
        MS.Notify('Zu langsam für den Tempomat.', 'error', 3000)
        return
    end

    Hud.Vehicle.tempomat = math.floor(ms * 3.6)
    SetEntityMaxSpeed(vehicle, ms)

    MS.Notify(('Tempomat auf %d km/h.'):format(Hud.Vehicle.tempomat), 'success', 3000)
end, false)

RegisterKeyMapping('tempomat', 'Tempomat', 'keyboard', '')

--- Der Tempomat endet mit dem Fahrzeug.
CreateThread(function()
    while true do
        Wait(1000)

        if Hud.Vehicle.tempomat then
            local vehicle, fahrer = Hud.InVehicle()

            if not vehicle or not fahrer then Hud.Vehicle.tempomat = nil end
        end
    end
end)

exports('IsBuckled', function()
    return Hud.Vehicle.angeschnallt
end)
