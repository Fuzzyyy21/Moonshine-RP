--- Ritualpunkte auf der Karte und die Uebersicht.

local points = {}
local blips = {}
local radii = {}
local offen = false

--- Farbe eines Blips aus der Wappenfarbe der haltenden Fraktion.
local function blipColour(entry)
    if not entry.factionId then return 4 end        -- weiss: ungebunden

    local COLOURS = {
        ['#c0392f'] = 1, ['#4caf7d'] = 2, ['#3d8bd4'] = 3, ['#d8b25f'] = 5,
        ['#9b6bd8'] = 27, ['#e07b39'] = 47, ['#d94f8a'] = 48, ['#2f8f8f'] = 30,
    }

    return COLOURS[(entry.colour or ''):lower()] or 27
end

local function clearBlips()
    for _, blip in pairs(blips) do RemoveBlip(blip) end
    for _, blip in pairs(radii) do RemoveBlip(blip) end

    blips, radii = {}, {}
end

local function drawBlips()
    clearBlips()

    for _, entry in ipairs(points) do
        local coords = vector3(entry.coords.x, entry.coords.y, entry.coords.z)

        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 303)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, blipColour(entry))
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(entry.factionTag
            and ('%s [%s]'):format(entry.label, entry.factionTag)
            or ('%s (ungebunden)'):format(entry.label))
        EndTextCommandSetBlipName(blip)

        blips[#blips + 1] = blip

        -- Nur gebundene Punkte bekommen einen Radius, damit die Karte
        -- nicht zugekleistert wird.
        if entry.factionId then
            local radius = AddBlipForRadius(coords.x, coords.y, coords.z,
                math.max(entry.radius or 3.0, 30.0))

            SetBlipColour(radius, blipColour(entry))
            SetBlipAlpha(radius, 70)
            radii[#radii + 1] = radius
        end
    end
end

function RitualWar.GetPoints() return points end

--- Eigene Fraktions-ID, falls moonshine-factions laeuft.
function RitualWar.OwnFaction()
    local data = nil
    pcall(function() data = exports['moonshine-factions']:GetFactionData() end)

    return type(data) == 'table' and data.id or nil
end

--- Haengt an jeden Punkt, ob er der eigenen Fraktion gehoert. Die
--- Oberflaeche faerbt danach ein.
local function decorate()
    local eigene = RitualWar.OwnFaction()

    for _, entry in ipairs(points) do
        entry.eigen = eigene ~= nil and entry.factionId == eigene
    end

    return points
end

--- Punkt, in dessen Anzeigebereich der Spieler steht.
function RitualWar.NearestPoint(coords, range)
    local best, distance = nil, range or WarConfig.Hud.range

    for _, entry in ipairs(points) do
        local centre = vector3(entry.coords.x, entry.coords.y, entry.coords.z)
        local d = #(coords - centre)

        if d <= distance then best, distance = entry, d end
    end

    return best, distance
end

RegisterNetEvent('ritualwar:client:points', function(payload)
    points = payload or {}
    drawBlips()

    if offen then
        SendNUIMessage({ action = 'ritualwar:points', data = decorate() })
    end

    TriggerEvent('ritualwar:client:updated', points)
end)

-- Uebersicht -----------------------------------------------------------------------

local function open()
    offen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'ritualwar:open', data = decorate() })
end

local function close()
    offen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'ritualwar:close' })
end

RegisterNetEvent('ritualwar:client:open', function(payload)
    points = payload or points
    open()
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('bind', function(_, cb)
    TriggerServerEvent('ritualwar:server:startBinding')
    cb('ok')
end)

RegisterNUICallback('cancel', function(_, cb)
    TriggerServerEvent('ritualwar:server:cancelBinding')
    cb('ok')
end)

--- Wegpunkt auf einen Punkt setzen.
RegisterNUICallback('route', function(data, cb)
    for _, entry in ipairs(points) do
        if entry.id == data.id then
            SetNewWaypoint(entry.coords.x, entry.coords.y)
            break
        end
    end

    cb('ok')
end)

RegisterCommand('ritualkarte', function()
    if offen then close() else open() end
end, false)

RegisterKeyMapping('ritualkarte', 'Ritualpunkte anzeigen', 'keyboard', '')

CreateThread(function()
    Wait(3000)
    TriggerServerEvent('ritualwar:server:request')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    clearBlips()
    if offen then SetNuiFocus(false, false) end
end)
