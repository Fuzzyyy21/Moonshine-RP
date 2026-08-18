--- API und Commands der Arbeit.

AddEventHandler('moonshine:server:playerLoaded', function(source)
    CreateThread(function()
        Wait(2500)
        Work.SyncShift(source)
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for source in pairs(Work.Shifts) do
        pcall(Work.Stop, source, true)
    end
end)

-- API ---------------------------------------------------------------------------

exports('GetWorkObject', function()
    return Work
end)

--- Laeuft gerade eine Schicht?
exports('IsWorking', function(source)
    return Work.Shifts[source] ~= nil
end)

exports('GetShift', function(source)
    local shift = Work.Shifts[source]
    if not shift then return nil end

    return {
        job       = shift.job,
        index     = shift.index,
        total     = #shift.stops,
        earned    = shift.earned,
        completed = shift.completed,
    }
end)

exports('StopShift', function(source)
    return Work.Stop(source, true)
end)

--- Statistik eines Charakters.
exports('GetWorkStats', function(source)
    local player = MS.GetPlayer(source)
    if not player then return {} end

    return Work.DB.Load(player.charId)
end)

-- Commands ----------------------------------------------------------------------

local function permission(source, level)
    if source == 0 then return true end

    local player = MS.GetPlayer(source)
    return player ~= nil and (player.adminLevel or 0) >= level
end

RegisterCommand('dienst', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local shift = Work.Shifts[source]
    if not shift then
        player:Notify('Du bist nicht im Dienst. Melde dich bei einem Auftraggeber an.',
            'info', 8000)
        return
    end

    local definition = Work.GetJob(shift.job)
    player:Notify(('%s: Station %d von %d, %s verdient.'):format(
        definition.label, math.min(shift.index, #shift.stops), #shift.stops,
        MS.Utils.FormatMoney(shift.earned)), 'info', 9000)
end, false)

RegisterCommand('feierabend', function(source)
    local ok, message = Work.Stop(source)

    if message ~= '' then
        exports['moonshine-core']:Notify(source, message,
            ok and 'success' or 'error', 9000)
    end
end, false)

RegisterCommand('arbeitsstatistik', function(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local rows = Work.DB.Load(player.charId)
    if #rows == 0 then
        player:Notify('Du hast noch nicht gearbeitet.', 'info')
        return
    end

    local parts = {}
    for _, row in ipairs(rows) do
        local definition = Work.GetJob(row.job)
        parts[#parts + 1] = ('%s: %d Schichten, %s'):format(
            definition and definition.label or row.job,
            tonumber(row.shifts) or 0,
            MS.Utils.FormatMoney(tonumber(row.earned) or 0))
    end

    player:Notify(table.concat(parts, ' · '), 'info', 12000)
end, false)

RegisterCommand('endshift', function(source, args)
    if not permission(source, 2) then return end

    local target = tonumber(args[1])
    if not target then return end

    Work.Stop(target, true)
end, false)

print('^2[Arbeit]^7 Jobcenter und Auftragssystem geladen.')
