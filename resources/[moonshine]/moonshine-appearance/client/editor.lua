--- Der Editor: Kamera, Vorschau, Drehen.

local MS = exports['moonshine-core']:GetCoreObject()

local camera = nil
local editing = false
local backup = nil
local origin = nil
local heading = 0.0
local view = AppearanceConfig.Camera.default

--- Setzt die Kamera auf einen Bereich des Peds.
function Appearance.SetView(name)
    local config = AppearanceConfig.Camera.views[name]
        or AppearanceConfig.Camera.views.ganz

    view = name

    if not camera or not DoesCamExist(camera) then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local pedHeading = GetEntityHeading(ped)

    local radians = math.rad(pedHeading)
    local x = coords.x + math.sin(-radians) * config.offset
    local y = coords.y + math.cos(-radians) * config.offset

    SetCamCoord(camera, x, y, coords.z + config.height)
    PointCamAtCoord(camera, coords.x, coords.y, coords.z + config.height)
    SetCamFov(camera, config.fov)
end

--- Startet den Editor.
function Appearance.StartEditor()
    if editing then return end

    editing = true
    backup = Appearance.Read()

    local ped = PlayerPedId()
    origin = { coords = GetEntityCoords(ped), heading = GetEntityHeading(ped) }
    heading = origin.heading

    camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(camera, true)
    RenderScriptCams(true, true, 600, true, true)

    Appearance.SetView(AppearanceConfig.Camera.default)

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    ClearPedTasksImmediately(ped)
end

--- Beendet den Editor.
---@param restore boolean Aussehen zuruecksetzen?
function Appearance.StopEditor(restore)
    if not editing then return end

    editing = false

    if restore and backup then Appearance.Apply(backup) end

    RenderScriptCams(false, true, 500, true, true)

    if camera and DoesCamExist(camera) then
        DestroyCam(camera, true)
        camera = nil
    end

    local ped = PlayerPedId()

    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)

    if origin then
        SetEntityHeading(ped, origin.heading)
        origin = nil
    end

    backup = nil
end

--- Drehen im Editor.
CreateThread(function()
    while true do
        if editing then
            -- Pfeiltasten drehen das Ped.
            if IsControlPressed(0, 174) then heading = heading + 1.6 end
            if IsControlPressed(0, 175) then heading = heading - 1.6 end

            -- Maus gedrueckt halten und ziehen.
            if IsControlPressed(0, 24) then
                heading = heading - GetDisabledControlNormal(0, 1) * 8.0
            end

            SetEntityHeading(PlayerPedId(), heading % 360.0)
            Appearance.SetView(view)

            -- Steuerung, die im Editor stoert.
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableAllControlActions(1)

            Wait(0)
        else
            Wait(400)
        end
    end
end)

exports('IsEditing', function()
    return editing
end)
