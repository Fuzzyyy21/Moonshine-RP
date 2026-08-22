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

--- [source] = { count, reasons, gruende, ersteAt, lastAt, sicher, gesehen }
Admin.Strikes = {}

--- [source] = { coords, at, gesetzt, inFolge }
Admin.Positions = {}

--- Wann diese Resource gestartet ist.
---
--- Nach einem Neustart weiss der Wachhund nichts von laufenden
--- Editorsitzungen, Rasten oder Verwandlungen - saemtliche Kulanzen sind
--- weg. In der Schonfrist meldet er deshalb, handelt aber nicht.
Admin.StartedAt = os.time()

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
---@param art string|nil Kategorie: 'ortswechsel', 'schaden', 'herzschlag' ...
function Admin.Flag(source, reason, weight, details, art)
    local config = AdminConfig.Guard
    if not config.enabled then return end

    local player = MS.GetPlayer(source)
    if Admin.Exempt(player) then return end

    art = art or 'sonstiges'

    local jetzt = os.time()
    local entry = Admin.Strikes[source]

    if not entry then
        entry = { count = 0, reasons = {}, arten = {}, gesehen = {},
                  ersteAt = jetzt, lastAt = jetzt }
        Admin.Strikes[source] = entry
    end

    -- Dieselbe Art Verdacht zaehlt nur einmal je Sperrzeit.
    --
    -- Ohne diese Bremse ist ein haengender Zustand ein Dauerfeuer: die
    -- Beobachtung laeuft alle 6 Sekunden und meldet denselben Fund immer
    -- wieder. Mit Gewicht 4 waere ein Spieler nach zwoelf Sekunden drueber -
    -- fuer etwas, das er nicht getan hat.
    --
    -- Gesperrt wird auf die Art, nicht auf den Text: "Ortswechsel 412 m" und
    -- "Ortswechsel 500 m" sind zwei Texte, aber derselbe Verdacht.
    if not Admin.MeldungZaehlt(entry.gesehen[art], jetzt, config.meldeSperre) then
        return
    end

    entry.gesehen[art] = jetzt

    -- Verfall zuerst: sonst zaehlt eine Stunde alter Verdacht noch mit.
    entry.count = Admin.Verfall(entry.count, entry.lastAt, jetzt, config.decay)

    entry.count = entry.count + (weight or 1)
    entry.lastAt = jetzt
    entry.arten[art] = true
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
---
--- Entschieden wird das nicht hier, sondern in Admin.Massnahme - einer
--- reinen Rechnung, die tools/testen.lua ohne FXServer durchspielen kann.
--- Diese Funktion fuehrt nur aus, was dort herauskommt.
function Admin.Enforce(source, entry)
    local config = AdminConfig.Guard

    local massnahme, grund = Admin.Massnahme(entry, os.time(), config,
        Admin.StartedAt)

    if massnahme == 'nichts' then
        if AdminConfig.Debug and grund then
            print(('^3[Wachhund]^7 %d: keine Massnahme (%s)'):format(source, grund))
        end
        return
    end

    local player = MS.GetPlayer(source)
    local name = player and player.fullname or ('Spieler ' .. source)
    local reason = ('Wachhund: %s'):format(entry.reasons[#entry.reasons] or 'Auffaellig')

    if massnahme == 'probelauf' then
        print(('^3[Wachhund]^7 PROBELAUF: %s haette jetzt %s bekommen (%d Strikes: %s).')
            :format(name, config.action, entry.count,
                table.concat(entry.reasons, ', ')))

        -- Zaehler zuruecksetzen, sonst meldet er das bei jedem weiteren
        -- Verdacht erneut.
        Admin.ClearStrikes(source)
        return
    end

    if massnahme == 'melden' then
        -- Nicht bei jeder Meldung neu in die Konsole schreiben.
        if Admin.MeldungZaehlt(entry.gemeldetAt, os.time(), config.meldeSperre) then
            entry.gemeldetAt = os.time()

            print(('^3[Wachhund]^7 %s ueber der Schwelle%s (%d Strikes: %s).')
                :format(name, grund and (' - ' .. grund) or '', entry.count,
                    table.concat(entry.reasons, ', ')))
        end

        -- Zurueckgesetzt wird nur im reinen Meldebetrieb.
        --
        -- Steht die Meldung dagegen nur an, weil bisher eine einzige Art
        -- aufgelaufen ist, bleiben die Strikes stehen: kommt spaeter ein
        -- zweiter, ganz anderer Verdacht dazu, soll das sofort greifen und
        -- nicht bei null anfangen.
        if config.action == 'log' then Admin.ClearStrikes(source) end
        return
    end

    if massnahme == 'kick' then
        -- Wer nur wegen der fehlenden Sicherheit nicht gebannt wird, soll
        -- trotzdem nachlesbar sein: ein Admin entscheidet das, nicht der
        -- Wachhund.
        if config.action == 'ban' then
            print(('^3[Wachhund]^7 %s: Bann NICHT gesetzt (%s). Rausgeworfen, '
                .. 'Vorgeschichte mit /verdacht %d.'):format(name, grund or '?', source))
        end

        Admin.ClearStrikes(source)
        DropPlayer(source, reason)
        return
    end

    if massnahme == 'ban' then
        -- Ueber alle Kennungen, nicht nur die Lizenz: ein neuer
        -- Rockstar-Account allein soll den Bann nicht abstreifen. Die IP
        -- bleibt aussen vor - dahinter steckt ein Anschluss, keine Person.
        local gesetzt = 0
        pcall(function()
            gesetzt = MS.Bans.Ban(source, reason, config.banHours, 'Wachhund',
                config.bannOhneIp)
        end)

        if gesetzt == 0 and player then
            -- Der alte Weg als Rueckfall, damit im Zweifel wenigstens die
            -- Lizenz gesperrt ist.
            pcall(function()
                MS.DB.SetBan(player.license, true, reason,
                    os.time() + config.banHours * 3600)
            end)
        end

        Admin.ClearStrikes(source)
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
---
--- Drei Dinge haben hier vorher Unschuldige getroffen:
---
---   1. Die erste Messung galt sofort als verlaesslich. Beim Verbinden
---      steht das Ped aber noch bei (0,0,0) - die naechste Messung war dann
---      ein Sprung ueber die halbe Karte.
---   2. Das Budget zu Fuss war fest. Wer aus einem Flugzeug springt, faellt
---      rund 50 m in der Sekunde; haengt der Server einmal, sind aus fuenf
---      Sekunden acht - und der Fallschirmspringer war ein Teleporter.
---   3. Ein einzelner Ausreisser reichte. Aufzug, Innenraum, Nachladeruck.
CreateThread(function()
    while true do
        Wait(AdminConfig.Guard.movement.interval * 1000)

        local config = AdminConfig.Guard.movement

        if AdminConfig.Guard.enabled and config.enabled then
            for _, player in pairs(MS.GetPlayers()) do
                if not exempt(player) then
                    local source = player.source
                    local ped = GetPlayerPed(source)

                    if ped and ped ~= 0 then
                        local coords = GetEntityCoords(ped)

                        -- Ein Ped am Nullpunkt ist kein Ort, sondern ein
                        -- Ped, das noch nicht da ist. Damit wird nicht
                        -- gerechnet - und die naechste Messung bekommt
                        -- keinen Sprung untergeschoben.
                        if #(coords - vector3(0.0, 0.0, 0.0)) < 1.0 then
                            Admin.Positions[source] = nil
                        else
                            local last = Admin.Positions[source]
                            local inVehicle = GetVehiclePedIsIn(ped, false) ~= 0
                            local inFolge = 0

                            if last then
                                local elapsed = math.max(1, os.time() - last.at)
                                local distance = #(coords - last.coords)

                                local auffaellig, grenze = Admin.OrtswechselAuffaellig(
                                    distance, elapsed, inVehicle, config)

                                if auffaellig and not IsEntityDead(ped)
                                    and not Admin.IsAllowed(source, 'teleport') then
                                    inFolge = (last.inFolge or 0) + 1

                                    -- Erst wenn es wieder passiert. Ein
                                    -- Teleport-Cheat springt nicht einmal.
                                    if inFolge >= (config.inFolge or 1) then
                                        Admin.Flag(source,
                                            ('Ortswechsel %d m in %d s'):format(
                                                math.floor(distance), elapsed),
                                            config.gewicht,
                                            { meter = math.floor(distance),
                                              sekunden = elapsed,
                                              grenze = math.floor(grenze),
                                              inFolge = inFolge,
                                              imFahrzeug = inVehicle },
                                            'ortswechsel')

                                        inFolge = 0
                                    end
                                end
                            end

                            Admin.Positions[source] = {
                                coords = coords, at = os.time(), inFolge = inFolge,
                            }
                        end
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

        for source, entry in pairs(Admin.Strikes) do
            local stand = Admin.Verfall(entry.count, entry.lastAt, now,
                AdminConfig.Guard.decay)

            if stand <= 0 then
                Admin.Strikes[source] = nil
            elseif stand < entry.count then
                -- lastAt mitziehen, sonst faellt beim naechsten Durchgang
                -- derselbe Zeitraum noch einmal an.
                entry.lastAt = entry.lastAt
                    + (entry.count - stand) * math.max(1, AdminConfig.Guard.decay) * 60
                entry.count = stand
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

-- Nachsehen, was der Wachhund gerade tut ------------------------------------------
--
-- Vor dem Scharfstellen die wichtigste Frage: was WUERDE passieren? Der
-- Probelauf schreibt das in die Konsole, aber nur wenn jemand ueber die
-- Schwelle geht. Dieser Befehl zeigt den Stand jederzeit.

RegisterCommand('wachhund', function(source, args)
    local player = source > 0 and MS.GetPlayer(source) or nil
    local level = source == 0 and 4 or (player and player.adminLevel or 0)

    if level < 3 then return end

    local config = AdminConfig.Guard

    -- Umschalten darf nur Level 4. Nachsehen reicht Level 3.
    if args and (args[1] == 'an' or args[1] == 'aus') then
        if level < 4 then
            if player then player:Notify('Dafuer fehlt dir das Level.', 'error') end
            return
        end

        config.enabled = args[1] == 'an'

        local text = ('Wachhund ist %s.'):format(
            config.enabled and 'aktiv' or 'abgeschaltet')

        if player then player:Notify(text, 'info') else print(text) end

        MS.Logger.Log('admin', text, player and player.license or nil)
        return
    end

    local zeilen = {}

    local function zeile(text) zeilen[#zeilen + 1] = text end

    zeile(('Wachhund: %s, Probelauf %s, Massnahme %s ab %d Strikes'):format(
        config.enabled and 'an' or 'AUS',
        config.probelauf and 'AN (nichts wird durchgesetzt)' or 'aus',
        config.action, config.schwelle))

    zeile(('Bremsen: dieselbe Art alle %ds, mindestens %d Arten, %ds Spanne'):format(
        config.meldeSperre, config.mindestGruende, config.mindestSpanne))

    if config.action == 'ban' then
        zeile(('Bann erst ab %d Strikes und nur mit sicherem Fund, ohne IP: %s'):format(
            config.bannSchwelle, config.bannOhneIp and 'ja' or 'NEIN'))
    end

    local seitStart = os.time() - Admin.StartedAt
    if seitStart < config.startKarenz then
        zeile(('Schonfrist nach dem Start laeuft noch %d Sekunden.'):format(
            config.startKarenz - seitStart))
    end

    -- Wer steht gerade wo?
    local offen = 0

    for quelle, entry in pairs(Admin.Strikes) do
        local ziel = MS.GetPlayer(quelle)
        local arten = {}
        for art in pairs(entry.arten or {}) do arten[#arten + 1] = art end

        local massnahme = Admin.Massnahme(entry, os.time(), config, Admin.StartedAt)

        zeile(('  %s (%d): %d Strikes [%s] -> %s'):format(
            ziel and ziel.fullname or ('Spieler ' .. quelle), quelle,
            entry.count, table.concat(arten, ', '), massnahme))

        offen = offen + 1
    end

    if offen == 0 then zeile('  Niemand ist gerade auffaellig.') end

    -- Laufende Kulanzen: die haeufigste Ursache fuer "warum meldet der nicht".
    for quelle, eintrag in pairs(Admin.Allowed or {}) do
        local arten = {}
        for art, bis in pairs(eintrag) do
            if bis > os.time() then
                arten[#arten + 1] = ('%s (%ds)'):format(art, bis - os.time())
            end
        end

        if #arten > 0 then
            zeile(('  Kulanz %d: %s'):format(quelle, table.concat(arten, ', ')))
        end
    end

    if player then
        for _, text in ipairs(zeilen) do player:Notify(text, 'info', 12000) end
    else
        print('^3[Wachhund]^7 ' .. table.concat(zeilen, '\n           '))
    end
end, false)
