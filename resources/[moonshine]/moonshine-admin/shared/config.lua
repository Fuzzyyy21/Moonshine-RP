--- Administration und Anticheat.

Admin = Admin or {}

AdminConfig = {}

AdminConfig.Debug = false

--- Ab welchem Adminlevel das Panel offen steht.
AdminConfig.PanelLevel = 2

--- Taste und Command.
AdminConfig.OpenKey = 'F9'
AdminConfig.Command = 'admin'

--- Welches Level welche Aktion darf.
--- Hinweis: "goto" ist in Lua 5.4 ein Schluesselwort, daher tpTo/tpHere.
AdminConfig.Actions = {
    tpTo       = 2,
    tpHere     = 2,
    spectate   = 2,
    heal       = 2,
    revive     = 2,
    freeze     = 2,
    kick       = 2,
    warn       = 2,
    noclip     = 2,
    invisible  = 2,
    setjob     = 3,
    givemoney  = 3,
    giveitem   = 3,
    ban        = 3,
    setrace    = 3,
    setmoney   = 4,
    setadmin   = 4,
    unban      = 3,
}

-- Anticheat ----------------------------------------------------------------------
AdminConfig.Guard = {
    enabled = true,

    -- Ab diesem Adminlevel wird niemand mehr geprueft.
    exemptLevel = 3,

    -- So viele Strikes, bevor die Massnahme greift. Stand frueher fest im
    -- Code, obwohl daneben eine Config lag.
    schwelle = 6,

    -- Die drei Bremsen gegen Fehlkicks --------------------------------------
    --
    -- Ohne sie reicht *ein* haengender Zustand fuer einen Rauswurf. Die
    -- Beobachtung laeuft alle 6 Sekunden; bleibt ein Spieler durch einen
    -- Fehler in irgendeinem Skript unverwundbar, meldet sie das mit Gewicht
    -- 4 im Sechssekundentakt. Nach zwoelf Sekunden waere er drueber - fuer
    -- etwas, das er nicht getan hat.

    -- 1. Dieselbe Meldung zaehlt nur einmal je Sperrzeit (Sekunden).
    --    Ein haengender Zustand ist damit ein Strike alle zwei Minuten,
    --    kein Dauerfeuer.
    meldeSperre = 120,

    -- 2. Es braucht mindestens so viele *verschiedene* Arten von Verdacht.
    --    Ein einzelner falsch eingestellter Grenzwert kann damit niemanden
    --    mehr aus dem Spiel werfen - dazu muesste ein zweiter, ganz anderer
    --    Verdacht dazukommen.
    --
    --    Wer nur in einer Art auffaellt, wird trotzdem gemeldet: Konsole,
    --    ms_flags und alle Admins im Dienst. Nur die Massnahme bleibt aus.
    --    Sonst waere der Preis zu hoch - wer ausschliesslich teleportiert,
    --    faellt in genau eine Art und kaeme ewig durch.
    mindestGruende = 2,

    -- 3. Zwischen der ersten und der letzten Meldung muessen so viele
    --    Sekunden liegen. Ein Ausbruch innerhalb weniger Sekunden - Laderuck,
    --    Resource-Neustart, ein Skript das kurz Unsinn macht - ist damit nie
    --    eine Massnahme, egal wie viele Strikes dabei zusammenkommen.
    mindestSpanne = 60,

    -- Schonfrist nach dem Start dieser Resource (Sekunden).
    --
    -- Beim Neustart weiss der Wachhund nichts von laufenden Editorsitzungen,
    -- Rasten oder Verwandlungen - alle Kulanzen sind weg. In dieser Zeit
    -- meldet er, handelt aber nicht.
    startKarenz = 90,

    -- Probelauf.
    --
    -- Steht das auf true, meldet der Wachhund alles, handelt aber nie. Kein
    -- Kick, kein Bann - nur Konsole, ms_logs und ms_flags.
    --
    -- Ab Werk an, und das mit Absicht: keine dieser Pruefungen lief je auf
    -- einem echten Server. Erst ein paar Tage mitlesen, dann abschalten.
    -- Ein Wachhund, der die eigenen Spieler kickt, ist schlimmer als keiner.
    probelauf = true,

    -- Was dann passiert: 'log' | 'kick' | 'ban'
    --
    -- 'ban' ist bewusst schwerer zu erreichen als es aussieht. Ein Bann ist
    -- die einzige Massnahme, die ein Spieler nicht einfach durch erneutes
    -- Verbinden loswird - ein Fehlbann kostet einen echten Spieler. Deshalb
    -- gelten dafuer zwei zusaetzliche Bedingungen (siehe bannSchwelle und
    -- Admin.Massnahme): eine hoehere Schwelle, und mindestens ein Verdacht
    -- aus der Kategorie "sicher".
    action = 'kick',
    banHours = 72,

    -- Eigene, hoehere Schwelle fuer den Bann.
    bannSchwelle = 12,

    -- Welche Kategorien fuer einen Bann taugen.
    --
    -- Nur was normales Spiel nie ausloest: Schaden, den keine Waffe
    -- anrichtet, ein Panzer aus dem Nichts, ein Cheatmenue-Ereignis.
    --
    -- Alles andere ist ein Hinweis. Ein Ortswechsel kann ein Aufzug sein,
    -- ein fehlender Herzschlag eine Leitung, zu viel Leben ein Bonus, den
    -- der Wachhund nicht kennt, ein fremdes Modell eine Verwandlung. Solche
    -- Funde werfen jemanden raus - sperren duerfen sie ihn nicht.
    sichereArten = {
        schaden  = true,
        entitaet = true,
        ereignis = true,
    },

    -- Ein automatischer Bann geht nie ueber die IP.
    --
    -- Hinter einer IP steckt ein Anschluss, keine Person: Wohngemeinschaft,
    -- Studentenwohnheim, Mobilfunk. Ein Admin darf das von Hand tun, wenn er
    -- weiss was er tut. Der Wachhund nicht.
    bannOhneIp = true,

    -- Strikes verfallen nach dieser Zeit (Minuten).
    --
    -- Gemeint ist: je <decay> Minuten ohne neue Meldung faellt ein Strike
    -- weg. Frueher fiel ueberhaupt nichts weg, solange ein Spieler
    -- regelmaessig auflief - der Zaehler kannte nur eine Richtung.
    decay = 10,

    -- Discord-Webhook fuer Meldungen (leer = nur Serverkonsole und ms_logs).
    webhook = '',

    -- Schicht 1: Beobachtung ---------------------------------------------------
    --- Der Server liest Leben, Weste und Waffe selbst vom Ped ab.
    ---
    --- Frueher meldete das der Client von sich aus. Das ist genau die
    --- falsche Richtung: wer cheatet, meldet eben saubere Werte oder gar
    --- nichts. Der Server kann all das selbst lesen.
    beobachtung = {
        enabled  = true,
        interval = 6,           -- Sekunden zwischen zwei Durchgaengen

        -- Leben und Weste: mehr als das ist nicht vorgesehen.
        maxLeben   = 200,
        lebenPuffer = 60,       -- Klassenboni koennen das Maximum heben
        maxWeste   = 105,
        gewicht    = 2,

        -- Unverwundbarkeit fragt der Server direkt ab. Der direkteste
        -- Godmode-Fund, den es gibt.
        godmode = true,
        godmodeGewicht = 4,

        -- Spielermodelle. Wer als Panzer oder Tier herumlaeuft, hat sich
        -- das nicht im Charaktereditor ausgesucht.
        --
        -- Die Liste bleibt bewusst kurz: alles andere ist verdaechtig. Wer
        -- eigene Modelle einbaut (Job-Uniformen als eigenes Ped, Tiere fuer
        -- Verwandlungen), traegt sie hier nach - sonst laeuft der Wachhund
        -- gegen die eigenen Leute.
        modelle = true,
        modellGewicht = 3,
        erlaubteModelle = {
            'mp_m_freemode_01', 'mp_f_freemode_01',
        },

        -- Gesperrte Waffen werden sofort entfernt.
        waffen = {
            enabled = true,
            gewicht = 3,
            gesperrt = {
                'WEAPON_RAILGUN', 'WEAPON_MINIGUN', 'WEAPON_RPG',
                'WEAPON_GRENADELAUNCHER', 'WEAPON_GRENADELAUNCHER_SMOKE',
                'WEAPON_FIREWORK', 'WEAPON_HOMINGLAUNCHER',
                'WEAPON_COMPACTLAUNCHER', 'WEAPON_RAYMINIGUN',
                'WEAPON_RAYPISTOL', 'WEAPON_RAYCARBINE',
                'WEAPON_STINGER', 'WEAPON_PIPEBOMB', 'WEAPON_PROXMINE',
            },
        },
    },

    -- Schicht 2: Ortswechsel -------------------------------------------------------
    movement = {
        enabled = true,
        maxSpeed = 190.0,       -- Meter je Sekunde im Fahrzeug
        maxJump  = 300.0,       -- Sprung zu Fuss in einem Durchgang
        maxFall  = 75.0,        -- Meter je Sekunde im freien Fall

        -- Wie oft ein Spieler in Folge auffallen muss.
        --
        -- Ein Fallschirmsprung, ein Aufzug, ein nachgeladener Innenraum:
        -- das sind einzelne Ausreisser. Ein Teleport-Cheat ist es nicht -
        -- der springt wieder und wieder.
        inFolge  = 2,

        interval = 5,
        gewicht  = 1,
    },

    -- Schicht 3: Spielereignisse -------------------------------------------------------
    --- FiveM meldet dem Server, was Clients im Spiel ausloesen. Das laesst
    --- sich nicht faelschen und nicht abschalten - es ist die verlaesslichste
    --- Quelle, die es gibt.

    --- Explosionen.
    ---
    --- Die Nummern sind die Explosionstypen aus GTA. Sie stehen hier
    --- bewusst als Sperrliste und die Massnahme steht auf 'melden': eine
    --- falsche Nummer wuerde sonst Spieler aus dem Spiel werfen, die nichts
    --- getan haben. Vor dem Scharfstellen einmal im Log nachsehen, was
    --- tatsaechlich auflaeuft.
    explosionen = {
        enabled = true,
        aktion  = 'melden',     -- 'melden' | 'abbrechen'
        gewicht = 4,

        gesperrt = {
            [36] = 'Railgun',
            [41] = 'Valkyrie-Kanone',
            [42] = 'Flugabwehr',
            [59] = 'Orbitalkanone',
            [70] = 'Raygun',
        },
    },

    --- Waffenschaden. Der Server sieht jeden Treffer.
    schaden = {
        enabled = true,
        gewicht = 3,

        -- Mehr Schaden als das kann keine Waffe im Spiel anrichten. Dieser
        -- Fund ist eindeutig - er darf abbrechen und zaehlt als "sicher".
        maxSchaden = 250,

        -- Treffer ueber diese Entfernung sind keine mehr (Meter).
        --
        -- Vorher standen hier 500 und der Treffer wurde abgebrochen. Das
        -- war zu eng: eine Heavy Sniper vom Mount Chiliad kommt weiter, und
        -- der Abbruch haette dem Schuetzen den Treffer weggenommen. Jetzt
        -- 1200 m und nur eine Meldung - Entfernung allein ist ein Hinweis,
        -- kein Beweis.
        maxEntfernung = 1200.0,
        entfernungAbbrechen = false,
    },

    --- Fahrzeuge und andere Objekte, die niemand erzeugen sollte.
    entitaeten = {
        enabled = true,
        aktion  = 'abbrechen',  -- 'melden' | 'abbrechen'
        gewicht = 4,

        gesperrteModelle = {
            'rhino', 'khanjali', 'chernobog', 'thruster', 'hydra',
            'lazer', 'savage', 'valkyrie', 'akula', 'annihilator',
            'oppressor', 'oppressor2', 'scramjet', 'deluxo',
            'apc', 'insurgent3', 'halftrack', 'barrage', 'minitank',
        },
    },

    --- Ereignisse, die auf ein Cheatmenue hindeuten.
    --- Achtung: zwei dieser drei Ereignisse loest auch der eigene Server aus.
    ---
    --- clearPedTasks feuert bei jedem ClearPedTasks() - und das steht bei
    --- uns an vierzehn Stellen: Tod, Wiederbelebung, Ritual, Tanken,
    --- Reparieren, Charaktereditor. Scharf gestellt bricht die Pruefung
    --- genau diese Aufrufe ab und verteilt dafuer Strafpunkte.
    ---
    --- giveWeapon feuert, wenn moonshine-boss dem Endgegner seine Waffe
    --- gibt. Das laeuft ueber den Client, der den Gegner besitzt - also
    --- ueber einen ganz normalen Spieler.
    ---
    --- Beide stehen deshalb auf false. Wer sie einschaltet, muss vorher die
    --- eigenen Aufrufe kennen. removeAllWeapons ruft bei uns niemand auf -
    --- das bleibt an.
    ereignisse = {
        enabled = true,
        gewicht = 3,

        giveWeapon        = false,
        removeAllWeapons  = true,
        clearPedTasks     = false,
    },

    -- Schicht 5: Herzschlag -------------------------------------------------------
    --- Die groesste Luecke eines Anticheats in reinem Lua: ein Cheatmenue
    --- kann die clientseitigen Skripte anhalten. Danach ist der Spieler
    --- unsichtbar fuer alles, was vom Client kommt.
    ---
    --- Dagegen hilft nur die Umkehrung: bleibt das Lebenszeichen aus, ist
    --- genau das die Meldung.
    herzschlag = {
        enabled  = true,
        interval = 20,      -- Sekunden zwischen zwei Zeichen
        karenz   = 60,      -- Schonfrist nach dem Verbinden
        gewicht  = 2,
    },

    -- Schicht 4: Beweise -------------------------------------------------------------
    --- Jede Meldung landet in ms_flags. Ein Admin sieht damit die
    --- Vorgeschichte, statt einer einzelnen Zeile im Chat.
    beweise = {
        enabled  = true,
        behalten = 30,          -- Tage, danach werden alte Zeilen geloescht
    },
}

--- Wie viele Eintraege das Panel im Protokoll zeigt.
AdminConfig.LogLimit = 60

-- Die Entscheidung, ob jemand fliegt --------------------------------------------
--
-- Absichtlich hier und nicht im Server: das ist die Stelle, an der ein
-- Fehler einen echten Spieler kostet. Reine Rechnung, kein Spielzustand -
-- damit tools/testen.lua sie ohne FXServer durchspielen kann.

--- Zaehlt diese Meldung, oder ist es dieselbe wie eben?
---
--- Ohne diese Bremse ist ein haengender Zustand ein Dauerfeuer: die
--- Beobachtung laeuft im Sechssekundentakt und meldet denselben Fund immer
--- wieder, bis der Spieler drueber ist.
---@param letzteMeldung number|nil Zeitpunkt derselben Meldung, oder nil
---@param jetzt number
---@param sperre number Sekunden
---@return boolean
function Admin.MeldungZaehlt(letzteMeldung, jetzt, sperre)
    if not letzteMeldung then return true end

    return (jetzt - letzteMeldung) >= (sperre or 0)
end

--- Wie viele Strikes sind inzwischen verfallen?
---
--- Je <decay> Minuten ohne neue Meldung faellt einer weg. Frueher wurde
--- lastAt bei jeder Meldung neu gesetzt und danach nur einmal je Durchgang
--- ein einziger Strike abgezogen - wer regelmaessig auflief, dessen Zaehler
--- kannte praktisch nur eine Richtung.
---@param count number
---@param lastAt number Zeitpunkt der letzten Meldung
---@param jetzt number
---@param decayMinuten number
---@return number neuerStand
function Admin.Verfall(count, lastAt, jetzt, decayMinuten)
    local schritt = math.max(1, (decayMinuten or 10)) * 60
    local weg = math.floor((jetzt - lastAt) / schritt)

    if weg <= 0 then return count end

    return math.max(0, count - weg)
end

--- Was darf jetzt passieren?
---
--- Gibt eine von fuenf Antworten zurueck:
---   'nichts'    - noch keine Massnahme
---   'probelauf' - waere eine gewesen, wird aber nur gemeldet
---   'melden'    - action = 'log'
---   'kick'      - rauswerfen
---   'ban'       - sperren
---
---@param entry table { count, arten = {[art] = true}, ersteAt, lastAt }
---@param jetzt number
---@param config table AdminConfig.Guard
---@param startAt number|nil Wann diese Resource gestartet ist
---@return string massnahme
---@return string|nil grund Warum nicht gehandelt wird
function Admin.Massnahme(entry, jetzt, config, startAt)
    if not config.enabled then return 'nichts', 'abgeschaltet' end
    if not entry then return 'nichts', 'kein Eintrag' end

    -- Schonfrist nach dem Start: der Wachhund weiss noch nichts von
    -- laufenden Editorsitzungen, Rasten oder Verwandlungen.
    if startAt and (jetzt - startAt) < (config.startKarenz or 0) then
        return 'nichts', 'Schonfrist nach dem Start'
    end

    if (entry.count or 0) < (config.schwelle or 6) then
        return 'nichts', 'unter der Schwelle'
    end

    -- Mindestens zwei verschiedene *Kategorien*. Ein einzelner falsch
    -- eingestellter Grenzwert soll niemanden aus dem Spiel werfen koennen.
    --
    -- Auf die Kategorie und nicht auf den Meldetext, sonst waere die
    -- Bedingung geschenkt: "Ortswechsel 412 m" und "Ortswechsel 500 m" sind
    -- zwei verschiedene Texte, aber derselbe Verdacht.
    local verschieden = 0
    for _ in pairs(entry.arten or {}) do verschieden = verschieden + 1 end

    if verschieden < (config.mindestGruende or 1) then
        -- Nicht rauswerfen - aber auch nicht schweigen.
        --
        -- Der Preis dieser Bremse waere sonst zu hoch: wer *nur*
        -- teleportiert, faellt in genau eine Art und kaeme damit ewig durch.
        -- Also wird gemeldet: Konsole, ms_flags, und alle Admins im Dienst
        -- bekommen es mit. Ein Mensch entscheidet, was daraus wird.
        return 'melden', 'nur eine Art'
    end

    -- Ein Ausbruch innerhalb von Sekunden ist ein Fehler, kein Cheat.
    local spanne = jetzt - (entry.ersteAt or jetzt)

    if spanne < (config.mindestSpanne or 0) then
        return 'nichts', 'zu kurze Spanne'
    end

    if config.probelauf then return 'probelauf', nil end
    if config.action == 'log' then return 'melden', nil end

    if config.action == 'ban' then
        -- Ein Bann braucht mehr als Verdachtsmomente. "sicher" ist nur, was
        -- kein normales Spiel je ausloest: Schaden, den keine Waffe
        -- anrichtet, ein Panzer aus dem Nichts, ein Cheatmenue-Ereignis.
        -- Ortswechsel, Herzschlag, Leben und Modelle sind Hinweise - fuer
        -- einen Bann reichen sie nicht.
        local sicher = false
        for art in pairs(entry.arten or {}) do
            if (config.sichereArten or {})[art] then sicher = true break end
        end

        if not sicher then return 'kick', 'kein sicherer Fund' end
        if (entry.count or 0) < (config.bannSchwelle or 12) then
            return 'kick', 'unter der Bannschwelle'
        end

        return 'ban', nil
    end

    return 'kick', nil
end

--- Ist dieser Ortswechsel auffaellig?
---
--- Zu Fuss gilt ein Budget je Durchgang. Das muss den freien Fall mit
--- abdecken: wer aus einem Flugzeug springt, faellt rund 50 m in der
--- Sekunde, und wenn der Server einmal haengt, sind aus 5 Sekunden schnell
--- 8. Ein festes Budget haette daraus einen Teleport gemacht.
---@param distance number Meter
---@param elapsed number Sekunden
---@param imFahrzeug boolean
---@param config table AdminConfig.Guard.movement
---@return boolean auffaellig
---@return number grenze Meter, die erlaubt gewesen waeren
function Admin.OrtswechselAuffaellig(distance, elapsed, imFahrzeug, config)
    elapsed = math.max(1, elapsed or 1)

    local grenze

    if imFahrzeug then
        grenze = (config.maxSpeed or 190.0) * elapsed
    else
        grenze = math.max(config.maxJump or 300.0,
                          (config.maxFall or 75.0) * elapsed)
    end

    return distance > grenze, grenze
end

--- Darf dieses Level die Aktion?
function Admin.Can(level, action)
    local needed = AdminConfig.Actions[action]
    if not needed then return false end

    return (level or 0) >= needed
end
