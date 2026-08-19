--- Tuning: der Client waehlt aus, der Server rechnet nach.
---
--- Der Client schickt nur, was er haben will. Was das kostet, rechnet der
--- Server aus seinem eigenen Katalog - sonst baut sich ein manipulierter
--- Client den Motor umsonst ein. Dasselbe gilt fuer Naehe und Besitz.

--- Rabatt fuer Mechaniker.
local function discountFor(player)
    if player.job and player.job.name == ServiceConfig.Repair.mechanicJob then
        return ServiceConfig.Tuning.mechanicDiscount
    end

    return 0
end

--- Darf dieser Spieler an diesem Fahrzeug schrauben?
local function mayModify(source, plate)
    local erlaubt = false
    pcall(function()
        erlaubt = exports['moonshine-vehicles']:MayModify(source, plate)
    end)

    return erlaubt == true
end

--- Die gespeicherten Umbauten eines Fahrzeugs.
local function storedMods(plate)
    local mods = nil
    pcall(function() mods = exports['moonshine-vehicles']:GetMods(plate) end)

    return type(mods) == 'table' and mods or {}
end

--- Was ein Wunsch kostet, gemessen am aktuellen Zustand.
---
--- Bezahlt wird nur, was sich aendert. Wer die Stufe behaelt, zahlt nichts;
--- wer zurueckbaut, bekommt auch nichts wieder.
---@param aktuell table gespeicherte Umbauten
---@param wunsch table was der Spieler angeklickt hat
---@return number preis, table sauber
local function priceFor(aktuell, wunsch)
    local preis = 0
    local sauber = { teile = {} }
    local config = ServiceConfig.Tuning

    -- Teile
    for id, stufe in pairs(type(wunsch.teile) == 'table' and wunsch.teile or {}) do
        local entry = Services.GetPart(id)

        if entry then
            local wert = math.floor(tonumber(stufe) or -1)
            local vorher = math.floor(tonumber((aktuell.teile or {})[tostring(entry.mod)]) or -1)

            if wert >= 0 then
                sauber.teile[tostring(entry.mod)] = wert
                if wert ~= vorher then preis = preis + Services.PartPrice(id, wert) end
            end
        end
    end

    -- Lackierung
    for feld, kosten in pairs({ primaer = config.preise.lack,
                                sekundaer = config.preise.lack,
                                perlmutt = config.preise.perlmutt,
                                felgenfarbe = config.preise.felgenfarbe }) do

        local wert = tonumber(wunsch[feld])

        if wert and Services.IsPaint(math.floor(wert)) then
            wert = math.floor(wert)
            sauber[feld] = wert

            if wert ~= tonumber(aktuell[feld]) then preis = preis + kosten end
        end
    end

    -- Felgenart gehoert zu den Felgen und kostet nichts extra.
    if tonumber(wunsch.felgenart) then
        sauber.felgenart = math.floor(wunsch.felgenart)
    end

    -- Fensterfolie
    local folie = Services.GetTint(math.floor(tonumber(wunsch.folie) or -1))
    if folie then
        sauber.folie = folie.id
        if folie.id ~= tonumber(aktuell.folie) then preis = preis + folie.preis end
    end

    -- Kennzeichenhalter
    local kennzeichen = math.floor(tonumber(wunsch.kennzeichen) or -1)
    if kennzeichen >= 0 and kennzeichen <= 5 then
        sauber.kennzeichen = kennzeichen
        if kennzeichen ~= tonumber(aktuell.kennzeichen) then
            preis = preis + config.preise.kennzeichen
        end
    end

    -- Neon
    if type(wunsch.neon) == 'table' then
        local farbe = Services.GetNeon(wunsch.neon.id)
        local an = wunsch.neon.an == true and farbe ~= nil

        sauber.neon = an
            and { an = true, id = farbe.id, r = farbe.r, g = farbe.g, b = farbe.b }
            or { an = false }

        local vorher = type(aktuell.neon) == 'table' and aktuell.neon or {}
        if an and (vorher.an ~= true or vorher.id ~= farbe.id) then
            preis = preis + config.preise.neon
        end
    end

    -- Xenon
    if type(wunsch.xenon) == 'table' then
        local farbe = math.floor(tonumber(wunsch.xenon.farbe) or -1)
        local an = wunsch.xenon.an == true and Services.IsXenon(farbe)

        sauber.xenon = an and { an = true, farbe = farbe } or { an = false }

        local vorher = type(aktuell.xenon) == 'table' and aktuell.xenon or {}
        if an and (vorher.an ~= true or vorher.farbe ~= farbe) then
            preis = preis + config.preise.xenon
        end
    end

    -- Reifenrauch
    if type(wunsch.rauch) == 'table' then
        local farbe = Services.GetNeon(wunsch.rauch.id)
        local an = wunsch.rauch.an == true and farbe ~= nil

        sauber.rauch = an
            and { an = true, id = farbe.id, r = farbe.r, g = farbe.g, b = farbe.b }
            or { an = false }

        local vorher = type(aktuell.rauch) == 'table' and aktuell.rauch or {}
        if an and (vorher.an ~= true or vorher.id ~= farbe.id) then
            preis = preis + config.preise.rauch
        end
    end

    return preis, sauber
end

--- Der Client fragt vorab, was der Wunsch kostet.
MS.RegisterServerCallback('services:tuningQuote', function(player, cb, plate, wunsch)
    if not player or not ServiceConfig.Tuning.enabled then return cb(nil) end
    if not Services.AtWorkshop(player.source) then return cb(nil) end
    if not mayModify(player.source, plate) then return cb(nil) end

    local preis = priceFor(storedMods(plate), type(wunsch) == 'table' and wunsch or {})
    local rabatt = discountFor(player)

    cb({
        preis   = math.floor(preis * (1 - rabatt)),
        rabatt  = rabatt,
        balance = player:GetMoney(ServiceConfig.Tuning.account),
    })
end)

--- Der Client fragt, was am Fahrzeug schon dran ist.
MS.RegisterServerCallback('services:tuningState', function(player, cb, plate)
    if not player or not ServiceConfig.Tuning.enabled then return cb(nil) end
    if not Services.AtWorkshop(player.source) then return cb(nil) end
    if not mayModify(player.source, plate) then return cb(nil) end

    cb({
        mods    = storedMods(plate),
        balance = player:GetMoney(ServiceConfig.Tuning.account),
        rabatt  = discountFor(player),
        katalog = {
            leistung  = Services.Performance,
            turbo     = Services.Turbo,
            optik     = Services.Cosmetics,
            lacke     = Services.Paints,
            folien    = Services.Tints,
            neon      = Services.Neon,
            xenon     = Services.Xenon,
            preise    = ServiceConfig.Tuning.preise,
        },
        dauer   = ServiceConfig.Tuning.dauer,
    })
end)

--- Einbauen.
RegisterNetEvent('services:server:tune', function(plate, wunsch)
    local source = source
    if not MS.RateLimit(source, 'services:tune', 10, 20) then return end

    local player = MS.GetPlayer(source)
    if not player or not ServiceConfig.Tuning.enabled then return end

    if not Services.AtWorkshop(source) then
        player:Notify('Du stehst an keiner Werkstatt.', 'error')
        return
    end

    if not mayModify(source, plate) then
        player:Notify('Das ist nicht dein Fahrzeug.', 'error')
        return
    end

    local aktuell = storedMods(plate)
    local preis, sauber = priceFor(aktuell, type(wunsch) == 'table' and wunsch or {})

    preis = math.floor(preis * (1 - discountFor(player)))

    if preis <= 0 then
        player:Notify('Daran ist nichts zu tun.', 'info')
        return
    end

    if not player:RemoveMoney(preis, ServiceConfig.Tuning.account, 'tuning') then
        player:Notify(('Der Umbau kostet %s.'):format(
            MS.Utils.FormatMoney(preis)), 'error')
        return
    end

    -- Was der Wunsch nicht anfasst, bleibt wie es war.
    for schluessel, wert in pairs(aktuell) do
        if sauber[schluessel] == nil then sauber[schluessel] = wert end
    end

    local ok = false
    pcall(function()
        ok = exports['moonshine-vehicles']:SetMods(plate, sauber)
    end)

    if not ok then
        -- Nichts angeschraubt, also auch nichts bezahlt.
        player:AddMoney(preis, ServiceConfig.Tuning.account, 'tuning-rueckgabe')
        player:Notify('Der Umbau ist fehlgeschlagen.', 'error')
        return
    end

    player:Notify(('Umbau fuer %s eingebaut.'):format(
        MS.Utils.FormatMoney(preis)), 'success', 8000)

    TriggerClientEvent('services:client:tuned', source, plate, sauber,
        ServiceConfig.Tuning.dauer)

    MS.Logger.Log('fahrzeug', ('%s hat %s fuer %s umgebaut.'):format(
        player.fullname, plate, MS.Utils.FormatMoney(preis)), player.license)

    TriggerEvent('services:server:vehicleTuned', source, plate, preis)
end)
