--- Ablauf einer Schicht beim Spieler: Ziel, Marker, Arbeit, Fahrgaeste.

local MS = exports['moonshine-core']:GetCoreObject()

local shift = nil
local targetBlip = nil
local workVehicle = nil
local passengerPed = nil
local passengerData = nil
local working = false

-- Hilfen ---------------------------------------------------------------------

local function clearBlip()
    if targetBlip then
        RemoveBlip(targetBlip)
        targetBlip = nil
    end
end

--- Setzt die Route auf einen Punkt.
local function routeTo(coords, label, colour)
    clearBlip()
    if not coords then return end

    targetBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(targetBlip, 1)
    SetBlipColour(targetBlip, colour or 5)
    SetBlipScale(targetBlip, 0.9)
    SetBlipRoute(targetBlip, true)
    SetBlipRouteColour(targetBlip, colour or 5)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Ziel')
    EndTextCommandSetBlipName(targetBlip)
end

local function removePassenger()
    if passengerPed and DoesEntityExist(passengerPed) then
        SetEntityAsNoLongerNeeded(passengerPed)
        DeletePed(passengerPed)
    end

    passengerPed = nil
    passengerData = nil
end

--- Aktuelles Ziel der Schicht.
local function currentTarget()
    if not shift or not shift.active then return nil, nil end

    if shift.phase == 'aufnehmen' and shift.pickup then
        return shift.pickup.coords, ('Fahrgast: %s'):format(shift.pickup.label)
    end

    if shift.phase == 'abmelden' then
        local definition = Work.GetJob(shift.job)
        return definition and definition.start.coords or nil,
               ('Abmelden: %s'):format(definition and definition.start.label or '')
    end

    -- Beim Abschleppdienst geht es nach jeder Station zurueck zum Hof.
    if shift.phase == 'abliefern' then
        local definition = Work.GetJob(shift.job)
        return definition and definition.start.coords or nil,
               ('Abliefern: %s'):format(definition and definition.start.label or '')
    end

    if shift.stop then
        return shift.stop.coords, shift.stop.label
    end

    return nil, nil
end

--- Setzt die Route neu.
local function refreshRoute()
    local coords, label = currentTarget()

    if not coords then
        clearBlip()
        return
    end

    routeTo(coords, label, shift and shift.phase == 'abmelden' and 2 or 5)
end

-- Server -> Client ---------------------------------------------------------------

RegisterNetEvent('work:client:shift', function(payload)
    local wasActive = shift and shift.active

    shift = payload
    Work.Active = payload

    SendNUIMessage({ action = 'work:shift', data = payload })

    if not payload or not payload.active then
        clearBlip()
        removePassenger()

        if wasActive then
            MS.Notify('Schicht beendet.', 'info')
        end

        return
    end

    -- Beim Wechsel der Phase den Fahrgast entfernen.
    if payload.phase == 'aufnehmen' then removePassenger() end

    refreshRoute()
end)

RegisterNetEvent('work:client:endShift', function()
    shift = nil
    Work.Active = nil
    clearBlip()
    removePassenger()

    SendNUIMessage({ action = 'work:shift', data = { active = false } })

    if workVehicle and DoesEntityExist(workVehicle) then
        SetEntityAsMissionEntity(workVehicle, true, true)
        DeleteVehicle(workVehicle)
    end

    workVehicle = nil
end)

--- Arbeitsfahrzeug ausgeben.
RegisterNetEvent('work:client:spawnVehicle', function(payload)
    if workVehicle and DoesEntityExist(workVehicle) then
        SetEntityAsMissionEntity(workVehicle, true, true)
        DeleteVehicle(workVehicle)
    end

    local hash = joaat(payload.model)
    if not IsModelInCdimage(hash) then
        MS.Notify('Das Arbeitsfahrzeug fehlt auf diesem Server.', 'error')
        return
    end

    RequestModel(hash)

    local tries = 0
    while not HasModelLoaded(hash) and tries < 100 do
        Wait(50)
        tries = tries + 1
    end

    if not HasModelLoaded(hash) then return end

    local spawn = payload.spawn
    workVehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w or 0.0,
        true, false)

    SetVehicleNumberPlateText(workVehicle, 'ARBEIT')
    SetEntityAsMissionEntity(workVehicle, true, true)
    SetVehicleOnGroundProperly(workVehicle)
    SetVehicleEngineOn(workVehicle, true, true, false)
    SetVehicleHasBeenOwnedByPlayer(workVehicle, true)

    TaskWarpPedIntoVehicle(PlayerPedId(), workVehicle, -1)
    SetModelAsNoLongerNeeded(hash)

    MS.Notify(('%s steht bereit.'):format(payload.label or 'Fahrzeug'), 'success')
end)

--- Fahrgast anlegen (Taxi).
RegisterNetEvent('work:client:passenger', function(payload)
    removePassenger()
    passengerData = payload
end)

-- Fahrgast erzeugen, sobald man nah genug ist ------------------------------------

CreateThread(function()
    while true do
        local wait = 1200

        if shift and shift.active and shift.phase == 'aufnehmen'
            and passengerData and not passengerPed then

            local coords = GetEntityCoords(PlayerPedId())
            local target = vector3(passengerData.coords.x, passengerData.coords.y,
                passengerData.coords.z)

            if #(coords - target) < 90.0 then
                local models = passengerData.models or { 'a_m_y_business_01' }
                local hash = joaat(models[math.random(#models)])

                RequestModel(hash)

                local tries = 0
                while not HasModelLoaded(hash) and tries < 60 do
                    Wait(50)
                    tries = tries + 1
                end

                if HasModelLoaded(hash) then
                    passengerPed = CreatePed(4, hash, target.x, target.y, target.z - 1.0,
                        0.0, false, true)

                    SetBlockingOfNonTemporaryEvents(passengerPed, true)
                    SetEntityInvincible(passengerPed, true)
                    TaskStartScenarioInPlace(passengerPed, 'WORLD_HUMAN_STAND_IMPATIENT',
                        0, true)

                    SetModelAsNoLongerNeeded(hash)
                end
            end
        end

        Wait(wait)
    end
end)

-- Aufnehmen und Absetzen ------------------------------------------------------------

--- Steigt der Fahrgast ein?
CreateThread(function()
    while true do
        local wait = 800

        if shift and shift.active and shift.phase == 'aufnehmen'
            and passengerPed and DoesEntityExist(passengerPed) then

            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle ~= 0 then
                local distance = #(GetEntityCoords(ped) - GetEntityCoords(passengerPed))

                if distance < 12.0 then
                    wait = 0

                    MS.DrawText3D(GetEntityCoords(passengerPed) + vector3(0.0, 0.0, 1.0),
                        '~b~E~s~  Fahrgast einsteigen lassen', 0.4)

                    if IsControlJustReleased(0, 38) then
                        ClearPedTasks(passengerPed)
                        TaskEnterVehicle(passengerPed, vehicle, 12000, 2, 1.5, 1, 0)

                        TriggerServerEvent('work:server:passengerIn')
                        MS.Notify('Fahrgast steigt ein. Fahr ihn zum Ziel.', 'success')
                    end
                end
            end
        end

        Wait(wait)
    end
end)

--- An der Station arbeiten.
CreateThread(function()
    while true do
        local wait = 700

        if shift and shift.active and not working then
            local coords, _ = currentTarget()

            if coords and shift.phase ~= 'aufnehmen' and shift.phase ~= 'abmelden' then
                local definition = Work.GetJob(shift.job)
                local text = shift.phase == 'abliefern'
                    and (definition and definition.ablieferLabel or 'Abliefern')
                    or (shift.actionLabel or 'Arbeiten')

                local target = vector3(coords.x, coords.y, coords.z)
                local distance = #(GetEntityCoords(PlayerPedId()) - target)

                if distance < 40.0 then
                    wait = 0

                    DrawMarker(1, target.x, target.y, target.z - 1.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 1.0,
                        216, 178, 95, 110, false, true, 2, false, nil, nil, false)
                end

                if distance <= WorkConfig.Shift.stopRange then
                    MS.DrawText3D(target + vector3(0.0, 0.0, 1.2),
                        ('~b~E~s~  %s'):format(text), 0.42)

                    if IsControlJustReleased(0, 38) then
                        if shift.phase == 'abliefern' then
                            Work.DoDeliver()
                        else
                            Work.DoStop()
                        end
                    end
                end
            end
        end

        Wait(wait)
    end
end)

--- Laedt das verladene Fahrzeug am Hof wieder ab.
function Work.DoDeliver()
    if working or not shift or not shift.active then return end
    if shift.phase ~= 'abliefern' then return end

    local definition = Work.GetJob(shift.job)
    if not definition then return end

    working = true

    CreateThread(function()
        local dauer = math.max(2, math.floor((definition.duration or 6) / 2))
        local schritte = 20

        for index = 1, schritte do
            Wait(math.floor(dauer * 1000 / schritte))
            SendNUIMessage({ action = 'work:progress', value = index / schritte })
        end

        SendNUIMessage({ action = 'work:progress', value = 0 })
        TriggerServerEvent('work:server:deliver')

        working = false
    end)
end

--- Fuehrt die Arbeit an einer Station aus.
function Work.DoStop()
    if working or not shift or not shift.active then return end

    local definition = Work.GetJob(shift.job)
    if not definition then return end

    working = true

    CreateThread(function()
        local ped = PlayerPedId()

        -- Beim Taxi steigt der Fahrgast aus, sonst wird gearbeitet.
        if shift.phase == 'fahren' and definition.passengers then
            if passengerPed and DoesEntityExist(passengerPed) then
                TaskLeaveVehicle(passengerPed, GetVehiclePedIsIn(ped, false), 0)
                Wait(1500)
                removePassenger()
            end
        else
            if IsPedInAnyVehicle(ped, false) then
                MS.Notify('Steig aus, um zu arbeiten.', 'error')
                working = false
                return
            end

            RequestAnimDict('anim@heists@box_carry@')
            local tries = 0
            while not HasAnimDictLoaded('anim@heists@box_carry@') and tries < 40 do
                Wait(50)
                tries = tries + 1
            end

            if HasAnimDictLoaded('anim@heists@box_carry@') then
                TaskPlayAnim(ped, 'anim@heists@box_carry@', 'idle', 2.0, -2.0, -1,
                    49, 0, false, false, false)
            end
        end

        local duration = (definition.duration or 5) * 1000
        local steps = 20

        for index = 1, steps do
            Wait(math.floor(duration / steps))
            SendNUIMessage({ action = 'work:progress', value = index / steps })
        end

        SendNUIMessage({ action = 'work:progress', value = 0 })
        ClearPedTasks(PlayerPedId())

        TriggerServerEvent('work:server:completeStop')
        working = false
    end)
end

--- Abmelden am Anmeldepunkt.
CreateThread(function()
    while true do
        local wait = 900

        if shift and shift.active then
            local definition = Work.GetJob(shift.job)

            if definition then
                local distance = #(GetEntityCoords(PlayerPedId()) - definition.start.coords)

                if distance < 20.0 then
                    wait = 0

                    if distance <= WorkConfig.Range + 4.0 then
                        MS.DrawText3D(definition.start.coords + vector3(0.0, 0.0, 1.1),
                            shift.phase == 'abmelden'
                                and '~b~E~s~  Schicht abschliessen'
                                or '~b~E~s~  Schicht beenden', 0.42)

                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('work:server:stop')
                        end
                    end
                end
            end
        end

        Wait(wait)
    end
end)

--- Laeuft gerade eine Schicht? Auch fuer client/main.lua.
function Work.IsWorking()
    return shift ~= nil and shift.active == true
end

exports('IsWorking', Work.IsWorking)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    clearBlip()
    removePassenger()

    if workVehicle and DoesEntityExist(workVehicle) then
        SetEntityAsMissionEntity(workVehicle, true, true)
        DeleteVehicle(workVehicle)
    end
end)
