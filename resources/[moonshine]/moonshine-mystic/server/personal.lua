--- Persoenlicher Skillbaum: Knoten steigern und zuruecksetzen.
--- Bezahlt wird mit Faehigkeitspunkten aus Stufenaufstiegen.

local MS = exports['moonshine-core']:GetCoreObject()

RegisterNetEvent('mystic:server:upgradePersonal', function(nodeId)
    local source = source
    local profile = Mystic.Profiles[source]
    if not profile then return end

    local entry = Mystic.GetPersonalNode(nodeId)
    if not entry then return end

    local current   = profile:GetPersonalRank(nodeId)
    local nextRank  = current + 1
    local cost      = Mystic.GetPersonalCost(entry, nextRank)

    if not cost then
        profile:Notify(('%s ist bereits auf Maximalstufe.'):format(entry.label), 'warning')
        return
    end

    if not Mystic.MeetsPersonalRequirements(entry, profile.personal) then
        profile:Notify('Du musst zuerst die vorherige Faehigkeit lernen.', 'error')
        return
    end

    if not profile:SpendSkillPoints(cost) then
        profile:Notify(('Dir fehlen %d Faehigkeitspunkte.'):format(cost - profile.skillPoints), 'error')
        return
    end

    profile.personal[nodeId] = nextRank

    -- Groesserer Essenzvorrat wirkt sofort.
    profile:SetEssence(profile.essence)

    profile:Save()
    profile:Sync()
    profile:Notify(('%s auf Stufe %d.'):format(entry.label, nextRank), 'success')
    TriggerEvent('mystic:server:personalUpgraded', source, nodeId, nextRank)
end)

--- Setzt den persoenlichen Baum zurueck und erstattet alle Punkte.
RegisterNetEvent('mystic:server:resetPersonal', function()
    if not MS.RateLimit(source, 'mystic:reset', 3, 60) then return end
    local source = source
    local profile = Mystic.Profiles[source]
    local player  = MS.GetPlayer(source)
    if not profile or not player then return end

    local spent = profile:GetSpentSkillPoints()
    if spent == 0 then
        profile:Notify('Du hast noch nichts geskillt.', 'info')
        return
    end

    local cost = MysticConfig.Progression.resetCost

    if cost and cost.amount > 0 then
        if not player:RemoveMoney(cost.amount, cost.account, 'skillreset') then
            profile:Notify(('Das Zuruecksetzen kostet %s.'):format(
                MS.Utils.FormatMoney(cost.amount)), 'error')
            return
        end
    end

    profile.personal = {}
    profile:AddSkillPoints(spent)
    profile:SetEssence(profile.essence)

    profile:Save()
    profile:Sync()
    profile:Notify(('Zurueckgesetzt, %d Faehigkeitspunkte erstattet.'):format(spent), 'success')
    TriggerEvent('mystic:server:personalReset', source, spent)
end)
