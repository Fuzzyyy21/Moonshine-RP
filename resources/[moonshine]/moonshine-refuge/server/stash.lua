--- Das Lager im Zufluchtsort.
---
--- Aufgebaut wie der Fraktionstresor: eine Liste von
--- { name = 'runenstein', count = 4, metadata = nil }. Anders als dort gibt
--- es keine Rechte - es ist das eigene Lager, sonst niemandes.

--- Gewicht eines Lagers.
local function weight(stash)
    local gesamt = 0

    for _, entry in ipairs(stash) do
        gesamt = gesamt + MS.GetItemWeight(entry.name, entry.count)
    end

    return gesamt
end

--- Sucht einen passenden Eintrag (gleiches Item, gleiche Metadaten).
local function findEntry(stash, name, metadata)
    local encoded = metadata and json.encode(metadata) or nil

    for index, entry in ipairs(stash) do
        if entry.name == name then
            local other = entry.metadata and json.encode(entry.metadata) or nil
            if other == encoded then return index end
        end
    end

    return nil
end

--- Baut die Anzeige des Lagers.
function Refuge.BuildStash(entry)
    local eintraege = {}

    for index, item in ipairs(entry.stash) do
        local definition = MS.GetItem(item.name)

        eintraege[#eintraege + 1] = {
            index    = index,
            name     = item.name,
            label    = definition and definition.label or item.name,
            count    = item.count,
            weight   = MS.GetItemWeight(item.name, item.count),
            metadata = item.metadata,
        }
    end

    table.sort(eintraege, function(a, b) return a.label < b.label end)

    return {
        entries   = eintraege,
        slots     = Refuge.GetSlots(entry.stufe),
        used      = #entry.stash,
        weight    = weight(entry.stash),
        maxWeight = RefugeConfig.Stash.maxWeight,
    }
end

--- Schickt Lager und Inventar an den Client.
function Refuge.SyncStash(source)
    local player = MS.GetPlayer(source)
    if not player then return end

    local placeId, entry = Refuge.Of(player.charId)
    if not placeId then return end

    -- Das eigene Inventar holt sich der Client selbst ueber die Core-API;
    -- hier geht nur das Lager rueber.
    TriggerClientEvent('refuge:client:stash', source, Refuge.BuildStash(entry))
end

RegisterNetEvent('refuge:server:stash', function()
    local source = source
    local player = MS.GetPlayer(source)
    if not player then return end

    local placeId = Refuge.Of(player.charId)
    if not placeId or not Refuge.AtPlace(source, placeId) then return end

    Refuge.SyncStash(source)
end)

-- Einlagern -----------------------------------------------------------------------

RegisterNetEvent('refuge:server:put', function(slot, count)
    local source = source
    if not MS.RateLimit(source, 'refuge:put', 25, 10) then return end

    local player = MS.GetPlayer(source)
    if not player then return end

    local placeId, entry = Refuge.Of(player.charId)
    if not placeId or not Refuge.AtPlace(source, placeId) then return end

    slot  = tonumber(slot)
    count = math.floor(tonumber(count) or 1)
    if not slot or count < 1 then return end

    local item = player:GetSlot(slot)
    if not item or item.count < count then return end

    local definition = MS.GetItem(item.name)
    if not definition then return end

    local index = findEntry(entry.stash, item.name, item.metadata)

    if not index and #entry.stash >= Refuge.GetSlots(entry.stufe) then
        player:Notify('Das Lager ist voll.', 'error')
        return
    end

    if weight(entry.stash) + MS.GetItemWeight(item.name, count)
        > RefugeConfig.Stash.maxWeight then

        player:Notify('Das Lager ist zu schwer beladen.', 'error')
        return
    end

    local name, metadata = item.name, item.metadata
    if not player:RemoveItem(name, count, slot) then return end

    if index then
        entry.stash[index].count = entry.stash[index].count + count
    else
        entry.stash[#entry.stash + 1] = { name = name, count = count, metadata = metadata }
    end

    Refuge.DB.SaveStash(placeId, entry.stash)
    Refuge.SyncStash(source)
end)

-- Entnehmen ------------------------------------------------------------------------

RegisterNetEvent('refuge:server:take', function(index, count)
    local source = source
    if not MS.RateLimit(source, 'refuge:take', 25, 10) then return end

    local player = MS.GetPlayer(source)
    if not player then return end

    local placeId, entry = Refuge.Of(player.charId)
    if not placeId or not Refuge.AtPlace(source, placeId) then return end

    index = math.floor(tonumber(index) or 0)
    count = math.floor(tonumber(count) or 1)

    local item = entry.stash[index]
    if not item or count < 1 or item.count < count then return end

    if not MS.GetItem(item.name) then return end

    if not player:CanCarryItem(item.name, count) then
        player:Notify('So viel kannst du nicht tragen.', 'error')
        return
    end

    if not player:AddItem(item.name, count, item.metadata) then
        player:Notify('Das passt nicht in dein Inventar.', 'error')
        return
    end

    item.count = item.count - count
    if item.count <= 0 then table.remove(entry.stash, index) end

    Refuge.DB.SaveStash(placeId, entry.stash)
    Refuge.SyncStash(source)
end)
