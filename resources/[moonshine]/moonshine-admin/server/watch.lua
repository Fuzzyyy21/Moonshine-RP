--- Schicht 1: der Server sieht selbst nach.
---
--- Frueher meldete der Client von sich aus Leben, Weste und Waffe. Das ist
--- genau die falsche Richtung: wer cheatet, meldet eben saubere Werte oder
--- schaltet die Meldung ganz ab. Der Server kann all das selbst vom Ped
--- ablesen - dafuer braucht er den Client gar nicht.

--- [source] = { treffer, letzteLeben } - fuer die Godmode-Erkennung.
Admin.Damage = {}

--- Waffen-Hashes einmal vorberechnen, statt bei jedem Durchgang neu.
local gesperrteWaffen = {}

--- Dasselbe fuer die Spielermodelle.
Admin.ErlaubteModelle = {}

CreateThread(function()
    for _, name in ipairs(AdminConfig.Guard.beobachtung.waffen.gesperrt) do
        gesperrteWaffen[GetHashKey(name)] = name
    end

    for _, name in ipairs(AdminConfig.Guard.beobachtung.erlaubteModelle) do
        Admin.ErlaubteModelle[GetHashKey(name)] = true
    end
end)

--- Wie viel Leben dieser Spieler haben darf.
---
--- Klassenboni aus moonshine-mystic heben das Maximum. Ohne die Resource
--- gilt der Grundwert.
local function erlaubtesLeben(source)
    local config = AdminConfig.Guard.beobachtung
    local erlaubt = config.maxLeben + config.lebenPuffer

    pcall(function()
        local mods = exports['moonshine-mystic']:GetModifiers(source)
        if mods and mods.healthBonus then erlaubt = erlaubt + mods.healthBonus end
    end)

    return erlaubt
end

--- Ein Durchgang ueber alle Spieler.
local function durchgang()
    local config = AdminConfig.Guard.beobachtung

    for _, player in pairs(MS.GetPlayers()) do
        local source = player.source

        if not Admin.Exempt(player) then
            local ped = GetPlayerPed(source)

            if ped and ped ~= 0 and not IsEntityDead(ped) then
                -- Leben
                local leben = GetEntityHealth(ped)
                local erlaubt = erlaubtesLeben(source)

                if leben > erlaubt and not Admin.IsAllowed(source, 'leben') then
                    Admin.Flag(source, ('Zu viel Leben (%d von %d)'):format(
                        leben, erlaubt), config.gewicht,
                        { leben = leben, erlaubt = erlaubt })
                end

                -- Weste
                local weste = GetPedArmour(ped)
                if weste > config.maxWeste then
                    Admin.Flag(source, ('Zu viel Weste (%d)'):format(weste),
                        config.gewicht, { weste = weste })
                end

                -- Unverwundbarkeit. Das ist der direkteste Godmode-Fund,
                -- den es gibt: der Server fragt das Flag selbst ab.
                if config.godmode and GetPlayerInvincible(source)
                    and not Admin.IsAllowed(source, 'godmode') then
                    Admin.Flag(source, 'Unverwundbar', config.godmodeGewicht,
                        { quelle = 'GetPlayerInvincible' })
                end

                -- Ped-Modell. Wer als Panzer oder Tier herumlaeuft, hat sich
                -- das nicht im Charaktereditor ausgesucht.
                if config.modelle then
                    local modell = GetEntityModel(ped)

                    if not Admin.ErlaubteModelle[modell]
                        and not Admin.IsAllowed(source, 'modell') then
                        Admin.Flag(source, 'Fremdes Spielermodell',
                            config.modellGewicht, { modell = modell })
                    end
                end

                -- Waffe
                if config.waffen.enabled then
                    local waffe = GetSelectedPedWeapon(ped)
                    local name = gesperrteWaffen[waffe]

                    if name then
                        Admin.Flag(source, ('Gesperrte Waffe: %s'):format(name),
                            config.waffen.gewicht, { waffe = name })

                        TriggerClientEvent('admin:client:stripWeapon', source, name)
                    end
                end
            end
        end
    end
end

CreateThread(function()
    Wait(15000)

    while true do
        Wait(math.max(2, AdminConfig.Guard.beobachtung.interval) * 1000)

        if AdminConfig.Guard.enabled and AdminConfig.Guard.beobachtung.enabled then
            local ok, err = pcall(durchgang)

            if not ok then
                print(('^1[Wachhund]^7 Durchgang fehlgeschlagen: %s'):format(
                    tostring(err)))
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    Admin.Damage[source] = nil
end)
