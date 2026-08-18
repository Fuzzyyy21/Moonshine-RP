--- Fahrzeuge: Autohaeuser, Garagen, Verwahrstelle.

Vehicles = Vehicles or {}

VehicleConfig = {}

VehicleConfig.Debug = false

--- Command fuer Garage und Autohaus (nur am jeweiligen Punkt).
VehicleConfig.Command = 'garage'

-- Besitz -----------------------------------------------------------------------
VehicleConfig.Ownership = {
    -- So viele Fahrzeuge darf ein Charakter besitzen.
    maxVehicles = 6,
    -- Kennzeichen: Praefix und Stellenzahl.
    platePrefix = 'MS',
    plateDigits = 5,
    -- Konto fuer Kauf und Verkauf.
    account = 'bank',
    -- Anteil des Neupreises beim Verkauf ans Autohaus.
    resale = 0.45,
}

-- Autohaeuser --------------------------------------------------------------------
VehicleConfig.Dealers = {
    {
        id = 'pdm', label = 'Premium Deluxe Motorsport',
        coords = vector3(-33.8, -1102.4, 26.4),
        heading = 340.0,
        -- Wo das gekaufte Fahrzeug erscheint.
        spawn = vector4(-19.0, -1090.0, 26.1, 70.0),
        -- Welche Kategorien hier verkauft werden.
        categories = { 'kompakt', 'limousine', 'suv', 'sport', 'muscle', 'gelaende' },
        blip = { sprite = 326, colour = 3, scale = 0.8 },
    },
    {
        id = 'lucky', label = 'Larrys RV Sales',
        coords = vector3(1225.6, 2728.0, 38.0),
        heading = 0.0,
        spawn = vector4(1238.0, 2723.0, 38.0, 90.0),
        categories = { 'kompakt', 'suv', 'gelaende', 'nutzfahrzeug' },
        blip = { sprite = 326, colour = 3, scale = 0.7 },
    },
    {
        id = 'bikes', label = 'Motorradhaendler',
        coords = vector3(1226.5, 2603.0, 45.9),
        heading = 190.0,
        spawn = vector4(1233.0, 2612.0, 45.9, 0.0),
        categories = { 'motorrad' },
        blip = { sprite = 226, colour = 3, scale = 0.7 },
    },
}

-- Garagen -------------------------------------------------------------------------
VehicleConfig.Garages = {
    { id = 'innenstadt', label = 'Garage Innenstadt',
      coords = vector3(215.0, -800.0, 30.8),
      spawn  = vector4(228.0, -795.0, 30.6, 250.0) },

    { id = 'hafen', label = 'Garage Hafen',
      coords = vector3(-57.0, -1093.0, 26.4),
      spawn  = vector4(-70.0, -1100.0, 26.4, 340.0) },

    { id = 'sandy', label = 'Garage Sandy Shores',
      coords = vector3(1735.0, 3316.0, 41.2),
      spawn  = vector4(1745.0, 3325.0, 41.2, 195.0) },

    { id = 'paleto', label = 'Garage Paleto Bay',
      coords = vector3(105.0, 6614.0, 31.8),
      spawn  = vector4(115.0, 6620.0, 31.5, 45.0) },

    { id = 'vinewood', label = 'Garage Vinewood',
      coords = vector3(-1157.0, -742.0, 19.7),
      spawn  = vector4(-1145.0, -735.0, 19.4, 30.0) },

    { id = 'grapeseed', label = 'Garage Grapeseed',
      coords = vector3(1697.0, 4928.0, 42.1),
      spawn  = vector4(1706.0, 4935.0, 42.0, 100.0) },
}

--- Radius fuer Marker und Interaktion.
VehicleConfig.Range = 2.5

--- Blip fuer Garagen.
VehicleConfig.GarageBlip = {
    enabled = true,
    sprite  = 357,
    colour  = 3,
    scale   = 0.7,
    label   = 'Garage',
}

-- Verwahrstelle --------------------------------------------------------------------
VehicleConfig.Impound = {
    enabled = true,
    label   = 'Verwahrstelle',
    coords  = vector3(409.0, -1622.0, 29.3),
    spawn   = vector4(400.0, -1637.0, 29.3, 230.0),
    -- Kosten fuer die Auslösung.
    fee     = 5000,
    account = 'bank',
    blip = { sprite = 68, colour = 1, scale = 0.7 },
}

-- Zustand ----------------------------------------------------------------------------
VehicleConfig.State = {
    -- Zustand wird alle X Sekunden gemeldet, solange man faehrt.
    reportInterval = 25,
    -- Startwerte eines neuen Fahrzeugs.
    startFuel = 100.0,
    -- Verbrauch je Minute bei laufendem Motor (Prozentpunkte).
    fuelPerMinute = 1.4,
    -- Unter diesem Wert geht der Motor aus.
    stallBelow = 0.4,
    -- Tanken: Preis je Prozentpunkt.
    fuelPrice = 45,
    -- Tankstellen-Radius.
    stationRange = 12.0,
}

-- Schluessel ---------------------------------------------------------------------------
VehicleConfig.Keys = {
    enabled = true,
    -- Ohne Schluessel springt der Motor nicht an.
    lockEngine = true,
    -- Reichweite zum Ver- und Entriegeln.
    range = 8.0,
    -- Taste zum Ver-/Entriegeln.
    lockKey = 'L',
}

--- Kennzeichen bereinigen (Vergleich mit dem Spiel).
function Vehicles.CleanPlate(plate)
    return tostring(plate or ''):gsub('%s+$', ''):gsub('^%s+', '')
end

--- Garage oder Autohaus an einer Position.
---@return table|nil entry, string kind
function Vehicles.PointAt(coords)
    for _, garage in ipairs(VehicleConfig.Garages) do
        if #(coords - garage.coords) <= VehicleConfig.Range + 2.0 then
            return garage, 'garage'
        end
    end

    for _, dealer in ipairs(VehicleConfig.Dealers) do
        if #(coords - dealer.coords) <= VehicleConfig.Range + 2.0 then
            return dealer, 'dealer'
        end
    end

    if VehicleConfig.Impound.enabled
        and #(coords - VehicleConfig.Impound.coords) <= VehicleConfig.Range + 2.0 then
        return VehicleConfig.Impound, 'impound'
    end

    return nil, ''
end

--- Garage anhand ihrer Kennung.
function Vehicles.GetGarage(id)
    for _, garage in ipairs(VehicleConfig.Garages) do
        if garage.id == id then return garage end
    end
    return nil
end

function Vehicles.GetDealer(id)
    for _, dealer in ipairs(VehicleConfig.Dealers) do
        if dealer.id == id then return dealer end
    end
    return nil
end
