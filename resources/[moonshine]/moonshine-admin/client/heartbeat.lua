--- Das Lebenszeichen an den Server.
---
--- Kurz gehalten mit Absicht: je weniger hier steht, desto weniger laesst
--- sich davon abschalten, ohne dass es sofort auffaellt. Wer diese Datei
--- anhaelt, wird still - und genau daran erkennt der Server ihn.

local token = nil
local intervall = 20

RegisterNetEvent('admin:client:heartbeat', function(neuerToken, sekunden)
    token = neuerToken
    intervall = tonumber(sekunden) or 20
end)

CreateThread(function()
    while true do
        Wait(1000)

        if token then
            local senden = token
            token = nil

            Wait(math.max(1, intervall - 1) * 1000)
            TriggerServerEvent('admin:server:heartbeat', senden)
        end
    end
end)
