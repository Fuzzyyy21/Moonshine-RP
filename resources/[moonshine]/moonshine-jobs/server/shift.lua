--- Schichten: anmelden, Stationen abarbeiten, abmelden.

MS = MS or exports['moonshine-core']:GetCoreObject()

--- Laufende Schichten: [source] = Schicht
Work.Shifts = {}

--- Steht der Spieler am Anmeldepunkt eines Jobs?
local function atStart(source, definition)
    local coords = GetEntityCoords(GetPlayerPed(source))
    return #(coords - definition.start.coords) <= WorkConfig.Range + 4.0
end

--- Zustand der Schicht fuer die Oberflaeche.
function Work.ShiftPayload(source)
    local shift = Work.Shifts[source]
    if not shift then return { active = false } end

    local definition = Work.GetJob(shift.job)
    local stop = shift.stops[shift.index]

    return {
        active      = true,
        job         = shift.job,
        label       = definition.label,
        icon        = definition.icon,
        colour      = definition.colour,
        action      = definition.action,
        actionLabel = definition.actionLabel,
        index       = shift.index,
        total       = #shift.stops,
        earned      = shift.earned,
        stop        = stop and {
            label  = stop.label,
            coords = { x = stop.coords.x, y = stop.coords.y, z = stop.coords.z },
        } or nil,
        pickup      = shift.pickup and {
            label  = shift.pickup.label,
            coords = { x = shift.pickup.coords.x, y = shift.pickup.coords.y,
                       z = shift.pickup.coords.z },
        } or nil,
        phase       = shift.phase,
        vehicle     = definition.vehicle and definition.vehicle.label or nil,
        finalPay    = definition.finalPay,
    }
end

function Work.SyncShift(source)
    TriggerClientEvent('work:client:shift', source, Work.ShiftPayload(source))
end

-- Anmelden ---------------------------------------------------------------------

--- Beginnt eine Schicht.
---@return boolean ok, string message
function Work.Start(source, jobId)
    local player = MS.GetPlayer(source)
    if not player then return false, '' end

    if Work.Shifts[source] then
        return false, 'Du bist bereits im Dienst.'
    end

    local definition = Work.GetJob(jobId)
    if not definition then return false, 'Diesen Auftrag gibt es nicht.' end

    if definition.requiresJob and player.job.name ~= definition.requiresJob then
        return false, ('Dafuer brauchst du den Job "%s".'):format(
            (MS.GetJob(definition.requiresJob) or {}).label or definition.requiresJob)
    end

    if not atStart(source, definition) then
        return false, ('Melde dich bei %s an.'):format(definition.start.label)
    end

    local stops = Work.PickStops(definition, WorkConfig.Shift.stops)
    if #stops == 0 then return false, 'Es gibt gerade nichts zu tun.' end

    Work.Shifts[source] = {
        job       = jobId,
        stops     = stops,
        index     = 1,
        earned    = 0,
        completed = 0,
        startedAt = os.time(),
        lastAt    = os.time(),
        phase     = definition.passengers and 'aufnehmen' or 'fahren',
        pickup    = nil,
    }

    -- Beim Taxi zuerst einen Fahrgast aufnehmen.
    if definition.passengers then
        Work.NextPassenger(source)
    end

    -- Arbeitsfahrzeug ausgeben.
    if definition.vehicle then
        TriggerClientEvent('work:client:spawnVehicle', source, {
            model = definition.vehicle.model,
            label = definition.vehicle.label,
            spawn = {
                x = definition.vehicle.spawn.x, y = definition.vehicle.spawn.y,
                z = definition.vehicle.spawn.z, w = definition.vehicle.spawn.w,
            },
        })
    end

    Work.SyncShift(source)
    TriggerEvent('work:server:shiftStarted', source, jobId)

    return true, ('Schicht bei %s begonnen. %d Stationen.'):format(
        definition.label, #stops)
end

--- Waehlt einen neuen Fahrgast (Taxi).
function Work.NextPassenger(source)
    local shift = Work.Shifts[source]
    if not shift then return end

    local definition = Work.GetJob(shift.job)
    if not definition or not definition.passengers then return end

    -- Aufnahmeort ist eine andere Station als das Ziel.
    local target = shift.stops[shift.index]
    local pool = {}

    for _, stop in ipairs(definition.stops) do
        if not target or stop.label ~= target.label then pool[#pool + 1] = stop end
    end

    shift.pickup = pool[math.random(#pool)]
    shift.phase = 'aufnehmen'

    TriggerClientEvent('work:client:passenger', source, {
        label  = shift.pickup.label,
        coords = { x = shift.pickup.coords.x, y = shift.pickup.coords.y,
                   z = shift.pickup.coords.z },
        models = definition.passengerModels,
    })
end

-- Station abschliessen -------------------------------------------------------------

--- Der Client meldet, dass er an der Station gearbeitet hat.
RegisterNetEvent('work:server:completeStop', function()
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local shift = Work.Shifts[source]
    if not shift then return end

    local definition = Work.GetJob(shift.job)
    local stop = shift.stops[shift.index]
    if not definition or not stop then return end

    -- Der Spieler muss wirklich dort stehen.
    local coords = GetEntityCoords(GetPlayerPed(source))
    if #(coords - stop.coords) > WorkConfig.Shift.stopRange + 6.0 then
        player:Notify('Du bist nicht an der Station.', 'error')
        return
    end

    -- Missbrauch abfangen: eine Station braucht mindestens ein paar Sekunden.
    if os.time() - shift.lastAt < math.max(2, definition.duration - 2) then return end

    shift.lastAt = os.time()

    -- Lohn berechnen.
    local pay = Work.RollPay(definition.pay)

    -- Beim Taxi kommt die gefahrene Strecke dazu.
    if definition.passengers and shift.pickup and definition.payPerKilometer then
        local metres = Work.Distance(shift.pickup.coords, stop.coords)
        pay = pay + math.floor((metres / 1000) * definition.payPerKilometer)
    end

    shift.earned = shift.earned + pay
    shift.completed = shift.completed + 1

    player:AddMoney(pay, WorkConfig.Account, ('arbeit-%s'):format(shift.job))

    -- Erfahrung fuer den persoenlichen Baum.
    pcall(function()
        exports['moonshine-mystic']:AddXp(source, WorkConfig.XpPerStop)
    end)

    Work.DB.Track(player.charId, shift.job, 1, pay, false)
    TriggerEvent('work:server:stopCompleted', source, shift.job, shift.index)

    shift.index = shift.index + 1

    if shift.index > #shift.stops then
        player:Notify(('Alle Stationen erledigt. Melde dich bei %s ab.'):format(
            definition.start.label), 'success', 9000)

        shift.phase = 'abmelden'
        shift.pickup = nil
    else
        player:Notify(('%s: %s (%d von %d)'):format(
            definition.actionLabel, MS.Utils.FormatMoney(pay),
            shift.index - 1, #shift.stops), 'success')

        if definition.passengers then
            Work.NextPassenger(source)
        else
            shift.phase = 'fahren'
        end
    end

    Work.SyncShift(source)
end)

--- Beim Taxi: Fahrgast ist eingestiegen.
RegisterNetEvent('work:server:passengerIn', function()
    local source = source
    local shift = Work.Shifts[source]
    if not shift or shift.phase ~= 'aufnehmen' then return end

    shift.phase = 'fahren'
    shift.lastAt = os.time()

    Work.SyncShift(source)
end)

-- Abmelden ---------------------------------------------------------------------------

--- Beendet die Schicht.
---@return boolean ok, string message
function Work.Stop(source, quiet)
    local player = MS.GetPlayer(source)
    local shift = Work.Shifts[source]
    if not shift then return false, 'Du bist nicht im Dienst.' end

    local definition = Work.GetJob(shift.job)
    Work.Shifts[source] = nil

    TriggerClientEvent('work:client:endShift', source)

    if not player then return true, '' end

    local finished = shift.completed >= #shift.stops
    local bonus = 0

    if finished then
        bonus = math.floor(definition.finalPay
            * (1 + WorkConfig.Shift.completionBonus))

        player:AddMoney(bonus, WorkConfig.Account, ('arbeit-%s-bonus'):format(shift.job))
    end

    Work.DB.Track(player.charId, shift.job, 0, 0, finished)
    TriggerEvent('work:server:shiftEnded', source, shift.job, finished, shift.earned + bonus)

    Work.SyncShift(source)

    if quiet then return true, '' end

    if finished then
        return true, ('Schicht beendet. %d Stationen, %s plus %s Abschlussbonus.'):format(
            shift.completed, MS.Utils.FormatMoney(shift.earned),
            MS.Utils.FormatMoney(bonus))
    end

    return true, ('Schicht abgebrochen nach %d von %d Stationen. %s verdient.'):format(
        shift.completed, #shift.stops, MS.Utils.FormatMoney(shift.earned))
end

RegisterNetEvent('work:server:start', function(jobId)
    local source = source
    local ok, message = Work.Start(source, jobId)

    if message ~= '' then
        exports['moonshine-core']:Notify(source, message,
            ok and 'success' or 'error', 8000)
    end
end)

RegisterNetEvent('work:server:stop', function()
    local source = source
    local ok, message = Work.Stop(source)

    if message ~= '' then
        exports['moonshine-core']:Notify(source, message,
            ok and 'success' or 'error', 9000)
    end
end)

RegisterNetEvent('work:server:request', function()
    Work.SyncShift(source)
end)

-- Aufraeumen ---------------------------------------------------------------------------

--- Schichten ohne Fortschritt laufen aus.
CreateThread(function()
    while true do
        Wait(60000)

        local now = os.time()

        for source, shift in pairs(Work.Shifts) do
            if now - shift.lastAt > WorkConfig.Shift.idleTimeout * 60 then
                local player = MS.GetPlayer(source)
                if player then
                    player:Notify('Deine Schicht ist ausgelaufen.', 'warning', 8000)
                end

                Work.Stop(source, true)
            end
        end
    end
end)

AddEventHandler('moonshine:server:playerDropped', function(source)
    if Work.Shifts[source] then Work.Stop(source, true) end
end)

AddEventHandler('moonshine:server:playerUnloaded', function(source)
    if Work.Shifts[source] then Work.Stop(source, true) end
end)
