--- Fahrzeugkatalog.
---
--- Preise sind Ingame-Waehrung. `seats` und `speed` dienen nur der Anzeige.

Vehicles.Categories = {
    { id = 'kompakt',       label = 'Kompakt',       icon = '🚗' },
    { id = 'limousine',     label = 'Limousinen',    icon = '🚙' },
    { id = 'suv',           label = 'SUV',           icon = '🚐' },
    { id = 'sport',         label = 'Sportwagen',    icon = '🏎' },
    { id = 'muscle',        label = 'Muscle',        icon = '🔧' },
    { id = 'gelaende',      label = 'Gelaende',      icon = '🛻' },
    { id = 'motorrad',      label = 'Motorraeder',   icon = '🏍' },
    { id = 'nutzfahrzeug',  label = 'Nutzfahrzeuge', icon = '🚚' },
}

Vehicles.Catalogue = {

    -- Kompakt --------------------------------------------------------------
    { model = 'blista',   label = 'Blista',      category = 'kompakt',   price =  32000, seats = 4, speed = 3 },
    { model = 'panto',    label = 'Panto',       category = 'kompakt',   price =  18000, seats = 2, speed = 2 },
    { model = 'issi2',    label = 'Issi',        category = 'kompakt',   price =  26000, seats = 2, speed = 3 },
    { model = 'prairie',  label = 'Prairie',     category = 'kompakt',   price =  35000, seats = 4, speed = 3 },
    { model = 'dilettante', label = 'Dilettante', category = 'kompakt',  price =  29000, seats = 4, speed = 2 },

    -- Limousinen -----------------------------------------------------------
    { model = 'asea',     label = 'Asea',        category = 'limousine', price =  24000, seats = 4, speed = 2 },
    { model = 'premier',  label = 'Premier',     category = 'limousine', price =  42000, seats = 4, speed = 3 },
    { model = 'washington', label = 'Washington', category = 'limousine', price = 55000, seats = 4, speed = 3 },
    { model = 'tailgater', label = 'Tailgater',  category = 'limousine', price =  78000, seats = 4, speed = 4 },
    { model = 'sultan',   label = 'Sultan',      category = 'limousine', price =  95000, seats = 4, speed = 4 },
    { model = 'schafter2', label = 'Schafter',   category = 'limousine', price = 125000, seats = 4, speed = 4 },

    -- SUV ------------------------------------------------------------------
    { model = 'baller',   label = 'Baller',      category = 'suv',       price = 145000, seats = 4, speed = 4 },
    { model = 'cavalcade', label = 'Cavalcade',  category = 'suv',       price =  98000, seats = 4, speed = 3 },
    { model = 'landstalker', label = 'Landstalker', category = 'suv',    price =  72000, seats = 4, speed = 3 },
    { model = 'granger',  label = 'Granger',     category = 'suv',       price =  88000, seats = 4, speed = 3 },
    { model = 'xls',      label = 'XLS',         category = 'suv',       price = 165000, seats = 4, speed = 4 },

    -- Sportwagen -----------------------------------------------------------
    { model = 'kuruma',   label = 'Kuruma',      category = 'sport',     price = 195000, seats = 4, speed = 5 },
    { model = 'jester',   label = 'Jester',      category = 'sport',     price = 285000, seats = 2, speed = 5 },
    { model = 'elegy2',   label = 'Elegy RH8',   category = 'sport',     price = 240000, seats = 2, speed = 5 },
    { model = 'comet2',   label = 'Comet',       category = 'sport',     price = 320000, seats = 2, speed = 5 },
    { model = 'feltzer2', label = 'Feltzer',     category = 'sport',     price = 275000, seats = 2, speed = 5 },
    { model = 'ninef',    label = 'Nine-F',      category = 'sport',     price = 250000, seats = 2, speed = 5 },
    { model = 'banshee',  label = 'Banshee',     category = 'sport',     price = 310000, seats = 2, speed = 5 },

    -- Muscle ---------------------------------------------------------------
    { model = 'dominator', label = 'Dominator',  category = 'muscle',    price = 165000, seats = 2, speed = 4 },
    { model = 'gauntlet', label = 'Gauntlet',    category = 'muscle',    price = 148000, seats = 2, speed = 4 },
    { model = 'buffalo3', label = 'Buffalo S',   category = 'muscle',    price = 185000, seats = 4, speed = 5 },
    { model = 'sabregt',  label = 'Sabre Turbo', category = 'muscle',    price = 132000, seats = 2, speed = 4 },
    { model = 'ruiner',   label = 'Ruiner',      category = 'muscle',    price = 118000, seats = 2, speed = 4 },
    { model = 'vigero',   label = 'Vigero',      category = 'muscle',    price =  95000, seats = 2, speed = 4 },

    -- Gelaende -------------------------------------------------------------
    { model = 'sandking2', label = 'Sandking',   category = 'gelaende',  price = 135000, seats = 4, speed = 3 },
    { model = 'rebel2',   label = 'Rebel',       category = 'gelaende',  price =  68000, seats = 2, speed = 3 },
    { model = 'bison',    label = 'Bison',       category = 'gelaende',  price =  62000, seats = 4, speed = 3 },
    { model = 'bodhi2',   label = 'Bodhi',       category = 'gelaende',  price =  58000, seats = 4, speed = 3 },
    { model = 'kalahari', label = 'Kalahari',    category = 'gelaende',  price =  45000, seats = 2, speed = 2 },

    -- Motorraeder ----------------------------------------------------------
    { model = 'akuma',    label = 'Akuma',       category = 'motorrad',  price =  85000, seats = 2, speed = 5 },
    { model = 'bati',     label = 'Bati 801',    category = 'motorrad',  price = 115000, seats = 2, speed = 5 },
    { model = 'faggio2',  label = 'Faggio',      category = 'motorrad',  price =  12000, seats = 2, speed = 1 },
    { model = 'sanchez',  label = 'Sanchez',     category = 'motorrad',  price =  38000, seats = 2, speed = 3 },
    { model = 'hexer',    label = 'Hexer',       category = 'motorrad',  price =  72000, seats = 2, speed = 4 },
    { model = 'daemon',   label = 'Daemon',      category = 'motorrad',  price =  68000, seats = 2, speed = 4 },

    -- Nutzfahrzeuge --------------------------------------------------------
    { model = 'rumpo',    label = 'Rumpo',       category = 'nutzfahrzeug', price =  70000, seats = 4, speed = 2 },
    { model = 'burrito3', label = 'Burrito',     category = 'nutzfahrzeug', price =  64000, seats = 4, speed = 2 },
    { model = 'pounder',  label = 'Pounder',     category = 'nutzfahrzeug', price = 185000, seats = 2, speed = 1 },
    { model = 'mule',     label = 'Mule',        category = 'nutzfahrzeug', price = 120000, seats = 2, speed = 2 },
}

Vehicles.CatalogueByModel = {}
for _, entry in ipairs(Vehicles.Catalogue) do
    Vehicles.CatalogueByModel[entry.model] = entry
end

--- Katalogeintrag zu einem Modell.
function Vehicles.GetModel(model)
    if type(model) ~= 'string' then return nil end
    return Vehicles.CatalogueByModel[model:lower()]
end

--- Alle Fahrzeuge einer Kategorie.
function Vehicles.GetByCategory(category)
    local list = {}

    for _, entry in ipairs(Vehicles.Catalogue) do
        if entry.category == category then list[#list + 1] = entry end
    end

    table.sort(list, function(a, b) return a.price < b.price end)
    return list
end

--- Alle Fahrzeuge, die ein bestimmtes Autohaus fuehrt.
function Vehicles.GetForDealer(dealer)
    local list = {}
    if not dealer then return list end

    local allowed = {}
    for _, category in ipairs(dealer.categories or {}) do allowed[category] = true end

    for _, entry in ipairs(Vehicles.Catalogue) do
        if allowed[entry.category] then list[#list + 1] = entry end
    end

    table.sort(list, function(a, b)
        if a.category ~= b.category then return a.category < b.category end
        return a.price < b.price
    end)

    return list
end

--- Bezeichnung einer Kategorie.
function Vehicles.GetCategoryLabel(id)
    for _, entry in ipairs(Vehicles.Categories) do
        if entry.id == id then return entry.label end
    end
    return id
end
