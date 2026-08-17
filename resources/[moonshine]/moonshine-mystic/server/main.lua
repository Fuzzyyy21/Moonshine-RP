--- Lebenszyklus der Profile, Essenzregeneration und Punktevergabe.

local MS = exports['moonshine-core']:GetCoreObject()

Mystic.RegisterStones()

--- Laedt das Profil eines Spielers, sobald sein Charakter im Spiel ist.
local function loadProfile(source, player)
    if not Mystic.DB.Ready then
        SetTimeout(3000, function() loadProfile(source, player) end)
        return
    end

    local row = Mystic.DB.Load(player.charId)
    local profile = Mystic.CreateProfile(source, player.charId, row)

    profile:Sync()
    TriggerEvent('mystic:server:profileLoaded', source, profile)

    if not profile.race and MysticConfig.Awakening.onlyAtRitualPoint then
        profile:Notify('Du bist noch nicht erweckt. Suche einen Ritualpunkt auf.', 'info')
    end
end

AddEventHandler('moonshine:server:playerLoaded', function(source, player)
    loadProfile(source, player)
end)

AddEventHandler('moonshine:server:playerDropped', function(source)
    local profile = Mystic.Profiles[source]
    if not profile then return end

    profile:Save()
    Mystic.Profiles[source] = nil
end)

AddEventHandler('moonshine:server:playerUnloaded', function(source)
    local profile = Mystic.Profiles[source]
    if not profile then return end

    profile:Save()
    Mystic.Profiles[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, profile in pairs(Mystic.Profiles) do
        profile:Save()
    end
end)

--- Der Client meldet sich nach einem Resource-Restart erneut an.
RegisterNetEvent('mystic:server:requestProfile', function()
    local source = source
    local profile = Mystic.Profiles[source]

    if profile then
        profile:Sync()
        return
    end

    local player = MS.GetPlayer(source)
    if player then loadProfile(source, player) end
end)

-- Essenzregeneration ---------------------------------------------------------

CreateThread(function()
    local interval = math.max(1, MysticConfig.Essence.tickInterval) * 1000

    while true do
        Wait(interval)

        local now = os.time()
        for _, profile in pairs(Mystic.Profiles) do
            if profile.race and now - profile.lastCast >= MysticConfig.Essence.lockAfterCast then
                local max = profile:GetMaxEssence()

                if profile.essence < max then
                    profile:SetEssence(profile.essence + profile:GetEssenceRegen())
                    TriggerClientEvent('mystic:client:essence', profile.source, math.floor(profile.essence), max)
                end
            end
        end
    end
end)

-- Punkte fuer Onlinezeit -----------------------------------------------------

CreateThread(function()
    local personalSeconds = math.max(1, MysticConfig.Points.minutesPerPersonalPoint) * 60
    local skillSeconds    = math.max(1, MysticConfig.Points.minutesPerSkillPoint) * 60

    while true do
        Wait(60000)

        for _, profile in pairs(Mystic.Profiles) do
            local before = profile.secondsPlayed
            profile.secondsPlayed = before + 60

            local gainedPersonal = math.floor(profile.secondsPlayed / personalSeconds)
                                 - math.floor(before / personalSeconds)
            local gainedSkill    = math.floor(profile.secondsPlayed / skillSeconds)
                                 - math.floor(before / skillSeconds)

            if gainedPersonal > 0 then
                profile:AddPersonalPoints(gainedPersonal)
                profile:Notify(('%d persoenliche(r) Punkt(e) erhalten.'):format(gainedPersonal), 'success')
            end

            if gainedSkill > 0 then
                profile:AddSkillPoints(gainedSkill)
                profile:Notify(('%d Skillpunkt(e) erhalten.'):format(gainedSkill), 'success')
            end

            if gainedPersonal > 0 or gainedSkill > 0 then
                profile:Sync()
            end
        end
    end
end)

-- Autosave -------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(5 * 60000)

        for _, profile in pairs(Mystic.Profiles) do
            profile:Save()
        end
    end
end)

-- Tod: laufende Effekte zuruecksetzen ---------------------------------------

AddEventHandler('moonshine:server:playerDeath', function(source)
    local profile = Mystic.Profiles[source]
    if not profile then return end

    profile:SetEssence(profile:GetMaxEssence() * 0.5)
    profile:Sync()
end)
