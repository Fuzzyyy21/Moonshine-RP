--- Adminwerkzeuge: Noclip, Unsichtbarkeit, Spectate, Teleport.

local MS = exports['moonshine-core']:GetCoreObject()

Admin.Noclip = false
Admin.Invisible = false
Admin.Spectating = nil

local noclipSpeed = 1.0

-- Teleport --------------------------------------------------------------------

RegisterNetEvent('admin:client:teleport', function(coords)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local entity = vehicle ~= 0 and vehicle or ped

    DoScreenFadeOut(300)
    Wait(350)

    SetEntityCoordsNoOffset(entity, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0,
        false, false, false)

    -- Boden suchen, damit niemand in der Luft landet.
    local ground, height = GetGroundZFor_3dCoord(coords.x + 0.0, coords.y + 0.0,
        coords.z + 30.0, false)

    if ground and height then
        SetEntityCoordsNoOffset(entity, coords.x + 0.0, coords.y + 0.0, height + 1.0,
            false, false, false)
    end

    Wait(200)
    DoScreenFadeIn(400)
end)

RegisterNetEvent('admin:client:heal', function()
    local ped = PlayerPedId()

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedBloodDamage(ped)
    MS.Notify('Du wurdest geheilt.', 'success')
end)

RegisterNetEvent('admin:client:freeze', function(state)
    local ped = PlayerPedId()

    FreezeEntityPosition(ped, state == true)
    MS.Notify(state and 'Du wurdest eingefroren.' or 'Du kannst dich wieder bewegen.',
        state and 'error' or 'info')
end)

-- 'admin:client:stripWeapon' liegt in client/guard.lua - dort nimmt es
-- auch die Waffe aus der Hand, nicht nur aus dem Inventar.

-- Noclip -------------------------------------------------------------------------

local function setNoclip(state)
    Admin.Noclip = state

    local ped = PlayerPedId()

    SetEntityInvincible(ped, state)
    SetEntityVisible(ped, not state and not Admin.Invisible, false)
    SetEntityCollision(ped, not state, not state)
    FreezeEntityPosition(ped, state)

    if not state then
        SetEntityVisible(ped, not Admin.Invisible, false)
    end

    MS.Notify(state and 'Noclip an.' or 'Noclip aus.', 'info', 3000)
end

CreateThread(function()
    while true do
        if Admin.Noclip then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local camera = GetGameplayCamRot(2)

            -- Tempo mit Mausrad.
            if IsControlJustPressed(0, 241) then
                noclipSpeed = math.min(12.0, noclipSpeed + 0.5)
            elseif IsControlJustPressed(0, 242) then
                noclipSpeed = math.max(0.2, noclipSpeed - 0.5)
            end

            local speed = noclipSpeed
            if IsControlPressed(0, 21) then speed = speed * 3.0 end

            local pitch = math.rad(camera.x)
            local yaw = math.rad(camera.z)

            local forward = vector3(
                -math.sin(yaw) * math.cos(pitch),
                 math.cos(yaw) * math.cos(pitch),
                 math.sin(pitch))

            local right = vector3(math.cos(yaw), math.sin(yaw), 0.0)

            local move = vector3(0.0, 0.0, 0.0)

            if IsControlPressed(0, 32) then move = move + forward end   -- W
            if IsControlPressed(0, 33) then move = move - forward end   -- S
            if IsControlPressed(0, 34) then move = move - right end     -- A
            if IsControlPressed(0, 35) then move = move + right end     -- D
            if IsControlPressed(0, 44) then move = move + vector3(0.0, 0.0, 1.0) end -- Q
            if IsControlPressed(0, 38) then move = move - vector3(0.0, 0.0, 1.0) end -- E

            if #move > 0.0 then
                local target = coords + move * speed
                SetEntityCoordsNoOffset(ped, target.x, target.y, target.z,
                    false, false, false)
            end

            -- Steuerung, die im Noclip stoert.
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 22, true)

            Wait(0)
        else
            Wait(300)
        end
    end
end)

RegisterCommand('noclip', function(source)
    -- Der Server prueft das Level beim Oeffnen des Panels; hier reicht die
    -- Anzeige, weil Noclip ohne Serverwirkung ist.
    if not Admin.Allowed then
        MS.Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    setNoclip(not Admin.Noclip)
end, false)

RegisterKeyMapping('noclip', 'Noclip (Admin)', 'keyboard', '')

-- Unsichtbarkeit ---------------------------------------------------------------------

RegisterCommand('unsichtbar', function()
    if not Admin.Allowed then
        MS.Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    Admin.Invisible = not Admin.Invisible
    SetEntityVisible(PlayerPedId(), not Admin.Invisible, false)

    MS.Notify(Admin.Invisible and 'Unsichtbar.' or 'Wieder sichtbar.', 'info', 3000)
end, false)

-- Spectate ----------------------------------------------------------------------------

RegisterNetEvent('admin:client:spectate', function(targetSource, coords, name)
    if Admin.Spectating then
        -- Beenden.
        local ped = PlayerPedId()

        NetworkSetInSpectatorMode(false, PlayerPedId())
        SetEntityVisible(ped, not Admin.Invisible, false)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)

        if Admin.SpectateReturn then
            SetEntityCoords(ped, Admin.SpectateReturn.x, Admin.SpectateReturn.y,
                Admin.SpectateReturn.z, false, false, false, false)
        end

        Admin.Spectating = nil
        Admin.SpectateReturn = nil

        SendNUIMessage({ action = 'admin:spectate', data = nil })
        MS.Notify('Beobachtung beendet.', 'info')
        return
    end

    local ped = PlayerPedId()
    Admin.SpectateReturn = GetEntityCoords(ped)

    SetEntityCoords(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0,
        false, false, false, false)

    Wait(500)

    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetSource))

    if targetPed and targetPed ~= 0 then
        NetworkSetInSpectatorMode(true, targetPed)
        SetEntityVisible(ped, false, false)
        SetEntityCollision(ped, false, false)
        FreezeEntityPosition(ped, true)

        Admin.Spectating = targetSource

        SendNUIMessage({ action = 'admin:spectate', data = { name = name } })
        MS.Notify(('Beobachtest %s. Nochmal klicken beendet es.'):format(name),
            'info', 8000)
    else
        SetEntityCoords(ped, Admin.SpectateReturn.x, Admin.SpectateReturn.y,
            Admin.SpectateReturn.z, false, false, false, false)
        MS.Notify('Der Spieler ist zu weit weg.', 'error')
    end
end)

--- Beim Resource-Stop alles zuruecksetzen.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    local ped = PlayerPedId()

    NetworkSetInSpectatorMode(false, ped)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
end)
