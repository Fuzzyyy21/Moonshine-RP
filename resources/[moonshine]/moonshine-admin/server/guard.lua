--- Anticheat: Meldungen, Strikes, Massnahmen.
---
--- Der Wachhund steht auf vier Schichten:
---
---   1. Beobachtung (server/watch.lua)   - der Server liest Leben, Weste
---      und Waffe selbst vom Ped ab, statt den Client zu fragen
---   2. Ortswechsel (hier)               - Sprunge und Geschwindigkeit
---   3. Spielereignisse (server/events.lua) - was FiveM dem Server von
---      selbst meldet: Explosionen, Schaden, erzeugte Objekte
---   4. Beweise (server/evidence.lua)    - jede Meldung landet in ms_flags
---
--- Diese Datei haelt nur die Strikes zusammen und setzt die Massnahme um.
--- Ein Fehlalarm soll niemanden aus dem Spiel werfen, deshalb sammelt der
--- Wachhund erst und handelt dann.

MS = MS or exports['moonshine-core']:GetCoreObject()

Admin.Strikes = {}     -- [source] = { count, reasons, lastAt }
Admin.Positions = {}   -- [source] = { coords, at }

--- Ist dieser Spieler von der Pruefung ausgenommen?
function Admin.Exempt(player)
    if not player then return true end
    return (player.adminLevel or 0) >= AdminConfig.Guard.exemptLevel
end

--- Kurzform fuer diese Datei.
local exempt = Admin.Exempt

--- Meldet einen Verdacht.
---@param source number
---@param reason string
---@param weight number|nil Wie schwer der Verdacht wiegt
---@param details table|nil Was genau gemessen wurde - kommt in die Beweise
function Admin.Flag(source, reason, weight, details)
    if not AdminConfig.Guard.enabled then return end

    local player = MS.GetPlayer(source)
    if Admin.Exempt(player) then return end

    local entry = Admin.Strikes[source]

    if not entry then
        entry = { count = 0, reasons = {}, lastAt = os.time() }
        Admin.Strikes[source] = entry
    end

    entry.count = entry.count + (weight or 1)
    entry.lastAt = os.time()
    entry.reasons[#entry.reasons + 1] = reason

    while #entry.reasons > 10 do table.remove(entry.reasons, 1) end

    local name = player and ('%s %s'):format(player.firstname, player.lastname)
        or ('Spieler %d'):format(source)

    print(('^3[Wachhund]^7 %s (%d): %s [%d Strikes]'):format(
        name, source, reason, entry.count))

    if player then
        MS.Logger.Log('anticheat', ('%s: %s (%d Strikes)'):format(
            name, reason, entry.count), player.license)
    end

    -- In die Beweiskette, damit ein Admin spaeter die Vorgeschichte sieht.
    if Admin.Evidence then
        Admin.Evidence.Add(player, reason, weight or 1, entry.count, details)
    end

    TriggerEvent('admin:server:flagged', source, reason, entry.count)

    -- Admins im Dienst bekommen es mit.
    for _, other in pairs(MS.GetPlayers()) do
        if (other.adminLevel or 0) >= 2 then
            other:Notify(('Wachhund: %s (%d) - %s'):format(name, source, reason),
                'warning', 8000)
        end
    end

    Admin.Enforce(source, entry)
end

--- Setzt die konfigurierte Massnahme um.
function Admin.Enforce(source, entry)
    local config = AdminConfig.Guard

    -- Stand frueher als 6 fest im Code, obwohl daneben eine Config lag.
    if entry.count < (config.schwelle or 6) then return end

    local reason = ('Wachhund: %s'):format(entry.reasons[#entry.reasons] or 'Auffaellig')

    if config.action == 'kick' then
        Admin.Strikes[source] = nil
        DropPlayer(source, reason)

    elseif config.action == 'ban' then
        local player = MS.GetPlayer(source)

        if player then
            pcall(function()
                MS.DB.SetBan(player.license, true, reason,
                    os.time() + config.banHours * 3600)
            end)
        end

        Admin.Strikes[source] = nil
        DropPlayer(source, reason)
    end
end

--- Strikes eines Spielers.
function Admin.GetStrikes(source)
    local entry = Admin.Strikes[source]
    return entry and entry.count or 0
end

function Admin.ClearStrikes(source)
    Admin.Strikes[source] = nil
end

-- Ratenbegrenzung ----------------------------------------------------------------

--- Die Begrenzung rechnet der Core.
---
--- Sie lag frueher hier. Das war falsch herum: moonshine-admin startet als
--- letzte Resource, und bis dahin waren saemtliche Limits im ganzen
--- Framework aus. Jetzt kommt hier nur noch die Meldung an, wenn jemand
--- wiederholt darueber geht - Admin.Flag ruft der Core selbst.
---@return boolean allowed
function Admin.RateLimit(source, key, max, windowSeconds)
    return MS.RateLimit(source, key, max, windowSeconds)
end

-- Meldungen vom Client -------------------------------------------------------------
--
-- Es gibt keine mehr. Frueher schickte der Client alle zwoelf Sekunden
-- Leben, Weste und Waffe an den Server, und der Server glaubte ihm. Wer
-- cheatet, schickt eben saubere Werte - oder gar keine, dann faellt es
-- ueberhaupt nicht auf. Das liest jetzt server/watch.lua selbst.

--- Positionspruefung laeuft serverseitig, damit sie nicht manipulierbar ist.
CreateThread(function()
    while true do
        Wait(AdminConfig.Guard.movement.interval * 1000)

        if AdminConfig.Guard.enabled and AdminConfig.Guard.movement.enabled then
            for _, player in pairs(MS.GetPlayers()) do
                if not exempt(player) then
                    local source = player.source
                    local ped = GetPlayerPed(source)

                    if ped and ped ~= 0 then
                        local coords = GetEntityCoords(ped)
                        local last = Admin.Positions[source]
                        local inVehicle = GetVehiclePedIsIn(ped, false) ~= 0

                        if last then
                            local elapsed = math.max(1, os.time() - last.at)
                            local distance = #(coords - last.coords)
                            local speed = distance / elapsed

                            local limit = inVehicle
                                and AdminConfig.Guard.movement.maxSpeed
                                or (AdminConfig.Guard.movement.maxJump / elapsed)

                            -- Tote und frisch geladene Spieler nicht melden.
                            if speed > limit and not IsEntityDead(ped)
                                and last.settled then
                                Admin.Flag(source, ('Ortswechsel %d m in %d s'):format(
                                    math.floor(distance), elapsed),
                                    AdminConfig.Guard.movement.gewicht,
                                    { meter = math.floor(distance),
                                      sekunden = elapsed,
                                      imFahrzeug = inVehicle })
                            end
                        end

                        Admin.Positions[source] = {
                            coords = coords, at = os.time(), settled = true,
                        }
                    end
                end
            end
        end
    end
end)

-- Aufraeumen ---------------------------------------------------------------------------

--- Strikes verfallen mit der Zeit.
CreateThread(function()
    while true do
        Wait(60000)

        local now = os.time()
        local decay = AdminConfig.Guard.decay * 60

        for source, entry in pairs(Admin.Strikes) do
            if now - entry.lastAt > decay then
                entry.count = entry.count - 1
                entry.lastAt = now

                if entry.count <= 0 then Admin.Strikes[source] = nil end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    Admin.Strikes[source] = nil
    Admin.Positions[source] = nil
end)

--- Nach einem Teleport durch einen Admin nicht sofort melden.
AddEventHandler('admin:server:teleported', function(source)
    Admin.Positions[source] = nil
end)

AddEventHandler('moonshine:server:playerLoaded', function(source)
    Admin.Positions[source] = nil
    Admin.Strikes[source] = nil
end)
