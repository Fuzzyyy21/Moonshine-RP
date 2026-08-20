--- Die Plaetze, an denen man sich einrichten kann.
---
--- Jeder Platz hat eine `art`. Wessen Klasse dazu passt (RefugeConfig.Kinds),
--- rastet dort besser - ein Vampir in einer Gruft schlaeft tiefer als ein
--- Vampir in einer Jagdhuette. Kaufen darf sie trotzdem jeder.
---
--- Die Koordinaten sind Schaetzwerte von der Karte und gehoeren vor dem
--- Livegang einmal nachgemessen. Der `zutritt` ist der Punkt, an dem der
--- Marker steht; `aufwachen` der Punkt, an dem man nach einer Zuflucht
--- wieder steht.

Refuge.Places = {
    -- Gruefte -----------------------------------------------------------------
    {
        id = 'vinewood_gruft', label = 'Gruft am Vinewood-Friedhof', art = 'gruft',
        preis = 320000,
        beschreibung = 'Eine zugewachsene Familiengruft am Rand des alten Friedhofs.',
        zutritt  = vector3(-1687.4, -282.6, 51.6),
        aufwachen = vector4(-1685.9, -281.2, 51.6, 130.0),
    },
    {
        id = 'paleto_gruft', label = 'Grabkammer Paleto', art = 'gruft',
        preis = 245000,
        beschreibung = 'Unter der kleinen Kapelle im Norden. Trocken und still.',
        zutritt  = vector3(-321.5, 6238.4, 31.5),
        aufwachen = vector4(-322.8, 6236.9, 31.5, 45.0),
    },

    -- Hoehlen -------------------------------------------------------------------
    {
        id = 'chiliad_hoehle', label = 'Hoehle am Mount Chiliad', art = 'hoehle',
        preis = 280000,
        beschreibung = 'Ein Spalt im Fels, hoch genug, dass niemand hinauffindet.',
        zutritt  = vector3(390.2, 5614.6, 578.0),
        aufwachen = vector4(391.8, 5613.1, 578.0, 200.0),
    },
    {
        id = 'zancudo_hoehle', label = 'Felsspalt am Zancudo', art = 'hoehle',
        preis = 235000,
        beschreibung = 'Am Flussufer, hinter dem Schilf. Man riecht das Wasser.',
        zutritt  = vector3(-2088.7, 2604.1, 3.1),
        aufwachen = vector4(-2087.2, 2602.8, 3.1, 310.0),
    },

    -- Tuerme ---------------------------------------------------------------------
    {
        id = 'kortz_turm', label = 'Turm ueber Kortz', art = 'turm',
        preis = 410000,
        beschreibung = 'Ein alter Wasserturm mit Blick ueber die ganze Bucht.',
        zutritt  = vector3(-2246.8, 264.3, 174.6),
        aufwachen = vector4(-2245.4, 265.7, 174.6, 90.0),
    },
    {
        id = 'palomino_turm', label = 'Leuchtturm Palomino', art = 'turm',
        preis = 360000,
        beschreibung = 'Ausser Betrieb seit Jahren. Die Treppe knarzt.',
        zutritt  = vector3(3428.9, 5171.2, 20.7),
        aufwachen = vector4(3427.5, 5172.6, 20.7, 175.0),
    },

    -- Haine ------------------------------------------------------------------------
    {
        id = 'chiliad_hain', label = 'Lichtung am Chiliad', art = 'hain',
        preis = 265000,
        beschreibung = 'Ein Ring alter Baeume. Hier wird es nie ganz dunkel.',
        zutritt  = vector3(-1290.6, 4520.9, 40.2),
        aufwachen = vector4(-1289.1, 4522.3, 40.2, 20.0),
    },
    {
        id = 'raton_hain', label = 'Weidenhain am Raton', art = 'hain',
        preis = 225000,
        beschreibung = 'Am Flusslauf, zwischen den Weiden versteckt.',
        zutritt  = vector3(-1748.3, 4419.5, 2.7),
        aufwachen = vector4(-1747.0, 4420.8, 2.7, 255.0),
    },

    -- Ruinen ------------------------------------------------------------------------
    {
        id = 'grand_ruine', label = 'Ruine am Grand Senora', art = 'ruine',
        preis = 210000,
        beschreibung = 'Vier Waende ohne Dach. Der Kreis im Boden war schon da.',
        zutritt  = vector3(1470.8, 3243.9, 41.0),
        aufwachen = vector4(1469.4, 3245.2, 41.0, 60.0),
    },
    {
        id = 'altruist_ruine', label = 'Verlassenes Lager', art = 'ruine',
        preis = 250000,
        beschreibung = 'Was die Altruisten zurueckgelassen haben, steht noch.',
        zutritt  = vector3(-1130.2, 4900.6, 216.0),
        aufwachen = vector4(-1131.6, 4899.2, 216.0, 300.0),
    },

    -- Keller ---------------------------------------------------------------------------
    {
        id = 'hafen_keller', label = 'Kellergewoelbe am Hafen', art = 'keller',
        preis = 275000,
        beschreibung = 'Unter einer Lagerhalle. Es ist immer zu warm hier unten.',
        zutritt  = vector3(486.1, -3115.4, 6.0),
        aufwachen = vector4(484.7, -3114.0, 6.0, 90.0),
    },
    {
        id = 'strawberry_keller', label = 'Heizkeller Strawberry', art = 'keller',
        preis = 195000,
        beschreibung = 'Der Kessel laeuft noch. Niemand weiss, wer ihn bezahlt.',
        zutritt  = vector3(288.4, -1849.2, 26.4),
        aufwachen = vector4(287.0, -1847.9, 26.4, 320.0),
    },

    -- Huetten ------------------------------------------------------------------------------
    {
        id = 'paleto_huette', label = 'Jagdhuette bei Paleto', art = 'huette',
        preis = 230000,
        beschreibung = 'Ein Zimmer, ein Ofen, Geweihe an der Wand.',
        zutritt  = vector3(-773.5, 5602.1, 33.6),
        aufwachen = vector4(-772.1, 5603.5, 33.6, 210.0),
    },
    {
        id = 'grapeseed_huette', label = 'Schuppen bei Grapeseed', art = 'huette',
        preis = 185000,
        beschreibung = 'Mehr Schuppen als Huette, aber er steht abseits.',
        zutritt  = vector3(2447.9, 4968.4, 46.8),
        aufwachen = vector4(2446.5, 4969.8, 46.8, 145.0),
    },
}

--- Platz nach Id.
function Refuge.GetPlace(id)
    for _, place in ipairs(Refuge.Places) do
        if place.id == id then return place end
    end

    return nil
end

--- Alle Arten, die es gibt.
function Refuge.Arts()
    local reihe, gesehen = {}, {}

    for _, place in ipairs(Refuge.Places) do
        if not gesehen[place.art] then
            gesehen[place.art] = true
            reihe[#reihe + 1] = place.art
        end
    end

    return reihe
end

--- Der naechstgelegene Platz zu einer Position.
function Refuge.NearestPlace(coords, range)
    local best, distance = nil, range or 3.0

    for _, place in ipairs(Refuge.Places) do
        local d = #(coords - place.zutritt)
        if d <= distance then best, distance = place, d end
    end

    return best, distance
end
