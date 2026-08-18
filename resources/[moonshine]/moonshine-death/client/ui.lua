--- Bildschirmanzeige waehrend der Bewusstlosigkeit.

local uiVisible = false

function Death.ShowUi(visible)
    uiVisible = visible
    SendNUIMessage({ action = 'death', data = { visible = visible } })
end

CreateThread(function()
    while true do
        Wait(500)

        if uiVisible and Death.downed then
            local remaining = math.max(0, math.floor((Death.downedUntil - GetGameTimer()) / 1000))
            local untilRespawn = math.max(0, math.floor((Death.respawnAt - GetGameTimer()) / 1000))

            SendNUIMessage({
                action = 'deathUpdate',
                data = {
                    remaining    = remaining,
                    untilRespawn = untilRespawn,
                    callKey      = DeathConfig.Keys.call,
                    respawnKey   = DeathConfig.Keys.respawn,
                },
            })
        end
    end
end)
