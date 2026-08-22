--- Schicht 3: was FiveM dem Server von selbst meldet.
---
--- Diese Ereignisse kommen aus dem Spiel, nicht aus einem Skript. Ein
--- Client kann sie weder faelschen noch abschalten - er kann sie nur
--- ausloesen oder nicht. Das macht sie zur verlaesslichsten Quelle, die es
--- gibt, und zu genau der Stelle, an der der bisherige Wachhund nichts
--- gesehen hat.

--- Modelle einmal als Hash, statt bei jedem Objekt neu.
local gesperrteModelle = {}

CreateThread(function()
    for _, name in ipairs(AdminConfig.Guard.entitaeten.gesperrteModelle) do
        gesperrteModelle[GetHashKey(name)] = name
    end
end)

--- Der Absender kommt als Zeichenkette herein.
local function absender(sender)
    local source = tonumber(sender)
    if not source or source <= 0 then return nil end

    return source
end

-- Explosionen -------------------------------------------------------------------

AddEventHandler('explosionEvent', function(sender, ev)
    local config = AdminConfig.Guard.explosionen
    if not AdminConfig.Guard.enabled or not config.enabled then return end

    local source = absender(sender)
    if not source then return end

    local art = config.gesperrt[tonumber(ev and ev.explosionType) or -1]
    if not art then return end

    -- Klassenfaehigkeiten zuenden Explosionen. Der Server hat sie erlaubt.
    if Admin.IsAllowed(source, 'explosion') then return end

    if config.aktion == 'abbrechen' then CancelEvent() end

    Admin.Flag(source, ('Explosion: %s'):format(art), config.gewicht, {
        typ = ev.explosionType,
        art = art,
        abgebrochen = config.aktion == 'abbrechen',
    }, 'explosion')
end)

-- Waffenschaden -------------------------------------------------------------------

AddEventHandler('weaponDamageEvent', function(sender, data)
    local config = AdminConfig.Guard.schaden
    if not AdminConfig.Guard.enabled or not config.enabled then return end

    local source = absender(sender)
    if not source then return end

    -- Schaden, den keine Waffe im Spiel anrichtet.
    local schaden = tonumber(data and data.weaponDamage) or 0

    if schaden > config.maxSchaden then
        CancelEvent()

        -- Eindeutig: keine Waffe im Spiel richtet so viel an. Das ist einer
        -- der wenigen Funde, die fuer einen Bann taugen.
        Admin.Flag(source, ('Unmoeglicher Schaden (%d)'):format(schaden),
            config.gewicht, { schaden = schaden, grenze = config.maxSchaden },
            'schaden')
        return
    end

    -- Treffer ueber die halbe Karte hinweg.
    local ziel = data and data.hitGlobalIds and data.hitGlobalIds[1]

    if ziel then
        local opfer = NetworkGetEntityFromNetworkId(ziel)
        local taeter = GetPlayerPed(source)

        if opfer and opfer ~= 0 and taeter and taeter ~= 0 then
            local weite = #(GetEntityCoords(taeter) - GetEntityCoords(opfer))

            if weite > config.maxEntfernung then
                -- Nur ein Hinweis, kein Beweis: eine Heavy Sniper vom Mount
                -- Chiliad kommt weit, und ein Abbruch haette dem Schuetzen
                -- den Treffer weggenommen. Der Abbruch ist deshalb abstellbar
                -- und ab Werk aus.
                if config.entfernungAbbrechen then CancelEvent() end

                Admin.Flag(source, ('Treffer ueber %d Meter'):format(math.floor(weite)),
                    config.gewicht, { entfernung = math.floor(weite),
                                      grenze = config.maxEntfernung },
                    'treffweite')
            end
        end
    end
end)

-- Erzeugte Objekte -------------------------------------------------------------------

AddEventHandler('entityCreating', function(entity)
    local config = AdminConfig.Guard.entitaeten
    if not AdminConfig.Guard.enabled or not config.enabled then return end
    if not entity or not DoesEntityExist(entity) then return end

    local name = gesperrteModelle[GetEntityModel(entity)]
    if not name then return end

    -- Wer das Objekt erzeugt hat, weiss nur das Netzwerk - und auch das
    -- nicht sicher. Fuer die Frage "darf das hier stehen" reicht es aber:
    -- ein Admin, der fuer ein Event einen Panzer setzt, soll ihn behalten.
    local owner = NetworkGetEntityOwner(entity)
    local source = (owner and owner > 0 and GetPlayerName(owner)) and owner or nil

    if source and (Admin.Exempt(MS.GetPlayer(source))
        or Admin.IsAllowed(source, 'modell')) then
        return
    end

    if config.aktion == 'abbrechen' then CancelEvent() end

    -- Gemeldet wird nur, wenn der Besitzer auch wirklich verbunden ist.
    -- Der Besitz eines Fahrzeugs wandert - ein Unbeteiligter soll dafuer
    -- keine Strikes bekommen. Alles andere geht in die Konsole.
    if source then
        Admin.Flag(source, ('Gesperrtes Modell: %s'):format(name), config.gewicht,
            { modell = name, abgebrochen = config.aktion == 'abbrechen',
              hinweis = 'Besitzer laut Netzwerk, nicht zwingend der Erzeuger' },
            'entitaet')
    else
        print(('^3[Wachhund]^7 Gesperrtes Modell %s erzeugt, Besitzer unklar.')
            :format(name))
    end
end)

-- Ereignisse aus dem Cheatmenue ---------------------------------------------------------

--- Diese drei loest ein Spieler im normalen Spiel nie selbst aus. Sie
--- stehen in jedem Cheatmenue an erster Stelle.
--- Diese Ereignisse loest kein normales Spiel aus - sie taugen als Beweis.
local function melde(source, was)
    Admin.Flag(source, was, AdminConfig.Guard.ereignisse.gewicht,
        { ereignis = was }, 'ereignis')
end

AddEventHandler('giveWeaponEvent', function(sender)
    local config = AdminConfig.Guard.ereignisse
    if not AdminConfig.Guard.enabled or not config.enabled or not config.giveWeapon then
        return
    end

    local source = absender(sender)
    if not source then return end

    CancelEvent()
    melde(source, 'Waffe per Ereignis gegeben')
end)

AddEventHandler('removeAllWeaponsEvent', function(sender)
    local config = AdminConfig.Guard.ereignisse
    if not AdminConfig.Guard.enabled or not config.enabled
        or not config.removeAllWeapons then return end

    local source = absender(sender)
    if not source then return end

    CancelEvent()
    melde(source, 'Alle Waffen per Ereignis entfernt')
end)

AddEventHandler('clearPedTasksEvent', function(sender)
    local config = AdminConfig.Guard.ereignisse
    if not AdminConfig.Guard.enabled or not config.enabled
        or not config.clearPedTasks then return end

    local source = absender(sender)
    if not source then return end

    CancelEvent()
    melde(source, 'Aufgaben per Ereignis abgebrochen')
end)
