ShopConfig = {}

--- Konto von dem bezahlt wird.
ShopConfig.Account = 'cash'

--- Sortiment aller 24/7-Laeden.
ShopConfig.Items = {
    { name = 'bread',   price = 15  },
    { name = 'water',   price = 12  },
    { name = 'burger',  price = 35  },
    { name = 'cola',    price = 18  },
    { name = 'bandage', price = 120 },
    { name = 'phone',   price = 950 },
    -- Notfallset fuer Wiederbelebungen (moonshine-death)
    { name = 'medikit',      price = 800 },
}

--- Standorte der Laeden.
ShopConfig.Locations = {
    vector3(25.7, -1347.3, 29.5),      -- Innocence Blvd
    vector3(-3038.9, 585.9, 7.9),      -- Great Ocean Hwy
    vector3(-1222.9, -906.9, 12.3),    -- Bay City Ave
    vector3(1729.2, 6414.1, 35.0),     -- Paleto Bay
    vector3(1163.3, -323.8, 69.2),     -- Mirror Park
}

ShopConfig.Blip = {
    enabled = true,
    sprite  = 52,
    color   = 2,
    scale   = 0.6,
    label   = '24/7 Laden',
}
