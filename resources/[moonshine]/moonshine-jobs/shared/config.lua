--- Arbeit: Jobcenter und Auftragssystem.

Work = Work or {}

WorkConfig = {}

WorkConfig.Debug = false

--- Konto, auf das Loehne gehen.
WorkConfig.Account = 'cash'

--- Reichweite fuer Marker und Interaktion.
WorkConfig.Range = 2.5

-- Jobcenter ----------------------------------------------------------------------
WorkConfig.JobCenter = {
    enabled = true,
    label   = 'Jobcenter',
    coords  = vector3(-266.0, -956.0, 31.2),
    heading = 208.0,
    ped     = 's_f_y_scrubs_01',
    blip    = { sprite = 407, colour = 5, scale = 0.8 },
    -- Wechselgebuehr, damit niemand im Minutentakt den Job tauscht.
    fee     = 0,
    -- Wartezeit zwischen zwei Wechseln in Minuten.
    cooldown = 5,
}

-- Schichten -----------------------------------------------------------------------
WorkConfig.Shift = {
    -- So viele Stationen hat eine Schicht.
    stops = 6,
    -- Nach dieser Zeit ohne Fortschritt endet die Schicht von selbst (Minuten).
    idleTimeout = 20,
    -- Wie nah man an eine Station muss.
    stopRange = 3.5,
    -- Bonus, wenn eine Schicht komplett durchgezogen wird.
    completionBonus = 0.35,
    -- Abzug, wenn das Arbeitsfahrzeug beim Abmelden fehlt.
    vehicleDeposit = 2500,
}

--- Wieviel Erfahrung eine abgeschlossene Station bringt (Mystik-XP).
WorkConfig.XpPerStop = 12

--- Zufaellige Abweichung auf jede Auszahlung (Anteil).
WorkConfig.PayVariance = 0.15

--- Wuerfelt einen Lohn mit Streuung.
function Work.RollPay(base)
    local variance = WorkConfig.PayVariance
    local factor = 1.0 + (math.random() * 2 - 1) * variance

    return math.max(1, math.floor(base * factor))
end

--- Entfernung zwischen zwei Punkten in Metern.
function Work.Distance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end
