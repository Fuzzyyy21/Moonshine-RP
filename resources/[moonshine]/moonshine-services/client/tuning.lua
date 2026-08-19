--- Tuning: Auswahl mit Vorschau direkt am Fahrzeug.
---
--- Angeschaut wird sofort am echten Fahrzeug, bezahlt erst beim Einbauen.
--- Wer abbricht, bekommt den alten Zustand zurueck - deshalb liegt hier
--- eine Sicherung.

local MS = exports['moonshine-core']:GetCoreObject()

local tuning = nil        -- { vehicle, plate, sicherung, wunsch }

--- Fahrzeug, an dem gearbeitet wird.
local function targetVehicle()
    local ped = PlayerPedId()

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then return vehicle end

    local coords = GetEntityCoords(ped)
    vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 6.0, 0, 71)

    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then return vehicle end
    return nil
end

--- Umbauten am Fahrzeug ablesen (ueber moonshine-vehicles).
local function readMods(vehicle)
    local mods = nil
    pcall(function() mods = exports['moonshine-vehicles']:ReadMods(vehicle) end)

    return type(mods) == 'table' and mods or {}
end

local function applyMods(vehicle, mods)
    pcall(function() exports['moonshine-vehicles']:ApplyMods(vehicle, mods) end)
end

--- Uebersetzt einen Wunsch in das, was moonshine-vehicles auftragen kann.
---
--- Die Oberflaeche denkt in Teilnamen ("motor") und Farb-Ids ("violett"),
--- das Fahrzeug in GTA-Modnummern und RGB. Ohne diese Uebersetzung waehlt
--- man in der Vorschau etwas aus und am Auto passiert nichts.
local function zuMods(wunsch)
    local mods = { teile = {} }

    for id, stufe in pairs(type(wunsch.teile) == 'table' and wunsch.teile or {}) do
        local entry = Services.GetPart(id)
        if entry then mods.teile[tostring(entry.mod)] = stufe end
    end

    for _, feld in ipairs({ 'primaer', 'sekundaer', 'perlmutt', 'felgenfarbe',
                            'felgenart', 'folie', 'kennzeichen' }) do
        if wunsch[feld] ~= nil then mods[feld] = wunsch[feld] end
    end

    for _, feld in ipairs({ 'neon', 'rauch' }) do
        local eintrag = wunsch[feld]

        if type(eintrag) == 'table' then
            local farbe = eintrag.an and Services.GetNeon(eintrag.id) or nil

            mods[feld] = farbe
                and { an = true, r = farbe.r, g = farbe.g, b = farbe.b }
                or { an = false }
        end
    end

    if type(wunsch.xenon) == 'table' then
        mods.xenon = wunsch.xenon.an
            and { an = true, farbe = wunsch.xenon.farbe }
            or { an = false }
    end

    return mods
end

--- Wie viele Stufen es fuer ein Teil an diesem Fahrzeug gibt.
local function countMod(vehicle, modId)
    local anzahl = 0
    pcall(function()
        anzahl = exports['moonshine-vehicles']:CountMod(vehicle, modId)
    end)

    return tonumber(anzahl) or 0
end

--- Was dieses Fahrzeug ueberhaupt anbietet. Ein Kleinwagen hat keinen
--- Ueberrollbuegel; solche Teile stehen gar nicht erst in der Liste.
local function verfuegbar(vehicle)
    local liste = {}

    for _, entry in ipairs(Services.Cosmetics) do
        local anzahl = countMod(vehicle, entry.mod)
        if anzahl > 0 then liste[entry.id] = anzahl end
    end

    for _, entry in ipairs(Services.Performance) do
        local anzahl = countMod(vehicle, entry.mod)
        if anzahl > 0 then liste[entry.id] = anzahl end
    end

    return liste
end

-- Oeffnen -------------------------------------------------------------------------

function Services.OpenTuning(shop)
    if not ServiceConfig.Tuning.enabled then return end

    local vehicle = targetVehicle()
    if not vehicle then
        MS.Notify('Fahr ein Fahrzeug in die Werkstatt.', 'error')
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+$', '')

    MS.TriggerServerCallback('services:tuningState', function(payload)
        if not payload then
            MS.Notify('An diesem Fahrzeug darfst du nicht schrauben.', 'error')
            return
        end

        tuning = {
            vehicle   = vehicle,
            plate     = plate,
            sicherung = readMods(vehicle),
            wunsch    = {},
        }

        Services.Open('tuning', {
            label      = shop.label,
            plate      = plate,
            mods       = payload.mods,
            aktuell    = tuning.sicherung,
            verfuegbar = verfuegbar(vehicle),
            katalog    = payload.katalog,
            balance    = payload.balance,
            rabatt     = payload.rabatt,
        })
    end, plate)
end

--- Werkstatt, an der der Spieler gerade steht.
local function nearestWorkshop()
    local coords = GetEntityCoords(PlayerPedId())

    for _, shop in ipairs(Services.Workshops) do
        if #(coords - shop.coords) <= ServiceConfig.Range + 4.0 then return shop end
    end

    return nil
end

RegisterCommand('tuning', function()
    local shop = nearestWorkshop()

    if not shop then
        MS.Notify('Du stehst an keiner Werkstatt.', 'error')
        return
    end

    Services.OpenTuning(shop)
end, false)

--- Stellt den Zustand von vor der Vorschau wieder her.
local function zuruecksetzen()
    if not tuning then return end

    if DoesEntityExist(tuning.vehicle) then
        applyMods(tuning.vehicle, tuning.sicherung)
    end

    tuning = nil
end

-- NUI ----------------------------------------------------------------------------------

--- Vorschau: sofort am Fahrzeug sichtbar, noch nichts bezahlt.
RegisterNUICallback('tuningPreview', function(data, cb)
    if not tuning or not DoesEntityExist(tuning.vehicle) then return cb({ preis = 0 }) end

    tuning.wunsch = type(data.wunsch) == 'table' and data.wunsch or {}

    -- Erst den alten Stand, dann den Wunsch darueber - sonst bleibt stehen,
    -- was der Spieler gerade abgewaehlt hat.
    applyMods(tuning.vehicle, tuning.sicherung)
    applyMods(tuning.vehicle, zuMods(tuning.wunsch))

    MS.TriggerServerCallback('services:tuningQuote', function(quote)
        cb(quote or { preis = 0 })
    end, tuning.plate, tuning.wunsch)
end)

RegisterNUICallback('tuningBuy', function(_, cb)
    if not tuning then return cb('ok') end

    TriggerServerEvent('services:server:tune', tuning.plate, tuning.wunsch)
    cb('ok')
end)

RegisterNUICallback('tuningCancel', function(_, cb)
    zuruecksetzen()
    Services.Close()
    cb('ok')
end)

--- Der Server hat den Umbau eingebaut und bezahlt.
RegisterNetEvent('services:client:tuned', function(plate, mods, dauer)
    if not tuning or tuning.plate ~= plate then return end

    local vehicle = tuning.vehicle

    -- Ab jetzt ist der neue Stand der alte: ein Abbruch danach darf ihn
    -- nicht mehr zurueckdrehen.
    tuning.sicherung = mods
    tuning.wunsch = {}

    Services.Close()
    tuning = nil

    CreateThread(function()
        local schritte = 20

        for index = 1, schritte do
            Wait(math.floor((dauer or 8) * 1000 / schritte))
            SendNUIMessage({ action = 'services:repairProgress',
                value = index / schritte })
        end

        SendNUIMessage({ action = 'services:repairProgress', value = 0 })

        if DoesEntityExist(vehicle) then applyMods(vehicle, mods) end
        MS.Notify('Der Umbau sitzt.', 'success')
    end)
end)

--- Wer die Oberflaeche anders schliesst, bekommt trotzdem sein Auto zurueck.
AddEventHandler('services:client:closed', function()
    zuruecksetzen()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    zuruecksetzen()
end)
