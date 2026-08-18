--- Einheitliche Belohnungsausgabe.
---
--- Jede Belohnung im Fortschrittssystem hat dieselbe Form:
---
---   reward = {
---       money = 5000,                                     -- Bank
---       cash  = 500,                                      -- Bar
---       items = { { name = 'runenstein', count = 2 } },   -- Inventar
---       bpxp  = 200,                                      -- Battle-Pass-XP
---       cases = { holz = 1 },                             -- Kisten
---       xp    = 300,                                      -- Mystik-XP
---   }

local ACCOUNTS = {
    money = 'bank',
    cash  = 'cash',
}

--- Beschreibt eine Belohnung als Liste kurzer Texte.
function Progress.DescribeReward(reward)
    local parts = {}
    if type(reward) ~= 'table' then return parts end

    if reward.money and reward.money > 0 then
        parts[#parts + 1] = { icon = '💰', text = MS.Utils.FormatMoney(reward.money) }
    end

    if reward.cash and reward.cash > 0 then
        parts[#parts + 1] = { icon = '💵', text = MS.Utils.FormatMoney(reward.cash) .. ' bar' }
    end

    for _, entry in ipairs(reward.items or {}) do
        local item = MS.GetItem(entry.name)
        parts[#parts + 1] = {
            icon = '◆',
            text = ('%dx %s'):format(entry.count or 1, item and item.label or entry.name),
        }
    end

    if reward.bpxp and reward.bpxp > 0 then
        parts[#parts + 1] = { icon = '⚡', text = ('%d Pass-XP'):format(reward.bpxp) }
    end

    if reward.xp and reward.xp > 0 then
        parts[#parts + 1] = { icon = '✦', text = ('%d Erfahrung'):format(reward.xp) }
    end

    for name, count in pairs(reward.cases or {}) do
        local case = Progress.GetCase(name)
        parts[#parts + 1] = {
            icon = case and case.icon or '📦',
            text = ('%dx %s'):format(count, case and case.label or name),
        }
    end

    return parts
end

--- Kurzform als Text, z. B. fuer Benachrichtigungen.
function Progress.RewardText(reward)
    local words = {}

    for _, part in ipairs(Progress.DescribeReward(reward)) do
        words[#words + 1] = part.text
    end

    return table.concat(words, ', ')
end

--- Gibt eine Belohnung aus.
---@param source number Spieler
---@param reward table  Belohnungsdefinition
---@param reason string Grund fuer das Transaktionslog
---@return boolean ok, string text
function Progress.GiveReward(source, reward, reason)
    if type(reward) ~= 'table' then return false, '' end

    local player = MS.GetPlayer(source)
    if not player then return false, '' end

    local profile = Progress.GetProfile(source)
    reason = reason or 'fortschritt'

    for field, account in pairs(ACCOUNTS) do
        local amount = math.floor(tonumber(reward[field]) or 0)
        if amount > 0 then player:AddMoney(amount, account, reason) end
    end

    for _, entry in ipairs(reward.items or {}) do
        local count = math.floor(tonumber(entry.count) or 1)

        if count > 0 then
            if not player:AddItem(entry.name, count) then
                -- Kein Platz: als Bodenitem ablegen, damit nichts verloren geht.
                local coords = GetEntityCoords(GetPlayerPed(source))
                if MS.CreateDrop then
                    MS.CreateDrop(entry.name, count, nil, coords)
                    player:Notify('Dein Inventar ist voll - die Belohnung liegt vor dir.', 'warning')
                else
                    player:Notify('Dein Inventar ist voll.', 'error')
                end
            end
        end
    end

    if profile then
        if reward.bpxp then profile:AddBattlePassXp(reward.bpxp) end

        for name, count in pairs(reward.cases or {}) do
            profile:AddCase(name, count)
        end
    end

    if reward.xp and reward.xp > 0 then
        pcall(function()
            exports['moonshine-mystic']:AddXp(source, reward.xp)
        end)
    end

    return true, Progress.RewardText(reward)
end

--- Prueft, ob eine Belohnung ueberhaupt etwas enthaelt.
function Progress.HasReward(reward)
    if type(reward) ~= 'table' then return false end

    if (reward.money or 0) > 0 then return true end
    if (reward.cash or 0) > 0 then return true end
    if (reward.bpxp or 0) > 0 then return true end
    if (reward.xp or 0) > 0 then return true end
    if reward.items and #reward.items > 0 then return true end

    for _ in pairs(reward.cases or {}) do return true end

    return false
end
