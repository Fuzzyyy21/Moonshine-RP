--- Zentrale Konfiguration des Mystik-Systems.

Mystic = Mystic or {}

MysticConfig = {}

MysticConfig.Debug = false

-- Erweckung ------------------------------------------------------------------
MysticConfig.Awakening = {
    -- Ohne Rasse gibt es keine Rassenskills, persoenliche Perks laufen trotzdem.
    onlyAtRitualPoint = true,
    -- Rassenwechsel fuer Spieler erlauben (sonst nur per Admin-Command).
    allowRaceChange   = false,
    -- Kosten fuer einen freiwilligen Rassenwechsel.
    raceChangeStones  = { seelenstein = 3 },
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

-- Punkte ---------------------------------------------------------------------
MysticConfig.Points = {
    -- Persoenliche Punkte (Perks) durch Onlinezeit.
    minutesPerPersonalPoint = 15,
    startPersonalPoints     = 3,
    -- Skillpunkte fuer den Rassen-Skilltree.
    minutesPerSkillPoint    = 30,
    startSkillPoints        = 1,
    -- Bonuspunkte beim Erwecken einer Rasse.
    awakeningSkillPoints    = 2,
}

-- Ritualpunkte ---------------------------------------------------------------
-- Hier oeffnet sich der Skilltree, hier wird erweckt und meditiert.
MysticConfig.RitualPoints = {
    { label = 'Vinewood Friedhof',   coords = vector3(-1671.2, -230.4, 55.1),  radius = 2.5 },
    { label = 'Chiliad Gipfel',      coords = vector3(450.9, 5566.5, 781.2),   radius = 3.0 },
    { label = 'Altruisten Lager',    coords = vector3(-1170.5, 4926.6, 224.3), radius = 3.0 },
    { label = 'Kirche Sandy Shores', coords = vector3(1972.4, 3815.5, 33.4),   radius = 2.5 },
    { label = 'Leuchtturm Paleto',   coords = vector3(3430.6, 5175.7, 21.0),   radius = 2.5 },
    { label = 'Steinkreis Zancudo',  coords = vector3(-2295.1, 3384.3, 31.9),  radius = 3.0 },
}

MysticConfig.RitualBlip = {
    enabled = true,
    sprite  = 434,
    color   = 27,
    scale   = 0.7,
    label   = 'Ritualpunkt',
}

-- Meditation -----------------------------------------------------------------
-- Am Ritualpunkt meditieren, um Steine zu erhalten.
MysticConfig.Meditation = {
    enabled   = true,
    duration  = 20,    -- Sekunden
    cooldown  = 900,   -- Sekunden bis zur naechsten Meditation
    -- Gewichtete Ausbeute. Es faellt genau ein Eintrag.
    loot = {
        { item = 'runenstein',    count = 1, weight = 45 },
        { item = 'runenstein',    count = 2, weight = 18 },
        { item = 'seelenstein',   count = 1, weight = 12 },
        { item = 'blutstein',     count = 1, weight = 4  },
        { item = 'mondstein',     count = 1, weight = 4  },
        { item = 'flammenstein',  count = 1, weight = 4  },
        { item = 'feenstaub',     count = 1, weight = 4  },
        { item = 'arkanstein',    count = 1, weight = 4  },
        { item = 'schattenstein', count = 1, weight = 3  },
        { item = 'silberstein',   count = 1, weight = 2  },
    },
    -- Steine, die zur Rasse des Spielers passen, fallen bevorzugt (Faktor).
    raceBonus = 2.5,
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
