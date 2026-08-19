--- Wegzoll, Stoerung, Segen und die Schnittstelle nach aussen.

-- Anwesenheit -------------------------------------------------------------------
--- [source] = { pointId, since } - wie lange jemand schon an einem Punkt steht.
RitualWar.Presence = {}

--- Position eines Spielers, oder nil.
local function coordsOf(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end

    return GetEntityCoords(ped)
end

CreateThread(function()
    while true do
        Wait(WarConfig.TickInterval * 1000)

        local now = os.time()
        local seen = {}

        for _, player in pairs(MS.GetPlayers()) do
            local coords = coordsOf(player.source)
            local point = coords and Mystic.IsNearRitualPoint(coords,
                WarConfig.Disruption.range)

            if point then
                seen[player.source] = true
                local entry = RitualWar.Presence[player.source]

                if entry and entry.pointId == point.id then
                    entry.coords = coords
                else
                    RitualWar.Presence[player.source] = {
                        pointId = point.id, since = now, coords = coords,
                    }
                end
            end
        end

        for source in pairs(RitualWar.Presence) do
            if not seen[source] then RitualWar.Presence[source] = nil end
        end
    end
end)

AddEventHandler('playerDropped', function()
    RitualWar.Presence[source] = nil
end)

-- Stoerung ------------------------------------------------------------------------

--- Steht jemand aus einer fremden Fraktion lange genug daneben?
---
--- Stoeren kann nur, wer selbst in einer Fraktion ist. Das ist Absicht:
--- sonst blockieren sich an einem belebten Punkt zwei Fremde gegenseitig,
--- ohne dass einer von beiden das ueberhaupt wollte.
---@param source number
---@param kind string|nil 'ritual', 'meditation' oder 'crafting'
---@return boolean gestoert, number|nil stoerer
function RitualWar.IsDisrupted(source, kind)
    if not WarConfig.Disruption.enabled then return false end
    if kind == 'meditation' and not WarConfig.Disruption.affectsMeditation then
        return false
    end
    if kind == 'crafting' and not WarConfig.Disruption.affectsCrafting then
        return false
    end

    local mine = RitualWar.Presence[source]
    if not mine then return false end

    local coords = coordsOf(source)
    if not coords then return false end

    local eigene = RitualWar.FactionOf(source)
    local now = os.time()

    for other, entry in pairs(RitualWar.Presence) do
        if other ~= source and entry.pointId == mine.pointId
            and (now - entry.since) >= WarConfig.Disruption.delay then

            local fremd = RitualWar.FactionOf(other)

            if fremd ~= nil and fremd ~= eigene then
                local otherCoords = coordsOf(other)

                if otherCoords and #(coords - otherCoords) <= WarConfig.Disruption.range then
                    return true, other
                end
            end
        end
    end

    return false
end

-- Wegzoll --------------------------------------------------------------------------

--- Verrechnet den Wegzoll eines Ritualertrags.
---
--- Mitglieder der haltenden Fraktion bekommen einen Aufschlag, Fremde
--- lassen einen Anteil in der Kasse des Halters liegen. Gehoert der Punkt
--- niemandem, bleibt alles beim Spieler.
---@return number betrag, number zoll, string|nil halterName
function RitualWar.ApplyToll(source, amount, grund)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not WarConfig.Toll.enabled then return amount, 0, nil end

    local mine = RitualWar.Presence[source]
    local coords = coordsOf(source)
    local point = mine and Mystic.GetRitualPoint(mine.pointId)
        or (coords and Mystic.IsNearRitualPoint(coords))

    if not point then return amount, 0, nil end

    local owner = RitualWar.OwnerOf(point.id)
    if not owner then return amount, 0, nil end

    local faction = nil
    pcall(function()
        faction = exports['moonshine-factions']:GetFactionsObject().Get(owner)
    end)

    local relation = RitualWar.FactionOf(source) == owner and 'eigen' or 'fremd'
    local betrag, zoll = RitualWar.Split(amount, relation)

    if zoll <= 0 then return betrag, 0, faction and faction.name or nil end

    if faction then
        faction:AddKasse(zoll, ('Wegzoll %s'):format(point.label))
        faction:Save()
        faction:Sync()
    end

    return betrag, zoll, faction and faction.name or nil
end

--- Faktor auf Meditationspunkte an einem gebundenen Punkt.
function RitualWar.MeditationFactor(source)
    if not WarConfig.Toll.enabled then return 1.0 end

    local mine = RitualWar.Presence[source]
    if not mine then return 1.0 end

    local owner = RitualWar.OwnerOf(mine.pointId)
    if not owner then return 1.0 end

    return RitualWar.MeditationFactorFor(
        RitualWar.FactionOf(source) == owner and 'eigen' or 'fremd')
end

-- Segen ------------------------------------------------------------------------------

--- Boni fuer Mitglieder der haltenden Fraktion in der Naehe ihres Punktes.
--- moonshine-mystic rechnet das in die Modifikatoren ein.
function RitualWar.GetBlessing(source)
    if not WarConfig.Blessing.enabled then return nil end

    local coords = coordsOf(source)
    if not coords then return nil end

    local eigene = RitualWar.FactionOf(source)
    if not eigene then return nil end

    for _, point in ipairs(MysticConfig.RitualPoints) do
        if RitualWar.OwnerOf(point.id) == eigene
            and #(coords - point.coords) <= WarConfig.Blessing.range then

            return WarConfig.Blessing.effects
        end
    end

    return nil
end

-- Schnittstelle -------------------------------------------------------------------------

exports('GetClaims', function() return RitualWar.Overview() end)
exports('OwnerOf', function(pointId) return RitualWar.OwnerOf(pointId) end)
exports('IsHolder', function(source, pointId) return RitualWar.IsHolder(source, pointId) end)
exports('IsDisrupted', function(source, kind)
    return RitualWar.IsDisrupted(source, kind)
end)
exports('ApplyToll', function(source, amount, grund)
    return RitualWar.ApplyToll(source, amount, grund)
end)
exports('MeditationFactor', function(source) return RitualWar.MeditationFactor(source) end)
exports('GetBlessing', function(source) return RitualWar.GetBlessing(source) end)
exports('StartBinding', function(source) return RitualWar.Binding.Start(source) end)

--- Wie viele Punkte haelt eine Fraktion?
exports('CountPoints', function(factionId)
    local count = 0

    for _, claim in pairs(RitualWar.Claims) do
        if claim.factionId == factionId then count = count + 1 end
    end

    return count
end)

-- Netz-Events ----------------------------------------------------------------------------

RegisterNetEvent('ritualwar:server:startBinding', function()
    local source = source
    if not MS.RateLimit(source, 'ritualwar:startBinding', 5, 30) then return end

    local player = MS.GetPlayer(source)
    if not player then return end

    local ok, grund = RitualWar.Binding.Start(source)
    player:Notify(grund, ok and 'success' or 'error', 8000)
end)

RegisterNetEvent('ritualwar:server:cancelBinding', function()
    local source = source
    if not MS.RateLimit(source, 'ritualwar:cancelBinding', 5, 30) then return end

    local factionId = RitualWar.FactionOf(source)
    if not factionId then return end

    local erlaubt = false
    pcall(function()
        erlaubt = exports['moonshine-factions']:HasPermission(
            source, WarConfig.Binding.permission)
    end)

    if not erlaubt then return end

    RitualWar.Binding.CancelFor(factionId, 'von Hand abgebrochen')
end)

-- Commands --------------------------------------------------------------------------------

local function adminLevel(source, level)
    if source == 0 then return true end

    local player = MS.GetPlayer(source)
    return player ~= nil and (player.adminLevel or 0) >= level
end

RegisterCommand('bindung', function(source)
    if source == 0 then return end

    local player = MS.GetPlayer(source)
    if not player then return end

    local ok, grund = RitualWar.Binding.Start(source)
    player:Notify(grund, ok and 'success' or 'error', 8000)
end, false)

RegisterCommand('ritualpunkte', function(source)
    if source == 0 then
        for _, point in ipairs(MysticConfig.RitualPoints) do
            local owner = RitualWar.OwnerOf(point.id)
            print(('%-10s %s'):format(point.id, owner and ('Fraktion ' .. owner) or 'frei'))
        end
        return
    end

    TriggerClientEvent('ritualwar:client:open', source, RitualWar.Overview())
end, false)

--- Admin: Punkt vergeben oder freigeben.
RegisterCommand('setritualpunkt', function(source, args)
    if not adminLevel(source, 3) then return end

    local pointId = args[1]
    local point = pointId and Mystic.GetRitualPoint(pointId)

    if not point then
        local namen = {}
        for _, entry in ipairs(MysticConfig.RitualPoints) do namen[#namen + 1] = entry.id end

        print(('Verwendung: /setritualpunkt [%s] [fraktionId|frei]'):format(
            table.concat(namen, '|')))
        return
    end

    local ziel = args[2]

    if not ziel or ziel == 'frei' then
        RitualWar.Assign(point.id, nil)
        return
    end

    local factionId = tonumber(ziel)
    if not factionId then return end

    RitualWar.Assign(point.id, factionId)
end, false)

-- Start ---------------------------------------------------------------------------------------

CreateThread(function()
    while not RitualWar.DB.Ready do Wait(500) end

    RitualWar.Load()
    RitualWar.Broadcast()

    local gehalten = 0
    for _, claim in pairs(RitualWar.Claims) do
        if claim.factionId then gehalten = gehalten + 1 end
    end

    print(('^5[Ritualkrieg]^7 %d von %d Punkten sind gebunden.'):format(
        gehalten, #MysticConfig.RitualPoints))
end)
