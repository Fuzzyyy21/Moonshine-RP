--- Klassenbeduerfnisse.
---
--- Jede Klasse hat neben Hunger und Durst etwas Eigenes, das sie am Leben
--- haelt. Wer es vernachlaessigt, verliert erst Essenzregeneration, dann
--- Tempo, am Ende Leben.

Needs = Needs or {}

NeedsConfig = {}

NeedsConfig.Debug = false

--- Takt in Sekunden.
NeedsConfig.TickInterval = 45

--- Schwellen und was sie bedeuten.
NeedsConfig.Thresholds = {
    -- Ab hier gibt es einen kleinen Bonus.
    satt    = 85,
    -- Ab hier die erste Warnung.
    warnung = 35,
    -- Ab hier wird es unangenehm.
    schwach = 15,
    -- Bei null zieht es Leben.
    leer    = 0,
}

--- Wirkung je Bereich.
NeedsConfig.Effects = {
    satt = {
        essenceRegen = 0.4,
        regenPerTick = 0.2,
    },
    normal = {},
    warnung = {
        essenceRegen = -0.3,
    },
    schwach = {
        essenceRegen = -0.8,
        speedMult    = -0.08,
        damageMult   = -0.10,
    },
    leer = {
        essenceRegen = -1.5,
        speedMult    = -0.15,
        damageMult   = -0.20,
        regenPerTick = -0.5,
    },
}

--- Schaden je Tick, wenn das Beduerfnis auf null steht.
NeedsConfig.DamagePerTick = 4

--- Anzeige.
NeedsConfig.Hud = {
    -- Aus: der Balken haengt jetzt in der Statusgruppe von moonshine-hud.
    -- Wieder einschalten geht, dann steht er zusaetzlich links unten.
    enabled = false,
    -- Der Balken zeigt sich immer, oder nur wenn es knapp wird.
    immerSichtbar = false,
    -- Ab diesem Wert taucht er von selbst auf.
    zeigenAb = 60,
    toggleCommand = 'beduerfnis',
}

--- Wie nah man an eine Quelle heran muss.
NeedsConfig.Range = 2.0

--- Abklingzeit zwischen zwei Aufnahmen aus derselben Quellart (Sekunden).
NeedsConfig.Cooldown = 20

--- Bereich einer Zahl bestimmen.
---@return string 'satt' | 'normal' | 'warnung' | 'schwach' | 'leer'
function Needs.GetBand(value)
    value = tonumber(value) or 100

    local schwellen = NeedsConfig.Thresholds

    if value <= schwellen.leer then return 'leer' end
    if value < schwellen.schwach then return 'schwach' end
    if value < schwellen.warnung then return 'warnung' end
    if value >= schwellen.satt then return 'satt' end

    return 'normal'
end

--- Die Werte, die dieser Bereich mitbringt.
function Needs.GetEffects(value)
    local effekte = NeedsConfig.Effects[Needs.GetBand(value)] or {}

    local kopie = {}
    for schluessel, wert in pairs(effekte) do kopie[schluessel] = wert end

    return kopie
end
