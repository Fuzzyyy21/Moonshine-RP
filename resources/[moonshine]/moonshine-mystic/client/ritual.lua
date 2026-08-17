--- Ritualpunkte: Marker, Skilltree-Oberflaeche und Meditation.

local MS = exports['moonshine-core']:GetCoreObject()

local uiOpen = false
local uiAtRitual = false
local meditating = false
local lastPayload = nil

-- Aufbereitung der Baumdaten -------------------------------------------------

--- Ein Knoten inklusive Stufen, Kosten und Sperren.
local function buildNode(skill, profile, level, stoneCount)
    local rank = (profile.ranks and profile.ranks[skill.id]) or 0
    local nextRank = rank + 1
    local price = Mystic.GetRankCost(skill, nextRank)

    local ranks = {}
    for step = 1, skill.maxRank do
        ranks[step] = {
            level   = step,
            text    = Mystic.DescribeRank(skill, step),
            owned   = step <= rank,
            current = step == nextRank,
        }
    end

    local requirementsMet = Mystic.MeetsRequirements(skill, profile.ranks or {})
    local levelMet = level >= (skill.level or 1)

    return {
        id          = skill.id,
        label       = skill.label,
        icon        = skill.icon,
        row         = skill.row,
        col         = skill.col,
        description = skill.description,
        passive     = skill.passive or false,
        rank        = rank,
        maxRank     = skill.maxRank,
        requires    = skill.requires,
        levelNeeded = skill.level or 1,

        maxed       = rank >= skill.maxRank,
        locked      = not requirementsMet or not levelMet,
        levelLocked = not levelMet,
        available   = requirementsMet and levelMet,
        affordable  = price ~= nil and stoneCount >= price,
        price       = price,

        essence     = Mystic.GetEssenceCost(skill, math.max(1, rank)),
        cooldown    = Mystic.GetCooldown(skill, math.max(1, rank)),
        ranks       = ranks,
    }
end

--- Verbindungslinien zwischen den Knoten.
local function buildLinks(skills)
    local links = {}

    for _, skill in ipairs(skills) do
        for _, requiredId in ipairs(skill.requires or {}) do
            links[#links + 1] = { from = requiredId, to = skill.id }
        end
    end

    return links
end

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

--- Klassenliste. Nach der ersten gelernten Faehigkeit bleibt nur die eigene
--- Klasse sichtbar.
local function buildClasses(profile)
    local list = {}

    if profile.canSwitchClass then
        for _, race in ipairs(Mystic.GetRaceList()) do
            race.current = race.name == profile.race
            list[#list + 1] = race
        end
        return list
    end

    local race = Mystic.GetRace(profile.race)
    if race then
        list[1] = {
            name        = profile.race,
            label       = race.label,
            icon        = race.icon,
            color       = race.color,
            description = race.description,
            traits      = race.traits,
            essence     = race.essence.label,
            current     = true,
        }
    end

    return list
end

local function openUi(payload)
    local profile = payload.profile
    lastPayload = payload

    local stoneCounts = payload.stones or {}
    local classStone = profile.classStone
    local stoneCount = classStone and (stoneCounts[classStone] or 0) or 0

    local skills = profile.race and Mystic.GetSkillsForRace(profile.race) or {}
    local nodes = {}
    for index, skill in ipairs(skills) do
        nodes[index] = buildNode(skill, profile, profile.level or 1, stoneCount)
    end

    local stoneList = {}
    for name, stone in pairs(Mystic.Stones) do
        stoneList[#stoneList + 1] = {
            name     = name,
            label    = stone.label,
            count    = stoneCounts[name] or 0,
            isClass  = name == classStone,
        }
    end
    table.sort(stoneList, function(a, b) return a.label < b.label end)

    local conversion = payload.conversion or MysticConfig.Stones.conversion
    local fromStone = Mystic.Stones[conversion.from]
    local race = profile.race and Mystic.GetRace(profile.race) or nil

    uiOpen = true
    uiAtRitual = payload.atRitual and true or false
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'mysticTree',
        data = {
            atRitual        = uiAtRitual,
            canSwitchClass  = profile.canSwitchClass,

            race            = profile.race,
            raceLabel       = profile.raceLabel,
            raceIcon        = profile.raceIcon,
            raceColor       = profile.raceColor,
            raceDescription = race and race.description or '',
            raceTraits      = race and race.traits or {},
            essenceLabel    = profile.essenceLabel,

            level           = profile.level,
            xpIntoLevel     = profile.xpIntoLevel,
            xpForNext       = profile.xpForNext,
            maxLevel        = MysticConfig.Progression.maxLevel,

            stone           = {
                name  = classStone,
                label = profile.classStoneLabel,
                count = stoneCount,
            },
            conversion      = {
                from      = conversion.from,
                fromLabel = fromStone and fromStone.label or conversion.from,
                amount    = conversion.amount,
                result    = conversion.result,
            },

            personalPoints  = profile.personalPoints,
            nodes           = nodes,
            links           = buildLinks(skills),
            classes         = buildClasses(profile),
            perks           = buildPerks(profile),
            bar             = buildBarSlots(profile),
            stones          = stoneList,
            meditation      = {
                enabled  = payload.canMeditate or false,
                left     = payload.meditationLeft or 0,
                duration = MysticConfig.Meditation.duration,
            },
        },
    })
end

RegisterNetEvent('mystic:client:openRitual', function(payload)
    openUi(payload)
end)

RegisterNetEvent('mystic:client:refreshRitual', function()
    if uiOpen then TriggerServerEvent('mystic:server:requestRitualData') end
end)

local function closeUi()
    if not uiOpen then return end

    uiOpen = false
    uiAtRitual = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'mysticTreeClose' })
end

--- Nach jeder Aktion die Daten frisch vom Server holen.
AddEventHandler('mystic:client:profileChanged', function()
    if not uiOpen then return end
    SetTimeout(150, function()
        if uiOpen then TriggerServerEvent('mystic:server:requestRitualData') end
    end)
end)

-- NUI-Callbacks --------------------------------------------------------------

RegisterNUICallback('mysticClose', function(_, cb)
    closeUi()
    cb('ok')
end)

RegisterNUICallback('mysticUpgrade', function(data, cb)
    TriggerServerEvent('mystic:server:upgradeSkill', data.id)
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

RegisterNUICallback('mysticConvert', function(data, cb)
    TriggerServerEvent('mystic:server:convertStones', data.times or 1)
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
