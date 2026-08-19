--- Das Bindungsritual.
---
--- Ein Gebiet in moonshine-factions nimmt man ein, indem man einfach lange
--- genug dasteht. Ein Ritualpunkt ist anders: die Fraktion zahlt, stellt
--- Leute hin und haelt sie 180 Sekunden lang dort. Wer stoert, haelt den
--- Balken an - und ein Abbruch kostet die Haelfte des Einsatzes.

RitualWar.Binding = {}

local TICK = math.max(1, WarConfig.TickInterval) * 1000

--- Fraktionsobjekt, ohne dass ein Fehler den Tick reisst.
local function getFaction(factionId)
    if not factionId then return nil end

    local faction = nil
    pcall(function()
        faction = exports['moonshine-factions']:GetFactionsObject().Get(factionId)
    end)

    return faction
end

--- Alle Spieler mit Fraktion und Position, einmal je Tick.
local function scanPlayers()
    local list = {}

    for _, player in pairs(MS.GetPlayers()) do
        local ped = GetPlayerPed(player.source)

        if ped and ped ~= 0 then
            local factionId = RitualWar.FactionOf(player.source)

            if factionId then
                list[#list + 1] = {
                    source = player.source,
                    factionId = factionId,
                    coords = GetEntityCoords(ped),
                }
            end
        end
    end

    return list
end

--- Zaehlt je Fraktion, wer nahe genug am Punkt steht.
local function countAt(point, present)
    local counts = {}

    for _, entry in ipairs(present) do
        if #(entry.coords - point.coords) <= WarConfig.Binding.range then
            counts[entry.factionId] = (counts[entry.factionId] or 0) + 1
        end
    end

    return counts
end

--- Wie viele Mitglieder eine Fraktion fuer die Bindung braucht.
function RitualWar.Binding.NeededMembers(factionId)
    local faction = getFaction(factionId)
    if faction and faction:GetModifiers().soloCapture then return 1 end

    return WarConfig.Binding.minMembers
end

-- Starten und Abbrechen ---------------------------------------------------------

--- Startet ein Bindungsritual.
---@return boolean ok, string grund
function RitualWar.Binding.Start(source)
    if not WarConfig.Binding.enabled then
        return false, 'Bindungsrituale sind abgeschaltet.'
    end

    local player = MS.GetPlayer(source)
    if not player then return false, 'Unbekannter Spieler.' end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, 'Unbekannte Position.' end

    local point = Mystic.IsNearRitualPoint(GetEntityCoords(ped))
    if not point then return false, 'Hier ist kein Ritualpunkt.' end

    local claim = RitualWar.Get(point.id)
    if not claim then return false, 'Dieser Punkt ist nicht bespielbar.' end

    if claim.binding then
        return false, 'An diesem Punkt laeuft bereits eine Bindung.'
    end

    local factionId = RitualWar.FactionOf(source)
    if not factionId then return false, 'Nur Fraktionen koennen binden.' end

    if claim.factionId == factionId then
        return false, 'Dieser Punkt gehoert euch bereits.'
    end

    if claim.protectedUntil > os.time() then
        local minuten = math.ceil((claim.protectedUntil - os.time()) / 60)
        return false, ('Die Bindung haelt noch %d Minuten.'):format(minuten)
    end

    local erlaubt = false
    pcall(function()
        erlaubt = exports['moonshine-factions']:HasPermission(
            source, WarConfig.Binding.permission)
    end)

    if not erlaubt then
        return false, 'Dein Rang darf keine Bindung starten.'
    end

    -- Genug Leute vor Ort? Wir zaehlen sofort, damit niemand die Kasse
    -- leert und dann feststellt, dass er allein dasteht.
    local counts = countAt(point, scanPlayers())
    local anwesend = counts[factionId] or 0
    local noetig = RitualWar.Binding.NeededMembers(factionId)

    if anwesend < noetig then
        return false, ('Ihr braucht %d Mitglieder am Punkt (%d da).'):format(
            noetig, anwesend)
    end

    local faction = getFaction(factionId)
    if not faction then return false, 'Fraktion nicht gefunden.' end

    local kosten = math.floor(WarConfig.Binding.cost)

    if kosten > 0 then
        if not faction:RemoveKasse(kosten, ('Bindung %s'):format(point.label)) then
            return false, ('Die Kasse braucht %s.'):format(
                MS.Utils.FormatMoney(kosten))
        end

        faction:Save()
        faction:Sync()
    end

    claim.binding = {
        factionId = factionId,
        progress  = 0.0,
        contested = false,
        paid      = kosten,
        startedAt = os.time(),
    }

    faction:Notify(('✦ Bindungsritual an %s begonnen.'):format(point.label),
        'warning', 9000)
    faction:Log('gebiet', ('Bindungsritual an %s gestartet.'):format(point.label))

    -- Der Halter merkt, dass an seinem Punkt gearbeitet wird.
    local halter = getFaction(claim.factionId)
    if halter then
        halter:Notify(('⚠ %s wird gebunden - jemand will euren Punkt.'):format(
            point.label), 'error', 12000)
    end

    RitualWar.Broadcast()
    TriggerEvent('ritualwar:server:bindingStarted', point.id, factionId)

    return true, 'Das Ritual laeuft.'
end

--- Bricht eine laufende Bindung ab und zahlt einen Teil zurueck.
function RitualWar.Binding.Cancel(pointId, grund)
    local claim = RitualWar.Get(pointId)
    if not claim or not claim.binding then return false end

    local binding = claim.binding
    local point = Mystic.GetRitualPoint(pointId)
    claim.binding = nil

    local faction = getFaction(binding.factionId)

    if faction then
        local zurueck = math.floor((binding.paid or 0) * (WarConfig.Binding.refund or 0))

        if zurueck > 0 then
            faction:AddKasse(zurueck, 'Bindung abgebrochen')
            faction:Save()
            faction:Sync()
        end

        faction:Notify(('✖ Bindung an %s abgebrochen: %s'):format(
            point and point.label or pointId, grund or 'unterbrochen'), 'error', 9000)

        faction:Log('gebiet', ('Bindung an %s abgebrochen (%s).'):format(
            point and point.label or pointId, grund or 'unterbrochen'))
    end

    RitualWar.Broadcast()
    TriggerEvent('ritualwar:server:bindingCancelled', pointId, binding.factionId)

    return true
end

--- Bricht alles ab, was eine Fraktion gerade bindet.
function RitualWar.Binding.CancelFor(factionId, grund)
    for pointId, claim in pairs(RitualWar.Claims) do
        if claim.binding and claim.binding.factionId == factionId then
            RitualWar.Binding.Cancel(pointId, grund or 'abgebrochen')
        end
    end
end

-- Durchlauf ------------------------------------------------------------------------

local function tick()
    local present = scanPlayers()
    local changed = false
    local schritt = WarConfig.TickInterval

    for _, point in ipairs(MysticConfig.RitualPoints) do
        local claim = RitualWar.Claims[point.id]
        local binding = claim and claim.binding

        if binding then
            local counts = countAt(point, present)
            local eigene = counts[binding.factionId] or 0

            -- Jede andere Fraktion vor Ort haelt das Ritual an.
            local stoerer = 0
            for factionId, count in pairs(counts) do
                if factionId ~= binding.factionId then stoerer = stoerer + count end
            end

            local noetig = RitualWar.Binding.NeededMembers(binding.factionId)
            local vorher = binding.contested

            binding.contested = eigene >= noetig and stoerer > 0
            if binding.contested ~= vorher then changed = true end

            if eigene < noetig then
                -- Die Fraktion steht nicht mehr vollzaehlig da. Das gilt auch,
                -- wenn Gegner den Punkt geraeumt haben - ohne eigene Leute
                -- laeuft nichts.
                binding.progress = binding.progress - WarConfig.Binding.decay * schritt
                changed = true

                if binding.progress <= 0.0 then
                    RitualWar.Binding.Cancel(point.id, 'niemand mehr am Punkt')
                end
            elseif stoerer > 0 then
                -- Gestoert: der Balken steht, faellt aber nicht. Damit sich
                -- ein Ritual nicht ewig festfaehrt, gibt es eine Obergrenze.
                if (os.time() - (binding.startedAt or 0)) > WarConfig.Binding.maxDuration then
                    RitualWar.Binding.Cancel(point.id, 'zu lange gestoert')
                    changed = true
                end
            else
                local faction = getFaction(binding.factionId)
                local speed = 1 + (faction and faction:GetModifiers().captureSpeed or 0)

                binding.progress = binding.progress + RitualWar.ProgressPerSecond() * speed * schritt
                changed = true

                if binding.progress >= 100.0 then
                    RitualWar.Assign(point.id, binding.factionId)

                    pcall(function()
                        exports['moonshine-factions']:AdvanceFactionMission(
                            binding.factionId, 'capture', 1)
                    end)
                end
            end
        end
    end

    if changed then RitualWar.Broadcast() end
end

CreateThread(function()
    while not RitualWar.DB.Ready do Wait(500) end
    Wait(3000)

    while true do
        Wait(TICK)

        if WarConfig.Binding.enabled then
            local ok, err = pcall(tick)

            if not ok then
                print(('^1[Ritualkrieg]^7 Bindungs-Tick fehlgeschlagen: %s'):format(
                    tostring(err)))
            end
        end
    end
end)

--- Loest sich die Fraktion auf, endet auch ihr Ritual.
AddEventHandler('factions:server:disbanded', function(factionId)
    RitualWar.Binding.CancelFor(factionId, 'Fraktion aufgeloest')
end)
