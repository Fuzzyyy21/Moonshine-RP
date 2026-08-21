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

    -- Leben und Weste: mehr als das ist nicht vorgesehen.
    health = {
        enabled = true,
        -- Puffer ueber dem erlaubten Maximum (Klassenboni koennen es erhoehen).
        tolerance = 60,
        maxArmour = 105,
        -- So oft darf es auffallen, bevor gehandelt wird.
        strikes = 3,
    },

    -- Ortswechsel: wer sich zu schnell bewegt, wird auffaellig.
    movement = {
        enabled = true,
        -- Meter je Sekunde, ab denen es gemeldet wird (Flugzeuge sind schnell).
        maxSpeed = 190.0,
        -- Sprung ohne Fahrzeug in einem Intervall.
        maxJump = 300.0,
        strikes = 4,
        -- Wie oft geprueft wird (Sekunden).
        interval = 5,
    },

    -- Waffen, die niemand haben sollte.
    weapons = {
        enabled = true,
        strikes = 2,
        blacklist = {
            'WEAPON_RAILGUN', 'WEAPON_MINIGUN', 'WEAPON_RPG',
            'WEAPON_GRENADELAUNCHER', 'WEAPON_GRENADELAUNCHER_SMOKE',
            'WEAPON_FIREWORK', 'WEAPON_HOMINGLAUNCHER',
            'WEAPON_COMPACTLAUNCHER', 'WEAPON_RAYMINIGUN',
            'WEAPON_RAYPISTOL', 'WEAPON_RAYCARBINE',
        },
    },

    -- Ratenbegrenzung fuer Netzwerkereignisse.
    -- Die Ratenbegrenzung steht jetzt im Core (Config.RateLimit). Sie lag
    -- hier, aber moonshine-admin startet als letzte Resource - bis dahin
    -- waren alle Limits aus. Was hier bleibt, ist die Meldung: der Core
    -- ruft Admin.Flag, wenn jemand wiederholt darueber geht.

    -- Was passiert, wenn das Strike-Limit erreicht ist.
    -- 'log' | 'kick' | 'ban'
    action = 'kick',
    banHours = 72,

    -- Strikes verfallen nach dieser Zeit (Minuten).
    decay = 30,

    -- Discord-Webhook fuer Meldungen (leer = nur Serverkonsole und ms_logs).
    webhook = '',
}

--- Wie viele Eintraege das Panel im Protokoll zeigt.
AdminConfig.LogLimit = 60

--- Darf dieses Level die Aktion?
function Admin.Can(level, action)
    local needed = AdminConfig.Actions[action]
    if not needed then return false end

    return (level or 0) >= needed
end
