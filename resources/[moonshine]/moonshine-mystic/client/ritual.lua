--- Ritualpunkte: Marker, Skilltree-Oberflaeche, Meditation und Rituale.

local MS = exports['moonshine-core']:GetCoreObject()

local uiOpen = false
local uiAtRitual = false
local channeling = false

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

--- Kategorien des persoenlichen Baums mit Fortschritt.
local function buildCategories(profile)
    local ranks = profile.personal or {}
    local result = {}

    for _, category in ipairs(Mystic.PersonalCategories) do
        local spent = 0
        for nodeId, rank in pairs(ranks) do
            local entry = Mystic.GetPersonalNode(nodeId)
            if entry and entry.category == category.id then spent = spent + rank end
        end

        result[#result + 1] = {
            id          = category.id,
            label       = category.label,
            icon        = category.icon,
            color       = category.color,
            motto       = category.motto,
            description = category.description,
            spent       = spent,
            max         = Mystic.GetCategoryMaxRanks(category.id),
        }
    end

    return result
end

--- Knoten einer Kategorie inklusive Stufen und Kosten.
local function buildPersonalNodes(profile, categoryId)
    local ranks = profile.personal or {}
    local points = profile.skillPoints or 0
    local result = {}

    for _, entry in ipairs(Mystic.GetPersonalNodesFor(categoryId)) do
        local rank = ranks[entry.id] or 0
        local nextRank = rank + 1
        local cost = Mystic.GetPersonalCost(entry, nextRank)

        local steps = {}
        for step = 1, entry.maxRank do
            steps[step] = {
                level   = step,
                text    = Mystic.DescribePersonalRank(entry, step),
                owned   = step <= rank,
                current = step == nextRank,
            }
        end

        local requirementsMet = Mystic.MeetsPersonalRequirements(entry, ranks)

        result[#result + 1] = {
            id          = entry.id,
            label       = entry.label,
            icon        = entry.icon,
            row         = entry.row,
            col         = entry.col,
            description = entry.description,
            rank        = rank,
            maxRank     = entry.maxRank,
            requires    = entry.requires,

            maxed       = rank >= entry.maxRank,
            locked      = not requirementsMet,
            available   = requirementsMet,
            affordable  = cost ~= nil and points >= cost,
            price       = cost,

            currentText = rank > 0 and Mystic.DescribePersonalRank(entry, rank) or nil,
            ranks       = steps,
        }
    end

    return result
end

--- Verbindungen im persoenlichen Baum.
local function buildPersonalLinks(categoryId)
    local links = {}

    for _, entry in ipairs(Mystic.GetPersonalNodesFor(categoryId)) do
        for _, requiredId in ipairs(entry.requires or {}) do
            links[#links + 1] = { from = requiredId, to = entry.id }
        end
    end

    return links
end

--- Zusammenfassung aller Boni fuer das Statistikfeld.
local function buildStatistics(profile)
    local totals = Mystic.SumPersonal(profile.personal or {})
    local rows = {}

    local function add(icon, label, text)
        rows[#rows + 1] = { icon = icon, label = label, value = text }
    end

    local function percent(value) return math.floor(value * 100 + 0.5) end

    if totals.healthBonus > 0     then add('❤', 'Max. Leben', ('+%d'):format(totals.healthBonus)) end
    if totals.regenPerTick > 0    then add('➕', 'Regeneration', ('+%d / 5 s'):format(totals.regenPerTick)) end
    if totals.damageReduction > 0 then add('🛡', 'Schadensreduktion', ('%d%%'):format(percent(totals.damageReduction))) end
    if totals.armorBonus > 0      then add('🦺', 'Weste', ('+%d'):format(totals.armorBonus)) end
    if totals.damageMult > 0      then add('🔫', 'Waffenschaden', ('+%d%%'):format(percent(totals.damageMult))) end
    if totals.meleeMult > 0       then add('👊', 'Nahkampf', ('+%d%%'):format(percent(totals.meleeMult))) end
    if totals.critChance > 0      then add('💥', 'Kritische Chance', ('%d%%'):format(percent(totals.critChance))) end
    if totals.stamina > 0         then add('⚡', 'Ausdauer', ('+%d%%'):format(totals.stamina)) end
    if totals.speedMult > 0       then add('🏃', 'Tempo', ('+%d%%'):format(percent(totals.speedMult))) end
    if totals.essenceBonus > 0    then add('🔵', 'Max. Essenz', ('+%d'):format(totals.essenceBonus)) end
    if totals.cooldownMult < 0    then add('⏱', 'Abklingzeit', ('%d%%'):format(percent(totals.cooldownMult))) end
    if totals.xpBonus > 0         then add('📘', 'Erfahrung', ('+%d%%'):format(percent(totals.xpBonus))) end
    if totals.lootChance > 0      then add('🍀', 'Extrabeute', ('%d%%'):format(percent(totals.lootChance))) end
    if totals.moneyBonus > 0      then add('💰', 'Ritualgeld', ('+%d%%'):format(percent(totals.moneyBonus))) end

    return rows
end

--- Segen mit Bezahlbarkeit.
local function buildBlessings(profile)
    if not MysticConfig.Blessings.enabled then return {} end

    local points = profile.meditationPoints or 0
    local result = {}

    for _, entry in ipairs(MysticConfig.Blessings.list) do
        result[#result + 1] = {
            id          = entry.id,
            label       = entry.label,
            icon        = entry.icon,
            cost        = entry.cost,
            description = entry.description,
            affordable  = points >= entry.cost,
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

    -- Rezept fuer den Klassenstein aufbereiten.
    local recipe = payload.recipe or MysticConfig.Stones.recipe
    local ingredients = {}

    for item, count in pairs(recipe) do
        if item ~= 'result' then
            local stone = Mystic.Stones[item]
            ingredients[#ingredients + 1] = {
                item  = item,
                label = stone and stone.label or item,
                need  = count,
                have  = stoneCounts[item] or 0,
            }
        end
    end
    table.sort(ingredients, function(a, b) return a.label < b.label end)

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

            -- Klassenbaum: Stufe = gekaufte Stufen, bezahlt mit Steinen
            level           = profile.level,
            maxRanks        = profile.maxRanks,

            -- Persoenlicher Baum: Erfahrung
            xp              = profile.xp,
            personalLevel   = profile.personalLevel,
            xpIntoLevel     = profile.xpIntoLevel,
            xpForNext       = profile.xpForNext,
            maxLevel        = MysticConfig.Progression.maxLevel,

            stone           = {
                name  = classStone,
                label = profile.classStoneLabel,
                count = stoneCount,
            },
            recipe          = {
                ingredients = ingredients,
                result      = recipe.result or 1,
                craftable   = payload.craftable or 0,
            },

            nodes           = nodes,
            links           = buildLinks(skills),
            classes         = buildClasses(profile),
            bar             = buildBarSlots(profile),
            stones          = stoneList,
            meditation      = {
                enabled  = payload.canMeditate or false,
                left     = payload.meditationLeft or 0,
                duration = MysticConfig.Meditation.duration,
                points   = MysticConfig.Meditation.points,
            },
            ritual          = {
                enabled  = (payload.ritual or MysticConfig.Ritual).enabled,
                left     = payload.ritualLeft or 0,
                duration = (payload.ritual or MysticConfig.Ritual).duration,
                reward   = (payload.ritual or MysticConfig.Ritual).reward.amount,
                cost     = (payload.ritual or MysticConfig.Ritual).costPoints or 0,
            },
            blessings       = buildBlessings(profile),

            -- Persoenlicher Baum
            categories      = buildCategories(profile),
            personalNodes   = (function()
                local nodes, links = {}, {}
                for _, category in ipairs(Mystic.PersonalCategories) do
                    nodes[category.id] = buildPersonalNodes(profile, category.id)
                    links[category.id] = buildPersonalLinks(category.id)
                end
                return { nodes = nodes, links = links }
            end)(),
            statistics      = buildStatistics(profile),
            skillPoints     = profile.skillPoints or 0,
            spentPoints     = profile.spentPoints or 0,
            resetCost       = MysticConfig.Progression.resetCost,
            meditationPoints = profile.meditationPoints or 0,
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

RegisterNUICallback('mysticUpgradePersonal', function(data, cb)
    TriggerServerEvent('mystic:server:upgradePersonal', data.id)
    cb('ok')
end)

RegisterNUICallback('mysticResetPersonal', function(_, cb)
    TriggerServerEvent('mystic:server:resetPersonal')
    cb('ok')
end)

RegisterNUICallback('mysticSetSlot', function(data, cb)
    TriggerServerEvent('mystic:server:setBarSlot', data.slot, data.id)
    cb('ok')
end)

RegisterNUICallback('mysticCraft', function(data, cb)
    TriggerServerEvent('mystic:server:craftStone', data.times or 1)
    cb('ok')
end)

RegisterNUICallback('mysticMeditate', function(_, cb)
    closeUi()
    TriggerServerEvent('mystic:server:meditate')
    cb('ok')
end)

RegisterNUICallback('mysticRitual', function(_, cb)
    closeUi()
    TriggerServerEvent('mystic:server:performRitual')
    cb('ok')
end)

RegisterNUICallback('mysticBlessing', function(data, cb)
    TriggerServerEvent('mystic:server:useBlessing', data.id)
    cb('ok')
end)

-- Kanalisieren: Meditation und Ritual ----------------------------------------

local CHANNEL_ANIMS = {
    meditation = { dict = 'amb@world_human_bum_slumped@male@laying_on_left_side@base', anim = 'base' },
    ritual     = { dict = 'amb@world_human_bum_standing@blowing@base',                 anim = 'base' },
}

RegisterNetEvent('mystic:client:channelStart', function(data)
    if channeling then return end
    channeling = true

    local ped = PlayerPedId()
    local animation = CHANNEL_ANIMS[data.kind] or CHANNEL_ANIMS.meditation

    RequestAnimDict(animation.dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(animation.dict) and GetGameTimer() < timeout do Wait(10) end

    if HasAnimDictLoaded(animation.dict) then
        TaskPlayAnim(ped, animation.dict, animation.anim, 8.0, -8.0,
            data.duration * 1000, 1, 0.0, false, false, false)
    end

    MS.Notify(('%s begonnen.'):format(data.label or 'Handlung'), 'info', 5000)

    CreateThread(function()
        local endTime = GetGameTimer() + data.duration * 1000

        while GetGameTimer() < endTime do
            local coords = GetEntityCoords(PlayerPedId())
            MS.DrawText3D(coords + vector3(0.0, 0.0, 1.1),
                ('%s ~y~%d s'):format(data.label or '', math.ceil((endTime - GetGameTimer()) / 1000)))
            Wait(0)
        end

        ClearPedTasks(PlayerPedId())
        channeling = false
    end)
end)

--- Segen wirken lassen.
RegisterNetEvent('mystic:client:blessing', function(blessing)
    local ped = PlayerPedId()

    if blessing.kind == 'heal' then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        ClearPedBloodDamage(ped)
        Mystic.Effects.slow = nil
        ClearTimecycleModifier()

    elseif blessing.kind == 'buff' then
        Mystic.Buffs['blessing_' .. blessing.id] = {
            expires    = GetGameTimer() + (blessing.duration or 60) * 1000,
            damageMult = blessing.damageMult,
            meleeMult  = blessing.meleeMult,
            speedMult  = blessing.speedMult,
        }

        if blessing.armor then
            SetPedArmour(ped, math.max(GetPedArmour(ped), blessing.armor))
        end
    end

    AnimpostfxPlay('HeistCelebPass', 2000, false)
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

        if MS.IsPlayerLoaded and not uiOpen and not channeling then
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
