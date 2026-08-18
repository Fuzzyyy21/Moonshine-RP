--- Uebertraegt Klassenwerte, passive Skills und den persoenlichen Baum
--- auf den Spieler.

local MS = exports['moonshine-core']:GetCoreObject()

local lastPed = 0

--- Wendet alle dauerhaften Werte auf den aktuellen Ped an.
local function applyStats()
    -- Waehrend einer Verwandlung gelten die Werte der Gestalt.
    if Mystic.IsTransformed and Mystic.IsTransformed() then return end

    local ped = PlayerPedId()
    local playerId = PlayerId()
    local mods = Mystic.GetActiveModifiers()

    -- Maximale Lebenspunkte (Basis des Spielers ist 200).
    local maxHealth = math.max(100, 200 + math.floor(mods.healthBonus))
    if GetEntityMaxHealth(ped) ~= maxHealth then
        SetEntityMaxHealth(ped, maxHealth)
        SetPedMaxHealth(ped, maxHealth)

        if GetEntityHealth(ped) > maxHealth then
            SetEntityHealth(ped, maxHealth)
        end
    end

    SetPlayerWeaponDamageModifier(playerId, mods.damageMult)
    SetPlayerMeleeWeaponDamageModifier(playerId, mods.meleeMult)
    SetPedMoveRateOverride(ped, mods.speedMult)

    -- Schadensreduktion wirkt ueber die Verteidigungsmodifikatoren.
    local defense = math.max(0.4, 1.0 - (mods.damageReduction or 0))
    SetPlayerWeaponDefenseModifier(playerId, defense)
    SetPlayerMeleeWeaponDefenseModifier(playerId, defense)

    -- Sprint und Schwimmen (Spiel begrenzt beides auf 1.49).
    SetRunSprintMultiplierForPlayer(playerId, math.min(1.49, 1.0 + (mods.sprintMult or 0)))
    SetSwimMultiplierForPlayer(playerId, math.min(1.49, 1.0 + (mods.swimMult or 0)))

    if (mods.breath or 0) > 0 then
        SetPedMaxTimeUnderwater(ped, 20.0 * (1.0 + mods.breath / 100))
    end

    if mods.noFallDamage then
        SetPedCanRagdollFromPlayerImpact(ped, false)
    end
end

CreateThread(function()
    while true do
        Wait(1000)

        if Mystic.Profile then
            applyStats()

            -- Nach einem Respawn ist der Ped neu und braucht die Werte erneut.
            local ped = PlayerPedId()
            if ped ~= lastPed then
                lastPed = ped

                local mods = Mystic.GetActiveModifiers()
                if mods.armorBonus > 0 and GetPedArmour(ped) < mods.armorBonus then
                    SetPedArmour(ped, math.floor(mods.armorBonus))
                end
            end
        end
    end
end)

--- Ausdauer: haelt den Sprint laenger aufrecht.
CreateThread(function()
    while true do
        Wait(3000)

        local mods = Mystic.GetActiveModifiers()
        if Mystic.Profile and (mods.stamina or 0) > 0 then
            if IsPedSprinting(PlayerPedId()) then
                RestorePlayerStamina(PlayerId(), math.min(1.0, mods.stamina / 100))
            end
        end
    end
end)

--- Hoehere Sprungkraft.
CreateThread(function()
    while true do
        local mods = Mystic.GetActiveModifiers()

        if Mystic.Profile and (mods.jumpBonus or 0) >= 0.3 then
            -- Erst ab einem deutlichen Bonus lohnt sich der Supersprung.
            SetSuperJumpThisFrame(PlayerId())
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

--- Fallschaden abfangen: Leben vor dem Sturz merken und anteilig
--- wiederherstellen.
CreateThread(function()
    local healthBeforeFall

    while true do
        local mods = Mystic.GetActiveModifiers()
        local reduction = mods.noFallDamage and 1.0 or (mods.fallReduction or 0)

        if Mystic.Profile and reduction > 0 then
            local ped = PlayerPedId()

            if IsPedFalling(ped) and not IsPedInAnyVehicle(ped, false) then
                healthBeforeFall = healthBeforeFall or GetEntityHealth(ped)
                if reduction >= 1.0 then
                    SetPedCanRagdollFromPlayerImpact(ped, false)
                end
            elseif healthBeforeFall then
                Wait(150)
                local current = GetEntityHealth(ped)

                if current > 0 and current < healthBeforeFall then
                    local lost = healthBeforeFall - current
                    SetEntityHealth(ped, math.min(healthBeforeFall,
                        current + math.floor(lost * reduction)))
                end
                healthBeforeFall = nil
            end

            Wait(100)
        else
            healthBeforeFall = nil
            Wait(1000)
        end
    end
end)

--- Standfestigkeit: schneller wieder auf die Beine.
CreateThread(function()
    while true do
        Wait(500)

        local mods = Mystic.GetActiveModifiers()
        if Mystic.Profile and (mods.ragdollResist or 0) > 0 then
            local ped = PlayerPedId()

            if IsPedRagdoll(ped) and math.random() < mods.ragdollResist then
                ClearPedTasksImmediately(ped)
            end
        end
    end
end)

-- Lebensraub und kritische Treffer -------------------------------------------

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    if not Mystic.Profile then return end

    local victim   = args[1]
    local attacker = args[2]
    local ped = PlayerPedId()

    if attacker ~= ped or victim == ped then return end
    if not DoesEntityExist(victim) then return end

    local mods = Mystic.GetActiveModifiers()

    -- Lebensraub im Nahkampf.
    if (mods.lifesteal or 0) > 0 and IsPedInMeleeCombat(ped) then
        local maxHealth = GetEntityMaxHealth(ped)
        local heal = math.max(1, math.floor(20 * mods.lifesteal))
        SetEntityHealth(ped, math.min(maxHealth, GetEntityHealth(ped) + heal))
    end

    -- Kritische Treffer wirken nur gegen Nicht-Spieler, damit der Schaden
    -- an Spielern serverseitig kontrolliert bleibt.
    if (mods.critChance or 0) > 0 and not IsPedAPlayer(victim) then
        if math.random() < mods.critChance then
            local bonus = math.max(5, math.floor(40 * (mods.critBonus or 0.25)))
            SetEntityHealth(victim, math.max(0, GetEntityHealth(victim) - bonus))
            PlaySoundFrontend(-1, 'Hit', 'RESPAWN_ONLINE_SOUNDSET', true)
        end
    end
end)

AddEventHandler('mystic:client:profileChanged', function()
    applyStats()
end)
