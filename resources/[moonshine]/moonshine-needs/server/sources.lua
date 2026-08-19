--- Die Wege, ein Beduerfnis zu fuellen.

--- Registriert die Gegenstaende und macht sie benutzbar.
CreateThread(function()
    for _ = 1, 20 do
        local ok = pcall(function()
            for name, entry in pairs(Needs.Items) do
                exports['moonshine-core']:RegisterItem(name, {
                    label       = entry.label,
                    weight      = entry.weight,
                    stack       = true,
                    usable      = true,
                    description = entry.description,
                })
            end
        end)

        if ok then break end
        Wait(500)
    end

    Wait(1500)

    for name in pairs(Needs.Items) do
        local itemName = name

        MS.RegisterUsableItem(itemName, function(player, slot)
            local source = player.source
            local race = Needs.RaceOf(source)

            local passend = Needs.RaceForItem(itemName)
            if passend and passend ~= race then
                local definition = Needs.Definitions[passend]
                player:Notify(('Damit kann nur %s etwas anfangen.'):format(
                    definition and definition.label or passend), 'error')
                return
            end

            local quelle = nil
            for _, source_ in ipairs(Needs.GetSources(race, 'item')) do
                if source_.item == itemName then quelle = source_ break end
            end

            if not quelle then
                player:Notify('Das bringt dir nichts.', 'error')
                return
            end

            if not player:RemoveItem(itemName, 1, slot) then return end

            local neu = Needs.Add(source, quelle.amount)
            local definition = Needs.Definitions[race]

            player:Notify(('%s %s: %d %%'):format(definition.icon,
                definition.label, math.floor(neu or 0)), 'success')

            TriggerClientEvent('needs:client:consumed', source, itemName)
            TriggerEvent('needs:server:filled', source, 'item', quelle.amount)
        end)
    end
end)

-- Am Passanten oder am Bewusstlosen ---------------------------------------------

--- Der Client meldet, dass er die Handlung abgeschlossen hat.
RegisterNetEvent('needs:server:drain', function(kind, targetId)
    local source = source
    if not MS.RateLimit(source, 'needs:drain', 8, 20) then return end

    local player = MS.GetPlayer(source)
    if not player then return end

    if kind ~= 'npc' and kind ~= 'downed' then return end

    local race = Needs.RaceOf(source)
    local quelle = Needs.GetSource(race, kind)

    if not quelle then
        player:Notify('Das bringt dir nichts.', 'error')
        return
    end

    if not Needs.CheckCooldown(source, kind) then
        player:Notify('Noch nicht. Warte einen Moment.', 'error')
        return
    end

    -- Am Bewusstlosen: der muss wirklich am Boden liegen und in Reichweite sein.
    if kind == 'downed' then
        local target = MS.GetPlayer(tonumber(targetId) or -1)
        if not target then return end

        local liegt = false
        pcall(function()
            liegt = exports['moonshine-death']:IsPlayerDowned(target.source) == true
        end)

        if not liegt then
            player:Notify('Der steht noch zu fest auf den Beinen.', 'error')
            return
        end

        local abstand = #(GetEntityCoords(GetPlayerPed(source))
            - GetEntityCoords(GetPlayerPed(target.source)))

        if abstand > 3.0 then
            player:Notify('Zu weit weg.', 'error')
            return
        end

        target:Notify('Jemand nimmt sich etwas von dir.', 'error', 9000)
        TriggerEvent('needs:server:drainedPlayer', source, target.source, race)
    end

    Needs.SetCooldown(source, kind)

    local neu = Needs.Add(source, quelle.amount)
    local definition = Needs.Definitions[race]

    player:Notify(('%s %s: %d %%'):format(definition.icon, definition.label,
        math.floor(neu or 0)), 'success')

    TriggerEvent('needs:server:filled', source, kind, quelle.amount)
end)

-- Meditation --------------------------------------------------------------------

AddEventHandler('mystic:server:meditated', function(source)
    local race = Needs.RaceOf(source)
    local quelle = Needs.GetSource(race, 'meditate')
    if not quelle then return end

    local neu = Needs.Add(source, quelle.amount)
    local definition = Needs.Definitions[race]

    local player = MS.GetPlayer(source)
    if player and definition then
        player:Notify(('%s Die Versenkung fuellt dich: %d %%'):format(
            definition.icon, math.floor(neu or 0)), 'success', 8000)
    end

    TriggerEvent('needs:server:filled', source, 'meditate', quelle.amount)
end)

-- Weltboss -----------------------------------------------------------------------

AddEventHandler('boss:server:participantRewarded', function(source)
    local race = Needs.RaceOf(source)
    local quelle = Needs.GetSource(race, 'boss')
    if not quelle then return end

    Needs.Add(source, quelle.amount)
    TriggerEvent('needs:server:filled', source, 'boss', quelle.amount)
end)

-- Wenn jemand durch die eigene Hand faellt --------------------------------------

--- Der Core prueft den gemeldeten Toeter bereits auf Plausibilitaet.
AddEventHandler('moonshine:server:playerDeath', function(victim, _, killer)
    if not killer or killer == victim then return end

    local race = Needs.RaceOf(killer)
    local quelle = Needs.GetSource(race, 'kill')
    if not quelle then return end

    Needs.Add(killer, quelle.amount)

    local player = MS.GetPlayer(killer)
    local definition = Needs.Definitions[race]

    if player and definition then
        player:Notify(('%s Du nimmst dir, was frei wird.'):format(definition.icon),
            'info', 6000)
    end

    TriggerEvent('needs:server:filled', killer, 'kill', quelle.amount)
end)
