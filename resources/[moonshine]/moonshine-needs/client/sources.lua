--- Die Handlungen, mit denen man sein Beduerfnis stillt.

local MS = exports['moonshine-core']:GetCoreObject()

local beschaeftigt = false

--- Hat meine Klasse eine Quelle dieser Art?
local function hatQuelle(kind)
    if not Needs.Current then return nil end

    for _, quelle in ipairs(Needs.Current.sources or {}) do
        if quelle.kind == kind then return quelle end
    end

    return nil
end

--- Fuehrt die Handlung mit Animation aus.
local function handlung(quelle, kind, targetId, ziel)
    if beschaeftigt then return end
    beschaeftigt = true

    CreateThread(function()
        local ped = PlayerPedId()

        RequestAnimDict('anim@gangops@morgue@table@')
        local tries = 0
        while not HasAnimDictLoaded('anim@gangops@morgue@table@') and tries < 30 do
            Wait(50)
            tries = tries + 1
        end

        if HasAnimDictLoaded('anim@gangops@morgue@table@') then
            TaskPlayAnim(ped, 'anim@gangops@morgue@table@', 'ko_front',
                2.0, -2.0, -1, 49, 0, false, false, false)
        end

        local dauer = (quelle.duration or 5) * 1000
        local schritte = 20

        for index = 1, schritte do
            Wait(math.floor(dauer / schritte))

            SendNUIMessage({ action = 'needs:progress', value = index / schritte })

            -- Bewegt sich das Ziel weg, bricht es ab.
            if ziel and DoesEntityExist(ziel) then
                if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ziel)) > 3.5 then
                    SendNUIMessage({ action = 'needs:progress', value = 0 })
                    ClearPedTasks(PlayerPedId())
                    MS.Notify('Abgebrochen.', 'error')

                    beschaeftigt = false
                    return
                end
            end
        end

        SendNUIMessage({ action = 'needs:progress', value = 0 })
        ClearPedTasks(PlayerPedId())

        TriggerServerEvent('needs:server:drain', kind, targetId)
        beschaeftigt = false
    end)
end

--- Naechster Passant oder naechstes Tier.
local function naechsterNpc(tiere)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local handle, gefunden = FindFirstPed()
    local erfolg
    local bester, besteDistanz = nil, 4.0

    repeat
        if DoesEntityExist(gefunden) and gefunden ~= ped
            and not IsPedAPlayer(gefunden) and not IsEntityDead(gefunden) then

            local istTier = IsPedHuman(gefunden) == false

            if (tiere and istTier) or (not tiere and not istTier) then
                local distanz = #(coords - GetEntityCoords(gefunden))

                if distanz < besteDistanz then
                    bester, besteDistanz = gefunden, distanz
                end
            end
        end

        erfolg, gefunden = FindNextPed(handle)
    until not erfolg

    EndFindPed(handle)
    return bester
end

--- Naechster bewusstloser Spieler.
local function naechsterBewusstloser()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local bester, besteDistanz, besteId = nil, 3.0, nil

    for _, other in ipairs(GetActivePlayers()) do
        local otherPed = GetPlayerPed(other)

        if otherPed ~= ped and DoesEntityExist(otherPed) then
            local distanz = #(coords - GetEntityCoords(otherPed))

            -- Bewusstlose liegen am Boden.
            if distanz < besteDistanz and
                (IsPedRagdoll(otherPed) or IsPedDeadOrDying(otherPed, true)
                 or GetEntityHealth(otherPed) <= 101) then

                bester, besteDistanz = otherPed, distanz
                besteId = GetPlayerServerId(other)
            end
        end
    end

    return bester, besteId
end

-- Interaktion ----------------------------------------------------------------

CreateThread(function()
    while true do
        local wait = 800

        if Needs.Current and not beschaeftigt and not IsEntityDead(PlayerPedId()) then
            local downed = hatQuelle('downed')
            local npc = hatQuelle('npc')

            -- Bewusstlose haben Vorrang.
            if downed then
                local ziel, id = naechsterBewusstloser()

                if ziel then
                    wait = 0

                    MS.DrawText3D(GetEntityCoords(ziel) + vector3(0.0, 0.0, 0.6),
                        ('~b~G~s~  %s'):format(downed.label), 0.4)

                    if IsControlJustReleased(0, 47) then
                        handlung(downed, 'downed', id, ziel)
                    end
                end
            end

            if npc and wait ~= 0 then
                local ziel = naechsterNpc(npc.animals == true)

                if ziel then
                    wait = 0

                    MS.DrawText3D(GetEntityCoords(ziel) + vector3(0.0, 0.0, 1.0),
                        ('~b~G~s~  %s'):format(npc.label), 0.4)

                    if IsControlJustReleased(0, 47) then
                        handlung(npc, 'npc', nil, ziel)
                    end
                end
            end
        end

        Wait(wait)
    end
end)

-- Zonen -----------------------------------------------------------------------

--- Zeigt an, wenn man in einer Zone steht, die das eigene Beduerfnis fuellt.
CreateThread(function()
    local letzteZone = nil

    while true do
        Wait(4000)

        if Needs.Current then
            local art, ort = Needs.ZoneAt(GetEntityCoords(PlayerPedId()))
            local menge = art and Needs.ZoneAmount(Needs.Current.race, art) or 0

            if menge > 0 and letzteZone ~= art then
                letzteZone = art

                local zone = Needs.Zones[art]
                MS.Notify(('%s %s - hier fuellst du dich auf.'):format(
                    zone.icon, ort.label), 'success', 7000)

                SendNUIMessage({ action = 'needs:zone', label = ort.label,
                    icon = zone.icon })

            elseif menge <= 0 and letzteZone then
                letzteZone = nil
                SendNUIMessage({ action = 'needs:zone' })
            end
        end
    end
end)

--- Kraftorte sind auch die Ritualpunkte - beim Start ergaenzen.
CreateThread(function()
    Wait(3000)

    -- MysticConfig ist ein shared-Script und liegt hier ohnehin vor.
    local ok = pcall(function()
        if not MysticConfig then return end

        for _, punkt in ipairs(MysticConfig.RitualPoints or {}) do
            Needs.Zones.kraftort.orte[#Needs.Zones.kraftort.orte + 1] = {
                label  = punkt.label or 'Ritualpunkt',
                coords = punkt.coords,
                radius = (punkt.radius or 20.0) + 25.0,
            }
        end
    end)

    if not ok and NeedsConfig.Debug then
        print('[Beduerfnisse] Ritualpunkte liessen sich nicht ergaenzen.')
    end
end)
