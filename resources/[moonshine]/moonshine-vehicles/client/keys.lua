--- Fahrzeugschluessel: Motor nur mit Schluessel, Ver- und Entriegeln.

local MS = exports['moonshine-core']:GetCoreObject()

--- Kennzeichen, fuer die der Schluessel schon geprueft wurde.
local checked = {}
local checking = false

--- Fragt den Server, ob wir dieses Fahrzeug fahren duerfen.
local function hasKey(plate, callback)
    if checked[plate] ~= nil then
        callback(checked[plate])
        return
    end

    if checking then
        callback(true)
        return
    end

    checking = true

    MS.TriggerServerCallback('vehicles:hasKey', function(allowed)
        checked[plate] = allowed == true
        checking = false
        callback(checked[plate])
    end, plate)
end

--- Beim Einsteigen pruefen.
CreateThread(function()
    if not VehicleConfig.Keys.enabled then return end

    local warned = nil

    while true do
        local wait = 500
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            local plate = Vehicles.CleanPlate(GetVehicleNumberPlateText(vehicle))

            hasKey(plate, function(allowed)
                if not allowed and VehicleConfig.Keys.lockEngine then
                    wait = 0

                    SetVehicleEngineOn(vehicle, false, true, true)
                    DisableControlAction(0, 71, true)   -- Gas
                    DisableControlAction(0, 72, true)   -- Bremse

                    if warned ~= plate then
                        warned = plate
                        MS.Notify('Du hast keinen Schluessel fuer dieses Fahrzeug.',
                            'error', 6000)
                    end
                else
                    warned = nil
                end
            end)
        else
            warned = nil
        end

        Wait(wait)
    end
end)

--- Ver- und Entriegeln per Taste.
local function toggleLock()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        vehicle = GetClosestVehicle(coords.x, coords.y, coords.z,
            VehicleConfig.Keys.range, 0, 71)
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        MS.Notify('Kein Fahrzeug in Reichweite.', 'error')
        return
    end

    local plate = Vehicles.CleanPlate(GetVehicleNumberPlateText(vehicle))

    hasKey(plate, function(allowed)
        if not allowed then
            MS.Notify('Dieses Fahrzeug gehoert dir nicht.', 'error')
            return
        end

        local locked = GetVehicleDoorLockStatus(vehicle) == 2

        SetVehicleDoorsLocked(vehicle, locked and 1 or 2)
        SetVehicleLights(vehicle, 2)
        Wait(180)
        SetVehicleLights(vehicle, 0)

        PlayVehicleDoorCloseSound(vehicle, 1)
        MS.Notify(locked and 'Fahrzeug aufgeschlossen.' or 'Fahrzeug abgeschlossen.',
            'info', 3000)
    end)
end

RegisterCommand('schliessen', function() toggleLock() end, false)
RegisterKeyMapping('schliessen', 'Fahrzeug ver-/entriegeln', 'keyboard',
    VehicleConfig.Keys.lockKey)

--- Schluessel an den Spieler geben, der neben dem Fahrzeug steht.
RegisterNetEvent('vehicles:client:giveKeyHere', function(targetId)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        vehicle = GetClosestVehicle(GetEntityCoords(ped), 6.0, 0, 71)
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        MS.Notify('Hier steht kein Fahrzeug.', 'error')
        return
    end

    local plate = Vehicles.CleanPlate(GetVehicleNumberPlateText(vehicle))
    TriggerServerEvent('vehicles:server:giveKeyByPlate', plate, targetId)
end)

--- Nach einem Besitzerwechsel neu pruefen.
RegisterNetEvent('vehicles:client:forgetKeys', function()
    checked = {}
end)
