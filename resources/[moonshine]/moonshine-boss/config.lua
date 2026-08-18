--- Weltbosse: Hauptquelle fuer Runen- und Seelensteine.

BossConfig = {}

-- Zeitplan -------------------------------------------------------------------
BossConfig.Interval   = 45    -- Minuten zwischen zwei Bossen
BossConfig.FirstDelay = 5     -- Minuten nach Serverstart bis zum ersten Boss
BossConfig.Lifetime   = 25    -- Minuten, danach verschwindet er wieder
BossConfig.MinPlayers = 1     -- so viele Spieler muessen online sein

-- Belohnung ------------------------------------------------------------------
-- Jeder Teilnehmer wuerfelt getrennt fuer beide Steinarten.
BossConfig.Rewards = {
    { item = 'runenstein',  min = 1, max = 4 },
    { item = 'seelenstein', min = 1, max = 4 },
}

--- Mindestens so viele Treffer, um als Teilnehmer zu gelten.
BossConfig.MinHits = 3

--- Umkreis, in dem man beim Tod des Bosses sein muss.
BossConfig.RewardRadius = 80.0

--- Extra-Belohnung fuer den Spieler mit den meisten Treffern.
BossConfig.TopDamageBonus = { item = 'seelenstein', amount = 2 }

-- Bosse ----------------------------------------------------------------------
BossConfig.Bosses = {
    {
        name    = 'Uralter Blutfuerst',
        model   = 'u_m_y_zombie_01',
        health  = 3500,
        armour  = 200,
        weapon  = 'WEAPON_MACHETE',
        accuracy = 70,
        blip    = { sprite = 303, color = 1 },
    },
    {
        name    = 'Bestie der Wildnis',
        model   = 'a_c_mtlion',
        health  = 2800,
        armour  = 0,
        weapon  = nil,
        accuracy = 100,
        blip    = { sprite = 141, color = 5 },
    },
    {
        name    = 'Schattenwandler',
        model   = 's_m_m_movalien_01',
        health  = 4200,
        armour  = 300,
        weapon  = 'WEAPON_KNIFE',
        accuracy = 80,
        blip    = { sprite = 303, color = 27 },
    },
}

-- Spawnpunkte ----------------------------------------------------------------
-- Bewusst abgelegen, damit der Kampf niemanden in der Stadt stoert.
BossConfig.Spawns = {
    { label = 'Steinkreis bei Zancudo', coords = vector4(-2295.6, 3389.5, 31.9, 150.0) },
    { label = 'Altruisten Lager',       coords = vector4(-1163.0, 4930.1, 224.3, 190.0) },
    { label = 'Chiliad Nordhang',       coords = vector4(414.9, 5595.5, 766.2, 30.0) },
    { label = 'Alter Steinbruch',       coords = vector4(2934.7, 2795.4, 41.0, 240.0) },
    { label = 'Cassidy Creek',          coords = vector4(-452.1, 4381.8, 60.4, 80.0) },
    { label = 'Leuchtturm Paleto',      coords = vector4(3421.5, 5182.7, 20.9, 300.0) },
}

-- Anzeige --------------------------------------------------------------------
BossConfig.Announce      = true    -- Ankuendigung an alle Spieler
BossConfig.ShowBlip      = true    -- Markierung auf der Karte
BossConfig.ShowHealthBar = true    -- Lebensbalken in der Naehe
BossConfig.HealthBarRange = 120.0
