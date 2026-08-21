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

    -- Was dann passiert: 'log' | 'kick' | 'ban'
    action = 'kick',
    banHours = 72,

    -- Strikes verfallen nach dieser Zeit (Minuten).
    decay = 30,

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
        maxJump  = 300.0,       -- Sprung zu Fuss in einem Intervall
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

        -- Mehr Schaden als das kann keine Waffe im Spiel anrichten.
        maxSchaden = 250,

        -- Treffer ueber diese Entfernung sind keine mehr (Meter).
        maxEntfernung = 500.0,
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
    ereignisse = {
        enabled = true,
        gewicht = 3,

        -- Wer Waffen verteilt oder Aufgaben abbricht, tut das nicht selbst.
        giveWeapon        = true,
        removeAllWeapons  = true,
        clearPedTasks     = true,
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

--- Darf dieses Level die Aktion?
function Admin.Can(level, action)
    local needed = AdminConfig.Actions[action]
    if not needed then return false end

    return (level or 0) >= needed
end
