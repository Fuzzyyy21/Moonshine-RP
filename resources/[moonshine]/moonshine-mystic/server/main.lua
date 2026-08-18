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

    if not profile.race then
        profile:Notify('Du bist noch nicht erweckt. Suche einen Ritualpunkt auf.', 'info')
    elseif profile:CanSwitchClass() then
        profile:Notify('Deine Klasse ist noch frei waehlbar, bis du die erste Faehigkeit lernst.', 'info', 8000)
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

-- Onlinezeit: Erfahrung fuer den persoenlichen Baum --------------------------

CreateThread(function()
    while true do
        Wait(60000)

        for _, profile in pairs(Mystic.Profiles) do
            profile.secondsPlayed = profile.secondsPlayed + 60

            -- XP gibt es unabhaengig von der Klasse, sie zaehlen nur fuer
            -- den persoenlichen Skillbaum.
            if MysticConfig.Progression.xpPerMinute > 0 then
                profile:AddXp(MysticConfig.Progression.xpPerMinute)
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

-- Welt: Mondphase und Ereignisse aendern die Werte aller Spieler -------------

--- Schickt allen Profilen frische Modifikatoren.
local function resyncAll(reason)
    for _, profile in pairs(Mystic.Profiles) do
        profile:Sync()
    end

    if reason and MysticConfig.Debug then
        MS.Utils.Print('info', 'Modifikatoren neu berechnet (%s).', reason)
    end
end

AddEventHandler('world:server:eventStarted', function(id)
    resyncAll(('Ereignis %s'):format(tostring(id)))
end)

AddEventHandler('world:server:eventEnded', function(id)
    resyncAll(('Ereignis %s beendet'):format(tostring(id)))
end)

AddEventHandler('world:server:phaseChanged', function(id)
    resyncAll(('Mondphase %s'):format(tostring(id)))
end)
