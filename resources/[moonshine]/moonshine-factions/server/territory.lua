--- Gebietskontrolle.
---
--- Der Server prueft alle zwei Sekunden, wer in welchem Gebiet steht. Steht
--- eine fremde Fraktion allein im Gebiet, waechst ihr Einnahmebalken. Steht
--- mehr als eine fremde Fraktion drin, ist das Gebiet umkaempft und der
--- Balken steht still.

local TICK = 2000

Factions.TerritoryState = {}   -- [territoryId] = Zustand

--- Legt den Zustand aller Gebiete an.
local function ensureState()
    for _, territory in ipairs(Factions.Territories) do
        if not Factions.TerritoryState[territory.id] then
            Factions.TerritoryState[territory.id] = {
                id             = territory.id,
                factionId      = nil,
                since          = 0,
                protectedUntil = 0,
                captureBy      = nil,
                progress       = 0.0,
                contested      = false,
                attackers      = 0,
                defenders      = 0,
            }
        end
    end
end

function Factions.LoadTerritories()
    ensureState()

    for _, row in ipairs(Factions.DB.LoadTerritories()) do
        local state = Factions.TerritoryState[row.territory_id]

        if state then
            state.factionId      = row.faction_id
            state.since          = tonumber(row.since) or 0
            state.protectedUntil = tonumber(row.protected_until) or 0
        end
    end
end

--- Alle Gebiete einer Fraktion.
function Factions.GetTerritoriesOf(factionId)
    local list = {}

    for _, state in pairs(Factions.TerritoryState) do
        if state.factionId == factionId then list[#list + 1] = state.id end
    end

    table.sort(list)
    return list
end

--- Gibt alle Gebiete einer Fraktion frei (z. B. beim Aufloesen).
function Factions.ReleaseTerritories(factionId)
    for _, state in pairs(Factions.TerritoryState) do
        if state.factionId == factionId then
            state.factionId = nil
            state.since = 0
            state.protectedUntil = 0
            state.progress = 0.0
            state.captureBy = nil

            Factions.DB.SaveTerritory(state.id, nil, 0, 0)
        end
    end

    Factions.BroadcastTerritories()
end

--- Zustand aller Gebiete fuer die Karte.
function Factions.GetTerritoryOverview()
    local list = {}

    for _, territory in ipairs(Factions.Territories) do
        local state = Factions.TerritoryState[territory.id] or {}
        local owner = state.factionId and Factions.Get(state.factionId)

        list[#list + 1] = {
            id          = territory.id,
            label       = territory.label,
            icon        = territory.icon,
            description = territory.description,
            coords      = { x = territory.coords.x, y = territory.coords.y, z = territory.coords.z },
            radius      = territory.radius,
            income      = territory.income,

            factionId   = state.factionId,
            factionName = owner and owner.name or nil,
            factionTag  = owner and owner.tag or nil,
            emblem      = owner and owner.emblem or nil,

            protected   = (state.protectedUntil or 0) > os.time(),
            protectedFor = math.max(0, (state.protectedUntil or 0) - os.time()),
            since       = state.since or 0,

            progress    = state.progress or 0.0,
            captureBy   = state.captureBy,
            captureName = state.captureBy and (Factions.Get(state.captureBy) or {}).name or nil,
            contested   = state.contested or false,
        }
    end

    return list
end

--- Gebietsteil der Fraktionsanzeige.
function Factions.BuildTerritoryPayload(faction)
    local own = Factions.GetTerritoriesOf(faction.id)
    local bonus = faction:GetModifiers().territoryIncome or 0

    return {
        enabled  = FactionConfig.Territory.enabled,
        owned    = own,
        income   = math.floor(Factions.TerritoryIncome(own) * (1 + bonus)),
        interval = FactionConfig.Territory.payoutInterval,
        list     = Factions.GetTerritoryOverview(),
    }
end

--- Schickt den Gebietszustand an alle.
function Factions.BroadcastTerritories()
    TriggerClientEvent('factions:client:territories', -1, Factions.GetTerritoryOverview())
end

RegisterNetEvent('factions:server:requestTerritories', function()
    TriggerClientEvent('factions:client:territories', source, Factions.GetTerritoryOverview())
end)

-- Einnahme -------------------------------------------------------------------------

--- Zaehlt, welche Fraktionen in einem Gebiet stehen.
local function scanTerritory(territory)
    local counts = {}

    for _, player in pairs(MS.GetPlayers()) do
        local faction = Factions.GetByCharacter(player.charId)

        if faction then
            local ped = GetPlayerPed(player.source)

            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)

                if #(coords - territory.coords) <= territory.radius then
                    counts[faction.id] = (counts[faction.id] or 0) + 1
                end
            end
        end
    end

    return counts
end

--- Uebergibt ein Gebiet an eine Fraktion.
local function captureTerritory(state, territory, factionId)
    local previous = state.factionId and Factions.Get(state.factionId)
    local faction  = Factions.Get(factionId)
    if not faction then return end

    local protection = FactionConfig.Territory.protection
        * (1 + (faction:GetModifiers().protectionBonus or 0))

    state.factionId      = factionId
    state.since          = os.time()
    state.protectedUntil = os.time() + math.floor(protection * 60)
    state.progress       = 0.0
    state.captureBy      = nil
    state.contested      = false

    Factions.DB.SaveTerritory(territory.id, factionId, state.since, state.protectedUntil)

    faction:AddXp(territory.xp)
    faction:Save()
    faction:Log('gebiet', ('%s wurde eingenommen.'):format(territory.label))
    faction:Notify(('%s gehoert jetzt euch.'):format(territory.label), 'success', 10000)

    if previous then
        previous:Log('gebiet', ('%s ging an %s verloren.'):format(territory.label, faction.name))
        previous:Notify(('%s wurde von %s eingenommen.'):format(
            territory.label, faction.name), 'error', 10000)
    end

    Factions.Advance(factionId, 'capture', 1)
    Factions.BroadcastTerritories()
    faction:Sync()

    TriggerEvent('factions:server:territoryCaptured', territory.id, factionId)
end

--- Ein Durchlauf ueber alle Gebiete.
local function tick()
    local now = os.time()
    local changed = false

    for _, territory in ipairs(Factions.Territories) do
        local state = Factions.TerritoryState[territory.id]
        if not state then goto continue end

        do
            local counts = scanTerritory(territory)

            -- Wer greift an, wer verteidigt?
            local attackers, attackerId, defenders = 0, nil, 0
            local attackingFactions = 0

            for factionId, count in pairs(counts) do
                if factionId == state.factionId then
                    defenders = count
                else
                    attackingFactions = attackingFactions + 1

                    if count > attackers then
                        attackers, attackerId = count, factionId
                    end
                end
            end

            state.attackers = attackers
            state.defenders = defenders

            local protected = state.protectedUntil > now
            local contested = attackingFactions > 1 or (defenders > 0 and attackers > 0)

            state.contested = contested

            local faction = attackerId and Factions.Get(attackerId)
            local modifiers = faction and faction:GetModifiers() or {}
            local needed = modifiers.soloCapture and 1 or FactionConfig.Territory.minAttackers

            if faction and not protected and not contested and attackers >= needed then
                -- Ein Wechsel der angreifenden Fraktion setzt den Balken zurueck.
                if state.captureBy ~= attackerId then
                    state.captureBy = attackerId
                    state.progress = 0.0
                end

                local perSecond = 100.0 / FactionConfig.Territory.captureTime
                local speed = 1 + (modifiers.captureSpeed or 0)

                state.progress = state.progress + perSecond * speed * (TICK / 1000)
                changed = true

                if state.progress >= 100.0 then
                    captureTerritory(state, territory, attackerId)
                    goto continue
                end
            elseif state.progress > 0 then
                -- Ohne Angreifer faellt der Balken zurueck. Verteidiger
                -- beschleunigen das.
                local owner = state.factionId and Factions.Get(state.factionId)
                local defence = owner and (owner:GetModifiers().defenceBonus or 0) or 0
                local decay = FactionConfig.Territory.decay * (1 + defence)
                    * (defenders > 0 and 2.0 or 1.0)

                state.progress = math.max(0.0, state.progress - decay * (TICK / 1000))
                if state.progress <= 0 then state.captureBy = nil end

                changed = true
            end
        end

        ::continue::
    end

    if changed then Factions.BroadcastTerritories() end
end

CreateThread(function()
    while not Factions.DB.Ready do Wait(500) end
    Wait(3000)

    while true do
        Wait(TICK)

        if FactionConfig.Territory.enabled then
            local ok, err = pcall(tick)
            if not ok then
                print(('^1[Fraktionen]^7 Gebiets-Tick fehlgeschlagen: %s'):format(tostring(err)))
            end
        end
    end
end)

-- Einkommen ---------------------------------------------------------------------------

CreateThread(function()
    while not Factions.DB.Ready do Wait(500) end

    while true do
        Wait(FactionConfig.Territory.payoutInterval * 60000)

        if FactionConfig.Territory.enabled then
            for _, faction in pairs(Factions.List) do
                local own = Factions.GetTerritoriesOf(faction.id)

                if #own > 0 then
                    local bonus = faction:GetModifiers().territoryIncome or 0
                    local income = math.floor(Factions.TerritoryIncome(own) * (1 + bonus))

                    faction:AddKasse(income, ('Gebietseinkommen (%d Gebiete)'):format(#own))
                    faction:AddXp(math.floor(income / 100))
                    faction:Save()

                    faction:Notify(('Gebietseinkommen: %s in die Kasse.'):format(
                        MS.Utils.FormatMoney(income)), 'info')
                    faction:Sync()
                end
            end
        end
    end
end)

-- Schutzzeit laeuft ab -----------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(30000)

        local now = os.time()
        for _, state in pairs(Factions.TerritoryState) do
            if state.protectedUntil > 0 and state.protectedUntil <= now then
                state.protectedUntil = 0
                Factions.DB.SaveTerritory(state.id, state.factionId, state.since, 0)
                Factions.BroadcastTerritories()
            end
        end
    end
end)
