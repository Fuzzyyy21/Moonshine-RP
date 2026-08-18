--- Dienstleistungen: Tankstellen, Werkstaetten, Bank, Schwarzmarkt.

Services = Services or {}

ServiceConfig = {}

ServiceConfig.Debug = false

--- Reichweite fuer Marker und Interaktion.
ServiceConfig.Range = 2.2

-- Bank -----------------------------------------------------------------------
ServiceConfig.Bank = {
    enabled = true,
    -- Konten, zwischen denen man umbuchen darf.
    from = 'bank',
    to   = 'cash',
    -- Ueberweisung an andere Spieler.
    transfer = {
        enabled = true,
        fee     = 0.01,     -- Anteil, den die Bank einbehaelt
        minimum = 1,
        maximum = 5000000,
    },
    -- Geldautomaten koennen weniger als eine Filiale.
    atm = {
        maxWithdraw = 25000,
        allowDeposit = true,
        allowTransfer = false,
    },
    -- Zinsen auf das Bankguthaben.
    interest = {
        enabled  = true,
        rate     = 0.004,   -- je Auszahlung
        interval = 60,      -- Minuten
        maximum  = 20000,   -- Deckel je Auszahlung
    },
}

-- Tankstellen -------------------------------------------------------------------
ServiceConfig.Fuel = {
    enabled = true,
    -- Preis je Prozentpunkt Sprit.
    price = 45,
    -- Konto, von dem bezahlt wird.
    account = 'cash',
    -- Wie weit man von der Zapfsaeule weg sein darf.
    nozzleRange = 4.5,
    -- Dauer je Prozentpunkt in Millisekunden.
    speed = 90,
    -- Kanister als Item (fuer unterwegs).
    canister = {
        item   = 'benzinkanister',
        amount = 25,        -- Prozentpunkte je Kanister
        price  = 1800,      -- Verkaufspreis an der Tankstelle
    },
}

-- Werkstaetten ---------------------------------------------------------------------
ServiceConfig.Repair = {
    enabled = true,
    account = 'bank',
    -- Preise je Prozentpunkt, der repariert wird.
    pricePerPoint = {
        engine = 120,
        body   = 70,
    },
    -- Grundgebuehr je Auftrag.
    baseFee = 750,
    -- Dauer der Reparatur in Sekunden.
    duration = 12,
    -- Mechaniker reparieren guenstiger.
    mechanicJob = 'mechanic',
    mechanicDiscount = 0.5,
    -- Reparaturkit aus dem Inventar: repariert weniger, kostet nichts.
    kit = {
        item   = 'repairkit',
        engine = 35,        -- Prozentpunkte
        body   = 35,
        duration = 15,
    },
}

-- Schwarzmarkt -----------------------------------------------------------------------
ServiceConfig.BlackMarket = {
    enabled = true,
    -- Konto, ueber das gehandelt wird.
    account = 'black',
    -- Der Markt wandert alle X Minuten an einen anderen Ort.
    moveInterval = 90,
    -- Vorwarnung an alle, wenn er umzieht.
    announce = true,
    -- Waschanlage: Schwarzgeld gegen Bargeld, mit Verlust.
    laundering = {
        enabled = true,
        rate    = 0.72,     -- so viel kommt raus
        maximum = 250000,   -- je Vorgang
    },
    -- Was hier verkauft wird. Bezahlt in Schwarzgeld.
    items = {
        { name = 'runenstein',  price = 2200, label = 'Runenstein' },
        { name = 'seelenstein', price = 2200, label = 'Seelenstein' },
        { name = 'lockpick',    price = 3500, label = 'Dietrich' },
        { name = 'medikit',     price = 4000, label = 'Medikit' },
        { name = 'repairkit',   price = 6500, label = 'Reparaturkit' },
    },
    -- Was der Markt ankauft. Zahlt Schwarzgeld.
    buys = {
        { name = 'runenstein',  price = 900,  label = 'Runenstein' },
        { name = 'seelenstein', price = 900,  label = 'Seelenstein' },
    },
}

--- Preis einer Reparatur.
---@param engine number Motorzustand in Prozent
---@param body number Karosseriezustand in Prozent
---@param discount number|nil Anteil Rabatt
function Services.RepairPrice(engine, body, discount)
    local config = ServiceConfig.Repair

    local missingEngine = math.max(0, 100 - (engine or 100))
    local missingBody   = math.max(0, 100 - (body or 100))

    local total = config.baseFee
        + missingEngine * config.pricePerPoint.engine
        + missingBody * config.pricePerPoint.body

    return math.floor(total * (1 - (discount or 0)))
end
