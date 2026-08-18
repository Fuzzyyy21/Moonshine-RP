--- Clientseitige Meldungen an den Wachhund.
---
--- Der Client meldet nur - beurteilt wird serverseitig. Position und
--- Geschwindigkeit prueft der Server ohnehin selbst.

CreateThread(function()
    Wait(20000)

    while true do
        Wait(12000)

        if AdminConfig.Guard.enabled then
            local ped = PlayerPedId()

            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                local weapon = GetSelectedPedWeapon(ped)
                local name = nil

                -- Nur gesperrte Waffen melden, alles andere geht niemanden an.
                for _, entry in ipairs(AdminConfig.Guard.weapons.blacklist) do
                    if weapon == joaat(entry) then
                        name = entry
                        break
                    end
                end

                TriggerServerEvent('admin:server:report', {
                    health = GetEntityHealth(ped),
                    armour = GetPedArmour(ped),
                    weapon = name,
                })
            end
        end
    end
end)
