--- HUD: Geld, Job, Status, Leben und Weste.

local hudVisible = true

local function buildHudPayload()
    local ped = PlayerPedId()
    local data = MS.PlayerData

    return {
        name     = data.fullname or '',
        id       = GetPlayerServerId(PlayerId()),
        job      = data.job and ('%s | %s'):format(data.job.label, data.job.gradeLabel) or '',
        cash     = data.accounts and data.accounts.cash or 0,
        bank     = data.accounts and data.accounts.bank or 0,
        health   = MS.Utils.Clamp(GetEntityHealth(ped) - 100, 0, 100),
        armor    = GetPedArmour(ped),
        hunger   = data.metadata and data.metadata.hunger or 100,
        thirst   = data.metadata and data.metadata.thirst or 100,
        showStatus = Config.Status.enabled,
    }
end

CreateThread(function()
    while true do
        Wait(500)

        if MS.IsPlayerLoaded and hudVisible then
            SendNUIMessage({ action = 'updateHud', data = buildHudPayload() })
        end
    end
end)

RegisterCommand('hud', function()
    hudVisible = not hudVisible
    SendNUIMessage({ action = 'setHudVisible', data = hudVisible })
end, false)

RegisterKeyMapping('hud', 'HUD ein-/ausblenden', 'keyboard', Config.Keys.hudToggle)

AddEventHandler('moonshine:client:playerUnloaded', function()
    SendNUIMessage({ action = 'setHudVisible', data = false })
end)

-- Standard-HUD von GTA reduzieren -------------------------------------------

CreateThread(function()
    while true do
        Wait(0)

        if MS.IsPlayerLoaded then
            HideHudComponentThisFrame(1)  -- Waffenrad
            HideHudComponentThisFrame(2)  -- Waffenrad Munition
            HideHudComponentThisFrame(3)  -- Cash
            HideHudComponentThisFrame(4)  -- MP Cash
            HideHudComponentThisFrame(13) -- Cash Change
            HideHudComponentThisFrame(20) -- Weapon Icon
        else
            Wait(500)
        end
    end
end)
