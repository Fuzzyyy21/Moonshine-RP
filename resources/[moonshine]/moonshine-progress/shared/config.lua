--- Fortschrittssystem: Playtime, Missionen, Battle Pass und Kisten.

Progress = Progress or {}

ProgressConfig = {}

ProgressConfig.Debug = false

--- Taste und Command fuer die Oberflaeche.
ProgressConfig.OpenKey = 'F6'
ProgressConfig.Command = 'fortschritt'

-- Playtime-Belohnungen -------------------------------------------------------
-- Die Spielzeit zaehlt pro Tag und wird um Mitternacht zurueckgesetzt.
ProgressConfig.Playtime = {
    enabled = true,
    -- Meilensteine in Minuten mit ihrer Belohnung.
    milestones = {
        { minutes = 15,  label = 'Aufgewaermt',   reward = { cash = 1500,  bpxp = 50 } },
        { minutes = 30,  label = 'Dabei',         reward = { money = 4000, bpxp = 100 } },
        { minutes = 60,  label = 'Eine Stunde',   reward = { money = 8000, bpxp = 200,
                                                             items = { { name = 'runenstein', count = 1 } } } },
        { minutes = 120, label = 'Zwei Stunden',  reward = { money = 15000, bpxp = 350,
                                                             cases = { holz = 1 } } },
        { minutes = 180, label = 'Drei Stunden',  reward = { money = 22000, bpxp = 500,
                                                             items = { { name = 'seelenstein', count = 2 } } } },
        { minutes = 240, label = 'Vier Stunden',  reward = { money = 30000, bpxp = 700,
                                                             cases = { silber = 1 } } },
        { minutes = 360, label = 'Sechs Stunden', reward = { money = 50000, bpxp = 1000,
                                                             cases = { gold = 1 } } },
    },
}

-- Missionen ------------------------------------------------------------------
ProgressConfig.Missions = {
    enabled = true,
    -- So viele Missionen bekommt jeder Spieler gleichzeitig.
    dailyCount  = 3,
    weeklyCount = 3,
    -- Stunde (Serverzeit), zu der taeglich zurueckgesetzt wird.
    resetHour = 4,
}

-- Battle Pass ----------------------------------------------------------------
ProgressConfig.BattlePass = {
    enabled = true,
    season  = 1,
    seasonLabel = 'Saison 1 - Erwachen',
    maxLevel = 50,
    -- XP je Stufe: base + stufe * step
    xpBase = 800,
    xpStep = 120,
    -- Premium freischalten (Ingame-Geld).
    premiumPrice = 250000,
    premiumAccount = 'bank',
}

-- Kisten ---------------------------------------------------------------------
ProgressConfig.Cases = {
    enabled = true,
    -- Dauer der Oeffnungsanimation in Millisekunden (nur Anzeige).
    animationTime = 3500,
}

--- Wie oft die Oberflaeche automatisch aktualisiert wird (Sekunden).
ProgressConfig.SyncInterval = 30
