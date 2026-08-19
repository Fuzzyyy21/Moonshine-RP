--- Umbauten an einem Fahrzeug: auftragen und wieder ablesen.
---
--- Die Spalte `mods` in ms_vehicles gab es von Anfang an, benutzt hat sie
--- niemand. Hier steht, was drin steht und wie es ans Fahrzeug kommt.
---
--- Aufbau:
---   {
---     teile      = { ['11'] = 3, ['12'] = 2, ... },  -- Modart -> Stufe
---     primaer    = 12, sekundaer = 12,
---     perlmutt   = 0,  felgenfarbe = 0,
---     felgenart  = 7,
---     folie      = 1,
---     kennzeichen= 0,
---     neon       = { an = true, r = 155, g = 107, b = 216 },
---     xenon      = { an = true, farbe = 1 },
---     rauch      = { an = true, r = 20, g = 20, b = 20 },
---   }

--- Modarten, die eine Stufe haben (0 bis n, -1 heisst ab Werk).
Vehicles.ModTypes = {
    motor = 11, bremsen = 12, getriebe = 13, federung = 15, panzerung = 16,
    turbo = 18, hupe = 14, felgen = 23, spoiler = 0, frontstossstange = 1,
    heckstossstange = 2, seitenschweller = 3, auspuff = 4, ueberrollbuegel = 5,
    griffe = 6, motorhaube = 7, kotfluegel = 8, hecklackierung = 9,
    dach = 10, kennzeichenhalter = 25, verzierung = 26, tuer = 27,
    lenkrad = 33, sitze = 32, schaltknauf = 34, gasgriff = 35,
}

--- Umgekehrt: Modart -> Name.
Vehicles.ModNames = {}
for name, id in pairs(Vehicles.ModTypes) do Vehicles.ModNames[id] = name end

--- Diese drei sind Schalter, keine Stufen. GetVehicleMod liefert dafuer
--- immer -1; abgefragt werden sie ueber IsToggleModOn.
local SCHALTER = { [18] = true, [20] = true, [22] = true }

--- Liest alle Umbauten von einem Fahrzeug ab.
function Vehicles.ReadMods(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return nil end

    local teile = {}
    for _, id in pairs(Vehicles.ModTypes) do
        if SCHALTER[id] then
            if IsToggleModOn(vehicle, id) then teile[tostring(id)] = 1 end
        else
            local stufe = GetVehicleMod(vehicle, id)
            if stufe ~= nil and stufe >= 0 then teile[tostring(id)] = stufe end
        end
    end

    local primaer, sekundaer = GetVehicleColours(vehicle)
    local perlmutt, felgenfarbe = GetVehicleExtraColours(vehicle)

    local neonAn = false
    for index = 0, 3 do
        if IsVehicleNeonLightEnabled(vehicle, index) then neonAn = true break end
    end

    local neonR, neonG, neonB = GetVehicleNeonLightsColour(vehicle)
    local rauchR, rauchG, rauchB = GetVehicleTyreSmokeColor(vehicle)

    return {
        teile       = teile,
        primaer     = primaer,
        sekundaer   = sekundaer,
        perlmutt    = perlmutt,
        felgenfarbe = felgenfarbe,
        felgenart   = GetVehicleWheelType(vehicle),
        folie       = GetVehicleWindowTint(vehicle),
        kennzeichen = GetVehicleNumberPlateTextIndex(vehicle),
        neon        = { an = neonAn, r = neonR, g = neonG, b = neonB },
        xenon       = { an = IsToggleModOn(vehicle, 22),
                        farbe = GetVehicleHeadlightsColour(vehicle) },
        rauch       = { an = IsToggleModOn(vehicle, 20),
                        r = rauchR, g = rauchG, b = rauchB },
    }
end

--- Traegt Umbauten auf ein Fahrzeug auf.
---
--- SetVehicleModKit muss vor allem anderen laufen, sonst nimmt das Fahrzeug
--- gar keine Umbauten an - das ist die haeufigste Stolperfalle dabei.
function Vehicles.ApplyMods(vehicle, mods)
    if not vehicle or not DoesEntityExist(vehicle) then return false end

    SetVehicleModKit(vehicle, 0)

    if type(mods) ~= 'table' then return false end

    -- Farben
    if mods.primaer or mods.sekundaer then
        local primaer, sekundaer = GetVehicleColours(vehicle)
        SetVehicleColours(vehicle, mods.primaer or primaer, mods.sekundaer or sekundaer)
    end

    if mods.perlmutt or mods.felgenfarbe then
        local perlmutt, felgenfarbe = GetVehicleExtraColours(vehicle)
        SetVehicleExtraColours(vehicle, mods.perlmutt or perlmutt,
            mods.felgenfarbe or felgenfarbe)
    end

    -- Felgenart muss vor den Felgen selbst stehen, sonst passt die
    -- Nummerierung nicht zusammen.
    if mods.felgenart then SetVehicleWheelType(vehicle, mods.felgenart) end
    if mods.folie then SetVehicleWindowTint(vehicle, mods.folie) end
    if mods.kennzeichen then SetVehicleNumberPlateTextIndex(vehicle, mods.kennzeichen) end

    -- Teile
    for id, stufe in pairs(mods.teile or {}) do
        local modId = tonumber(id)
        local wert = tonumber(stufe)

        if modId and wert then
            if SCHALTER[modId] then
                ToggleVehicleMod(vehicle, modId, wert > 0)
            else
                SetVehicleMod(vehicle, modId, wert, false)
            end
        end
    end

    -- Neon
    if type(mods.neon) == 'table' then
        for index = 0, 3 do
            SetVehicleNeonLightEnabled(vehicle, index, mods.neon.an == true)
        end

        if mods.neon.an then
            SetVehicleNeonLightsColour(vehicle,
                mods.neon.r or 255, mods.neon.g or 255, mods.neon.b or 255)
        end
    end

    -- Xenon
    if type(mods.xenon) == 'table' then
        ToggleVehicleMod(vehicle, 22, mods.xenon.an == true)
        if mods.xenon.an then
            SetVehicleHeadlightsColour(vehicle, mods.xenon.farbe or 0)
        end
    end

    -- Reifenrauch
    if type(mods.rauch) == 'table' then
        ToggleVehicleMod(vehicle, 20, mods.rauch.an == true)
        if mods.rauch.an then
            SetVehicleTyreSmokeColor(vehicle,
                mods.rauch.r or 255, mods.rauch.g or 255, mods.rauch.b or 255)
        end
    end

    return true
end

--- Wie viele Stufen es fuer eine Modart an diesem Fahrzeug gibt.
--- 0 heisst: gibt es hier nicht.
function Vehicles.CountMod(vehicle, modId)
    if not vehicle or not DoesEntityExist(vehicle) then return 0 end

    SetVehicleModKit(vehicle, 0)
    return GetNumVehicleMods(vehicle, modId) or 0
end

-- Vom Server ---------------------------------------------------------------------

RegisterNetEvent('vehicles:client:applyMods', function(plate, mods)
    local vehicle = Vehicles.Mine[Vehicles.CleanPlate(plate)]

    if not vehicle or not DoesEntityExist(vehicle) then
        vehicle = Vehicles.FindByPlate(plate, 12.0)
    end

    if vehicle then Vehicles.ApplyMods(vehicle, mods) end
end)

exports('ApplyMods', function(vehicle, mods)
    return Vehicles.ApplyMods(vehicle, mods)
end)

exports('ReadMods', function(vehicle)
    return Vehicles.ReadMods(vehicle)
end)

exports('CountMod', function(vehicle, modId)
    return Vehicles.CountMod(vehicle, modId)
end)
