--- Anzeige am Punkt: wer haelt ihn, wie weit ist die Bindung.

local aktiv = nil        -- Punkt, an dem der Spieler gerade steht.
local sichtbar = false

--- Wie der Punkt zum Spieler steht: eigen, fremd oder frei.
local function relation(entry)
    if not entry or not entry.factionId then return 'frei' end

    return entry.factionId == RitualWar.OwnFaction() and 'eigen' or 'fremd'
end

local function push(entry)
    if not entry then return end

    SendNUIMessage({ action = 'ritualwar:hud', data = {
        id        = entry.id,
        label     = entry.label,
        faction   = entry.factionName,
        tag       = entry.factionTag,
        colour    = entry.colour,
        relation  = relation(entry),
        protected = entry.protected,
        protectedFor = entry.protectedFor,
        payouts   = entry.payouts,
        binding   = entry.binding and {
            progress  = entry.binding.progress or 0,
            contested = entry.binding.contested or false,
            eigene    = entry.binding.factionId == RitualWar.OwnFaction(),
        } or nil,
    } })
end

local function hide()
    if not sichtbar then return end

    sichtbar = false
    aktiv = nil
    SendNUIMessage({ action = 'ritualwar:hudOff' })
end

--- Frische Werte in die laufende Anzeige holen.
AddEventHandler('ritualwar:client:updated', function(points)
    if not aktiv then return end

    for _, entry in ipairs(points) do
        if entry.id == aktiv.id then
            aktiv = entry
            push(entry)
            return
        end
    end
end)

CreateThread(function()
    Wait(4000)

    while true do
        local wartezeit = 1000

        if WarConfig.Hud.enabled then
            local coords = GetEntityCoords(PlayerPedId())
            local entry = RitualWar.NearestPoint(coords, WarConfig.Hud.range)

            if entry and (not aktiv or aktiv.id ~= entry.id) then
                aktiv = entry
                sichtbar = true
                push(entry)
            elseif entry and aktiv then
                aktiv = entry
                push(entry)
            elseif not entry then
                hide()
                wartezeit = 1500
            end
        else
            wartezeit = 5000
        end

        Wait(wartezeit)
    end
end)

--- Ein Markierungsring am gebundenen Punkt, damit der Besitz vor Ort sichtbar ist.
CreateThread(function()
    while true do
        local wartezeit = 800

        if aktiv then
            local coords = GetEntityCoords(PlayerPedId())
            local centre = vector3(aktiv.coords.x, aktiv.coords.y, aktiv.coords.z)

            if #(coords - centre) <= 30.0 then
                wartezeit = 0

                local r, g, b = 220, 220, 220

                if relation(aktiv) == 'eigen' then
                    r, g, b = 110, 210, 150
                elseif relation(aktiv) == 'fremd' then
                    r, g, b = 210, 90, 90
                end

                DrawMarker(1, centre.x, centre.y, centre.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    (aktiv.radius or 3.0) * 2.0, (aktiv.radius or 3.0) * 2.0, 0.6,
                    r, g, b, 70, false, false, 2, false, nil, nil, false)
            end
        end

        Wait(wartezeit)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    hide()
end)
