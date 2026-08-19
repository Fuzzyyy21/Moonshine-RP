--- Zentrale Konfiguration des Mystik-Systems.

Mystic = Mystic or {}

MysticConfig = {}

MysticConfig.Debug = false

-- Erweckung ------------------------------------------------------------------
MysticConfig.Awakening = {
    -- Ohne Klasse gibt es keine Klassenskills, persoenliche Perks laufen trotzdem.
    onlyAtRitualPoint = true,

    -- Kernregel: Die Klasse laesst sich frei wechseln, solange noch KEINE
    -- Faehigkeit gelernt wurde. Mit der ersten geskillten Faehigkeit ist die
    -- Wahl endgueltig und im Skilltree ist nur noch die eigene Klasse sichtbar.
    lockAfterFirstSkill = true,

    -- Wechsel auch nach der ersten Faehigkeit erlauben (gegen Steine).
    allowRaceChange  = false,
    raceChangeStones = { seelenstein = 3 },
}

-- Skillleiste ----------------------------------------------------------------
MysticConfig.SkillBar = {
    slots     = 6,
    toggleKey = 'F5',                                          -- Leiste ein-/ausblenden
    keys      = { 'NUMPAD1', 'NUMPAD2', 'NUMPAD3',
                  'NUMPAD4', 'NUMPAD5', 'NUMPAD6' },           -- Slot 1-6
    -- Leiste automatisch einblenden, sobald ein Skill ausgeruestet ist.
    showOnStart = true,
    -- Skills lassen sich nur ausloesen, wenn die Leiste ausgeklappt ist.
    requireVisible = true,
}

-- Klassenstufe ---------------------------------------------------------------
-- Der Klassenbaum kostet ausschliesslich Klassensteine. Die Klassenstufe ist
-- keine XP-Stufe, sondern zaehlt die im Baum gekauften Stufen. Tiefe Knoten
-- verlangen darueber eine Mindestanzahl (Feld `level` in shared/skills.lua).
MysticConfig.ClassLevel = {
    -- Wird nur fuer die Anzeige gebraucht.
    label = 'Stufe',
}

-- Erfahrung (nur persoenlicher Skillbaum) ------------------------------------
-- XP sind die Waehrung fuer Leben, Ausdauer, Schaden und die uebrigen Perks.
-- Der Klassenbaum verwendet sie bewusst nicht.
MysticConfig.Progression = {
    maxLevel = 50,

    -- Faehigkeitspunkte fuer den persoenlichen Baum.
    startPoints    = 3,    -- zum Start
    pointsPerLevel = 2,    -- je Stufenaufstieg

    -- Kosten fuer das Zuruecksetzen des persoenlichen Baums.
    resetCost = { account = 'bank', amount = 1000 },

    -- Kurve fuer die persoenliche Stufe (reine Anzeige des Fortschritts).
    xpBase = 500,
    xpStep = 650,

    -- XP-Quellen
    xpPerMinute     = 20,   -- Onlinezeit
    xpPerSkillCast  = 10,   -- eingesetzter Skill
    xpPerSkillHit   = 8,    -- je getroffenem Ziel
    xpPerMeditation = 150,  -- abgeschlossene Meditation
    xpPerKill       = 0,    -- optional, von eigenen Scripts vergebbar
}

-- Steine ---------------------------------------------------------------------
-- Es gibt nur zwei Grundsteine: Runenstein und Seelenstein. Beide bekommt man
-- beim Weltboss oder kauft sie beim Haendler. Der Klassenstein wird daraus am
-- Ritualpunkt gecraftet und ist die einzige Waehrung im Skilltree.
MysticConfig.Stones = {
    --- Rezept fuer einen Klassenstein.
    recipe = {
        runenstein  = 10,
        seelenstein = 10,
        result      = 1,
    },

    --- Grundsteine, die es zu kaufen und zu finden gibt.
    base = { 'runenstein', 'seelenstein' },

    --- Startguthaben beim Erwecken (Klassensteine).
    startAmount = 1,
}

-- Steinhaendler --------------------------------------------------------------
MysticConfig.Merchant = {
    enabled = true,
    model   = 's_m_y_dealer_01',
    price   = 1000,      -- Dollar je Grundstein
    account = 'cash',
    maxPerPurchase = 20,

    peds = {
        { label = 'Steinhaendler (Vinewood)',    coords = vector4(-1660.4, -237.3, 55.2, 118.0) },
        { label = 'Steinhaendler (Sandy Shores)', coords = vector4(1962.1, 3803.4, 32.4, 300.0) },
        { label = 'Steinhaendler (Paleto Bay)',   coords = vector4(-125.5, 6465.3, 31.5, 45.0) },
        { label = 'Steinhaendler (Innenstadt)',   coords = vector4(275.4, -1155.3, 29.3, 90.0) },
    },

    blip = { enabled = true, sprite = 617, color = 27, scale = 0.65, label = 'Steinhaendler' },
}

-- Ritualpunkte ---------------------------------------------------------------
-- Hier oeffnet sich der Skilltree, hier wird erweckt und meditiert.
--- Die Kennung muss stabil bleiben - moonshine-ritualwar speichert sie.
MysticConfig.RitualPoints = {
    { id = 'vinewood', label = 'Vinewood Friedhof',
      coords = vector3(-1671.2, -230.4, 55.1),  radius = 2.5 },
    { id = 'chiliad',  label = 'Chiliad Gipfel',
      coords = vector3(450.9, 5566.5, 781.2),   radius = 3.0 },
    { id = 'altruist', label = 'Altruisten Lager',
      coords = vector3(-1170.5, 4926.6, 224.3), radius = 3.0 },
    { id = 'sandy',    label = 'Kirche Sandy Shores',
      coords = vector3(1972.4, 3815.5, 33.4),   radius = 2.5 },
    { id = 'paleto',   label = 'Leuchtturm Paleto',
      coords = vector3(3430.6, 5175.7, 21.0),   radius = 2.5 },
    { id = 'zancudo',  label = 'Steinkreis Zancudo',
      coords = vector3(-2295.1, 3384.3, 31.9),  radius = 3.0 },
}

--- Ritualpunkt anhand seiner Kennung.
function Mystic.GetRitualPoint(id)
    if type(id) ~= 'string' then return nil end

    for _, point in ipairs(MysticConfig.RitualPoints) do
        if point.id == id then return point end
    end

    return nil
end

MysticConfig.RitualBlip = {
    enabled = true,
    sprite  = 434,
    color   = 27,
    scale   = 0.7,
    label   = 'Ritualpunkt',
}

-- Meditation -----------------------------------------------------------------
-- Meditation gibt ausschliesslich Meditationspunkte, keine Steine.
MysticConfig.Meditation = {
    enabled  = true,
    duration = 20,     -- Sekunden Versenkung
    cooldown = 900,    -- Sekunden bis zur naechsten Meditation
    points   = { min = 1, max = 3 },
}

-- Rituale --------------------------------------------------------------------
-- Ein Ritual am Ritualpunkt bringt vorerst nur Geld. Was noch dazukommt,
-- steht in docs/ROADMAP.md unter "Rituale".
MysticConfig.Ritual = {
    enabled  = true,
    duration = 30,      -- Sekunden Konzentration
    cooldown = 1800,    -- 30 Minuten
    reward   = { account = 'bank', amount = 10000 },
    -- Einsatz an Meditationspunkten (0 = keiner).
    costPoints = 0,
}

-- Segen ----------------------------------------------------------------------
-- Verwendung der Meditationspunkte. Erster Entwurf, leicht austauschbar.
MysticConfig.Blessings = {
    enabled = true,
    list = {
        {
            id = 'klarheit', label = 'Segen der Klarheit', icon = '🔵', cost = 1,
            description = 'Fuellt deine Essenz sofort vollstaendig auf.',
            kind = 'essence',
        },
        {
            id = 'genesung', label = 'Segen der Genesung', icon = '💚', cost = 2,
            description = 'Heilt dich vollstaendig und reinigt Flueche.',
            kind = 'heal',
        },
        {
            id = 'eile', label = 'Segen der Eile', icon = '⏱', cost = 2,
            description = 'Setzt alle Abklingzeiten deiner Faehigkeiten zurueck.',
            kind = 'cooldowns',
        },
        {
            id = 'schutz', label = 'Segen des Schutzes', icon = '🛡', cost = 3,
            description = '5 Minuten lang 75 Weste und mehr Widerstand.',
            kind = 'buff', duration = 300, armor = 75,
        },
        {
            id = 'staerke', label = 'Segen der Staerke', icon = '💪', cost = 4,
            description = '5 Minuten lang 25 Prozent mehr Schaden.',
            kind = 'buff', duration = 300, damageMult = 1.25, meleeMult = 1.25,
        },
    },
}

-- Ressource (Essenz) ---------------------------------------------------------
MysticConfig.Essence = {
    -- Regeneration laeuft serverseitig im Takt von tickInterval Sekunden.
    tickInterval = 5,
    -- Prozent der maximalen Essenz pro Tick.
    regenPerTick = 4.0,
    -- Kein Regen fuer diese Zeit nach einem Skill-Einsatz.
    lockAfterCast = 4,
}

-- Rassenschwaechen -----------------------------------------------------------
MysticConfig.Weaknesses = {
    -- Vampire nehmen bei Tageslicht Schaden (Ingame-Zeit 07:00-19:00).
    sunlight = {
        enabled  = true,
        damage   = 4,
        interval = 6,       -- Sekunden
        fromHour = 7,
        toHour   = 19,
    },
    -- Werwoelfe sind nachts staerker.
    moonlight = {
        enabled    = true,
        damageMult = 1.25,
        fromHour   = 21,
        toHour     = 5,
    },
}

-- Kampf ----------------------------------------------------------------------
MysticConfig.Combat = {
    -- Maximale Reichweite fuer Ziel-Skills in Metern.
    maxTargetRange = 30.0,
    -- Schutzzonen, in denen keine Skills wirken (z.B. Spawn / Behoerden).
    safeZones = {
        -- { coords = vector3(441.0, -982.0, 30.7), radius = 60.0, label = 'Mission Row' },
    },
    -- Friendly Fire fuer Skills der gleichen Rasse.
    friendlyFireSameRace = true,
}

MysticConfig.Notifications = {
    showCooldownHints = true,
}

--- Liefert den Ritualpunkt an der Position, sonst nil.
--- Wird auf Server und Client verwendet.
---@param coords vector3
---@param tolerance number|nil zusaetzlicher Puffer in Metern
function Mystic.IsNearRitualPoint(coords, tolerance)
    for _, point in ipairs(MysticConfig.RitualPoints) do
        if #(coords - point.coords) <= point.radius + (tolerance or 2.0) then
            return point
        end
    end
end
