Config = {}

-- Allgemein ------------------------------------------------------------------
Config.ServerName        = 'Moonshine RP'
Config.Debug             = false
Config.EnableWelcomeInfo = true

-- Charaktere -----------------------------------------------------------------
Config.MaxCharacters   = 3                              -- Slots pro Lizenz
Config.AllowDeletion   = true                           -- Charakter loeschbar?
Config.DefaultSpawn    = vector4(-1037.7, -2737.8, 20.2, 328.0)  -- Flughafen LS
Config.SelectionCamera = {
    coords = vector3(-1042.1, -2745.5, 21.4),
    look   = vector3(-1037.7, -2737.8, 20.9),
}

-- Wirtschaft -----------------------------------------------------------------
Config.Accounts = {
    cash  = { label = 'Bargeld',    default = 500,  hidden = false },
    bank  = { label = 'Bank',       default = 5000, hidden = false },
    black = { label = 'Schwarzgeld', default = 0,   hidden = true  },
}

Config.Paycheck = {
    enabled       = true,
    interval      = 30,     -- Minuten
    account       = 'bank', -- Konto auf das ausgezahlt wird
    payUnemployed = true,   -- Arbeitslosengeld auszahlen?
}

-- Inventar -------------------------------------------------------------------
Config.Inventory = {
    maxWeight  = 40000, -- in Gramm (40 kg)
    maxSlots   = 40,
    dropOnDeath = false,
}

-- Status (Hunger / Durst) ----------------------------------------------------
Config.Status = {
    enabled       = true,
    tickInterval  = 60,   -- Sekunden zwischen den Ticks
    hungerPerTick = 0.9,  -- Verlust pro Tick in Prozent
    thirstPerTick = 1.2,
    damagePerTick = 5,    -- Schaden wenn Hunger/Durst bei 0
}

-- Speicherung ----------------------------------------------------------------
Config.SaveInterval  = 5   -- Minuten, Autosave aller Spieler
Config.SaveOnDropped = true

-- Berechtigungen -------------------------------------------------------------
-- admin_level in der Datenbank (ms_users.admin_level)
Config.Permissions = {
    [0] = 'user',
    [1] = 'support',
    [2] = 'moderator',
    [3] = 'admin',
    [4] = 'owner',
}

Config.CommandPermissions = {
    ['setjob']    = 3,
    ['givemoney'] = 3,
    ['setmoney']  = 4,
    ['giveitem']  = 3,
    ['setadmin']  = 4,
    ['revive']    = 2,
    ['heal']      = 2,
    ['tp']        = 2,
    ['bring']     = 2,
    ['goto']      = 2,
    ['kick']      = 2,
    ['ban']       = 3,
    ['unban']     = 3,
    ['setstatus'] = 3,
}

-- Logging --------------------------------------------------------------------
Config.Logs = {
    console = true,
    database = true,
    -- Discord Webhook optional, leer lassen zum Deaktivieren
    webhook = '',
}

-- Tastenbelegung (client) ----------------------------------------------------
Config.Keys = {
    inventory = 'F2',
    hudToggle = 'F7',
}
