--- Uebertraegt Rassenwerte, passive Skills und Perks auf den Spieler.

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
        if Mystic.Profile and mods.stamina > 0 then
            local playerId = PlayerId()
            if IsPedSprinting(PlayerPedId()) then
                RestorePlayerStamina(playerId, math.min(1.0, mods.stamina / 100))
            end
        end
    end
end)

--- Fallschaden abfangen: Leben vor dem Sturz merken und nach der Landung
--- wiederherstellen.
CreateThread(function()
    local healthBeforeFall

    while true do
        local mods = Mystic.GetActiveModifiers()

        if Mystic.Profile and mods.noFallDamage then
            local ped = PlayerPedId()

            if IsPedFalling(ped) and not IsPedInAnyVehicle(ped, false) then
                healthBeforeFall = healthBeforeFall or GetEntityHealth(ped)
                SetPedCanRagdollFromPlayerImpact(ped, false)
            elseif healthBeforeFall then
                Wait(150)
                local current = GetEntityHealth(ped)

                if current > 0 and current < healthBeforeFall then
                    SetEntityHealth(ped, healthBeforeFall)
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

AddEventHandler('mystic:client:profileChanged', function()
    applyStats()
end)
