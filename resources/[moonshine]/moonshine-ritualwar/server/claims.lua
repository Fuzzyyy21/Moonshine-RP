--- Besitz der Ritualpunkte: Zustand, Ertrag, Wegzoll, Segen.

MS = MS or exports['moonshine-core']:GetCoreObject()

--- [pointId] = { factionId, since, protectedUntil, payouts, binding }
RitualWar.Claims = {}

--- Legt den Zustand aller Punkte an.
local function ensure()
    for _, point in ipairs(MysticConfig.RitualPoints) do
        if not RitualWar.Claims[point.id] then
            RitualWar.Claims[point.id] = {
                id = point.id, factionId = nil, since = 0,
                protectedUntil = 0, payouts = 0, binding = nil,
            }
        end
    end
end

function RitualWar.Load()
    ensure()

    for _, row in ipairs(RitualWar.DB.LoadAll()) do
        local claim = RitualWar.Claims[row.point_id]

        if claim then
            claim.factionId      = row.faction_id
            claim.since          = tonumber(row.since) or 0
            claim.protectedUntil = tonumber(row.protected_until) or 0
            claim.payouts        = tonumber(row.payouts) or 0
        end
    end
end

--- Zustand eines Punktes.
function RitualWar.Get(pointId)
    return RitualWar.Claims[pointId]
end

--- Welche Fraktion haelt diesen Punkt?
---@return number|nil
function RitualWar.OwnerOf(pointId)
    local claim = RitualWar.Claims[pointId]
    return claim and claim.factionId or nil
end

--- Punkt an der Position, sonst nil.
function RitualWar.PointAt(coords, tolerance)
    return Mystic.IsNearRitualPoint(coords, tolerance)
end

--- Gehoert dieser Spieler zur haltenden Fraktion?
function RitualWar.IsHolder(source, pointId)
    local owner = RitualWar.OwnerOf(pointId)
    if not owner then return false end

    local eigene = nil
    pcall(function() eigene = exports['moonshine-factions']:GetFactionId(source) end)

    return eigene ~= nil and eigene == owner
end

--- Fraktion eines Spielers.
function RitualWar.FactionOf(source)
    local id = nil
    pcall(function() id = exports['moonshine-factions']:GetFactionId(source) end)

    return id
end

--- Kurzinfo einer Fraktion.
local function factionInfo(factionId)
    if not factionId then return nil end

    local info = nil
    pcall(function()
        local faction = exports['moonshine-factions']:GetFactionsObject().Get(factionId)

        if faction then
            info = { id = faction.id, name = faction.name, tag = faction.tag,
                     emblem = faction.emblem }
        end
    end)

    return info
end

--- Zustand aller Punkte fuer die Clients.
function RitualWar.Overview()
    local list = {}

    for _, point in ipairs(MysticConfig.RitualPoints) do
        local claim = RitualWar.Claims[point.id] or {}
        local owner = factionInfo(claim.factionId)

        list[#list + 1] = {
            id      = point.id,
            label   = point.label,
            coords  = { x = point.coords.x, y = point.coords.y, z = point.coords.z },
            radius  = point.radius,

            factionId   = claim.factionId,
            factionName = owner and owner.name or nil,
            factionTag  = owner and owner.tag or nil,
            colour      = owner and owner.emblem and owner.emblem.primary or nil,

            protected    = (claim.protectedUntil or 0) > os.time(),
            protectedFor = math.max(0, (claim.protectedUntil or 0) - os.time()),
            since        = claim.since or 0,
            payouts      = claim.payouts or 0,

            binding      = claim.binding and {
                factionId = claim.binding.factionId,
                progress  = claim.binding.progress,
                contested = claim.binding.contested,
            } or nil,
        }
    end

    return list
end

function RitualWar.Broadcast()
    TriggerClientEvent('ritualwar:client:points', -1, RitualWar.Overview())
end

RegisterNetEvent('ritualwar:server:request', function()
    TriggerClientEvent('ritualwar:client:points', source, RitualWar.Overview())
end)

-- Besitz wechseln -------------------------------------------------------------

--- Uebergibt einen Punkt an eine Fraktion.
function RitualWar.Assign(pointId, factionId, quiet)
    local claim = RitualWar.Claims[pointId]
    local point = Mystic.GetRitualPoint(pointId)
    if not claim or not point then return false end

    local vorher = claim.factionId

    claim.factionId = factionId
    claim.since = os.time()
    claim.payouts = 0

    if factionId then
        local minuten = WarConfig.Binding.protection

        -- Der Fraktionsbaum verlaengert die Schutzzeit.
        pcall(function()
            local faction = exports['moonshine-factions']:GetFactionsObject().Get(factionId)
            if faction then
                minuten = minuten * (1 + (faction:GetModifiers().protectionBonus or 0))
            end
        end)

        claim.protectedUntil = os.time() + math.floor(minuten * 60)
    else
        claim.protectedUntil = 0
    end

    claim.binding = nil

    RitualWar.DB.Save(pointId, factionId, claim.since, claim.protectedUntil, 0)
    RitualWar.Broadcast()

    if not quiet then
        local neu = factionInfo(factionId)
        local alt = factionInfo(vorher)

        for _, player in pairs(MS.GetPlayers()) do
            if neu then
                player:Notify(('✦ %s wurde von %s gebunden.'):format(
                    point.label, neu.name), 'warning', 10000)
            else
                player:Notify(('✦ %s ist wieder frei.'):format(point.label),
                    'info', 8000)
            end
        end

        if alt and vorher ~= factionId then
            pcall(function()
                exports['moonshine-factions']:GetFactionsObject().Get(vorher)
                    :Log('gebiet', ('%s ging verloren.'):format(point.label))
            end)
        end
    end

    TriggerEvent('ritualwar:server:claimed', pointId, factionId, vorher)
    return true
end

--- Gibt alle Punkte einer Fraktion frei.
function RitualWar.ReleaseFaction(factionId)
    for id, claim in pairs(RitualWar.Claims) do
        if claim.factionId == factionId then
            claim.factionId = nil
            claim.since = 0
            claim.protectedUntil = 0
            claim.binding = nil
        end
    end

    RitualWar.DB.Release(factionId)
    RitualWar.Broadcast()
end

AddEventHandler('factions:server:disbanded', function(factionId)
    RitualWar.ReleaseFaction(factionId)
end)

-- Ertrag -------------------------------------------------------------------------

CreateThread(function()
    while not RitualWar.DB.Ready do Wait(500) end

    while true do
        Wait(WarConfig.Income.interval * 60000)

        if WarConfig.Income.enabled then
            for pointId, claim in pairs(RitualWar.Claims) do
                if claim.factionId then
                    local point = Mystic.GetRitualPoint(pointId)
                    local bonus = 0

                    if WarConfig.Income.useFactionBonus then
                        pcall(function()
                            local faction = exports['moonshine-factions']
                                :GetFactionsObject().Get(claim.factionId)

                            if faction then
                                bonus = faction:GetModifiers().territoryIncome or 0
                            end
                        end)
                    end

                    local teile = {}

                    for _, entry in ipairs(WarConfig.Income.stones) do
                        local menge = math.random(entry.min, entry.max)
                        menge = math.max(1, math.floor(menge * (1 + bonus)))

                        local ok = false
                        pcall(function()
                            ok = exports['moonshine-factions']:AddToVault(
                                claim.factionId, entry.item, menge)
                        end)

                        if ok then
                            local item = MS.GetItem(entry.item)
                            teile[#teile + 1] = ('%dx %s'):format(menge,
                                item and item.label or entry.item)
                        end
                    end

                    pcall(function()
                        exports['moonshine-factions']:AddFactionXp(
                            claim.factionId, WarConfig.Income.xp)
                    end)

                    claim.payouts = (claim.payouts or 0) + 1
                    RitualWar.DB.Save(pointId, claim.factionId, claim.since,
                        claim.protectedUntil, claim.payouts)

                    if #teile > 0 then
                        pcall(function()
                            local faction = exports['moonshine-factions']
                                :GetFactionsObject().Get(claim.factionId)

                            if faction then
                                faction:Notify(('%s wirft ab: %s'):format(
                                    point and point.label or pointId,
                                    table.concat(teile, ', ')), 'success', 9000)

                                faction:Log('gebiet', ('%s: %s in den Tresor.'):format(
                                    point and point.label or pointId,
                                    table.concat(teile, ', ')))
                            end
                        end)
                    end

                    TriggerEvent('ritualwar:server:payout', pointId, claim.factionId)
                end
            end
        end
    end
end)

--- Schutzzeit laeuft ab.
CreateThread(function()
    while true do
        Wait(30000)

        local now = os.time()
        local changed = false

        for pointId, claim in pairs(RitualWar.Claims) do
            if claim.protectedUntil > 0 and claim.protectedUntil <= now then
                claim.protectedUntil = 0
                RitualWar.DB.Save(pointId, claim.factionId, claim.since, 0, claim.payouts)
                changed = true
            end
        end

        if changed then RitualWar.Broadcast() end
    end
end)
