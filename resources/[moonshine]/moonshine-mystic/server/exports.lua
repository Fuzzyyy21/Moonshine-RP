--- Oeffentliche API des Mystik-Systems.
---
---   local Mystic = exports['moonshine-mystic']:GetMysticObject()
---   local profile = Mystic.GetProfile(source)

exports('GetMysticObject', function()
    return Mystic
end)

exports('GetProfile', function(source)
    return Mystic.GetProfile(source)
end)

exports('GetRace', function(source)
    local profile = Mystic.GetProfile(source)
    return profile and profile.race or nil
end)

exports('IsRace', function(source, raceName)
    local profile = Mystic.GetProfile(source)
    return profile ~= nil and profile.race == raceName
end)

exports('HasSkill', function(source, skillId)
    local profile = Mystic.GetProfile(source)
    return profile ~= nil and profile:IsUnlocked(skillId)
end)

exports('GetModifiers', function(source)
    local profile = Mystic.GetProfile(source)
    return profile and profile:GetModifiers() or nil
end)

exports('AddSkillPoints', function(source, amount)
    local profile = Mystic.GetProfile(source)
    if not profile then return false end

    profile:AddSkillPoints(amount)
    profile:Sync()
    return true
end)

exports('AddPersonalPoints', function(source, amount)
    local profile = Mystic.GetProfile(source)
    if not profile then return false end

    profile:AddPersonalPoints(amount)
    profile:Sync()
    return true
end)

exports('AddEssence', function(source, amount)
    local profile = Mystic.GetProfile(source)
    if not profile then return false end

    profile:SetEssence(profile.essence + amount)
    profile:Sync()
    return true
end)

exports('SetRace', function(source, raceName)
    local profile = Mystic.GetProfile(source)
    if not profile or not Mystic.GetRace(raceName) then return false end

    profile.race = raceName
    profile:SetEssence(profile:GetMaxEssence())
    Mystic.DB.SetRace(profile.characterId, raceName)
    profile:Save()
    profile:Sync()

    TriggerClientEvent('mystic:client:awakened', source, raceName)
    return true
end)
