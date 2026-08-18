--- Weltbosse auf dem Client: KI, Anzeige und Trefferrueckmeldung.

local MS = exports['moonshine-core']:GetCoreObject()

local boss = nil    -- { netId, entity, name, maxHealth, blipHandle }
local prepared = false

-- Feindschaft ----------------------------------------------------------------

local BOSS_GROUP = `MYSTIC_BOSS`

CreateThread(function()
    AddRelationshipGroup('MYSTIC_BOSS')
    SetRelationshipBetweenGroups(5, BOSS_GROUP, `PLAYER`)
    SetRelationshipBetweenGroups(5, `PLAYER`, BOSS_GROUP)
end)

-- Spawn und Despawn ----------------------------------------------------------

local function resolveEntity()
    if not boss then return nil end

    if boss.entity and DoesEntityExist(boss.entity) then return boss.entity end
    if not NetworkDoesNetworkIdExist(boss.netId) then return nil end

    boss.entity = NetworkGetEntityFromNetworkId(boss.netId)
    return DoesEntityExist(boss.entity) and boss.entity or nil
end

RegisterNetEvent('boss:client:spawn', function(data)
    boss = {
        netId     = data.netId,
        name      = data.name,
        maxHealth = data.health,
        coords    = data.coords,
    }
    prepared = false

    if data.showBlip then
        local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
        SetBlipSprite(blip, data.blip and data.blip.sprite or 303)
        SetBlipColour(blip, data.blip and data.blip.color or 1)
        SetBlipScale(blip, 1.2)
        SetBlipFlashes(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(data.name)
        EndTextCommandSetBlipName(blip)

        boss.blipHandle = blip
    end

    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', true)
end)

RegisterNetEvent('boss:client:defeated', function()
    if not boss then return end

    MS.Notify(('%s wurde besiegt.'):format(boss.name), 'success', 8000)
end)

RegisterNetEvent('boss:client:despawn', function()
    if boss and boss.blipHandle and DoesBlipExist(boss.blipHandle) then
        RemoveBlip(boss.blipHandle)
    end
    boss = nil
    prepared = false
end)

-- Kampfverhalten -------------------------------------------------------------

--- Wer die Kontrolle ueber den Ped hat, gibt ihm Werte und Kampfauftrag.
local function prepare(entity)
    local state = Entity(entity).state.mysticBoss
    if not state then return end

    SetEntityMaxHealth(entity, state.health)
    SetEntityHealth(entity, state.health)
    if state.armour and state.armour > 0 then
        SetPedArmour(entity, state.armour)
    end

    if state.weapon then
        GiveWeaponToPed(entity, joaat(state.weapon), 500, false, true)
    end

    SetPedAccuracy(entity, state.accuracy or 60)
    SetPedRelationshipGroupHash(entity, BOSS_GROUP)
    SetPedFleeAttributes(entity, 0, false)
    SetPedCombatAttributes(entity, 46, true)    -- kaempft immer
    SetPedCombatAttributes(entity, 5, true)     -- nutzt Deckung nicht dauernd
    SetPedCombatRange(entity, 2)
    SetPedCombatMovement(entity, 3)             -- geht nach vorn
    SetPedSeeingRange(entity, 120.0)
    SetPedHearingRange(entity, 150.0)
    SetPedSuffersCriticalHits(entity, false)
    SetPedDiesWhenInjured(entity, false)
    SetPedCanRagdollFromPlayerImpact(entity, false)

    prepared = true
end

CreateThread(function()
    while true do
        local sleep = 1000

        if boss then
            local entity = resolveEntity()

            if entity then
                if NetworkHasControlOfEntity(entity) then
                    if not prepared then prepare(entity) end

                    -- Immer den naechsten Spieler angreifen.
                    if not IsPedInCombat(entity, PlayerPedId()) then
                        local target = GetClosestPlayerPed(entity)
                        if target then
                            TaskCombatPed(entity, target, 0, 16)
                        end
                    end
                end

                sleep = 2000
            end
        end

        Wait(sleep)
    end
end)

--- Naechster Spieler-Ped zu einer Entitaet.
function GetClosestPlayerPed(entity)
    local coords = GetEntityCoords(entity)
    local best, bestDistance = nil, 120.0

    for _, index in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(index)

        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            local distance = #(coords - GetEntityCoords(ped))
            if distance < bestDistance then
                best, bestDistance = ped, distance
            end
        end
    end

    return best
end

-- Treffer melden -------------------------------------------------------------

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or not boss then return end

    local victim   = args[1]
    local attacker = args[2]
    local entity   = resolveEntity()

    if entity and victim == entity and attacker == PlayerPedId() then
        TriggerServerEvent('boss:server:hit')
    end
end)

-- Lebensbalken ---------------------------------------------------------------

local function drawHealthBar(entity)
    local health = math.max(0, GetEntityHealth(entity))
    local progress = boss.maxHealth > 0 and math.min(1.0, health / boss.maxHealth) or 0

    local width, height = 0.26, 0.024
    local x, y = 0.5, 0.09

    DrawRect(x, y, width + 0.008, height + 0.01, 0, 0, 0, 190)
    DrawRect(x - width / 2 + (width * progress) / 2, y, width * progress, height, 170, 40, 40, 235)

    SetTextFont(4)
    SetTextScale(0.42, 0.42)
    SetTextColour(240, 235, 235, 230)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(('%s   %d / %d'):format(boss.name, health, boss.maxHealth))
    DrawText(x, y - 0.042)
end

CreateThread(function()
    while true do
        local sleep = 800

        if boss and BossConfig.ShowHealthBar then
            local entity = resolveEntity()

            if entity then
                local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(entity))

                if distance < BossConfig.HealthBarRange then
                    sleep = 0
                    drawHealthBar(entity)
                end
            end
        end

        Wait(sleep)
    end
end)
