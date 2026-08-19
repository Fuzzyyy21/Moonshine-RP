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

exports('GetSkillRank', function(source, skillId)
    local profile = Mystic.GetProfile(source)
    return profile and profile:GetRank(skillId) or 0
end)

--- Klassenstufe = Anzahl der im Klassenbaum gekauften Stufen.
exports('GetLevel', function(source)
    local profile = Mystic.GetProfile(source)
    return profile and profile:GetLevel() or 0
end)

--- Persoenliche Stufe aus der gesamten verdienten Erfahrung.
exports('GetPersonalLevel', function(source)
    local profile = Mystic.GetProfile(source)
    if not profile then return 0 end

    local level = profile:GetPersonalProgress()
    return level
end)

exports('AddXp', function(source, amount)
    local profile = Mystic.GetProfile(source)
    if not profile then return false end

    profile:AddXp(amount)
    profile:Sync()
    return true
end)

--- Rechnet die Werte neu und schickt sie an den Client. Braucht jede
--- Resource, die von aussen etwas veraendert hat (Weltereignis, Beduerfnis).
exports('RefreshModifiers', function(source)
    local profile = Mystic.GetProfile(source)
    if not profile then return false end

    profile:Sync()
    return true
end)

exports('GetModifiers', function(source)
    local profile = Mystic.GetProfile(source)
    return profile and profile:GetModifiers() or nil
end)

exports('GetMeditationPoints', function(source)
    local profile = Mystic.GetProfile(source)
    return profile and profile.meditationPoints or 0
end)

exports('AddMeditationPoints', function(source, amount)
    local profile = Mystic.GetProfile(source)
    if not profile then return false end

    profile:AddMeditationPoints(amount)
    profile:Sync()
    return true
end)

exports('SpendMeditationPoints', function(source, amount)
    local profile = Mystic.GetProfile(source)
    if not profile or not profile:SpendMeditationPoints(amount) then return false end

    profile:Sync()
    return true
end)

exports('GetXp', function(source)
    local profile = Mystic.GetProfile(source)
    return profile and profile.xp or 0
end)

exports('SpendXp', function(source, amount)
    local profile = Mystic.GetProfile(source)
    if not profile or not profile:SpendXp(amount) then return false end

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
