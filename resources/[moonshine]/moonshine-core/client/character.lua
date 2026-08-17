--- Charakterauswahl inkl. Kamera und Spawn.

local selectionCam = nil
local inSelection  = false

-- Hilfsfunktionen ------------------------------------------------------------

local function setPlayerVisible(visible)
    local ped = PlayerPedId()
    SetEntityVisible(ped, visible, false)
    SetEntityCollision(ped, visible, visible)
    FreezeEntityPosition(ped, not visible)
    SetPlayerInvincible(PlayerId(), not visible)
    if visible then
        SetPlayerControl(PlayerId(), true, 0)
    else
        SetPlayerControl(PlayerId(), false, 0)
    end
end

local function startSelectionCamera()
    local camera = Config.SelectionCamera
    selectionCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    SetCamCoord(selectionCam, camera.coords.x, camera.coords.y, camera.coords.z)
    PointCamAtCoord(selectionCam, camera.look.x, camera.look.y, camera.look.z)
    SetCamActive(selectionCam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function stopSelectionCamera()
    if not selectionCam then return end

    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(selectionCam, true)
    selectionCam = nil
end

--- Laedt das Spielermodell passend zum Geschlecht.
local function applyModel(gender)
    local model = gender == 'w' and `mp_f_freemode_01` or `mp_m_freemode_01`

    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end

    if not HasModelLoaded(model) then return end

    SetPlayerModel(PlayerId(), model)
    SetPedDefaultComponentVariation(PlayerPedId())
    SetModelAsNoLongerNeeded(model)
end

-- Ablauf ---------------------------------------------------------------------

local function enterSelection()
    if inSelection then
        -- Auswahl laeuft bereits (z.B. nach dem Loeschen eines Charakters).
        SetNuiFocus(true, true)
        return
    end

    inSelection = true

    DoScreenFadeOut(0)
    setPlayerVisible(false)

    local camera = Config.SelectionCamera
    SetEntityCoords(PlayerPedId(), camera.coords.x, camera.coords.y, camera.coords.z - 5.0, false, false, false, false)

    startSelectionCamera()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'setHudVisible', data = false })
    DoScreenFadeIn(500)
end

--- Beendet die Auswahl und setzt den Spieler in die Welt.
function MS.SpawnPlayer(position)
    inSelection = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'showCharSelect', data = false })
    DoScreenFadeOut(500)
    Wait(500)

    applyModel(MS.PlayerData.gender)
    stopSelectionCamera()

    local ped = PlayerPedId()
    SetEntityCoords(ped, position.x, position.y, position.z, false, false, false, false)
    SetEntityHeading(ped, position.heading or 0.0)

    setPlayerVisible(true)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))

    -- Warten bis die Umgebung geladen ist, damit der Spieler nicht durchfaellt.
    local timeout = GetGameTimer() + 10000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(10) end

    ShutdownLoadingScreen()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'setHudVisible', data = true })
    DoScreenFadeIn(800)
end

RegisterNetEvent('moonshine:client:characterList', function(payload)
    enterSelection()

    SendNUIMessage({ action = 'showCharSelect', data = true })
    SendNUIMessage({ action = 'setCharacters', data = payload })
end)

RegisterNetEvent('moonshine:client:characterError', function(message)
    SendNUIMessage({ action = 'characterError', data = message })
    MS.Notify(message, 'error')
end)

-- NUI-Callbacks --------------------------------------------------------------

RegisterNUICallback('selectCharacter', function(data, cb)
    TriggerServerEvent('moonshine:server:selectCharacter', data.id)
    cb('ok')
end)

RegisterNUICallback('createCharacter', function(data, cb)
    TriggerServerEvent('moonshine:server:createCharacter', {
        firstname = data.firstname,
        lastname  = data.lastname,
        dob       = data.dob,
        gender    = data.gender,
    })
    cb('ok')
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    TriggerServerEvent('moonshine:server:deleteCharacter', data.id)
    cb('ok')
end)

-- Start ----------------------------------------------------------------------

CreateThread(function()
    -- Standard-Spawnverhalten deaktivieren, wir spawnen selbst.
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)

    DoScreenFadeOut(0)
    while not NetworkIsSessionStarted() do Wait(100) end
    Wait(500)

    TriggerServerEvent('moonshine:server:playerReady')
end)

-- Steuerung waehrend der Auswahl blockieren.
CreateThread(function()
    while true do
        if inSelection then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)   -- Maus X
            EnableControlAction(0, 2, true)   -- Maus Y
            Wait(0)
        else
            Wait(500)
        end
    end
end)
