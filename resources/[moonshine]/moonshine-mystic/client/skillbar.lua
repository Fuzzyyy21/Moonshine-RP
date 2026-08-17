--- Ausklappbare Skillleiste inklusive Tastenbelegung.

local MS = exports['moonshine-core']:GetCoreObject()

local barVisible = false

--- Baut die Anzeigedaten der Leiste aus dem Profil.
local function buildBar()
    local profile = Mystic.Profile
    local slots = {}

    for slot = 1, MysticConfig.SkillBar.slots do
        local skillId = profile and profile.skillbar and profile.skillbar[slot]
        local skill = skillId and Mystic.GetSkill(skillId) or nil

        slots[slot] = {
            slot     = slot,
            key      = MysticConfig.SkillBar.keys[slot] or tostring(slot),
            id       = skill and skill.id or nil,
            label    = skill and skill.label or nil,
            icon     = skill and skill.icon or nil,
            cost     = skill and skill.cost or 0,
            cooldown = skill and profile.cooldowns and profile.cooldowns[skill.id] or 0,
        }
    end

    local race = profile and profile.race and Mystic.GetRace(profile.race) or nil

    return {
        visible      = barVisible,
        slots        = slots,
        essence      = profile and profile.essence or 0,
        maxEssence   = profile and profile.maxEssence or 0,
        essenceLabel = profile and profile.essenceLabel or 'Essenz',
        raceLabel    = race and race.label or nil,
        raceIcon     = race and race.icon or nil,
        raceColor    = race and race.color or nil,
    }
end

local function pushBar()
    SendNUIMessage({ action = 'mysticBar', data = buildBar() })
end

function Mystic.SetBarVisible(visible)
    barVisible = visible
    pushBar()
end

-- Tastenbelegung -------------------------------------------------------------

RegisterCommand('skillleiste', function()
    if not Mystic.Profile or not Mystic.Profile.race then
        MS.Notify('Du bist noch nicht erweckt.', 'error')
        return
    end

    Mystic.SetBarVisible(not barVisible)
end, false)

RegisterKeyMapping('skillleiste', 'Skillleiste aus-/einklappen', 'keyboard', MysticConfig.SkillBar.toggleKey)

for slot = 1, MysticConfig.SkillBar.slots do
    local command = 'mysticslot' .. slot

    RegisterCommand(command, function()
        if not Mystic.Profile or not Mystic.Profile.race then return end

        if MysticConfig.SkillBar.requireVisible and not barVisible then
            MS.Notify(('Skillleiste ist eingeklappt (%s).'):format(MysticConfig.SkillBar.toggleKey), 'warning', 3000)
            return
        end

        local skillId = Mystic.Profile.skillbar and Mystic.Profile.skillbar[slot]
        if not skillId then
            MS.Notify(('Slot %d ist leer.'):format(slot), 'warning', 3000)
            return
        end

        Mystic.UseSkill(skillId)
    end, false)

    RegisterKeyMapping(command, ('Skill-Slot %d'):format(slot), 'keyboard',
        MysticConfig.SkillBar.keys[slot] or tostring(slot))
end

-- Aktualisierung -------------------------------------------------------------

AddEventHandler('mystic:client:profileChanged', function(data)
    if MysticConfig.SkillBar.showOnStart and not barVisible and data.race then
        for slot = 1, MysticConfig.SkillBar.slots do
            if data.skillbar and data.skillbar[slot] then
                barVisible = true
                break
            end
        end
    end

    pushBar()
end)

RegisterNetEvent('mystic:client:essence', function()
    if barVisible then pushBar() end
end)

AddEventHandler('moonshine:client:playerUnloaded', function()
    barVisible = false
    pushBar()
end)
