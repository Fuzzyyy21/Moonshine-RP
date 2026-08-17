--- Spielerische Auswirkungen von Hunger und Durst.

if not Config.Status.enabled then return end

local effectActive = false

local function lowestStatus()
    local metadata = MS.PlayerData.metadata
    if not metadata then return 100 end
    return math.min(metadata.hunger or 100, metadata.thirst or 100)
end

CreateThread(function()
    while true do
        Wait(2000)

        if MS.IsPlayerLoaded then
            local value = lowestStatus()

            if value <= 10 then
                if not effectActive then
                    StartScreenEffect('DeathFailOut', 0, true)
                    effectActive = true
                end
                -- Ausdauer sinkt schneller
                RestorePlayerStamina(PlayerId(), 0.1)
            elseif effectActive then
                StopScreenEffect('DeathFailOut')
                effectActive = false
            end
        elseif effectActive then
            StopScreenEffect('DeathFailOut')
            effectActive = false
        end
    end
end)

RegisterNetEvent('moonshine:client:statusChanged', function(name, value)
    if MS.PlayerData.metadata then
        MS.PlayerData.metadata[name] = value
    end
end)
