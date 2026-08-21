--- Schicht 5: der Herzschlag.
---
--- Die groesste Luecke eines Anticheats in reinem Lua: ein Cheatmenue kann
--- die clientseitigen Skripte anhalten, bevor sie etwas melden. Danach ist
--- der Spieler unsichtbar fuer alles, was vom Client kommt.
---
--- Dagegen hilft nur die Umkehrung: der Server erwartet regelmaessig ein
--- Lebenszeichen. Bleibt es aus, ist genau das die Meldung. Wer den
--- Anticheat abschaltet, faellt dadurch auf, dass er still wird.
---
--- Das Zeichen selbst traegt einen Wert, den nur der Server kennt und der
--- sich bei jedem Schlag aendert. Ein Cheater muesste also nicht nur
--- irgendetwas schicken, sondern das Richtige - und das bekommt er nur,
--- wenn das echte Skript laeuft.

--- [source] = { token, letzterSchlag, ausstehend, geladenAt }
Admin.Heartbeat = {}

local function neuerToken()
    return ('%d-%d'):format(math.random(100000, 999999), os.time())
end

--- Beginnt die Ueberwachung fuer einen Spieler.
function Admin.Heartbeat.Start(source)
    if not AdminConfig.Guard.herzschlag.enabled then return end

    local token = neuerToken()

    Admin.Heartbeat[source] = {
        token = token,
        letzterSchlag = os.time(),
        ausstehend = 0,
        geladenAt = os.time(),
    }

    TriggerClientEvent('admin:client:heartbeat', source, token,
        AdminConfig.Guard.herzschlag.interval)
end

RegisterNetEvent('admin:server:heartbeat', function(token)
    local source = source
    local eintrag = Admin.Heartbeat[source]
    if not eintrag then return end

    -- Ein falscher Wert ist schlimmer als gar keiner: den kann nur schicken,
    -- wer die Antwort raet oder ein eigenes Skript untergeschoben hat.
    if token ~= eintrag.token then
        Admin.Flag(source, 'Herzschlag mit falschem Wert',
            AdminConfig.Guard.herzschlag.gewicht, { erwartet = 'geheim' })
        return
    end

    eintrag.letzterSchlag = os.time()
    eintrag.ausstehend = 0
    eintrag.token = neuerToken()

    TriggerClientEvent('admin:client:heartbeat', source, eintrag.token,
        AdminConfig.Guard.herzschlag.interval)
end)

--- Wer still wird, faellt auf.
CreateThread(function()
    while true do
        Wait(5000)

        local config = AdminConfig.Guard.herzschlag

        if AdminConfig.Guard.enabled and config.enabled then
            local now = os.time()

            for _, player in pairs(MS.GetPlayers()) do
                local source = player.source
                local eintrag = Admin.Heartbeat[source]

                if eintrag and not Admin.Exempt(player) then
                    -- Nach dem Verbinden etwas Luft lassen: das Skript
                    -- braucht einen Moment, bis es laeuft.
                    local seitJoin = now - eintrag.geladenAt

                    if seitJoin > config.karenz then
                        local still = now - eintrag.letzterSchlag

                        if still > config.interval * 2 then
                            eintrag.ausstehend = eintrag.ausstehend + 1
                            eintrag.letzterSchlag = now

                            Admin.Flag(source,
                                ('Kein Herzschlag seit %d Sekunden'):format(still),
                                config.gewicht, { stillSeit = still,
                                                  ausgefallen = eintrag.ausstehend })
                        end
                    end
                end
            end
        end
    end
end)

AddEventHandler('moonshine:server:playerLoaded', function(source)
    Admin.Heartbeat.Start(source)
end)

AddEventHandler('playerDropped', function()
    Admin.Heartbeat[source] = nil
end)
