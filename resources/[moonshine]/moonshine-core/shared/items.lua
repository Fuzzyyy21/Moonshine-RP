--- Item-Definitionen.
--- weight    = Gewicht in Gramm
--- stack     = stapelbar (mehrere Einheiten pro Slot)
--- usable    = kann per Inventar/Command benutzt werden
--- closeUi   = Inventar schliesst sich beim Benutzen
MS.Items = {
    bread = {
        label = 'Brot', weight = 200, stack = true, usable = true, closeUi = true,
        description = 'Stillt den Hunger.',
    },
    water = {
        label = 'Wasserflasche', weight = 500, stack = true, usable = true, closeUi = true,
        description = 'Loescht den Durst.',
    },
    burger = {
        label = 'Burger', weight = 300, stack = true, usable = true, closeUi = true,
        description = 'Fettig, aber saettigend.',
    },
    cola = {
        label = 'Cola', weight = 500, stack = true, usable = true, closeUi = true,
        description = 'Zuckrig und kalt.',
    },
    bandage = {
        label = 'Verband', weight = 100, stack = true, usable = true, closeUi = true,
        description = 'Stellt etwas Leben wieder her.',
    },
    phone = {
        label = 'Handy', weight = 180, stack = false, usable = true, closeUi = true,
        description = 'Smartphone mit Rissen im Display.',
    },
    radio = {
        label = 'Funkgeraet', weight = 350, stack = false, usable = true, closeUi = true,
        description = 'Kurzstreckenfunk.',
    },
    lockpick = {
        label = 'Dietrich', weight = 120, stack = true, usable = true, closeUi = true,
        description = 'Oeffnet einfache Schloesser. Meistens.',
    },
    repairkit = {
        label = 'Reparaturkit', weight = 4000, stack = true, usable = true, closeUi = true,
        description = 'Behebt leichte Fahrzeugschaeden.',
    },
    money_roll = {
        label = 'Geldbuendel', weight = 50, stack = true, usable = false,
        description = 'Ein Buendel gebrauchter Scheine.',
    },
    id_card = {
        label = 'Personalausweis', weight = 10, stack = false, usable = true, closeUi = false,
        description = 'Amtlicher Lichtbildausweis.',
    },
}

--- Liefert die Item-Definition oder nil.
function MS.GetItem(name)
    if type(name) ~= 'string' then return nil end
    return MS.Items[name]
end

--- Registriert ein Item zur Laufzeit, damit andere Resources eigene Items
--- mitbringen koennen. Muss auf Server UND Client aufgerufen werden.
---@param name string
---@param definition table { label, weight, stack, usable, closeUi, description }
function MS.RegisterItem(name, definition)
    if type(name) ~= 'string' or type(definition) ~= 'table' then return false end

    MS.Items[name] = {
        label       = definition.label or name,
        weight      = definition.weight or 100,
        stack       = definition.stack ~= false,
        usable      = definition.usable or false,
        closeUi     = definition.closeUi ~= false,
        description = definition.description or '',
    }
    return true
end

--- Gewicht einer bestimmten Menge eines Items.
function MS.GetItemWeight(name, count)
    local item = MS.GetItem(name)
    if not item then return 0 end
    return item.weight * (count or 1)
end
