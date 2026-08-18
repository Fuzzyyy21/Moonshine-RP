--- Kisten: Bestand, Oeffnen und Ausbeute.
---
--- Kisten liegen als Zaehler im Fortschrittsprofil. Zusaetzlich gibt es je
--- Kiste ein Item (kiste_holz, kiste_silber, ...), damit sie handelbar sind.
--- Wer das Item benutzt, legt die Kiste in seinen Bestand.

local opening = {}

--- Zieht ein Los aus der Lootliste.
local function rollLoot(case)
    local total = 0
    for _, entry in ipairs(case.loot) do total = total + entry.weight end
    if total <= 0 then return nil end

    local roll = math.random() * total
    local sum  = 0

    for _, entry in ipairs(case.loot) do
        sum = sum + entry.weight
        if roll <= sum then return entry end
    end

    return case.loot[#case.loot]
end

--- Baut die Kistenanzeige.
function Progress.BuildCasePayload(profile)
    local entries = {}

    for _, name in ipairs(Progress.CaseOrder) do
        local case = Progress.Cases[name]

        local loot = {}
        local total = 0
        for _, entry in ipairs(case.loot) do total = total + entry.weight end

        for _, entry in ipairs(case.loot) do
            loot[#loot + 1] = {
                label  = entry.label,
                chance = total > 0 and (entry.weight / total) or 0,
            }
        end

        entries[#entries + 1] = {
            name        = name,
            label       = case.label,
            icon        = case.icon,
            color       = case.color,
            description = case.description,
            count       = profile:GetCaseCount(name),
            loot        = loot,
        }
    end

    return entries
end

--- Oeffnet eine Kiste.
function Progress.OpenCase(source, name)
    local profile = Progress.GetProfile(source)
    if not profile or not ProgressConfig.Cases.enabled then return false end

    local player = profile:Player()
    if not player then return false end

    local case = Progress.GetCase(name)
    if not case then return false end

    -- Doppelklick und Spam abfangen.
    if opening[source] and opening[source] > GetGameTimer() then return false end
    opening[source] = GetGameTimer() + ProgressConfig.Cases.animationTime + 500

    if not profile:RemoveCase(name, 1) then
        player:Notify('Du hast keine solche Kiste.', 'error')
        opening[source] = nil
        return false
    end

    local entry = rollLoot(case)
    if not entry then
        profile:AddCase(name, 1)
        opening[source] = nil
        return false
    end

    profile:Save()

    -- Erst die Animation, dann die Ausgabe.
    TriggerClientEvent('progress:client:caseResult', source, {
        case   = name,
        label  = case.label,
        icon   = case.icon,
        color  = case.color,
        result = entry.label,
        reward = Progress.DescribeReward(entry.reward),
    })

    SetTimeout(ProgressConfig.Cases.animationTime, function()
        if not MS.GetPlayer(source) then return end

        local current = Progress.GetProfile(source)
        if not current then return end

        Progress.GiveReward(source, entry.reward, 'kiste')
        current:Save()
        current:Sync()

        opening[source] = nil
    end)

    TriggerEvent('progress:server:caseOpened', source, name, entry.label)
    return true
end

--- Kisten von aussen vergeben.
function Progress.GiveCase(source, name, amount)
    local profile = Progress.GetProfile(source)
    if not profile then return false end

    if not profile:AddCase(name, amount or 1) then return false end

    profile:Save()
    profile:Sync()

    return true
end

--- Wandelt eine Kiste in ein handelbares Item.
function Progress.PackCase(source, name, amount)
    local profile = Progress.GetProfile(source)
    if not profile then return false end

    local player = profile:Player()
    if not player then return false end

    local case = Progress.GetCase(name)
    if not case then return false end

    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then return false end

    local item = Progress.GetCaseItem(name)

    if not player:CanCarryItem(item, amount) then
        player:Notify('So viel kannst du nicht tragen.', 'error')
        return false
    end

    if not profile:RemoveCase(name, amount) then
        player:Notify('So viele Kisten hast du nicht.', 'error')
        return false
    end

    if not player:AddItem(item, amount) then
        profile:AddCase(name, amount)
        return false
    end

    player:Notify(('%dx %s eingepackt.'):format(amount, case.label), 'success')

    profile:Save()
    profile:Sync()

    return true
end

RegisterNetEvent('progress:server:openCase', function(name)
    if type(name) ~= 'string' then return end
    Progress.OpenCase(source, name)
end)

RegisterNetEvent('progress:server:packCase', function(name, amount)
    if type(name) ~= 'string' then return end
    Progress.PackCase(source, name, amount)
end)

AddEventHandler('playerDropped', function()
    opening[source] = nil
end)

-- Kistenitems benutzbar machen ------------------------------------------------

CreateThread(function()
    -- Der Core braucht evtl. einen Moment, bis seine Exporte stehen.
    for _ = 1, 20 do
        if Progress.RegisterCaseItems() then break end
        Wait(500)
    end

    for name in pairs(Progress.Cases) do
        local caseName = name
        local itemName = Progress.GetCaseItem(name)

        MS.RegisterUsableItem(itemName, function(player, slot)
            local profile = Progress.GetProfile(player.source)
            if not profile then return end

            if not player:RemoveItem(itemName, 1, slot) then return end

            profile:AddCase(caseName, 1)
            profile:Save()
            profile:Sync()

            local case = Progress.GetCase(caseName)
            player:Notify(('%s liegt in deinem Kistenbestand.'):format(case.label), 'success')
        end)
    end
end)
