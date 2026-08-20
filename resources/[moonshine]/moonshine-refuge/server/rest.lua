--- Rasten: Essenz und Leben voll, dazu ein Segen auf Zeit.
---
--- Der Segen laeuft ueber moonshine-mystic. Ohne die Resource bleibt die
--- Rast trotzdem sinnvoll - Leben wird auch dann wieder voll.

--- [source] = { bis, werte } - laufende Segen.
Refuge.Blessings = {}

--- Der Segen eines Spielers, oder nil.
function Refuge.ActiveBlessing(source)
    local eintrag = Refuge.Blessings[source]
    if not eintrag then return nil end

    if os.time() >= eintrag.bis then
        Refuge.Blessings[source] = nil
        return nil
    end

    return eintrag.werte
end

RegisterNetEvent('refuge:server:rest', function()
    local source = source
    if not MS.RateLimit(source, 'refuge:rest', 5, 30) then return end

    local player = MS.GetPlayer(source)
    if not player or not RefugeConfig.Rest.enabled then return end

    local placeId, entry = Refuge.Of(player.charId)
    if not placeId then return end

    if not Refuge.AtPlace(source, placeId) then
        player:Notify('Dafuer musst du an deinem Ort sein.', 'error')
        return
    end

    if not Refuge.RestReady(entry) then
        local rest = RefugeConfig.Rest.cooldown * 60 - (os.time() - entry.lastRest)
        player:Notify(('Du bist noch nicht muede. Noch %d Minuten.'):format(
            math.ceil(rest / 60)), 'warning', 8000)
        return
    end

    local place = Refuge.GetPlace(placeId)
    local race = Refuge.RaceOf(source)
    local kind = Refuge.GetKind(race)
    local werte, passt = Refuge.GetBlessing(race, place and place.art or nil)

    entry.lastRest = os.time()
    Refuge.DB.Touch(placeId, 'last_rest', entry.lastRest)

    TriggerClientEvent('refuge:client:rest', source, {
        dauer = RefugeConfig.Rest.duration,
        text  = kind.ruhe,
        passt = passt,
    })

    -- Der Rest passiert erst, wenn der Bildschirm wieder hell wird.
    SetTimeout(RefugeConfig.Rest.duration * 1000, function()
        local jetzt = MS.GetPlayer(source)
        if not jetzt then return end

        -- Essenz auffuellen (moonshine-mystic, optional).
        pcall(function()
            exports['moonshine-mystic']:AddEssence(source, 9999)
        end)

        Refuge.Blessings[source] = {
            bis   = os.time() + RefugeConfig.Rest.segenDauer * 60,
            werte = werte,
        }

        -- Die Mystik rechnet den Segen ab jetzt mit ein.
        pcall(function()
            exports['moonshine-mystic']:RefreshModifiers(source)
        end)

        jetzt:Notify(passt
            and ('Ausgeruht. Der Ort passt zu dir - der Segen haelt %d Minuten.')
                :format(RefugeConfig.Rest.segenDauer)
            or ('Ausgeruht. Der Segen haelt %d Minuten.')
                :format(RefugeConfig.Rest.segenDauer),
            'success', 10000)

        TriggerEvent('refuge:server:rested', source, placeId, passt)
    end)
end)

AddEventHandler('playerDropped', function()
    Refuge.Blessings[source] = nil
end)

--- moonshine-mystic fragt das beim Zusammenrechnen der Modifikatoren ab.
exports('GetModifiers', function(source)
    return Refuge.ActiveBlessing(source)
end)
