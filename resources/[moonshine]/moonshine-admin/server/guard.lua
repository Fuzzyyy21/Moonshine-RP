--- Anticheat-Grundlagen.
---
--- Bewusst zurueckhaltend: der Wachhund meldet und sammelt Strikes, statt
--- sofort zu kicken. Ein Fehlalarm soll niemanden aus dem Spiel werfen.
---
--- Andere Resources koennen die Ratenbegrenzung mitbenutzen:
---
---   if not exports['moonshine-admin']:RateLimit(source, 'shop:buy', 10, 5) then
---       return
---   end

MS = MS or exports['moonshine-core']:GetCoreObject()

Admin.Strikes = {}     -- [source] = { count, reasons, lastAt }
Admin.Positions = {}   -- [source] = { coords, at }
Admin.Rates = {}       -- [source] = { [key] = { count, until } }

--- Ist dieser Spieler von der Pruefung ausgenommen?
local function exempt(player)
    if not player then return true end
    return (player.adminLevel or 0) >= AdminConfig.Guard.exemptLevel
end

--- Meldet einen Verdacht.
---@param source number
---@param reason string
---@param weight number|nil Wie schwer der Verdacht wiegt
function Admin.Flag(source, reason, weight)
    if not AdminConfig.Guard.enabled then return end

    local player = MS.GetPlayer(source)
    if exempt(player) then return end

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
    if entry.count < 6 then return end

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

--- Prueft und zaehlt einen Aufruf.
---@return boolean allowed
function Admin.RateLimit(source, key, max, windowSeconds)
    if not AdminConfig.Guard.enabled or not AdminConfig.Guard.rateLimit.enabled then
        return true
    end

    local player = MS.GetPlayer(source)
    if exempt(player) then return true end

    max = max or AdminConfig.Guard.rateLimit.defaultMax
    windowSeconds = windowSeconds or AdminConfig.Guard.rateLimit.defaultWindow

    local buckets = Admin.Rates[source]
    if not buckets then
        buckets = {}
        Admin.Rates[source] = buckets
    end

    local now = os.time()
    local bucket = buckets[key]

    if not bucket or bucket.resetAt <= now then
        buckets[key] = { count = 1, resetAt = now + windowSeconds, warned = 0 }
        return true
    end

    bucket.count = bucket.count + 1

    if bucket.count <= max then return true end

    bucket.warned = bucket.warned + 1

    if bucket.warned >= AdminConfig.Guard.rateLimit.strikes then
        bucket.warned = 0
        Admin.Flag(source, ('Zu viele Aufrufe von "%s"'):format(key), 2)
    end

    return false
end

-- Meldungen vom Client -------------------------------------------------------------

--- Der Client meldet Leben, Weste, Position und Waffen.
RegisterNetEvent('admin:server:report', function(payload)
    local source = source
    local player = MS.GetPlayer(source)
    if not player or exempt(player) or type(payload) ~= 'table' then return end

    local config = AdminConfig.Guard

    -- Leben und Weste.
    if config.health.enabled then
        local allowed = 200 + config.health.tolerance

        -- Klassenboni erhoehen das Maximum.
        pcall(function()
            local mods = exports['moonshine-mystic']:GetModifiers(source)
            if mods and mods.healthBonus then allowed = allowed + mods.healthBonus end
        end)

        if (tonumber(payload.health) or 0) > allowed then
            Admin.Flag(source, ('Zu viel Leben (%d von %d)'):format(
                payload.health, allowed), 2)
        end

        if (tonumber(payload.armour) or 0) > config.health.maxArmour then
            Admin.Flag(source, ('Zu viel Weste (%d)'):format(payload.armour), 2)
        end
    end

    -- Waffen.
    if config.weapons.enabled and type(payload.weapon) == 'string' then
        for _, name in ipairs(config.weapons.blacklist) do
            if payload.weapon == name then
                Admin.Flag(source, ('Gesperrte Waffe: %s'):format(name), 3)
                TriggerClientEvent('admin:client:stripWeapon', source, name)
                break
            end
        end
    end
end)

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
                                    math.floor(distance), elapsed), 1)
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
    Admin.Rates[source] = nil
end)

--- Nach einem Teleport durch einen Admin nicht sofort melden.
AddEventHandler('admin:server:teleported', function(source)
    Admin.Positions[source] = nil
end)

AddEventHandler('moonshine:server:playerLoaded', function(source)
    Admin.Positions[source] = nil
    Admin.Strikes[source] = nil
end)
