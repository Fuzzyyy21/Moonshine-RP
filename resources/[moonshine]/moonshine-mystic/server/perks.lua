--- Persoenlicher Skillbaum: Stufen mit Erfahrung kaufen und zuruecksetzen.
--- XP sind hier die einzige Waehrung; der Klassenbaum nutzt Klassensteine.

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

    if not profile:SpendXp(cost) then
        profile:Notify(('Dir fehlen %d XP.'):format(cost - profile.xp), 'error')
        return
    end

    profile.perks[perkId] = nextLevel

    -- Groesserer Essenzvorrat wirkt sofort.
    profile:SetEssence(profile.essence)

    profile:Save()
    profile:Sync()
    profile:Notify(('%s auf Stufe %d.'):format(perk.label, nextLevel), 'success')
    TriggerEvent('mystic:server:perkUpgraded', source, perkId, nextLevel)
end)

--- Setzt alle Perks zurueck und erstattet die ausgegebene Erfahrung.
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
        if perk then refund = refund + Mystic.GetSpentXp(perk, level) end
    end

    if refund == 0 then
        profile:Notify('Du hast noch keine persoenlichen Skills gelernt.', 'info')
        return
    end

    profile.perks = {}
    profile:RefundXp(refund)
    profile:SetEssence(profile.essence)

    profile:Save()
    profile:Sync()
    profile:Notify(('Zurueckgesetzt, %d XP erstattet.'):format(refund), 'success')
end)
