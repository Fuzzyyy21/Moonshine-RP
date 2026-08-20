--- Die Rast: Bildschirm dunkel, Text, dann wieder hell.

local MS = exports['moonshine-core']:GetCoreObject()

local rastend = false

RegisterNetEvent('refuge:client:rest', function(payload)
    if rastend then return end

    rastend = true

    CreateThread(function()
        local ped = PlayerPedId()
        local dauer = math.max(3, payload.dauer or 15)

        DoScreenFadeOut(1200)
        while not IsScreenFadedOut() do Wait(10) end

        -- Waehrend der Rast passiert nichts mit dem Ped.
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetEntityVisible(ped, false, false)

        SendNUIMessage({ action = 'refuge:resting', data = {
            text  = payload.text,
            dauer = dauer,
            passt = payload.passt == true,
        } })

        local schritte = 20
        for _ = 1, schritte do Wait(math.floor(dauer * 1000 / schritte)) end

        SendNUIMessage({ action = 'refuge:restDone' })

        ped = PlayerPedId()
        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, false)
        FreezeEntityPosition(ped, false)

        -- Leben wieder voll - das gilt auch ohne Mystik.
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        ClearPedBloodDamage(ped)

        DoScreenFadeIn(1400)
        rastend = false
    end)
end)

exports('IsResting', function() return rastend end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if rastend then
        local ped = PlayerPedId()
        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, false)
        FreezeEntityPosition(ped, false)
        DoScreenFadeIn(0)
    end
end)
