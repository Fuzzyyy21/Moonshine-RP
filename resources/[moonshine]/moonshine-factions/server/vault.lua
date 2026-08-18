--- Fraktionstresor: gemeinsames Lager mit Rechten und Protokoll.
---
--- Der Tresor liegt als Liste in der Fraktion. Jeder Eintrag ist
--- { name = 'bread', count = 4, metadata = nil }.

--- Gewicht des Tresors.
local function vaultWeight(faction)
    local weight = 0

    for _, entry in ipairs(faction.vault) do
        weight = weight + MS.GetItemWeight(entry.name, entry.count)
    end

    return weight
end

--- Sucht einen passenden Eintrag (gleiches Item, gleiche Metadaten).
local function findEntry(faction, name, metadata)
    local encoded = metadata and json.encode(metadata) or nil

    for index, entry in ipairs(faction.vault) do
        if entry.name == name then
            local other = entry.metadata and json.encode(entry.metadata) or nil
            if other == encoded then return index, entry end
        end
    end

    return nil, nil
end

--- Baut die Tresoranzeige.
function Factions.BuildVaultPayload(faction)
    local entries = {}

    for index, entry in ipairs(faction.vault) do
        local item = MS.GetItem(entry.name)

        entries[#entries + 1] = {
            index    = index,
            name     = entry.name,
            label    = item and item.label or entry.name,
            count    = entry.count,
            weight   = MS.GetItemWeight(entry.name, entry.count),
            metadata = entry.metadata,
        }
    end

    table.sort(entries, function(a, b) return a.label < b.label end)

    return {
        entries   = entries,
        slots     = faction:GetVaultSlots(),
        used      = #faction.vault,
        weight    = vaultWeight(faction),
        maxWeight = FactionConfig.Vault.maxWeight,
    }
end

-- Einlagern ---------------------------------------------------------------------

RegisterNetEvent('factions:server:vaultPut', function(slot, count)
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'vaultPut') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    slot  = tonumber(slot)
    count = math.floor(tonumber(count) or 1)
    if not slot or count < 1 then return end

    local entry = player:GetSlot(slot)
    if not entry or entry.count < count then return end

    local item = MS.GetItem(entry.name)
    if not item then return end

    local index = findEntry(faction, entry.name, entry.metadata)

    if not index and #faction.vault >= faction:GetVaultSlots() then
        player:Notify('Der Tresor ist voll.', 'error')
        return
    end

    if vaultWeight(faction) + MS.GetItemWeight(entry.name, count) > FactionConfig.Vault.maxWeight then
        player:Notify('Der Tresor ist zu schwer beladen.', 'error')
        return
    end

    local name, metadata = entry.name, entry.metadata
    if not player:RemoveItem(name, count, slot) then return end

    if index then
        faction.vault[index].count = faction.vault[index].count + count
    else
        faction.vault[#faction.vault + 1] = { name = name, count = count, metadata = metadata }
    end

    faction.dirty = true
    faction:Save()
    faction:Log('tresor', ('%s %s hat %dx %s eingelagert.'):format(
        player.firstname, player.lastname, count, item.label))

    faction:Sync()
end)

-- Entnehmen ------------------------------------------------------------------------

RegisterNetEvent('factions:server:vaultTake', function(index, count)
    local source = source
    if not MS.RateLimit(source, 'factions:server:vaultTake', 20, 10) then return end
    local player = MS.GetPlayer(source)
    if not player then return end

    local faction = Factions.GetByPlayer(source)
    if not faction or not faction:Can(player.charId, 'vaultTake') then
        player:Notify('Dafuer fehlt dir das Recht.', 'error')
        return
    end

    index = math.floor(tonumber(index) or 0)
    count = math.floor(tonumber(count) or 1)

    local entry = faction.vault[index]
    if not entry or count < 1 or entry.count < count then return end

    local item = MS.GetItem(entry.name)
    if not item then return end

    if not player:CanCarryItem(entry.name, count) then
        player:Notify('So viel kannst du nicht tragen.', 'error')
        return
    end

    if not player:AddItem(entry.name, count, entry.metadata) then
        player:Notify('Das passt nicht in dein Inventar.', 'error')
        return
    end

    entry.count = entry.count - count
    if entry.count <= 0 then table.remove(faction.vault, index) end

    faction.dirty = true
    faction:Save()
    faction:Log('tresor', ('%s %s hat %dx %s entnommen.'):format(
        player.firstname, player.lastname, count, item.label))

    faction:Sync()
end)
