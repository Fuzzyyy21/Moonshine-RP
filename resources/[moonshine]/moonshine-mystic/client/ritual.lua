--- Ritualpunkte: Marker, Oberflaeche und Meditation.

local MS = exports['moonshine-core']:GetCoreObject()

local uiOpen = false
local uiAtRitual = false
local meditating = false
local lastStones = {}

-- Oberflaechendaten ----------------------------------------------------------

--- Baut die Skilliste der eigenen Rasse fuer die Oberflaeche.
local function buildSkills(profile, stones)
    if not profile.race then return {} end

    local unlocked = {}
    for _, id in ipairs(profile.unlocked or {}) do unlocked[id] = true end

    local result = {}

    for _, skill in ipairs(Mystic.GetSkillsForRace(profile.race)) do
        local costs, affordable = {}, profile.skillPoints >= skill.unlock.points

        for item, count in pairs(skill.unlock.stones) do
            local have = stones[item] or 0
            if have < count then affordable = false end

            costs[#costs + 1] = {
                item  = item,
                label = Mystic.Stones[item] and Mystic.Stones[item].label or item,
                count = count,
                have  = have,
            }
        end

        table.sort(costs, function(a, b) return a.label < b.label end)

        result[#result + 1] = {
            id          = skill.id,
            label       = skill.label,
            icon        = skill.icon,
            tier        = skill.tier,
            description = skill.description,
            passive     = skill.passive or false,
            cooldown    = skill.cooldown,
            cost        = skill.cost,
            points      = skill.unlock.points,
            stones      = costs,
            requires    = skill.requires,
            unlocked    = unlocked[skill.id] or false,
            available   = Mystic.MeetsRequirements(skill, unlocked),
            affordable  = affordable,
        }
    end

    return result
end

--- Baut die Perkliste inklusive naechster Stufe und Kosten.
local function buildPerks(profile)
    local result = {}

    for _, perk in ipairs(Mystic.Perks) do
        local level = (profile.perks and profile.perks[perk.id]) or 0
        local nextCost = Mystic.GetPerkCost(perk, level + 1)

        result[#result + 1] = {
            id          = perk.id,
            label       = perk.label,
            icon        = perk.icon,
            description = perk.description,
            level       = level,
            maxLevel    = perk.maxLevel,
            nextCost    = nextCost,
            affordable  = nextCost ~= nil and profile.personalPoints >= nextCost,
        }
    end

    return result
end

local function buildBarSlots(profile)
    local slots = {}

    for slot = 1, MysticConfig.SkillBar.slots do
        local skillId = profile.skillbar and profile.skillbar[slot]
        local skill = skillId and Mystic.GetSkill(skillId) or nil

        slots[slot] = {
            slot  = slot,
            key   = MysticConfig.SkillBar.keys[slot] or tostring(slot),
            id    = skill and skill.id or nil,
            label = skill and skill.label or nil,
            icon  = skill and skill.icon or nil,
        }
    end

    return slots
end

local function openUi(payload, atRitual)
    local profile = payload.profile
    lastStones = payload.stones or {}

    local stoneList = {}
    for name, stone in pairs(Mystic.Stones) do
        stoneList[#stoneList + 1] = {
            name  = name,
            label = stone.label,
            count = lastStones[name] or 0,
        }
    end
    table.sort(stoneList, function(a, b) return a.label < b.label end)

    uiOpen = true
    uiAtRitual = atRitual
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'mysticRitual',
        data = {
            atRitual       = atRitual,
            race           = profile.race,
            raceLabel      = profile.raceLabel,
            raceIcon       = profile.raceIcon,
            raceColor      = profile.raceColor,
            essenceLabel   = profile.essenceLabel,
            races          = Mystic.GetRaceList(),
            skills         = buildSkills(profile, lastStones),
            perks          = buildPerks(profile),
            bar            = buildBarSlots(profile),
            stones         = stoneList,
            skillPoints    = profile.skillPoints,
            personalPoints = profile.personalPoints,
            canChangeRace  = payload.canChangeRace or false,
            meditation     = {
                enabled  = payload.canMeditate or false,
                left     = payload.meditationLeft or 0,
                duration = MysticConfig.Meditation.duration,
            },
        },
    })
end

RegisterNetEvent('mystic:client:openRitual', function(payload)
    openUi(payload, true)
end)

RegisterNetEvent('mystic:client:openOverview', function(profile)
    openUi({ profile = profile, stones = lastStones }, false)
end)

local function closeUi()
    if not uiOpen then return end

    uiOpen = false
    uiAtRitual = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'mysticRitualClose' })
end

--- Nach jeder Aktion die Daten neu holen, damit Punkte und Steine stimmen.
--- In der Uebersicht (/mystik) baut der Client die Ansicht selbst neu auf,
--- weil der Server dort keine Ritualdaten liefert.
local function refresh()
    if not uiOpen then return end

    if uiAtRitual then
        TriggerServerEvent('mystic:server:requestRitualData')
    elseif Mystic.Profile then
        openUi({ profile = Mystic.Profile, stones = lastStones }, false)
    end
end

AddEventHandler('mystic:client:profileChanged', function()
    if uiOpen then
        SetTimeout(150, refresh)
    end
end)

-- NUI-Callbacks --------------------------------------------------------------

RegisterNUICallback('mysticClose', function(_, cb)
    closeUi()
    cb('ok')
end)

RegisterNUICallback('mysticUnlock', function(data, cb)
    TriggerServerEvent('mystic:server:unlockSkill', data.id)
    cb('ok')
end)

RegisterNUICallback('mysticAwaken', function(data, cb)
    TriggerServerEvent('mystic:server:awaken', data.race)
    cb('ok')
end)

RegisterNUICallback('mysticUpgradePerk', function(data, cb)
    TriggerServerEvent('mystic:server:upgradePerk', data.id)
    cb('ok')
end)

RegisterNUICallback('mysticResetPerks', function(_, cb)
    TriggerServerEvent('mystic:server:resetPerks')
    cb('ok')
end)

RegisterNUICallback('mysticSetSlot', function(data, cb)
    TriggerServerEvent('mystic:server:setBarSlot', data.slot, data.id)
    cb('ok')
end)

RegisterNUICallback('mysticMeditate', function(_, cb)
    closeUi()
    TriggerServerEvent('mystic:server:meditate')
    cb('ok')
end)

-- Meditation -----------------------------------------------------------------

RegisterNetEvent('mystic:client:meditationStart', function(duration)
    if meditating then return end
    meditating = true

    local ped = PlayerPedId()
    local dict = 'amb@world_human_bum_slumped@male@laying_on_left_side@base'

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end

    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, 'base', 8.0, -8.0, duration * 1000, 1, 0.0, false, false, false)
    end

    MS.Notify('Du versenkst dich in Meditation.', 'info', 5000)

    CreateThread(function()
        local endTime = GetGameTimer() + duration * 1000

        while GetGameTimer() < endTime do
            local coords = GetEntityCoords(PlayerPedId())
            MS.DrawText3D(coords + vector3(0.0, 0.0, 1.1),
                ('Meditation ~y~%d s'):format(math.ceil((endTime - GetGameTimer()) / 1000)))
            Wait(0)
        end

        ClearPedTasks(PlayerPedId())
        meditating = false
    end)
end)

-- Marker und Blips -----------------------------------------------------------

CreateThread(function()
    if not MysticConfig.RitualBlip.enabled then return end

    for _, point in ipairs(MysticConfig.RitualPoints) do
        local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
        SetBlipSprite(blip, MysticConfig.RitualBlip.sprite)
        SetBlipColour(blip, MysticConfig.RitualBlip.color)
        SetBlipScale(blip, MysticConfig.RitualBlip.scale)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('%s (%s)'):format(MysticConfig.RitualBlip.label, point.label))
        EndTextCommandSetBlipName(blip)
    end
end)

CreateThread(function()
    while true do
        local sleep = 800

        if MS.IsPlayerLoaded and not uiOpen and not meditating then
            local coords = GetEntityCoords(PlayerPedId())

            for _, point in ipairs(MysticConfig.RitualPoints) do
                local distance = #(coords - point.coords)

                if distance < 25.0 then
                    sleep = 0
                    DrawMarker(25, point.coords.x, point.coords.y, point.coords.z - 0.9,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 2.2, 2.2,
                        150, 90, 220, 120, false, false, 2, false, nil, nil, false)

                    if distance < point.radius then
                        MS.DrawHelpText('Druecke ~INPUT_CONTEXT~ fuer das Ritual')

                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('mystic:server:requestRitualData')
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
