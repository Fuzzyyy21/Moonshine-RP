--- Ritualpunkte als umkaempfte Gebiete.
---
--- Bisher liefen zwei Kreislaeufe nebeneinander her: Fraktionen halten
--- Gebiete fuer Geld, Mystiker nutzen Ritualpunkte fuer Steine. Hier treffen
--- sie sich - wer einen Ritualpunkt bindet, verdient an allem, was dort
--- geschieht.

RitualWar = RitualWar or {}

WarConfig = {}

WarConfig.Debug = false

-- Bindung ---------------------------------------------------------------------
WarConfig.Binding = {
    enabled = true,

    -- Dauer eines Bindungsrituals in Sekunden.
    duration = 180,

    -- So viele Fraktionsmitglieder muessen dabei sein.
    minMembers = 2,

    -- Reichweite, in der jemand als "dabei" zaehlt.
    range = 12.0,

    -- Nach einer Bindung ist der Punkt so lange unantastbar (Minuten).
    protection = 45,

    -- Ohne Fortschritt faellt der Balken so schnell zurueck (Prozent je Sekunde).
    decay = 2.0,

    -- Ein gestoertes Ritual steht still. Damit es sich nicht ewig festfaehrt,
    -- endet es spaetestens nach dieser Zeit (Sekunden).
    maxDuration = 900,

    -- Der Fraktions-Skill "Sturmtrupp" laesst eine Person allein binden.
    soloPerk = 'soloCapture',

    -- Kosten des Bindungsrituals, aus der Fraktionskasse.
    cost = 75000,
    costAccount = 'kasse',

    -- Bricht die Bindung ab, kommt dieser Anteil zurueck in die Kasse.
    -- Nicht alles: ein angefangenes Ritual verbrennt Material.
    refund = 0.5,

    -- Recht, das ein Rang braucht, um eine Bindung zu starten.
    permission = 'territory',
}

-- Ertrag -----------------------------------------------------------------------
WarConfig.Income = {
    enabled = true,

    -- Ausschuettung alle X Minuten.
    interval = 20,

    -- Steine je Ausschuettung, in den Fraktionstresor.
    stones = {
        { item = 'runenstein',  min = 1, max = 3 },
        { item = 'seelenstein', min = 1, max = 3 },
    },

    -- Zusaetzlich Fraktions-XP.
    xp = 180,

    -- Der Fraktions-Skilltree erhoeht das ueber territoryIncome.
    useFactionBonus = true,
}

-- Wegzoll ------------------------------------------------------------------------
WarConfig.Toll = {
    enabled = true,

    -- Anteil, den die haltende Fraktion von fremden Ritualen einbehaelt.
    share = 0.25,

    -- Auch von Meditationspunkten? Nein - Punkte lassen sich nicht teilen.
    -- Stattdessen bekommen Fremde weniger.
    meditationPenalty = 0.30,

    -- Mitglieder der haltenden Fraktion bekommen stattdessen einen Bonus.
    memberBonus = 0.20,
}

-- Stoerung -------------------------------------------------------------------------
WarConfig.Disruption = {
    enabled = true,

    -- Wer nicht zur haltenden Fraktion gehoert und so nah steht, stoert.
    range = 8.0,

    -- So lange muss er dableiben, bis es wirkt (Sekunden).
    delay = 6,

    -- Gilt auch fuer Meditation und Steinbindung?
    affectsMeditation = true,
    affectsCrafting = false,
}

-- Segen der Bindung -----------------------------------------------------------------
--- Was Mitglieder der haltenden Fraktion an ihrem Punkt bekommen.
WarConfig.Blessing = {
    enabled = true,
    range = 25.0,

    effects = {
        essenceRegen = 0.6,
        regenPerTick = 0.3,
        xpBonus      = 0.15,
    },
}

--- Anzeige.
WarConfig.Hud = {
    enabled = true,
    -- Ab dieser Entfernung taucht die Punktanzeige auf.
    range = 60.0,
}

--- Wie oft der Server die Punkte durchgeht (Sekunden).
WarConfig.TickInterval = 2


-- Rechnungen -------------------------------------------------------------------
--- Bewusst hier und nicht im Server: so laesst sich die Wirtschaft ohne
--- laufenden FXServer nachrechnen.

--- Teilt einen Ritualertrag zwischen Spieler und haltender Fraktion auf.
---@param amount number
---@param relation string 'eigen' (Mitglied), 'fremd' oder 'frei' (ungebunden)
---@return number betrag, number zoll
function RitualWar.Split(amount, relation)
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then return 0, 0 end
    if not WarConfig.Toll.enabled or relation == 'frei' then return amount, 0 end

    if relation == 'eigen' then
        return math.floor(amount * (1 + WarConfig.Toll.memberBonus)), 0
    end

    local zoll = math.floor(amount * WarConfig.Toll.share)
    return amount - zoll, zoll
end

--- Faktor auf Meditationspunkte an einem gebundenen Punkt.
---@param relation string 'eigen', 'fremd' oder 'frei'
function RitualWar.MeditationFactorFor(relation)
    if not WarConfig.Toll.enabled or relation == 'frei' then return 1.0 end
    if relation == 'eigen' then return 1.0 + WarConfig.Toll.memberBonus end

    return 1.0 - WarConfig.Toll.meditationPenalty
end

--- Fortschritt der Bindung je Sekunde.
function RitualWar.ProgressPerSecond()
    return 100.0 / math.max(1, WarConfig.Binding.duration)
end

--- Wie lange ein voller Balken ohne Anwesende braucht, bis er leer ist.
function RitualWar.DecayTime()
    return 100.0 / math.max(0.01, WarConfig.Binding.decay)
end
