--- Gebiete: Blips auf der Karte, Radius und die Kontrollanzeige.

local territories = {}
local blips = {}
local radiusBlips = {}
local inside = nil

--- Farbe eines Blips aus der Wappenfarbe der Fraktion.
local function blipColour(entry)
    if not entry.factionId then return 0 end        -- weiss: frei

    local primary = entry.emblem and entry.emblem.primary or '#9b6bd8'

    -- Grobe Zuordnung auf die GTA-Blipfarben.
    local COLOURS = {
        ['#c0392f'] = 1, ['#4caf7d'] = 2, ['#3d8bd4'] = 3, ['#d8b25f'] = 5,
        ['#9b6bd8'] = 27, ['#e07b39'] = 47, ['#d94f8a'] = 48, ['#2f8f8f'] = 30,
    }

    return COLOURS[primary:lower()] or 27
end

local function clearBlips()
    for _, blip in pairs(blips) do RemoveBlip(blip) end
    for _, blip in pairs(radiusBlips) do RemoveBlip(blip) end

    blips = {}
    radiusBlips = {}
end

local function drawBlips()
    clearBlips()

    for _, entry in ipairs(territories) do
        local coords = vector3(entry.coords.x, entry.coords.y, entry.coords.z)

        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 492)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.85)
        SetBlipColour(blip, blipColour(entry))
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(entry.factionTag
            and ('%s [%s]'):format(entry.label, entry.factionTag)
            or ('%s (frei)'):format(entry.label))
        EndTextCommandSetBlipName(blip)

        blips[#blips + 1] = blip

        local radius = AddBlipForRadius(coords.x, coords.y, coords.z, entry.radius)
        SetBlipColour(radius, blipColour(entry))
        SetBlipAlpha(radius, entry.factionId and 90 or 45)
        radiusBlips[#radiusBlips + 1] = radius
    end
end

RegisterNetEvent('factions:client:territories', function(payload)
    territories = payload or {}
    drawBlips()

    SendNUIMessage({ action = 'factions:territories', data = territories })

    -- Die Kontrollanzeige mit den frischen Werten fuettern.
    if inside then
        for _, entry in ipairs(territories) do
            if entry.id == inside.id then
                inside = entry
                SendNUIMessage({ action = 'factions:control', data = entry })
                return
            end
        end
    end
end)

--- In welchem Gebiet steht der Spieler?
local function findTerritory(coords)
    for _, entry in ipairs(territories) do
        local centre = vector3(entry.coords.x, entry.coords.y, entry.coords.z)
        if #(coords - centre) <= entry.radius then return entry end
    end

    return nil
end

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('factions:server:requestTerritories')

    while true do
        local coords = GetEntityCoords(PlayerPedId())
        local current = findTerritory(coords)

        if current and not inside then
            inside = current
            SendNUIMessage({ action = 'factions:control', data = current })
        elseif not current and inside then
            inside = nil
            SendNUIMessage({ action = 'factions:controlOff' })
        elseif current and inside and current.id ~= inside.id then
            inside = current
            SendNUIMessage({ action = 'factions:control', data = current })
        end

        Wait(1000)
    end
end)

--- Solange man im Gebiet steht, laeuft die Anzeige mit.
CreateThread(function()
    while true do
        if inside then
            SendNUIMessage({ action = 'factions:controlTick', data = {
                progress  = inside.progress or 0,
                contested = inside.contested or false,
            } })
            Wait(1000)
        else
            Wait(1500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearBlips()
end)
