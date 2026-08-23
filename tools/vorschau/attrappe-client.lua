-- Attrappe fuer Client-Dateien.
--
-- Erweitert tools/attrappe.lua um das, was Client-Code beim Laden anfasst:
-- Natives, Tasten, NUI. Zwei Dinge werden dabei nicht nur geschluckt,
-- sondern gemerkt:
--
--   Fangen.Ereignisse[name]   die mit RegisterNetEvent angemeldeten Handler
--   Fangen.Nachrichten        alles, was SendNUIMessage geschickt hat
--
-- Damit laesst sich der echte Aufbauweg gehen: Ereignis ausloesen, und was
-- dabei ans NUI ginge, faellt hinten heraus. Kein nachgebauter Payload -
-- der echte.

dofile('tools/attrappe.lua')

Fangen = { Ereignisse = {}, Nachrichten = {}, Rueckrufe = {} }

-- Manche Nutzlasten baut der Server. Damit sich auch dessen Dateien laden
-- lassen, braucht es oxmysql - hier als Attrappe, die nichts findet. Die
-- Aufbaufunktionen rechnen ohnehin auf einem Profil, nicht auf der Bank.
local function leer() return nil end
local function leereListe() return {} end

MySQL = {
    ready       = function(fn) end,
    query       = { await = leereListe },
    single      = { await = leer },
    scalar      = { await = leer },
    insert      = setmetatable({ await = function() return 1 end },
                               { __call = function() end }),
    update      = setmetatable({ await = function() return 1 end },
                               { __call = function() end }),
    prepare     = { await = leer },
    transaction = { await = function() return true end },
}

function RegisterNetEvent(name, handler)
    if handler then Fangen.Ereignisse[name] = handler end
end

function AddEventHandler(name, handler)
    if handler then Fangen.Ereignisse[name] = handler end
end

function RegisterNUICallback(name, handler)
    Fangen.Rueckrufe[name] = handler
end

-- CreateThread laeuft hier wirklich - bis zum ersten Wait.
--
-- Als Nichts waere es zu wenig: viele Resourcen bauen ihre Nachschlage-
-- tabellen in einem Thread auf, und ohne den bleiben sie leer. Als echte
-- Schleife waere es zu viel: ein "while true do ... Wait(0) end" liefe
-- ewig, weil Wait hier nichts tut.
--
-- Also: die Funktion laeuft, und das erste Wait bricht sie ab. Genau der
-- Teil, der einmal am Anfang steht, wird damit ausgefuehrt.
local ABBRUCH = {}
local imThread = false

function Wait(...)
    if imThread then error(ABBRUCH) end
end

function CreateThread(fn)
    if type(fn) ~= 'function' then return end

    local vorher = imThread
    imThread = true

    local ok, err = pcall(fn)

    imThread = vorher

    if not ok and err ~= ABBRUCH then
        -- Echte Fehler nicht verschlucken.
        error(err, 0)
    end
end

function SetTimeout(_, fn)
    if type(fn) == 'function' then CreateThread(fn) end
end

function SendNUIMessage(nachricht)
    Fangen.Nachrichten[#Fangen.Nachrichten + 1] = nachricht
end

--- Loest ein Ereignis aus und gibt zurueck, was dabei ans NUI ging.
function Fangen.Ausloesen(name, ...)
    local handler = Fangen.Ereignisse[name]
    if not handler then
        error(('Ereignis "%s" ist nicht angemeldet'):format(name), 2)
    end

    Fangen.Nachrichten = {}

    local ok, err = pcall(handler, ...)
    if not ok then
        error(('Ereignis "%s" bricht ab: %s'):format(name, tostring(err)), 2)
    end

    return Fangen.Nachrichten
end

--- Sucht unter den gefangenen Nachrichten die mit dieser Aktion.
function Fangen.Nachricht(aktion)
    for _, nachricht in ipairs(Fangen.Nachrichten) do
        if nachricht.action == aktion then return nachricht end
    end

    return nil
end

-- Natives, die Client-Dateien beim Laden oder Zeichnen anfassen. Alle geben
-- etwas Harmloses zurueck; gebraucht wird hier nur, dass sie existieren.
local NICHTS = function() end
local NULL   = function() return 0 end
local FALSCH = function() return false end

for _, name in ipairs({
    'SetNuiFocus', 'SetNuiFocusKeepInput', 'RegisterCommand', 'RegisterKeyMapping',
    'SetPlayerInvincible', 'ShutdownLoadingScreen', 'ShutdownLoadingScreenNui',
    'SetEntityRotation', 'SetCamFov', 'SetCamRot', 'SetGameplayCamRelativeHeading',
    'SetPedComponentVariation', 'FreezeEntityPosition', 'NetworkResurrectLocalPlayer',
    'SetPlayerWantedLevel', 'ClearPlayerWantedLevel', 'SetMaxWantedLevel',
    'TriggerScreenblurFadeIn', 'TriggerScreenblurFadeOut', 'SetTimecycleModifier',
    'ClearTimecycleModifier', 'SetWeatherTypeNowPersist', 'SetClockTime',
    'NetworkOverrideClockTime', 'SetRainLevel', 'SetWind', 'SetBlackout',
    'StartAudioScene', 'StopAudioScene', 'SetAudioFlag',
    'TriggerServerEvent', 'TriggerEvent', 'DoScreenFadeOut', 'DoScreenFadeIn',
    'FreezeEntityPosition', 'SetEntityVisible', 'SetEntityInvincible',
    'ClearPedTasksImmediately', 'ClearPedTasks', 'SetEntityCoords',
    'SetEntityCoordsNoOffset', 'SetEntityHeading', 'RenderScriptCams',
    'DestroyCam', 'SetCamActive', 'SetCamCoord', 'SetCamRot', 'PointCamAtCoord',
    'DisplayRadar', 'SetPlayerControl', 'SetEntityCollision', 'AnimpostfxPlay',
    'AnimpostfxStop', 'RequestAnimDict', 'RemoveAnimDict', 'TaskPlayAnim',
    'RequestModel', 'SetModelAsNoLongerNeeded', 'SetPlayerModel',
    'SetPedDefaultComponentVariation', 'SetPedComponentVariation',
    'SetPedPropIndex', 'ClearPedProp', 'SetPedHeadBlendData',
    'SetPedFaceFeature', 'SetPedHeadOverlay', 'SetPedHeadOverlayColour',
    'SetPedHairColor', 'SetPedEyeColor', 'SetPedArmour', 'SetPedMoveRateOverride',
    'SetEntityMaxHealth', 'SetEntityHealth', 'SetEntityAlpha', 'ResetEntityAlpha',
    'AddBlipForCoord', 'RemoveBlip', 'SetBlipSprite', 'SetBlipColour',
    'SetBlipScale', 'SetBlipAsShortRange', 'BeginTextCommandSetBlipName',
    'AddTextComponentString', 'EndTextCommandSetBlipName', 'SetBlipRoute',
    'DrawMarker', 'DrawLine', 'DrawRect', 'SetTextFont', 'SetTextScale',
    'SetTextColour', 'SetTextEntry', 'DrawText', 'SetTextCentre',
    'BeginTextCommandDisplayText', 'EndTextCommandDisplayText',
    'SetTextOutline', 'SetDrawOrigin', 'ClearDrawOrigin', 'World3dToScreen2d',
    'PlaySoundFrontend', 'RequestScriptAudioBank', 'StartScreenEffect',
    'StopScreenEffect', 'ShakeGameplayCam', 'StopGameplayCamShaking',
    'NetworkFadeOutEntity', 'NetworkFadeInEntity', 'SetBlipDisplay',
    'SetBlipHighDetail', 'SetBlipAlpha', 'SetBlipFlashes', 'SetBlipCategory',
}) do
    if _G[name] == nil then _G[name] = NICHTS end
end

for _, name in ipairs({
    'PlayerPedId', 'PlayerId', 'GetPlayerServerId', 'GetEntityModel',
    'GetVehiclePedIsIn', 'GetEntityHealth', 'GetPedArmour', 'GetEntityHeading',
    'GetGameTimer', 'GetClockHours', 'GetClockMinutes', 'CreateCam',
    'GetSelectedPedWeapon', 'GetPedMaxHealth', 'GetEntitySpeed',
    'GetVehicleClass', 'GetVehicleNumberOfPassengers', 'GetPedInVehicleSeat',
}) do
    if _G[name] == nil then _G[name] = NULL end
end

for _, name in ipairs({
    'DoesEntityExist', 'DoesCamExist', 'IsEntityDead', 'IsPedInAnyVehicle',
    'IsScreenFadedOut', 'IsScreenFadedIn', 'HasModelLoaded',
    'HasAnimDictLoaded', 'IsControlJustPressed', 'IsDisabledControlJustPressed',
    'NetworkIsPlayerActive', 'IsPauseMenuActive', 'IsNuiFocused',
}) do
    if _G[name] == nil then _G[name] = FALSCH end
end

function GetEntityCoords() return vector3(0.0, 0.0, 0.0) end
function GetOffsetFromEntityInWorldCoords() return vector3(0.0, 0.0, 0.0) end
function GetEntityForwardVector() return vector3(0.0, 1.0, 0.0) end
function GetStreetNameAtCoord() return 0, 0 end
function GetStreetNameFromHashKey() return 'Vinewood Blvd' end
function GetLabelText(name) return tostring(name) end
function GetHashKey(text) return #tostring(text) end
function joaat(text) return #tostring(text) end

--- Laedt eine Lua-Datei aus einer Resource.
---
--- CfxLua kennt `modell` als Kurzform fuer GetHashKey('modell'). Lua 5.4
--- kennt das nicht und bricht an der ersten Stelle ab. Ersetzt wird es
--- durch eine Zahl - gebraucht wird hier nur, dass die Datei laedt.
---@return boolean ok, string|nil fehler
function Fangen.Laden(pfad)
    local datei = io.open(pfad, 'r')
    if not datei then return false, 'nicht gefunden' end

    local text = datei:read('a')
    datei:close()

    text = text:gsub('`([%w_]+)`', function(name) return tostring(#name) end)

    local chunk, err = load(text, '@' .. pfad)
    if not chunk then return false, err end

    local ok, err2 = pcall(chunk)
    if not ok then return false, tostring(err2) end

    return true
end

--- Laedt eine ganze Resource so, wie ihr fxmanifest es vorgibt.
---@param mitServer boolean|nil Auch die Server-Dateien laden
---@return table Liste der Dateien, die nicht luden
function Fangen.Resource(name, mitServer)
    local basis = 'resources/[moonshine]/' .. name .. '/'

    local manifest = io.open(basis .. 'fxmanifest.lua', 'r')
    if not manifest then return { 'kein fxmanifest' } end

    local text = manifest:read('a')
    manifest:close()

    local dateien = {}

    for block in text:gmatch('shared_scripts%s*{(.-)}') do
        for pfad in block:gmatch("'([^']+)'") do dateien[#dateien + 1] = pfad end
    end

    -- Server zuerst: dort stehen die Aufbaufunktionen, die der Client
    -- spaeter nur weiterreicht.
    if mitServer then
        for block in text:gmatch('server_scripts%s*{(.-)}') do
            for pfad in block:gmatch("'([^']+)'") do
                -- @oxmysql/... und Aehnliches liegt ausserhalb.
                if not pfad:match('^@oxmysql') then
                    dateien[#dateien + 1] = pfad
                end
            end
        end
    end

    for block in text:gmatch('client_scripts%s*{(.-)}') do
        for pfad in block:gmatch("'([^']+)'") do dateien[#dateien + 1] = pfad end
    end

    local fehler = {}

    for _, pfad in ipairs(dateien) do
        -- @resource/datei.lua zeigt in eine andere Resource.
        local voll = pfad:match('^@(.+)$')
        voll = voll and ('resources/[moonshine]/' .. voll) or (basis .. pfad)

        local ok, err = Fangen.Laden(voll)
        if not ok then fehler[#fehler + 1] = pfad .. ': ' .. tostring(err) end
    end

    return fehler
end
