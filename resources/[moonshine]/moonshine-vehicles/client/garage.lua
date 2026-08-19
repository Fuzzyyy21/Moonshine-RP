--- Fahrzeuge erzeugen, einparken und ihren Zustand melden.

local MS = exports['moonshine-core']:GetCoreObject()

--- Fahrzeuge, die dieser Client erzeugt hat: [plate] = entity
Vehicles.Mine = {}

--- Tankfuellung je Kennzeichen (der Server ist die Wahrheit, das hier ist
--- der laufende Zwischenstand).
Vehicles.Fuel = {}

--- Laufende Abfragen, damit nicht jede Sekunde erneut gefragt wird.
Vehicles.Asking = {}

--- Laedt ein Modell.
local function loadModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end

    RequestModel(hash)

    local tries = 0
    while not HasModelLoaded(hash) and tries < 100 do
        Wait(50)
        tries = tries + 1
    end

    return HasModelLoaded(hash) and hash or nil
end

--- Ist der Platz frei?
local function isSpotClear(coords)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 71)
    return vehicle == 0 or not DoesEntityExist(vehicle)
end

RegisterNetEvent('vehicles:client:spawn', function(payload)
    if not payload or not payload.model then return end

    local hash = loadModel(payload.model)
    if not hash then
        MS.Notify('Dieses Fahrzeug laesst sich nicht laden.', 'error')
        return
    end

    local spawn = payload.spawn

    if not isSpotClear(vector3(spawn.x, spawn.y, spawn.z)) then
        MS.Notify('Der Ausgabeplatz ist blockiert.', 'error')
        SetModelAsNoLongerNeeded(hash)
        return
    end

    local vehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w or 0.0,
        true, false)

    SetVehicleNumberPlateText(vehicle, payload.plate)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleDirtLevel(vehicle, 2.0)

    -- Zustand wiederherstellen.
    SetVehicleEngineHealth(vehicle, payload.engine or 1000.0)
    SetVehicleBodyHealth(vehicle, payload.body or 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)

    -- Umbauten aus der Werkstatt.
    Vehicles.ApplyMods(vehicle, payload.mods)

    local plate = Vehicles.CleanPlate(payload.plate)
    Vehicles.Mine[plate] = vehicle
    Vehicles.Fuel[plate] = payload.fuel or 100.0

    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    SetVehicleEngineOn(vehicle, true, true, false)

    SetModelAsNoLongerNeeded(hash)
    MS.Notify(('%s steht bereit.'):format(payload.label or 'Dein Fahrzeug'), 'success')
end)

RegisterNetEvent('vehicles:client:despawn', function(plate)
    plate = Vehicles.CleanPlate(plate)

    local vehicle = Vehicles.Mine[plate]

    -- Auch fremd erzeugte Fahrzeuge mit diesem Kennzeichen finden.
    if not vehicle or not DoesEntityExist(vehicle) then
        vehicle = Vehicles.FindByPlate(plate, 12.0)
    end

    if vehicle and DoesEntityExist(vehicle) then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    end

    Vehicles.Mine[plate] = nil
    Vehicles.Fuel[plate] = nil
end)

RegisterNetEvent('vehicles:client:setFuel', function(plate, fuel)
    Vehicles.Fuel[Vehicles.CleanPlate(plate)] = fuel
end)

--- Sucht ein Fahrzeug mit diesem Kennzeichen in der Naehe.
function Vehicles.FindByPlate(plate, range)
    plate = Vehicles.CleanPlate(plate)

    local coords = GetEntityCoords(PlayerPedId())
    local handle, vehicle = FindFirstVehicle()
    local success

    repeat
        if DoesEntityExist(vehicle)
            and Vehicles.CleanPlate(GetVehicleNumberPlateText(vehicle)) == plate
            and #(GetEntityCoords(vehicle) - coords) <= (range or 30.0) then

            EndFindVehicle(handle)
            return vehicle
        end

        success, vehicle = FindNextVehicle(handle)
    until not success

    EndFindVehicle(handle)
    return nil
end

--- Parkt das Fahrzeug ein, in dem man sitzt bzw. das daneben steht.
function Vehicles.StoreCurrent()
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

    TriggerServerEvent('vehicles:server:store', plate,
        Vehicles.Fuel[plate] or 100.0,
        GetVehicleEngineHealth(vehicle),
        GetVehicleBodyHealth(vehicle))

    -- Der Server bestaetigt und schickt despawn.
end

-- Sprit -----------------------------------------------------------------------------

--- Verbrauch, solange der Motor laeuft.
CreateThread(function()
    while true do
        Wait(10000)

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            local plate = Vehicles.CleanPlate(GetVehicleNumberPlateText(vehicle))

            -- Fahrzeug von jemand anderem uebernommen: Stand einmal holen.
            if Vehicles.Fuel[plate] == nil and not Vehicles.Asking[plate] then
                Vehicles.Asking[plate] = true

                MS.TriggerServerCallback('vehicles:fuel', function(value)
                    Vehicles.Asking[plate] = nil
                    if value then Vehicles.Fuel[plate] = value end
                end, plate)
            end

            local fuel = Vehicles.Fuel[plate]

            if fuel and GetIsVehicleEngineRunning(vehicle) then
                -- Anteil einer Minute.
                local used = VehicleConfig.State.fuelPerMinute / 6.0

                -- Vollgas kostet mehr.
                local speed = GetEntitySpeed(vehicle) * 3.6
                if speed > 90 then used = used * 1.4 end

                fuel = math.max(0.0, fuel - used)
                Vehicles.Fuel[plate] = fuel

                if fuel <= VehicleConfig.State.stallBelow then
                    SetVehicleEngineOn(vehicle, false, true, true)
                    SetVehicleUndriveable(vehicle, true)
                    MS.Notify('Der Tank ist leer.', 'error', 8000)
                elseif fuel < 12 and math.random() < 0.3 then
                    MS.Notify(('Nur noch %d Prozent im Tank.'):format(fuel), 'warning')
                end
            end
        end
    end
end)

--- Zustand regelmaessig an den Server melden.
CreateThread(function()
    while true do
        Wait(VehicleConfig.State.reportInterval * 1000)

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            local plate = Vehicles.CleanPlate(GetVehicleNumberPlateText(vehicle))

            if Vehicles.Fuel[plate] then
                TriggerServerEvent('vehicles:server:report', plate,
                    Vehicles.Fuel[plate],
                    GetVehicleEngineHealth(vehicle),
                    GetVehicleBodyHealth(vehicle))
            end
        end
    end
end)

exports('GetFuel', function(plate)
    return Vehicles.Fuel[Vehicles.CleanPlate(plate)]
end)

--- Tankstand setzen (Tankstelle, Kanister, Admin).
exports('SetFuel', function(plate, value)
    plate = Vehicles.CleanPlate(plate)

    value = math.max(0.0, math.min(100.0, tonumber(value) or 0.0))
    Vehicles.Fuel[plate] = value

    -- Wieder fahrbar machen, sobald etwas im Tank ist.
    if value > VehicleConfig.State.stallBelow then
        local vehicle = Vehicles.Mine[plate]
        if not vehicle or not DoesEntityExist(vehicle) then
            vehicle = Vehicles.FindByPlate(plate, 12.0)
        end

        if vehicle and DoesEntityExist(vehicle) then
            SetVehicleUndriveable(vehicle, false)
        end
    end

    -- Den neuen Stand sofort sichern, damit er ein Relog ueberlebt.
    local vehicle = Vehicles.Mine[plate] or Vehicles.FindByPlate(plate, 12.0)

    if vehicle and DoesEntityExist(vehicle) then
        TriggerServerEvent('vehicles:server:report', plate, value,
            GetVehicleEngineHealth(vehicle), GetVehicleBodyHealth(vehicle))
    end

    return true
end)

exports('StoreCurrentVehicle', function()
    Vehicles.StoreCurrent()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, vehicle in pairs(Vehicles.Mine) do
        if DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end
end)
