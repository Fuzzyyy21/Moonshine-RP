--- Persoenliche Skills: Stufen kaufen und zuruecksetzen.

RegisterNetEvent('mystic:server:upgradePerk', function(perkId)
    local source = source
    local profile = Mystic.Profiles[source]
    if not profile then return end

    local perk = Mystic.GetPerk(perkId)
    if not perk then return end

    local current   = profile.perks[perkId] or 0
    local nextLevel = current + 1
    local cost      = Mystic.GetPerkCost(perk, nextLevel)

    if not cost then
        profile:Notify(('%s ist bereits auf Maximalstufe.'):format(perk.label), 'warning')
        return
    end

    if profile.personalPoints < cost then
        profile:Notify(('Dir fehlen %d persoenliche Punkte.'):format(cost - profile.personalPoints), 'error')
        return
    end

    profile:AddPersonalPoints(-cost)
    profile.perks[perkId] = nextLevel

    -- Groesserer Essenzvorrat wirkt sofort.
    profile:SetEssence(profile.essence)

    profile:Save()
    profile:Sync()
    profile:Notify(('%s auf Stufe %d.'):format(perk.label, nextLevel), 'success')
    TriggerEvent('mystic:server:perkUpgraded', source, perkId, nextLevel)
end)

--- Setzt alle Perks zurueck und erstattet die Punkte.
RegisterNetEvent('mystic:server:resetPerks', function()
    local source = source
    local profile = Mystic.Profiles[source]
    if not profile then return end

    if not Mystic.IsNearRitualPoint(GetEntityCoords(GetPlayerPed(source))) then
        profile:Notify('Das geht nur an einem Ritualpunkt.', 'error')
        return
    end

    local refund = 0
    for perkId, level in pairs(profile.perks) do
        local perk = Mystic.GetPerk(perkId)
        if perk then
            for step = 1, level do
                refund = refund + (Mystic.GetPerkCost(perk, step) or 0)
            end
        end
    end

    if refund == 0 then
        profile:Notify('Du hast noch keine Perks gelernt.', 'info')
        return
    end

    profile.perks = {}
    profile:AddPersonalPoints(refund)
    profile:SetEssence(profile.essence)

    profile:Save()
    profile:Sync()
    profile:Notify(('Perks zurueckgesetzt, %d Punkte erstattet.'):format(refund), 'success')
end)
