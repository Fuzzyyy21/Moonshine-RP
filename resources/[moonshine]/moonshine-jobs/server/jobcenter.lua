--- Jobcenter: Job wechseln, Statistik einsehen, Bestenliste.

--- Wann jemand zuletzt gewechselt hat: [charId] = Zeitstempel
local lastSwitch = {}

--- Steht der Spieler im Jobcenter?
local function atCenter(source)
    local coords = GetEntityCoords(GetPlayerPed(source))
    return #(coords - WorkConfig.JobCenter.coords) <= WorkConfig.Range + 3.0
end

--- Welche Core-Jobs darf man sich hier selbst geben?
local function openJobs()
    local list = {}

    for name, job in pairs(MS.Jobs) do
        if not job.whitelisted then
            list[#list + 1] = {
                name  = name,
                label = job.label,
                grades = (function()
                    local count = 0
                    for _ in pairs(job.grades) do count = count + 1 end
                    return count
                end)(),
                salary = (job.grades[0] or {}).salary or 0,
            }
        end
    end

    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

--- Zustand des Jobcenters fuer die Oberflaeche.
function Work.CenterPayload(source)
    local player = MS.GetPlayer(source)
    if not player then return nil end

    local stats = {}
    local totalEarned, totalStops, totalShifts = 0, 0, 0

    for _, row in ipairs(Work.DB.Load(player.charId)) do
        local definition = Work.GetJob(row.job)

        stats[row.job] = {
            shifts = tonumber(row.shifts) or 0,
            stops  = tonumber(row.stops) or 0,
            earned = tonumber(row.earned) or 0,
            label  = definition and definition.label or row.job,
        }

        totalEarned = totalEarned + (tonumber(row.earned) or 0)
        totalStops  = totalStops + (tonumber(row.stops) or 0)
        totalShifts = totalShifts + (tonumber(row.shifts) or 0)
    end

    local contracts = {}
    for _, definition in ipairs(Work.GetAvailable(player.job.name)) do
        contracts[#contracts + 1] = {
            id          = definition.id,
            label       = definition.label,
            icon        = definition.icon,
            colour      = definition.colour,
            description = definition.description,
            requiresJob = definition.requiresJob,
            pay         = definition.pay,
            finalPay    = definition.finalPay,
            stops       = WorkConfig.Shift.stops,
            vehicle     = definition.vehicle and definition.vehicle.label or nil,
            start       = definition.start.label,
            startCoords = { x = definition.start.coords.x,
                            y = definition.start.coords.y,
                            z = definition.start.coords.z },
            stats       = stats[definition.id],

            -- Die Nachtwache steht tagsueber zwar da, laesst sich aber
            -- nicht beginnen. Das gehoert dazugesagt statt verschwiegen.
            nurNachts   = definition.nurNachts == true,
            gesperrt    = definition.nurNachts == true and not Work.IsNight(),
        }
    end

    -- Auch Auftraege, fuer die der Job fehlt, werden angezeigt - ausgegraut.
    for _, id in ipairs(Work.Order) do
        local definition = Work.GetJob(id)
        local shown = false

        for _, entry in ipairs(contracts) do
            if entry.id == id then shown = true break end
        end

        if not shown then
            contracts[#contracts + 1] = {
                id = definition.id, label = definition.label, icon = definition.icon,
                colour = definition.colour, description = definition.description,
                requiresJob = definition.requiresJob,
                requiresLabel = (MS.GetJob(definition.requiresJob) or {}).label,
                pay = definition.pay, finalPay = definition.finalPay,
                stops = WorkConfig.Shift.stops,
                vehicle = definition.vehicle and definition.vehicle.label or nil,
                start = definition.start.label,
                startCoords = { x = definition.start.coords.x,
                                y = definition.start.coords.y,
                                z = definition.start.coords.z },
                locked = true, stats = stats[definition.id],
            }
        end
    end

    local cooldown = 0
    if lastSwitch[player.charId] then
        cooldown = math.max(0, (lastSwitch[player.charId]
            + WorkConfig.JobCenter.cooldown * 60) - os.time())
    end

    return {
        job       = { name = player.job.name, label = player.job.label,
                      grade = player.job.grade, gradeLabel = player.job.gradeLabel,
                      salary = player.job.salary },
        jobs      = openJobs(),
        contracts = contracts,
        totals    = { earned = totalEarned, stops = totalStops, shifts = totalShifts },
        fee       = WorkConfig.JobCenter.fee,
        cooldown  = cooldown,
    }
end

RegisterNetEvent('work:server:openCenter', function()
    local source = source
    if not MS.GetPlayer(source) or not atCenter(source) then return end

    local payload = Work.CenterPayload(source)
    if payload then
        TriggerClientEvent('work:client:center', source, payload)
    end
end)

--- Job wechseln.
RegisterNetEvent('work:server:setJob', function(name)
    if not MS.RateLimit(source, 'work:setJob', 5, 30) then return end
    local source = source
    local player = MS.GetPlayer(source)
    if not player or not atCenter(source) then return end

    local job = MS.GetJob(name)
    if not job then return end

    if job.whitelisted then
        player:Notify('Dieser Job wird nicht im Jobcenter vergeben.', 'error')
        return
    end

    if player.job.name == name then
        player:Notify('Den hast du bereits.', 'info')
        return
    end

    if Work.Shifts[source] then
        player:Notify('Beende erst deine Schicht.', 'error')
        return
    end

    local last = lastSwitch[player.charId]
    if last and os.time() - last < WorkConfig.JobCenter.cooldown * 60 then
        local wait = math.ceil((last + WorkConfig.JobCenter.cooldown * 60 - os.time()) / 60)
        player:Notify(('Noch %d Minuten bis zum naechsten Wechsel.'):format(wait), 'error')
        return
    end

    local fee = WorkConfig.JobCenter.fee
    if fee > 0 and not player:RemoveMoney(fee, 'bank', 'jobwechsel') then
        player:Notify(('Der Wechsel kostet %s.'):format(MS.Utils.FormatMoney(fee)), 'error')
        return
    end

    player:SetJob(name, 0)
    lastSwitch[player.charId] = os.time()

    player:Notify(('Du arbeitest jetzt als %s.'):format(job.label), 'success', 8000)

    local payload = Work.CenterPayload(source)
    if payload then
        TriggerClientEvent('work:client:center', source, payload)
    end

    TriggerEvent('work:server:jobChanged', source, name)
end)

--- Bestenliste eines Auftrags.
MS.RegisterServerCallback('work:leaderboard', function(player, cb, jobId)
    if not player or not Work.GetJob(jobId) then return cb({}) end

    local rows = {}

    for _, row in ipairs(Work.DB.Leaderboard(jobId, 10)) do
        rows[#rows + 1] = {
            name   = ('%s %s'):format(row.firstname or '?', row.lastname or ''),
            earned = tonumber(row.earned) or 0,
            stops  = tonumber(row.stops) or 0,
            shifts = tonumber(row.shifts) or 0,
        }
    end

    cb(rows)
end)
