--- Rangsystem.
---
--- Jede Fraktion hat bis zu acht Raenge. Rang 0 ist der Anfaenger, der
--- hoechste Rang ist immer die Fuehrung und hat alle Rechte.

--- Alle Rechte, die ein Rang haben kann.
Factions.Permissions = {
    { id = 'invite',    label = 'Einladen',            icon = '➕' },
    { id = 'kick',      label = 'Rauswerfen',          icon = '➖' },
    { id = 'promote',   label = 'Raenge vergeben',     icon = '🎖' },
    { id = 'vaultTake', label = 'Tresor entnehmen',    icon = '📤' },
    { id = 'vaultPut',  label = 'Tresor einlagern',    icon = '📥' },
    { id = 'kasseTake', label = 'Kasse abheben',       icon = '💸' },
    { id = 'shop',      label = 'Shop nutzen',         icon = '🛒' },
    { id = 'garage',    label = 'Garage nutzen',       icon = '🚗' },
    { id = 'garageBuy', label = 'Fahrzeuge kaufen',    icon = '🔑' },
    { id = 'skills',    label = 'Skilltree verwalten', icon = '🌳' },
    { id = 'territory', label = 'Gebiete einnehmen',   icon = '🏴' },
    { id = 'missions',  label = 'Missionen abrechnen', icon = '📜' },
    { id = 'manage',    label = 'Fraktion verwalten',  icon = '⚙' },
}

Factions.PermissionById = {}
for _, entry in ipairs(Factions.Permissions) do
    Factions.PermissionById[entry.id] = entry
end

--- Auswaehlbare Rang-Icons.
Factions.RankIcons = {
    '🎖', '⭐', '✦', '⚔', '🛡', '👑', '🥉', '🥈', '🥇', '🗡',
    '🏹', '🪓', '🔱', '⚜', '❖', '▲', '●', '◆',
}

--- Standardraenge einer neuen Fraktion (Index = Rangstufe).
Factions.DefaultRanks = {
    { label = 'Anwaerter', icon = '●',
      permissions = {} },

    { label = 'Mitglied',  icon = '◆',
      permissions = { 'vaultPut', 'shop', 'garage', 'territory', 'missions' } },

    { label = 'Veteran',   icon = '✦',
      permissions = { 'vaultPut', 'vaultTake', 'shop', 'garage', 'territory', 'missions', 'invite' } },

    { label = 'Hauptmann', icon = '⚔',
      permissions = { 'vaultPut', 'vaultTake', 'shop', 'garage', 'garageBuy', 'territory',
                      'missions', 'invite', 'kick', 'kasseTake' } },

    { label = 'Rat',       icon = '🛡',
      permissions = { 'vaultPut', 'vaultTake', 'shop', 'garage', 'garageBuy', 'territory',
                      'missions', 'invite', 'kick', 'kasseTake', 'promote', 'skills' } },

    { label = 'Fuehrung',  icon = '👑',
      permissions = 'all' },
}

Factions.MaxRanks = 8

--- Rechte eines Rangs als Nachschlagetabelle.
local function permissionSet(rank)
    local set = {}

    if rank.permissions == 'all' then
        for _, entry in ipairs(Factions.Permissions) do set[entry.id] = true end
        return set
    end

    for _, id in ipairs(rank.permissions or {}) do
        if Factions.PermissionById[id] then set[id] = true end
    end

    return set
end

--- Darf ein Rang das?
---@param ranks table Rangliste der Fraktion
---@param grade number Rangstufe (0-basiert)
---@param permission string
function Factions.RankHas(ranks, grade, permission)
    grade = math.floor(tonumber(grade) or 0)

    -- Der hoechste Rang darf immer alles.
    if grade >= #ranks - 1 then return true end

    local rank = ranks[grade + 1]
    if not rank then return false end

    return permissionSet(rank)[permission] == true
end

--- Rangdefinition zu einer Stufe.
function Factions.GetRank(ranks, grade)
    grade = math.floor(tonumber(grade) or 0)
    return ranks[grade + 1] or ranks[#ranks]
end

--- Hoechste Rangstufe.
function Factions.TopGrade(ranks)
    return math.max(0, #ranks - 1)
end

--- Prueft und bereinigt eine Rangliste aus der Oberflaeche.
function Factions.SanitizeRanks(input, current)
    if type(input) ~= 'table' or #input < 2 then
        return current or Factions.CopyDefaultRanks()
    end

    local ranks = {}

    for index = 1, math.min(#input, Factions.MaxRanks) do
        local entry = input[index]
        if type(entry) ~= 'table' then break end

        local label = type(entry.label) == 'string' and entry.label:sub(1, 24) or ('Rang %d'):format(index)
        if label:gsub('%s', '') == '' then label = ('Rang %d'):format(index) end

        local icon = '●'
        for _, candidate in ipairs(Factions.RankIcons) do
            if candidate == entry.icon then icon = candidate break end
        end

        local permissions = {}
        if index == math.min(#input, Factions.MaxRanks) then
            permissions = 'all'
        else
            for _, id in ipairs(entry.permissions or {}) do
                if Factions.PermissionById[id] then permissions[#permissions + 1] = id end
            end
        end

        ranks[index] = { label = label, icon = icon, permissions = permissions }
    end

    if #ranks < 2 then return current or Factions.CopyDefaultRanks() end
    return ranks
end

--- Frische Kopie der Standardraenge.
function Factions.CopyDefaultRanks()
    local ranks = {}

    for index, rank in ipairs(Factions.DefaultRanks) do
        local permissions = rank.permissions

        if type(permissions) == 'table' then
            local copy = {}
            for position, id in ipairs(permissions) do copy[position] = id end
            permissions = copy
        end

        ranks[index] = { label = rank.label, icon = rank.icon, permissions = permissions }
    end

    return ranks
end
